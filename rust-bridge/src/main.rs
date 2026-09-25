// Qwen-Image Studio Rust Bridge & Accelerator
// Part of the simonez.qwenimage Omarchy Plugin
// Author: simonez & Arci

mod prompts_db;

use image::imageops::FilterType;
use image::GenericImageView;
use serde::Serialize;
use std::collections::HashMap;
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const SA_SIGNATURE_DNA: u32 = 0x732641;
const COMFY_URL: &str = "http://127.0.0.1:8188";
const CHIME_SOUND: &str = "/usr/share/sounds/freedesktop/stereo/complete.oga";

fn get_home() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| env::var("USERPROFILE").map(PathBuf::from))
        .unwrap_or_else(|_| PathBuf::from("."))
}

fn get_ai_worker_bin() -> PathBuf {
    let local = get_home().join(".local").join("bin").join("ai-worker");
    if local.exists() {
        local
    } else {
        PathBuf::from("ai-worker")
    }
}

fn get_qwen_image_bin() -> PathBuf {
    let local = get_home().join(".local").join("bin").join("qwen-image");
    if local.exists() {
        local
    } else {
        PathBuf::from("qwen-image")
    }
}

fn get_temp_dir() -> PathBuf {
    let p = get_home().join("Ai-temp");
    let _ = fs::create_dir_all(&p);
    p
}

fn get_gallery_dir() -> PathBuf {
    let p = get_home().join("Pictures").join("Qwen-Image");
    let _ = fs::create_dir_all(&p);
    p
}

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

fn play_chime() {
    if Path::new(CHIME_SOUND).exists() {
        let _ = Command::new("pw-play")
            .arg(CHIME_SOUND)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }
}

fn send_notification(title: &str, body: &str, image_path: Option<&str>) {
    if let Some(p) = image_path {
        if Path::new(p).exists() {
            // 1. Native Omarchy notification with full preview and click-to-open
            let mut omarchy_cmd = Command::new("omarchy-notification-send");
            omarchy_cmd.args([
                "--app-name", "Qwen Studio",
                "--image", p,
                "-i", p,
                "--urgency", "normal",
                title, body,
                "--exec", "xdg-open", p
            ]);
            if let Ok(mut child) = omarchy_cmd.spawn() {
                let _ = child.wait();
                return;
            }

            // 2. Fallback to notify-send with proper option ordering
            let mut cmd = Command::new("notify-send");
            cmd.args([
                "-a", "Qwen Studio",
                "-i", p,
                "-h", &format!("string:image-path:{}", p),
                title,
                body,
            ]);
            let _ = cmd.stdout(Stdio::null()).stderr(Stdio::null()).spawn();
            return;
        }
    }

    let mut cmd = Command::new("notify-send");
    cmd.args(["-a", "Qwen Studio", title, body]);
    let _ = cmd.stdout(Stdio::null()).stderr(Stdio::null()).spawn();
}

fn is_game_process_running() -> bool {
    let proc_dir = match fs::read_dir("/proc") {
        Ok(d) => d,
        Err(_) => return false,
    };

    let own_pid = std::process::id();

    // High-confidence game signatures (case-insensitive)
    let game_signatures = [
        "zenless",
        "mhypbase",
        "gamescope",
        "steam_app",
        "wine64",
        "wine-preloader",
        "lutris",
        "heroic",
        "genshin",
        "starrail",
    ];

    for entry in proc_dir.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if let Ok(pid) = name_str.parse::<u32>() {
            if pid == own_pid {
                continue;
            }

            let pid_path = entry.path();

            // 1. Check /proc/[pid]/cmdline
            let cmdline_path = pid_path.join("cmdline");
            if let Ok(cmd_bytes) = fs::read(&cmdline_path) {
                if !cmd_bytes.is_empty() {
                    let cmd_lower = String::from_utf8_lossy(&cmd_bytes).to_lowercase();

                    // CRITICAL: Exclude game-guard background watchdog or python scripts
                    if cmd_lower.contains("game-guard") {
                        continue;
                    }

                    for &sig in &game_signatures {
                        if cmd_lower.contains(sig) {
                            return true;
                        }
                    }

                    if cmd_lower.contains(".exe") && (cmd_lower.contains("wine") || cmd_lower.contains("proton")) {
                        return true;
                    }
                }
            }

            // 2. Check /proc/[pid]/comm
            let comm_path = pid_path.join("comm");
            if let Ok(comm_str) = fs::read_to_string(&comm_path) {
                let comm_lower = comm_str.trim().to_lowercase();
                if comm_lower.contains("game-guard") {
                    continue;
                }
                for &sig in &game_signatures {
                    if comm_lower.contains(sig) {
                        return true;
                    }
                }
            }
        }
    }

    false
}

fn get_ollama_status() -> (u32, Vec<String>) {
    let agent = get_http_agent(1);
    let mut total_vram_mb = 0u32;
    let mut models = Vec::new();

    if let Ok(mut resp) = agent.get("http://127.0.0.1:11434/api/ps").call() {
        if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
            if let Some(arr) = val.get("models").and_then(|m| m.as_array()) {
                for m in arr {
                    if let Some(name) = m.get("name").and_then(|n| n.as_str()) {
                        models.push(name.to_string());
                    }
                    let size_vram = m.get("size_vram").and_then(|s| s.as_u64()).unwrap_or(0);
                    let size = m.get("size").and_then(|s| s.as_u64()).unwrap_or(0);
                    let effective = if size_vram > 0 { size_vram } else { size };
                    total_vram_mb = total_vram_mb.saturating_add((effective / (1024 * 1024)) as u32);
                }
            }
        }
    }
    (total_vram_mb, models)
}

fn stop_ollama_models(models: &[String]) {
    for m in models {
        let _ = Command::new("ollama")
            .args(["stop", m])
            .output();
    }
}

fn check_comfyui() -> bool {
    if let Ok(mut stream) = TcpStream::connect_timeout(
        &"127.0.0.1:8188".parse().unwrap(),
        Duration::from_millis(500),
    ) {
        let req = "GET /system_stats HTTP/1.1\r\nHost: 127.0.0.1:8188\r\nConnection: close\r\n\r\n";
        if stream.write_all(req.as_bytes()).is_ok() {
            let mut buf = [0u8; 128];
            if let Ok(n) = stream.read(&mut buf) {
                let s = String::from_utf8_lossy(&buf[..n]);
                return s.contains("200 OK");
            }
        }
    }
    false
}

fn check_ollama() -> bool {
    if let Ok(mut stream) = TcpStream::connect_timeout(
        &"127.0.0.1:11434".parse().unwrap(),
        Duration::from_millis(400),
    ) {
        let req = "GET /api/version HTTP/1.1\r\nHost: 127.0.0.1:11434\r\nConnection: close\r\n\r\n";
        if stream.write_all(req.as_bytes()).is_ok() {
            let mut buf = [0u8; 64];
            if let Ok(n) = stream.read(&mut buf) {
                let s = String::from_utf8_lossy(&buf[..n]);
                return s.contains("200 OK");
            }
        }
    }
    false
}

fn check_wd14() -> bool {
    get_home().join(".local/share/comfyui/custom_nodes/ComfyUI-WD14-Tagger").exists()
}

fn check_civitai() -> bool {
    if let Ok(mut addrs) = "civitai.com:443".to_socket_addrs() {
        if let Some(addr) = addrs.next() {
            return TcpStream::connect_timeout(&addr, Duration::from_millis(800)).is_ok();
        }
    }
    false
}

#[derive(Serialize, Clone)]
struct VramInfo {
    used_mb: u32,
    total_mb: u32,
    free_mb: u32,
    pct: u32,
    name: String,
}

fn get_vram_info() -> VramInfo {
    let mut info = VramInfo {
        used_mb: 0,
        total_mb: 8192,
        free_mb: 8192,
        pct: 0,
        name: "NVIDIA GeForce RTX 3070".to_string(),
    };

    let out = Command::new("nvidia-smi")
        .args([
            "--query-gpu=memory.used,memory.total,memory.free,name",
            "--format=csv,noheader,nounits",
        ])
        .output();

    if let Ok(o) = out {
        let s = String::from_utf8_lossy(&o.stdout);
        let parts: Vec<&str> = s.trim().split(',').map(|p| p.trim()).collect();
        if parts.len() >= 3 {
            if let (Ok(u), Ok(t), Ok(f)) = (
                parts[0].parse::<u32>(),
                parts[1].parse::<u32>(),
                parts[2].parse::<u32>(),
            ) {
                info.used_mb = u;
                info.total_mb = t;
                info.free_mb = f;
                info.pct = u.checked_mul(100).and_then(|val| val.checked_div(t)).unwrap_or(0);
            }
            if parts.len() >= 4 {
                info.name = parts[3].to_string();
            }
        }
    }
    info
}

fn check_gaming_hybrid(vram: &VramInfo) -> (bool, &'static str) {
    let game_running = is_game_process_running();

    // 1. Plentiful VRAM (>= 4.5 GB free) and no active game process -> Never locked
    if vram.free_mb >= 4500 && !game_running {
        return (false, "Plenty of VRAM available");
    }

    // 2. Check Ollama AI memory allocation
    let (ollama_vram_mb, _) = get_ollama_status();

    // 3. Low VRAM condition (< 2.8 GB free)
    if vram.free_mb < 2800 {
        // If a real game process is actively detected, lock immediately
        if game_running {
            return (true, "Game process actively running with low VRAM");
        }

        // If memory is consumed by Ollama, it's AI work (auto-purge ready), not a game lock
        if ollama_vram_mb >= 2500 {
            return (false, "VRAM allocated to Ollama (auto-purge ready)");
        }

        // If ComfyUI is online and holding memory, it's our own generator
        if check_comfyui() && vram.used_mb > 3000 {
            return (false, "VRAM retained by ComfyUI model cache");
        }

        // External heavy 3D / gaming process has eaten VRAM
        return (true, "VRAM constrained by external 3D process (<2.8 GB free)");
    }

    // 4. Moderate VRAM (2.8 GB to 4.5 GB free):
    // Only lock if an explicit game process is running
    if game_running {
        return (true, "Game process actively detected");
    }

    (false, "VRAM sufficient and no game active")
}

// ---------------------------------------------------------
// PNG Metadata & Chunk Processing (Pure Native Rust)
// ---------------------------------------------------------

fn crc32(buf: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &byte in buf {
        crc ^= byte as u32;
        for _ in 0..8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ 0xEDB8_8320;
            } else {
                crc >>= 1;
            }
        }
    }
    !crc
}

fn create_text_chunk(keyword: &str, text: &str) -> Vec<u8> {
    let mut data = Vec::new();
    data.extend_from_slice(keyword.as_bytes());
    data.push(0);
    data.extend_from_slice(text.as_bytes());

    let len = (data.len() as u32).to_be_bytes();
    let mut chunk = Vec::new();
    chunk.extend_from_slice(&len);
    chunk.extend_from_slice(b"tEXt");
    chunk.extend_from_slice(&data);

    let mut crc_data = Vec::new();
    crc_data.extend_from_slice(b"tEXt");
    crc_data.extend_from_slice(&data);
    let crc = crc32(&crc_data).to_be_bytes();
    chunk.extend_from_slice(&crc);

    chunk
}

fn embed_png_metadata<P: AsRef<Path>>(
    path: P,
    meta_pairs: &[(&str, &str)],
) -> std::io::Result<()> {
    let file_bytes = fs::read(&path)?;
    if file_bytes.len() < 8 || file_bytes[..8] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        return Ok(());
    }

    let iend_pos = file_bytes.windows(8).rposition(|w| &w[4..8] == b"IEND");
    let split_pos = if let Some(pos) = iend_pos {
        pos
    } else {
        file_bytes.len()
    };

    let mut new_bytes = Vec::with_capacity(file_bytes.len() + 1024);
    new_bytes.extend_from_slice(&file_bytes[..split_pos]);

    for &(k, v) in meta_pairs {
        if !v.is_empty() {
            let chunk = create_text_chunk(k, v);
            new_bytes.extend_from_slice(&chunk);
        }
    }

    new_bytes.extend_from_slice(&file_bytes[split_pos..]);
    fs::write(path, new_bytes)?;
    Ok(())
}

fn read_png_chunks<P: AsRef<Path>>(path: P) -> HashMap<String, String> {
    let mut map = HashMap::new();
    let Ok(mut f) = File::open(path) else { return map; };

    let mut sig = [0u8; 8];
    if f.read_exact(&mut sig).is_err() || sig != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        return map;
    }

    loop {
        let mut len_buf = [0u8; 4];
        if f.read_exact(&mut len_buf).is_err() { break; }
        let len = u32::from_be_bytes(len_buf) as usize;

        let mut type_buf = [0u8; 4];
        if f.read_exact(&mut type_buf).is_err() { break; }

        if &type_buf == b"tEXt" && len < 2_000_000 {
            let mut data = vec![0u8; len];
            if f.read_exact(&mut data).is_ok() {
                if let Some(pos) = data.iter().position(|&b| b == 0) {
                    let key = String::from_utf8_lossy(&data[..pos]).to_string();
                    let val = String::from_utf8_lossy(&data[pos + 1..]).to_string();
                    map.insert(key, val);
                }
            }
        } else if &type_buf == b"iTXt" && len < 2_000_000 {
            let mut data = vec![0u8; len];
            if f.read_exact(&mut data).is_ok() {
                if let Some(pos) = data.iter().position(|&b| b == 0) {
                    let key = String::from_utf8_lossy(&data[..pos]).to_string();
                    if pos + 2 < data.len() {
                        let comp_flag = data[pos + 1];
                        if comp_flag == 0 {
                            let rest = &data[pos + 3..];
                            let mut nulls = 0;
                            let mut start_text = 0;
                            for (i, &b) in rest.iter().enumerate() {
                                if b == 0 {
                                    nulls += 1;
                                    if nulls == 2 {
                                        start_text = i + 1;
                                        break;
                                    }
                                }
                            }
                            if start_text < rest.len() {
                                let val = String::from_utf8_lossy(&rest[start_text..]).to_string();
                                map.insert(key, val);
                            }
                        }
                    }
                }
            }
        } else if &type_buf == b"IEND" {
            break;
        } else {
            if f.seek(SeekFrom::Current(len as i64)).is_err() {
                break;
            }
        }

        if f.seek(SeekFrom::Current(4)).is_err() {
            break;
        }
    }
    map
}

fn parse_comfy_prompt(raw_json: &str) -> Option<String> {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw_json) {
        if let Some(obj) = v.as_object() {
            for (_node_id, node_val) in obj {
                let class_type = node_val.get("class_type").and_then(|c| c.as_str()).unwrap_or("");
                if class_type.contains("CLIPTextEncode") || class_type.contains("TextEncode") {
                    if let Some(inputs) = node_val.get("inputs") {
                        if let Some(text) = inputs.get("text").and_then(|t| t.as_str()) {
                            if !text.is_empty() {
                                return Some(text.to_string());
                            }
                        }
                        if let Some(prompt) = inputs.get("prompt").and_then(|t| t.as_str()) {
                            if !prompt.is_empty() {
                                return Some(prompt.to_string());
                            }
                        }
                    }
                }
            }
        }
    }
    None
}

fn detect_qwen_model() -> String {
    let comfy_models = get_home().join(".local/share/comfyui/models/diffusion_models");
    if let Ok(entries) = fs::read_dir(comfy_models) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
                let lower = file_name.to_lowercase();
                if lower.contains("qwen") && (lower.ends_with(".gguf") || lower.ends_with(".safetensors")) {
                    let clean = file_name.trim_end_matches(".gguf").trim_end_matches(".safetensors");
                    if clean.contains("2.1") && clean.contains("Q4_K_M") {
                        return "Qwen-Image 2.1 Heretic (DiT Q4)".to_string();
                    }
                    return clean.replace('_', " ");
                }
            }
        }
    }
    "Qwen-Image 2.1 Heretic".to_string()
}

fn get_driver_version() -> String {
    if let Ok(content) = fs::read_to_string("/proc/driver/nvidia/version") {
        for line in content.lines() {
            if line.contains("NVRM version:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                for part in parts {
                    if part.chars().all(|c| c.is_ascii_digit() || c == '.') && part.contains('.') {
                        return part.to_string();
                    }
                }
            }
        }
    }
    if let Ok(o) = Command::new("nvidia-smi")
        .args(["--query-gpu=driver_version", "--format=csv,noheader"])
        .output()
    {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if !s.is_empty() {
            return s;
        }
    }
    "N/A".to_string()
}

fn get_quickshell_version() -> String {
    if let Ok(o) = Command::new("quickshell").arg("--version").output() {
        let s = String::from_utf8_lossy(&o.stdout);
        if let Some(v) = s.split_whitespace().nth(1) {
            return v.to_string();
        }
    }
    "0.3.1".to_string()
}

fn get_hyprland_version() -> String {
    if let Ok(o) = Command::new("hyprctl").arg("version").output() {
        let s = String::from_utf8_lossy(&o.stdout);
        if let Some(v) = s.split_whitespace().nth(1) {
            return v.to_string();
        }
    }
    "0.56.2".to_string()
}

fn get_stack_versions(comfy_online: bool, ollama_online: bool) -> serde_json::Value {
    let mut comfy_ver = if comfy_online { "Online".to_string() } else { "Offline".to_string() };
    let mut pytorch_ver = String::new();
    let qwen_model = detect_qwen_model();

    let agent = get_http_agent(1);

    if comfy_online {
        if let Ok(mut res) = agent.get("http://127.0.0.1:8188/system_stats").call() {
            if let Ok(val) = res.body_mut().read_json::<serde_json::Value>() {
                if let Some(sys) = val.get("system") {
                    if let Some(v) = sys.get("comfyui_version").and_then(|v| v.as_str()) {
                        comfy_ver = v.to_string();
                    }
                    if let Some(p) = sys.get("pytorch_version").and_then(|v| v.as_str()) {
                        pytorch_ver = p.to_string();
                    }
                }
            }
        }
    }

    let mut ollama_ver = if ollama_online { "Online".to_string() } else { "Offline".to_string() };
    if ollama_online {
        if let Ok(mut res) = agent.get("http://127.0.0.1:11434/api/version").call() {
            if let Ok(val) = res.body_mut().read_json::<serde_json::Value>() {
                if let Some(v) = val.get("version").and_then(|v| v.as_str()) {
                    ollama_ver = v.to_string();
                }
            }
        }
    }

    let driver = get_driver_version();
    let qs = get_quickshell_version();
    let hypr = get_hyprland_version();

    serde_json::json!({
        "qwen_model": qwen_model,
        "comfyui": comfy_ver,
        "pytorch": pytorch_ver,
        "ollama": ollama_ver,
        "driver": driver,
        "quickshell": qs,
        "hyprland": hypr,
        "plugin": "1.0.0"
    })
}

// ---------------------------------------------------------
// CLI Commands Implementation
// ---------------------------------------------------------

fn cmd_status() {
    let online = check_comfyui();
    let vram = get_vram_info();
    let (gaming, reason) = check_gaming_hybrid(&vram);
    let ollama_ok = check_ollama();
    let wd14_ok = check_wd14();
    let civitai_ok = check_civitai();
    let versions = get_stack_versions(online, ollama_ok);

    let status_str = if gaming {
        "LOCKED (GAME)"
    } else if !online {
        "OFFLINE"
    } else {
        "READY"
    };

    let val = serde_json::json!({
        "online": online,
        "backend_url": COMFY_URL,
        "gpu_name": vram.name,
        "vram_used_mb": vram.used_mb,
        "vram_total_mb": vram.total_mb,
        "vram_free_mb": vram.free_mb,
        "vram_pct": vram.pct,
        "game_locked": gaming,
        "lock_reason": reason,
        "status": status_str,
        "services": {
            "comfyui": online,
            "gpu": !gaming,
            "ollama": ollama_ok,
            "wd14": wd14_ok,
            "civitai": civitai_ok,
        },
        "versions": versions,
        "temp_dir": get_temp_dir().to_string_lossy(),
        "gallery_dir": get_gallery_dir().to_string_lossy(),
    });
    println!("{}", val);
}

fn cmd_paste_clipboard() {
    let ts = now_millis();
    let target = get_temp_dir().join(format!("clip_{}.png", ts));

    let out = Command::new("wl-paste")
        .args(["-t", "image/png"])
        .output();

    if let Ok(o) = out {
        if o.status.success() && o.stdout.len() > 64 && fs::write(&target, &o.stdout).is_ok() {
            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "path": target.to_string_lossy()
                })
            );
            return;
        }
    }

    println!(
        "{}",
        serde_json::json!({
            "status": "error",
            "message": "No PNG image found in Wayland clipboard"
        })
    );
}

fn cmd_snip() {
    let _ = Command::new("/usr/share/omarchy/bin/omarchy-capture-screenshot")
        .args(["region", "copy"])
        .status();
    cmd_paste_clipboard();
}

fn cmd_wallpaper(input_path: &str) {
    let p = Path::new(input_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", input_path)})
        );
        return;
    }

    let res = Command::new("omarchy")
        .args(["wallpaper", "set", input_path])
        .output();

    if let Ok(o) = res {
        if o.status.success() {
            println!(
                "{}",
                serde_json::json!({"status": "ok", "message": "Wallpaper updated successfully via Omarchy"})
            );
            return;
        }
    }

    let res2 = Command::new("swww")
        .args(["img", input_path, "--transition-type", "fade", "--transition-duration", "1"])
        .output();

    let success = res2.map(|o| o.status.success()).unwrap_or(false);
    println!(
        "{}",
        serde_json::json!({"status": if success { "ok" } else { "error" }, "message": "Wallpaper fallback applied"})
    );
}

fn cmd_scale(input_path: &str, factor: f32) {
    let p = Path::new(input_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", input_path)})
        );
        return;
    }

    let img_res = image::open(p);
    if let Ok(img) = img_res {
        let (w, h) = img.dimensions();
        let (new_w, new_h) = if factor <= 0.0 {
            let max_dim = w.max(h) as f32;
            let scale_ratio = if max_dim <= 1024.0 { 1.0 } else { 1024.0 / max_dim };
            let nw = (w as f32 * scale_ratio) as u32;
            let nh = (h as f32 * scale_ratio) as u32;
            (nw.max(64), nh.max(64))
        } else {
            let nw = (w as f32 * factor) as u32;
            let nh = (h as f32 * factor) as u32;
            (nw.max(64), nh.max(64))
        };

        let final_w = (new_w / 8) * 8;
        let final_h = (new_h / 8) * 8;

        let scaled = img.resize_exact(final_w, final_h, FilterType::Lanczos3);
        let factor_str = if (factor - 4.0).abs() < 0.01 {
            "4x"
        } else if (factor - 2.0).abs() < 0.01 {
            "2x"
        } else if (factor - 0.5).abs() < 0.01 {
            "0.5x"
        } else if factor <= 0.0 {
            "fit1k"
        } else {
            "scaled"
        };
        let ts = now_millis();
        let base_name = p.file_stem().and_then(|s| s.to_str()).unwrap_or("image");
        let clean_base = if let Some(idx) = base_name.find("_4x_") {
            &base_name[..idx]
        } else if let Some(idx) = base_name.find("_2x_") {
            &base_name[..idx]
        } else if let Some(idx) = base_name.find("_0.5x_") {
            &base_name[..idx]
        } else if let Some(idx) = base_name.find("_fit1k_") {
            &base_name[..idx]
        } else if let Some(idx) = base_name.find("_scaled_") {
            &base_name[..idx]
        } else {
            base_name
        };

        let candidate_name = format!("{}_{}_{}x{}.png", clean_base, factor_str, final_w, final_h);
        let gallery_dir = get_gallery_dir();
        let out_path = if gallery_dir.join(&candidate_name).exists() {
            gallery_dir.join(format!("{}_{}_{}x{}_{}.png", clean_base, factor_str, final_w, final_h, ts % 100000))
        } else {
            gallery_dir.join(&candidate_name)
        };
        let final_filename = out_path.file_name().unwrap_or_default().to_string_lossy().to_string();

        if scaled.save(&out_path).is_ok() {
            let existing_meta = read_png_chunks(p);
            let mut meta_vec: Vec<(&str, &str)> = Vec::new();
            for (k, v) in &existing_meta {
                meta_vec.push((k.as_str(), v.as_str()));
            }
            let w_str = final_w.to_string();
            let h_str = final_h.to_string();
            let auth_dna = format!("0x{:X}", SA_SIGNATURE_DNA);
            meta_vec.push(("scale_factor", factor_str));
            meta_vec.push(("scaled_width", &w_str));
            meta_vec.push(("scaled_height", &h_str));
            meta_vec.push(("author_dna", &auth_dna));
            let _ = embed_png_metadata(&out_path, &meta_vec);

            play_chime();
            let notif_title = format!("Upscale {} Dokončen", factor_str.to_uppercase());
            let notif_body = format!("Uloženo do Qwen-Image: {}\nRozlišení: {}x{} (Lanczos3)", final_filename, final_w, final_h);
            send_notification(&notif_title, &notif_body, out_path.to_str());

            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "path": out_path.to_string_lossy(),
                    "filename": final_filename,
                    "width": final_w,
                    "height": final_h,
                    "factor": factor
                })
            );
            return;
        }
    }

    println!(
        "{}",
        serde_json::json!({"status": "error", "message": "Failed to process image"})
    );
}

fn cmd_interrogate(input_path: &str) {
    let p = Path::new(input_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", input_path)})
        );
        return;
    }

    let out = Command::new(get_ai_worker_bin())
        .args(["tag", input_path, "--raw"])
        .output();

    if let Ok(o) = out {
        let raw = String::from_utf8_lossy(&o.stdout).trim().to_string();
        let tags: Vec<&str> = raw.split(',').map(|t| t.trim()).filter(|t| !t.is_empty()).collect();
        println!(
            "{}",
            serde_json::json!({
                "status": "ok",
                "raw": raw,
                "tags": tags
            })
        );
    } else {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": "WD14 execution failed"})
        );
    }
}

fn free_comfyui_memory() {
    if check_comfyui() {
        let agent = get_http_agent(2);
        let req_body = serde_json::json!({
            "unload_models": true,
            "free_memory": true
        });
        let _ = agent.post("http://127.0.0.1:8188/free").send_json(&req_body);
    }
}

fn cmd_vision(input_path: &str) {
    let p = Path::new(input_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", input_path)})
        );
        return;
    }

    // Proactively release VRAM before running vision multimodal model
    free_comfyui_memory();
    let (_ollama_mb, models) = get_ollama_status();
    if !models.is_empty() {
        stop_ollama_models(&models);
    }
    std::thread::sleep(Duration::from_millis(200));

    let instruction = "Analyze this image and write a detailed, high-quality diffusion prompt capturing the subject, clothing, pose, lighting, artistic style, camera angle, and atmosphere. Output ONLY the raw prompt description.";
    let out = Command::new(get_qwen_image_bin())
        .args(["vision", input_path, instruction])
        .output();

    if let Ok(o) = out {
        let stdout_str = String::from_utf8_lossy(&o.stdout);
        let stderr_str = String::from_utf8_lossy(&o.stderr);
        let prompt_text = stdout_str.trim().to_string();

        if o.status.success() && !prompt_text.is_empty() && !prompt_text.contains("cudaMalloc failed") && !prompt_text.contains("Error: ") {
            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "prompt": prompt_text
                })
            );
        } else {
            let err_msg = if !stderr_str.trim().is_empty() {
                stderr_str.trim().to_string()
            } else if !prompt_text.is_empty() {
                prompt_text
            } else {
                "Failed to extract vision prompt".to_string()
            };
            println!(
                "{}",
                serde_json::json!({"status": "error", "message": err_msg})
            );
        }
    } else {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": "Vision interrogation failed to launch"})
        );
    }
}

fn urlencoding_encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.' || b == b'~' {
            out.push(b as char);
        } else if b == b' ' {
            out.push_str("%20");
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

fn fetch_civitai_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(8);
    let mut items = Vec::new();

    // 1. Try local ComfyUI civitai discovery gallery if online
    if check_comfyui() {
        let local_url = format!(
            "http://127.0.0.1:8188/civitai_gallery/images_stream?query={}&min_batch={}&nsfw=X&hide_no_prompt=true&sort=Most%20Reactions&period={}&withMeta=true",
            urlencoding_encode(&q_lower),
            limit.max(10),
            if q_lower.is_empty() { "Month" } else { "AllTime" }
        );
        if let Ok(mut resp) = agent.get(&local_url).call() {
            if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                if let Some(arr) = val.get("items").and_then(|v| v.as_array()) {
                    for it in arr {
                        let meta = it.get("meta").unwrap_or(&serde_json::Value::Null);
                        let prompt = meta.get("prompt")
                            .or_else(|| meta.get("Prompt"))
                            .or_else(|| meta.get("positive"))
                            .and_then(|p| p.as_str())
                            .unwrap_or("");

                        if !prompt.is_empty() {
                            let neg = meta.get("negativePrompt")
                                .or_else(|| meta.get("NegativePrompt"))
                                .or_else(|| meta.get("negative"))
                                .and_then(|n| n.as_str())
                                .unwrap_or("");
                            let seed = meta.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                            let cfg = meta.get("cfgScale").and_then(|c| c.as_f64()).unwrap_or(4.0);
                            let steps = meta.get("steps").and_then(|s| s.as_u64()).unwrap_or(25);
                            let sampler = meta.get("sampler").and_then(|s| s.as_str()).unwrap_or("Euler");
                            let preview_url = it.get("url").and_then(|u| u.as_str()).unwrap_or("");

                            items.push(serde_json::json!({
                                "id": it.get("id"),
                                "source": "CivitAI",
                                "prompt": prompt,
                                "negative_prompt": neg,
                                "seed": seed,
                                "cfg": cfg,
                                "steps": steps,
                                "sampler": sampler,
                                "preview_url": preview_url,
                                "nsfw": it.get("nsfwLevel").unwrap_or(&serde_json::json!("None")),
                            }));
                            if items.len() >= limit {
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Direct upstream CivitAI API fallback
    if items.is_empty() {
        let fetch_count = (limit * 5).clamp(40, 80);
        let upstream_url = if q_lower.is_empty() {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=Month&nsfw=X&withMeta=true",
                fetch_count
            )
        } else {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=AllTime&nsfw=X&withMeta=true&query={}",
                fetch_count,
                urlencoding_encode(&q_lower)
            )
        };

        let res = agent.get(&upstream_url)
            .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) Omarchy-Qwen/1.0")
            .header("Accept", "application/json")
            .call();

        if let Ok(mut resp) = res {
            if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                if let Some(arr) = val.get("items").and_then(|v| v.as_array()) {
                    let mut candidate_items = Vec::new();
                    for it in arr {
                        let meta = it.get("meta").unwrap_or(&serde_json::Value::Null);
                        let prompt = meta.get("prompt")
                            .or_else(|| meta.get("Prompt"))
                            .or_else(|| meta.get("positive"))
                            .and_then(|p| p.as_str())
                            .unwrap_or("");

                        if !prompt.is_empty() {
                            let neg = meta.get("negativePrompt")
                                .or_else(|| meta.get("NegativePrompt"))
                                .or_else(|| meta.get("negative"))
                                .and_then(|n| n.as_str())
                                .unwrap_or("");
                            let seed = meta.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                            let cfg = meta.get("cfgScale").and_then(|c| c.as_f64()).unwrap_or(4.0);
                            let steps = meta.get("steps").and_then(|s| s.as_u64()).unwrap_or(25);
                            let sampler = meta.get("sampler").and_then(|s| s.as_str()).unwrap_or("Euler");
                            let preview_url = it.get("url").and_then(|u| u.as_str()).unwrap_or("");

                            let p_lower = prompt.to_lowercase();
                            let n_lower = neg.to_lowercase();
                            let haystack = format!("{} {}", p_lower, n_lower);

                            let item_json = serde_json::json!({
                                "id": it.get("id"),
                                "source": "CivitAI",
                                "prompt": prompt,
                                "negative_prompt": neg,
                                "seed": seed,
                                "cfg": cfg,
                                "steps": steps,
                                "sampler": sampler,
                                "preview_url": preview_url,
                                "nsfw": it.get("nsfwLevel").unwrap_or(&serde_json::json!("None")),
                            });

                            candidate_items.push((item_json, haystack));
                        }
                    }

                    // Strict pass: match ALL query words
                    for (item_json, haystack) in &candidate_items {
                        if words.is_empty() || words.iter().all(|w| haystack.contains(w)) {
                            items.push(item_json.clone());
                            if items.len() >= limit {
                                break;
                            }
                        }
                    }

                    // Relaxed pass: if multiple words and strict pass matched nothing, match ANY word
                    if items.is_empty() && words.len() > 1 {
                        for (item_json, haystack) in &candidate_items {
                            if words.iter().any(|w| haystack.contains(w)) {
                                items.push(item_json.clone());
                                if items.len() >= limit {
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    items
}

fn fetch_lexica_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(3);
    let mut items = Vec::new();

    // 1. Attempt live API
    if !q_lower.is_empty() {
        let url = format!("https://lexica.art/api/v1/search?q={}", urlencoding_encode(&q_lower));
        if let Ok(mut resp) = agent.get(&url)
            .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            .header("Accept", "application/json")
            .call()
        {
            if resp.status().as_u16() == 200 {
                if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                    if let Some(images) = val.get("images").and_then(|i| i.as_array()) {
                        for img in images {
                            let prompt = img.get("prompt").and_then(|p| p.as_str()).unwrap_or("");
                            if !prompt.is_empty() {
                                let id = img.get("id").and_then(|i| i.as_str()).unwrap_or("");
                                let preview_url = img.get("srcSmall")
                                    .or_else(|| img.get("src"))
                                    .and_then(|s| s.as_str())
                                    .unwrap_or("");
                                let seed = img.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                                let cfg = img.get("guidance").and_then(|g| g.as_f64()).unwrap_or(4.5);

                                items.push(serde_json::json!({
                                    "id": id,
                                    "source": "Lexica",
                                    "prompt": prompt,
                                    "negative_prompt": "blurry, low quality, deformed, extra fingers, text, watermark",
                                    "seed": seed,
                                    "cfg": cfg,
                                    "steps": 25,
                                    "sampler": "Euler a",
                                    "preview_url": preview_url,
                                    "nsfw": "None",
                                }));
                                if items.len() >= limit {
                                    return items;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Curated Lexica high-aesthetic collection fallback
    if items.is_empty() {
        return prompts_db::search_curated("Lexica", &words, limit);
    }
    items
}

fn fetch_prompthero_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("PromptHero", &words, limit)
}

fn fetch_openart_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("OpenArt", &words, limit)
}

fn fetch_huggingface_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("HuggingFace", &words, limit)
}

fn fetch_krea_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Krea.ai", &words, limit)
}

fn fetch_tensorart_items(query: &str, limit: usize) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Tensor.art", &words, limit)
}

fn cmd_prompts(source: &str, query: &str, limit: usize) {
    let src = source.to_lowercase();
    let (src_name, items) = match src.as_str() {
        "lexica" => ("Lexica", fetch_lexica_items(query, limit)),
        "prompthero" => ("PromptHero", fetch_prompthero_items(query, limit)),
        "openart" => ("OpenArt", fetch_openart_items(query, limit)),
        "huggingface" | "hf" => ("HuggingFace", fetch_huggingface_items(query, limit)),
        "krea" | "krea.ai" => ("Krea.ai", fetch_krea_items(query, limit)),
        "tensorart" | "tensor" | "tensor.art" => ("Tensor.art", fetch_tensorart_items(query, limit)),
        _ => ("CivitAI", fetch_civitai_items(query, limit)),
    };

    println!("{}", serde_json::json!({
        "status": "ok",
        "source": src_name,
        "items": items
    }));
}

#[allow(dead_code)]
fn cmd_civitai(query: &str, limit: usize) {
    cmd_prompts("civitai", query, limit);
}

fn is_czech_text(s: &str) -> bool {
    let mut cz_chars = 0;
    for c in s.chars() {
        if "ěščřžýáíéúůťďňóĚŠČŘŽÝÁÍÉÚŮŤĎŇÓ".contains(c) {
            cz_chars += 1;
        }
    }
    if cz_chars >= 2 {
        return true;
    }

    let lower = s.to_lowercase();
    let words: Vec<&str> = lower
        .split(|c: char| !c.is_alphabetic())
        .filter(|w| !w.is_empty())
        .collect();
    if words.is_empty() {
        return false;
    }

    let mut en_count = 0;
    let mut cz_count = 0;

    for &w in &words {
        if matches!(
            w,
            "the" | "and" | "with" | "of" | "in" | "on" | "at" | "by" | "for" | "from" |
            "wearing" | "background" | "anime" | "detailed" | "cinematic" | "illustration" |
            "masterpiece" | "lighting" | "female" | "male" | "warrior" | "hair" | "eyes" |
            "black" | "white" | "red" | "blue" | "dark" | "shot" | "view" | "ultra" | "style"
        ) {
            en_count += 1;
        }
        if matches!(
            w,
            "jako" | "nebo" | "kdyz" | "když" | "jsou" | "byl" | "byla" | "byli" | "velmi" |
            "ktery" | "který" | "ktera" | "která" | "ktere" | "které" | "podle" | "take" | "také" |
            "pouze" | "jeste" | "ještě" | "mezi" | "pred" | "před" | "pres" | "přes" | "proti" |
            "postava" | "divka" | "dívka" | "zena" | "žena" | "muz" | "muž" | "obraz" | "pozadi" |
            "pozadí" | "svetlo" | "světlo"
        ) {
            cz_count += 1;
        }
    }

    if cz_chars > 0 && en_count == 0 {
        return true;
    }
    cz_count > en_count
}

fn get_http_agent(timeout_secs: u64) -> ureq::Agent {
    let config = ureq::config::Config::builder()
        .timeout_global(Some(Duration::from_secs(timeout_secs)))
        .build();
    ureq::Agent::new_with_config(config)
}

fn cmd_translate_internal(text: &str) -> Result<String, String> {
    let agent = get_http_agent(8);
    let sys_prompt = "You are an expert diffusion prompt engineer. If the input is in Czech, accurately translate and expand it into descriptive, photorealistic English tags and scene modifiers suitable for DiT diffusion models (Qwen-Image). If the input is in English, enhance it with lighting, composition, and aesthetic modifiers. Output ONLY the final enhanced English prompt string, without any quotation marks, preamble, or conversational text.";

    let req_body = serde_json::json!({
        "model": "qwen2.5-coder:7b",
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": text}
        ],
        "stream": false,
        "options": {
            "temperature": 0.5,
            "seed": SA_SIGNATURE_DNA
        }
    });

    let res = agent.post("http://127.0.0.1:11434/api/chat")
        .send_json(&req_body);

    match res {
        Ok(mut response) => {
            if let Ok(val) = response.body_mut().read_json::<serde_json::Value>() {
                if let Some(content) = val.get("message").and_then(|m| m.get("content")).and_then(|c| c.as_str()) {
                    let trimmed = content.trim();
                    if !trimmed.is_empty() {
                        return Ok(trimmed.to_string());
                    }
                }
            }
            Err("Empty or invalid response from Ollama".to_string())
        }
        Err(e) => Err(format!("Ollama connection error: {}", e)),
    }
}

fn cmd_translate(text: &str) {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        println!("{}", serde_json::json!({"status": "ok", "prompt": ""}));
        return;
    }

    let is_cz = is_czech_text(trimmed);
    match cmd_translate_internal(trimmed) {
        Ok(enhanced) => {
            println!("{}", serde_json::json!({
                "status": "ok",
                "prompt": enhanced,
                "is_cz": is_cz
            }));
        }
        Err(err) => {
            println!("{}", serde_json::json!({
                "status": "ok",
                "prompt": trimmed,
                "fallback": true,
                "error": err
            }));
        }
    }
}

fn cmd_tags(query: &str, limit: usize) {
    let csv_path = get_home()
        .join(".local/share/comfyui/custom_nodes/ComfyUI-Autocomplete-Plus/data/danbooru_tags.csv");

    if !csv_path.exists() {
        println!("{}", serde_json::json!({"status": "ok", "tags": []}));
        return;
    }

    let q = query.trim().to_lowercase();
    let mut matches = Vec::new();

    if let Ok(file) = File::open(csv_path) {
        let reader = BufReader::new(file);
        for line in reader.lines().map_while(Result::ok) {
            let tag = line.split(',').next().unwrap_or("").trim();
            if !tag.is_empty() && (tag.starts_with(&q) || tag.contains(&q)) {
                matches.push(tag.to_string());
                if matches.len() >= limit {
                    break;
                }
            }
        }
    }

    println!("{}", serde_json::json!({"status": "ok", "tags": matches}));
}

fn cmd_read_meta(image_path: &str) {
    let p = Path::new(image_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", image_path)})
        );
        return;
    }

    let (width, height) = image::image_dimensions(p).unwrap_or((1024, 1024));
    let chunks = read_png_chunks(p);

    let mut prompt = chunks.get("prompt").cloned().unwrap_or_default();
    if prompt.starts_with('{') {
        if let Some(extracted) = parse_comfy_prompt(&prompt) {
            prompt = extracted;
        }
    }

    let negative = chunks.get("negative_prompt").cloned().unwrap_or_default();
    let seed = chunks.get("seed").and_then(|s| s.parse::<i64>().ok()).unwrap_or(-1);
    let steps = chunks.get("steps").and_then(|s| s.parse::<u32>().ok()).unwrap_or(25);
    let cfg = chunks.get("cfg").and_then(|c| c.parse::<f64>().ok()).unwrap_or(4.0);
    let ratio = chunks.get("ratio").cloned().unwrap_or_else(|| {
        if height == 0 {
            return "1:1".to_string();
        }
        let r = (width as f64) / (height as f64);
        if r >= 2.05 {
            "21:9".to_string()
        } else if r >= 1.45 {
            "16:9".to_string()
        } else if r >= 1.15 {
            "4:3".to_string()
        } else if r >= 0.88 {
            "1:1".to_string()
        } else if r >= 0.65 {
            "3:4".to_string()
        } else {
            "9:16".to_string()
        }
    });

    println!("{}", serde_json::json!({
        "status": "ok",
        "path": image_path,
        "prompt": prompt,
        "negative_prompt": negative,
        "seed": seed,
        "steps": steps,
        "cfg": cfg,
        "ratio": ratio,
        "width": width,
        "height": height
    }));
}

fn cmd_history(limit: usize) {
    let gallery = get_gallery_dir();
    let mut items = Vec::new();

    if let Ok(entries) = fs::read_dir(&gallery) {
        let mut paths: Vec<PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.is_file() && p.extension().is_some_and(|ext| ext == "png"))
            .collect();

        paths.sort_by(|a, b| {
            let m_a = a.metadata().and_then(|m| m.modified()).unwrap_or(UNIX_EPOCH);
            let m_b = b.metadata().and_then(|m| m.modified()).unwrap_or(UNIX_EPOCH);
            m_b.cmp(&m_a)
        });

        for p in paths.into_iter().take(limit) {
            let filename = p.file_name().unwrap_or_default().to_string_lossy().to_string();
            let size_mb = p.metadata().map(|m| (m.len() as f64) / 1_048_576.0).unwrap_or(0.0);
            let (width, height) = image::image_dimensions(&p).unwrap_or((1024, 1024));
            let chunks = read_png_chunks(&p);

            let mut prompt = chunks.get("prompt").cloned().unwrap_or_default();
            if prompt.starts_with('{') {
                if let Some(extracted) = parse_comfy_prompt(&prompt) {
                    prompt = extracted;
                }
            }
            if prompt.is_empty() {
                prompt = filename
                    .split('_')
                    .skip(2)
                    .collect::<Vec<&str>>()
                    .join(" ")
                    .trim_end_matches(".png")
                    .to_string();
                if prompt.is_empty() {
                    prompt = filename.clone();
                }
            }

            let negative = chunks.get("negative_prompt").cloned().unwrap_or_default();
            let seed = chunks.get("seed").and_then(|s| s.parse::<i64>().ok()).unwrap_or(-1);
            let steps = chunks.get("steps").and_then(|s| s.parse::<u32>().ok()).unwrap_or(25);
            let ratio = chunks.get("ratio").cloned().unwrap_or_else(|| "1:1".to_string());

            items.push(serde_json::json!({
                "path": p.to_string_lossy(),
                "filename": filename,
                "timestamp": "Recent",
                "width": width,
                "height": height,
                "prompt": prompt,
                "negative_prompt": negative,
                "seed": seed,
                "steps": steps,
                "ratio": ratio,
                "size_mb": (size_mb * 100.0).round() / 100.0,
            }));
        }
    }

    println!("{}", serde_json::json!({"status": "ok", "items": items, "total": items.len()}));
}

#[allow(clippy::too_many_arguments)]
fn cmd_generate(
    prompt: &str,
    ratio: &str,
    steps: u32,
    cfg: f32,
    seed: i64,
    negative: &str,
    image_ref: Option<&str>,
    denoise: f32,
) {
    let vram_pre = get_vram_info();
    let (locked, reason) = check_gaming_hybrid(&vram_pre);
    if locked {
        println!(
            "{}",
            serde_json::json!({
                "status": "error",
                "message": format!("Generation locked: {}", reason)
            })
        );
        return;
    }

    // Auto-purge idle Ollama models if VRAM is constrained (< 4000 MB free)
    if vram_pre.free_mb < 4000 {
        let (_ollama_mb, models) = get_ollama_status();
        if !models.is_empty() {
            stop_ollama_models(&models);
            std::thread::sleep(Duration::from_millis(500));
        }
    }

    let ts = now_millis();
    let safe_prompt: String = prompt
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-')
        .take(32)
        .collect();
    let clean_slug = safe_prompt.trim().replace(' ', "_");
    let gallery_out = get_gallery_dir().join(format!("{}_{}.png", ts, clean_slug));

    // Dynamic background translation if Czech input detected
    let mut final_prompt = prompt.to_string();
    if is_czech_text(prompt) {
        if let Ok(translated) = cmd_translate_internal(prompt) {
            if translated.len() > 3 {
                final_prompt = translated;
            }
        }
    }

    // Ensure all Ollama models are stopped so VRAM is 100% available for ComfyUI DiT
    let (_ollama_mb, models) = get_ollama_status();
    if !models.is_empty() {
        stop_ollama_models(&models);
        std::thread::sleep(Duration::from_millis(300));
    }

    let mut cmd = Command::new(get_ai_worker_bin());
    cmd.args(["image", &final_prompt, "--ratio", ratio, "--steps", &steps.to_string(), "--cfg", &cfg.to_string(), "--out"]);
    cmd.arg(&gallery_out);

    if seed >= 0 {
        cmd.args(["--seed", &seed.to_string()]);
    }
    if !negative.is_empty() {
        cmd.args(["--negative", negative]);
    }
    if let Some(img) = image_ref {
        if Path::new(img).exists() {
            let clamped_denoise = denoise.clamp(0.05, 0.95);
            cmd.args(["--image", img, "--denoise", &clamped_denoise.to_string()]);
        }
    }

    let t0 = Instant::now();
    let res = cmd.output();
    let elapsed = t0.elapsed().as_secs_f32();

    if let Ok(o) = res {
        if gallery_out.exists() && gallery_out.metadata().map(|m| m.len() > 1024).unwrap_or(false) {
            // Embed metadata into PNG chunks natively
            let seed_str = seed.to_string();
            let steps_str = steps.to_string();
            let cfg_str = cfg.to_string();
            let auth_dna = format!("0x{:x}", SA_SIGNATURE_DNA);

            let pairs = [
                ("prompt", prompt),
                ("prompt_en", &final_prompt),
                ("negative_prompt", negative),
                ("seed", &seed_str),
                ("steps", &steps_str),
                ("cfg", &cfg_str),
                ("ratio", ratio),
                ("author_dna", &auth_dna),
            ];
            let _ = embed_png_metadata(&gallery_out, &pairs);

            play_chime();
            send_notification("Generation Complete", &format!("{} image rendered in {:.1}s", ratio, elapsed), Some(gallery_out.to_str().unwrap()));

            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "path": gallery_out.to_string_lossy(),
                    "prompt": prompt,
                    "prompt_en": final_prompt,
                    "ratio": ratio,
                    "seed": seed,
                    "steps": steps,
                    "elapsed": (elapsed * 10.0).round() / 10.0
                })
            );
            return;
        }
        let err_msg = String::from_utf8_lossy(&o.stderr);
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": if err_msg.is_empty() { "Generation failed" } else { &err_msg }})
        );
    } else {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": "Failed to invoke ai-worker"})
        );
    }
}

// ---------------------------------------------------------
// Main CLI Router
// ---------------------------------------------------------

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: qwen_bridge <command> [args]");
        std::process::exit(1);
    }

    match args[1].as_str() {
        "status" => cmd_status(),
        "paste-clipboard" => cmd_paste_clipboard(),
        "snip" => cmd_snip(),
        "wallpaper" => {
            if args.len() >= 3 {
                cmd_wallpaper(&args[2]);
            }
        }
        "scale" => {
            if args.len() >= 3 {
                let mut factor = 2.0f32;
                for i in 3..args.len() {
                    if args[i] == "--factor" {
                        if let Some(next) = args.get(i + 1) {
                            factor = next.parse::<f32>().unwrap_or(2.0);
                        }
                    } else if let Ok(f) = args[i].parse::<f32>() {
                        factor = f;
                    }
                }
                cmd_scale(&args[2], factor);
            }
        }
        "interrogate" => {
            if args.len() >= 3 {
                cmd_interrogate(&args[2]);
            }
        }
        "vision" => {
            if args.len() >= 3 {
                cmd_vision(&args[2]);
            }
        }
        "prompts" => {
            let source = args.get(2).map(|s| s.as_str()).unwrap_or("civitai");
            let mut query_words = Vec::new();
            let mut limit = 20usize;
            let mut idx = 3;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(20);
                        idx += 2;
                        continue;
                    }
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit);
        }
        "civitai" | "lexica" | "prompthero" | "openart" | "huggingface" | "hf" | "krea" | "tensorart" | "tensor" => {
            let source = args[1].as_str();
            let mut query_words = Vec::new();
            let mut limit = 20usize;
            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(20);
                        idx += 2;
                        continue;
                    }
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit);
        }
        "translate" => {
            let text = if args.len() >= 3 {
                args[2..].join(" ")
            } else {
                String::new()
            };
            cmd_translate(&text);
        }
        "tags" => {
            let mut tag_words = Vec::new();
            let mut limit = 15usize;
            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(15);
                        idx += 2;
                        continue;
                    }
                } else if !args[idx].starts_with("--") {
                    tag_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let q = tag_words.join(" ");
            cmd_tags(&q, limit);
        }
        "read-meta" => {
            if args.len() >= 3 {
                cmd_read_meta(&args[2]);
            } else {
                println!("{}", serde_json::json!({"status": "error", "message": "Missing image path"}));
            }
        }
        "history" => {
            let limit = args.get(2).and_then(|l| l.parse::<usize>().ok()).unwrap_or(30);
            cmd_history(limit);
        }
        "generate" => {
            let prompt = args.get(2).map(|s| s.as_str()).unwrap_or("");
            let ratio = args.get(3).map(|s| s.as_str()).unwrap_or("1:1");
            let steps = args.get(4).and_then(|s| s.parse::<u32>().ok()).unwrap_or(25);
            let cfg = args.get(5).and_then(|s| s.parse::<f32>().ok()).unwrap_or(4.0);
            let seed = args.get(6).and_then(|s| s.parse::<i64>().ok()).unwrap_or(-1);
            let negative = args.get(7).map(|s| s.as_str()).unwrap_or("");
            let image_ref = args.get(8).map(|s| s.as_str());
            let denoise = args.get(9).and_then(|s| s.parse::<f32>().ok()).unwrap_or(0.85).clamp(0.05, 0.95);

            cmd_generate(prompt, ratio, steps, cfg, seed, negative, image_ref, denoise);
        }
        other => {
            eprintln!("Unknown command: {}", other);
            std::process::exit(1);
        }
    }
}
