// Qwen-Image Studio Rust Bridge & Accelerator
// Part of the simonez.qwenimage Omarchy Plugin
// Author: simonez & Arci

mod prompts_db;
mod comfy;

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

// Native self-contained runtime: no external ai-worker or qwen-image binary dependencies.

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
        "plugin": env!("CARGO_PKG_VERSION")
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

    let (tier, max_dim, modes) = if vram.total_mb >= 20480 {
        ("S", 2560, vec!["draft", "standard", "high", "ultra", "max"])
    } else if vram.total_mb >= 12000 {
        ("A", 2048, vec!["draft", "standard", "high", "ultra"])
    } else {
        ("B", 1536, vec!["draft", "standard", "high"])
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
        "hardware_tier": tier,
        "max_res_dim": max_dim,
        "supported_res_modes": modes,
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

fn decode_percent_str(s: &str) -> String {
    let mut bytes = Vec::new();
    let mut chars = s.as_bytes().iter();
    while let Some(&b) = chars.next() {
        if b == b'%' {
            if let (Some(&h1), Some(&h2)) = (chars.next(), chars.next()) {
                if let Ok(val) = u8::from_str_radix(std::str::from_utf8(&[h1, h2]).unwrap_or(""), 16) {
                    bytes.push(val);
                    continue;
                }
            }
        }
        bytes.push(b);
    }
    String::from_utf8_lossy(&bytes).to_string()
}

fn is_supported_image_path(p: &Path) -> bool {
    if !p.exists() || !p.is_file() {
        return false;
    }
    p.extension()
        .and_then(|e| e.to_str())
        .map(|ext| {
            matches!(
                ext.to_lowercase().as_str(),
                "png" | "jpg" | "jpeg" | "webp" | "bmp" | "gif" | "tiff" | "avif" | "ico"
            )
        })
        .unwrap_or(false)
}

fn cmd_paste_clipboard() {
    let ts = now_millis();
    let temp_dir = get_temp_dir();

    // 1. Zkusit surové obrazové MIME typy (PNG, JPEG, WebP, BMP, TIFF)
    let image_mimes = [
        ("image/png", "png"),
        ("image/jpeg", "jpg"),
        ("image/webp", "webp"),
        ("image/bmp", "bmp"),
        ("image/tiff", "tiff"),
    ];

    for (mime, ext) in &image_mimes {
        let target = temp_dir.join(format!("clip_{}.{}", ts, ext));
        let out = Command::new("wl-paste")
            .args(["-t", mime])
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
    }

    // 2. Zkusit text/uri-list (soubory zkopírované ze správce souborů nebo prohlížeče)
    let uri_out = Command::new("wl-paste")
        .args(["-t", "text/uri-list"])
        .output();

    if let Ok(o) = uri_out {
        if o.status.success() && !o.stdout.is_empty() {
            let content = String::from_utf8_lossy(&o.stdout);
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    continue;
                }
                let raw_path = if let Some(stripped) = trimmed.strip_prefix("file://") {
                    decode_percent_str(stripped)
                } else {
                    trimmed.to_string()
                };
                let p = Path::new(&raw_path);
                if is_supported_image_path(p) {
                    println!(
                        "{}",
                        serde_json::json!({
                            "status": "ok",
                            "path": p.to_string_lossy()
                        })
                    );
                    return;
                }
            }
        }
    }

    // 3. Zkusit čistý text (cesty zkopírované jako text nebo standardní výstup wl-paste)
    let text_out = Command::new("wl-paste").output();
    if let Ok(o) = text_out {
        if o.status.success() && !o.stdout.is_empty() {
            let content = String::from_utf8_lossy(&o.stdout);
            for line in content.lines() {
                let trimmed = line.trim().trim_matches('"').trim_matches('\'');
                if trimmed.is_empty() {
                    continue;
                }
                let raw_path = if let Some(stripped) = trimmed.strip_prefix("file://") {
                    decode_percent_str(stripped)
                } else {
                    trimmed.to_string()
                };
                let p = Path::new(&raw_path);
                if is_supported_image_path(p) {
                    println!(
                        "{}",
                        serde_json::json!({
                            "status": "ok",
                            "path": p.to_string_lossy()
                        })
                    );
                    return;
                }

                // Pokud jde o HTTP/HTTPS odkaz na obrázek, stáhnout do tempu
                if raw_path.starts_with("http://") || raw_path.starts_with("https://") {
                    let agent = get_http_agent(10);
                    if let Ok(mut resp) = agent.get(&raw_path).call() {
                        let target = temp_dir.join(format!("clip_web_{}.png", ts));
                        let mut reader = resp.body_mut().as_reader();
                        let mut bytes = Vec::new();
                        if std::io::copy(&mut reader, &mut bytes).is_ok()
                            && bytes.len() > 64
                            && fs::write(&target, &bytes).is_ok()
                        {
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
                }
            }
        }
    }

    println!(
        "{}",
        serde_json::json!({
            "status": "error",
            "message": "Ve schránce nebyl nalezen žádný podporovaný obrázek ani platná cesta k souboru"
        })
    );
}

fn cmd_snip() {
    let _ = Command::new("/usr/share/omarchy/bin/omarchy-capture-screenshot")
        .args(["region", "copy"])
        .status();
    cmd_paste_clipboard();
}

fn cmd_copy_text(text_arg: Option<&str>) {
    let mut child = match Command::new("wl-copy")
        .stdin(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to spawn wl-copy: {}", e);
            return;
        }
    };

    if let Some(mut stdin) = child.stdin.take() {
        if let Some(t) = text_arg {
            let _ = stdin.write_all(t.as_bytes());
        } else {
            let mut buf = Vec::new();
            let _ = std::io::stdin().read_to_end(&mut buf);
            let _ = stdin.write_all(&buf);
        }
    }
    let _ = child.wait();
}

fn cmd_copy_image(path: &str) {
    let p = Path::new(path);
    if !p.exists() || !p.is_file() {
        eprintln!("File not found: {}", path);
        return;
    }
    if let Ok(file) = File::open(p) {
        let _ = Command::new("wl-copy")
            .args(["-t", "image/png"])
            .stdin(file)
            .status();
    }
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

    match comfy::execute_wd14(input_path, 0.35) {
        Ok((raw, tags)) => {
            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "raw": raw,
                    "tags": tags
                })
            );
        }
        Err(e) => {
            println!(
                "{}",
                serde_json::json!({"status": "error", "message": format!("WD14 execution failed: {}", e)})
            );
        }
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

    // Optional local acceleration via qwen-image if installed on host
    let local_qwen = get_home().join(".local").join("bin").join("qwen-image");
    if local_qwen.exists() {
        if let Ok(o) = Command::new(&local_qwen).args(["vision", input_path, instruction]).output() {
            let stdout_str = String::from_utf8_lossy(&o.stdout);
            let prompt_text = stdout_str.trim().to_string();
            if o.status.success() && !prompt_text.is_empty() && !prompt_text.contains("cudaMalloc failed") && !prompt_text.contains("Error: ") {
                println!("{}", serde_json::json!({"status": "ok", "prompt": prompt_text}));
                return;
            }
        }
    }

    // Direct HTTP Ollama vision fallback
    if let Ok(img_bytes) = fs::read(input_path) {
        let agent = get_http_agent(120);
        let b64 = data_encoding::BASE64.encode(&img_bytes);
        let vision_models = ["minicpm-v:latest", "mimo-v:latest", "llama3.2-vision:latest"];
        for vm in &vision_models {
            let payload = serde_json::json!({
                "model": vm,
                "prompt": instruction,
                "images": [b64],
                "stream": false
            });
            if let Ok(mut resp) = agent.post("http://127.0.0.1:11434/api/generate").send_json(&payload) {
                if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                    if let Some(resp_text) = val.get("response").and_then(|r| r.as_str()) {
                        let trimmed = resp_text.trim();
                        if !trimmed.is_empty() {
                            println!("{}", serde_json::json!({"status": "ok", "prompt": trimmed}));
                            return;
                        }
                    }
                }
            }
        }
    }

    println!("{}", serde_json::json!({"status": "error", "message": "Vision interrogation requires a local vision model in Ollama (e.g. minicpm-v) or local qwen-image"}));
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

fn fetch_civitai_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(8);
    let mut items = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let nsfw_filter = if nsfw_allowed { "true" } else { "None" };

    // 1. Try local ComfyUI civitai discovery gallery if online
    if check_comfyui() {
        let local_url = format!(
            "http://127.0.0.1:8188/civitai_gallery/images_stream?query={}&min_batch={}&nsfw={}&hide_no_prompt=true&sort=Most%20Reactions&period={}&withMeta=true",
            urlencoding_encode(&q_lower),
            limit.max(10),
            nsfw_filter,
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
                            let p_norm = prompt.trim().to_lowercase();
                            if !seen.insert(p_norm) {
                                continue;
                            }

                            let nsfw_str = it.get("nsfwLevel").and_then(|v| v.as_str()).unwrap_or("None");
                            if !nsfw_allowed
                                && (nsfw_str.eq_ignore_ascii_case("x")
                                    || nsfw_str.eq_ignore_ascii_case("mature")
                                    || nsfw_str.eq_ignore_ascii_case("soft"))
                            {
                                continue;
                            }

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
                                "nsfw": nsfw_str,
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
        let fetch_count = (limit * 2).clamp(50, 200);
        let upstream_url = if q_lower.is_empty() {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=Month&nsfw={}&withMeta=true",
                fetch_count,
                nsfw_filter
            )
        } else {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=AllTime&nsfw={}&withMeta=true&query={}",
                fetch_count,
                nsfw_filter,
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
                            let p_norm = prompt.trim().to_lowercase();
                            if !seen.insert(p_norm) {
                                continue;
                            }

                            let nsfw_str = it.get("nsfwLevel").and_then(|v| v.as_str()).unwrap_or("None");
                            if !nsfw_allowed
                                && (nsfw_str.eq_ignore_ascii_case("x")
                                    || nsfw_str.eq_ignore_ascii_case("mature")
                                    || nsfw_str.eq_ignore_ascii_case("soft"))
                            {
                                continue;
                            }

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
                                "nsfw": nsfw_str,
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

    if items.is_empty() {
        return prompts_db::search_curated("CivitAI", &words, limit, nsfw_allowed);
    }

    items
}

fn fetch_lexica_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(3);
    let mut items = Vec::new();
    let mut seen = std::collections::HashSet::new();

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
                                let p_norm = prompt.trim().to_lowercase();
                                if !seen.insert(p_norm) {
                                    continue;
                                }

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
        return prompts_db::search_curated("Lexica", &words, limit, nsfw_allowed);
    }
    items
}

fn fetch_prompthero_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("PromptHero", &words, limit, nsfw_allowed)
}

fn fetch_openart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("OpenArt", &words, limit, nsfw_allowed)
}

fn fetch_huggingface_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("HuggingFace", &words, limit, nsfw_allowed)
}

fn fetch_krea_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Krea.ai", &words, limit, nsfw_allowed)
}

fn fetch_tensorart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Tensor.art", &words, limit, nsfw_allowed)
}

fn fetch_midlibrary_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Midlibrary", &words, limit, nsfw_allowed)
}

fn fetch_diffusiondb_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("DiffusionDB", &words, limit, nsfw_allowed)
}

fn fetch_seaart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("SeaArt", &words, limit, nsfw_allowed)
}

fn fetch_shakker_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Shakker", &words, limit, nsfw_allowed)
}

fn fetch_playground_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Playground", &words, limit, nsfw_allowed)
}

fn cmd_prompts(source: &str, query: &str, limit: usize, nsfw_allowed: bool) {
    let src = source.to_lowercase();
    let (src_name, items) = match src.as_str() {
        "midlibrary" | "midlib" | "midlibrary.io" => ("Midlibrary", fetch_midlibrary_items(query, limit, nsfw_allowed)),
        "diffusiondb" | "diffdb" => ("DiffusionDB", fetch_diffusiondb_items(query, limit, nsfw_allowed)),
        "seaart" | "seaart.ai" => ("SeaArt", fetch_seaart_items(query, limit, nsfw_allowed)),
        "shakker" | "shakker.ai" => ("Shakker", fetch_shakker_items(query, limit, nsfw_allowed)),
        "playground" | "playground.com" => ("Playground", fetch_playground_items(query, limit, nsfw_allowed)),
        "lexica" => ("Lexica", fetch_lexica_items(query, limit, nsfw_allowed)),
        "prompthero" => ("PromptHero", fetch_prompthero_items(query, limit, nsfw_allowed)),
        "openart" => ("OpenArt", fetch_openart_items(query, limit, nsfw_allowed)),
        "huggingface" | "hf" => ("HuggingFace", fetch_huggingface_items(query, limit, nsfw_allowed)),
        "krea" | "krea.ai" => ("Krea.ai", fetch_krea_items(query, limit, nsfw_allowed)),
        "tensorart" | "tensor" | "tensor.art" => ("Tensor.art", fetch_tensorart_items(query, limit, nsfw_allowed)),
        _ => ("CivitAI", fetch_civitai_items(query, limit, nsfw_allowed)),
    };

    println!("{}", serde_json::json!({
        "status": "ok",
        "source": src_name,
        "items": items
    }));
}

#[allow(dead_code)]
fn cmd_civitai(query: &str, limit: usize, nsfw_allowed: bool) {
    cmd_prompts("civitai", query, limit, nsfw_allowed);
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

fn detect_human_subject(prompt: &str) -> bool {
    let p = prompt.to_ascii_lowercase();
    const HUMAN_TOKENS: &[&str] = &[
        "woman", "man", "girl", "boy", "person", "body", "nude", "naked",
        "erotic", "portrait", "skin", "breasts", "legs", "face", "buttocks",
        "ass", "waist", "hips", "thighs", "female", "male", "model",
        "dívka", "žena", "muž", "tělo", "nahá", "nahý", "akt"
    ];
    HUMAN_TOKENS.iter().any(|&token| p.contains(token))
}

fn strip_foreign_prompt_tags(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut in_tag = false;
    for c in s.chars() {
        if c == '<' {
            in_tag = true;
        } else if c == '>' && in_tag {
            in_tag = false;
        } else if !in_tag {
            out.push(c);
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn unpack_json_prompt_if_present(s: &str) -> String {
    if s.contains("rewritten_prompt") {
        if let Some(pos) = s.find("\"rewritten_prompt\"") {
            let rest = &s[pos + 18..];
            if let Some(colon) = rest.find(':') {
                let after_colon = rest[colon + 1..].trim_start();
                if let Some(stripped) = after_colon.strip_prefix('"') {
                    let mut extracted = String::new();
                    let mut chars = stripped.chars();
                    while let Some(c) = chars.next() {
                        if c == '\\' {
                            if let Some(next_c) = chars.next() {
                                if next_c == 'n' {
                                    extracted.push('\n');
                                } else {
                                    extracted.push(next_c);
                                }
                            }
                        } else if c == '"' {
                            break;
                        } else {
                            extracted.push(c);
                        }
                    }
                    if extracted.len() > 20 {
                        return extracted;
                    }
                }
            }
        }
    }
    s.to_string()
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
    anime: bool,
    turbo: bool,
    uncensored: bool,
    res_mode: Option<&str>,
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

    // Auto-purge idle Ollama models and ComfyUI cache if VRAM is constrained (< 4000 MB free)
    if vram_pre.free_mb < 4000 {
        let (_ollama_mb, models) = get_ollama_status();
        if !models.is_empty() {
            stop_ollama_models(&models);
            std::thread::sleep(Duration::from_millis(500));
        }
        free_comfyui_memory();
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

    // Clean Civitai / Automatic1111 raw syntax tags (<lora:...>, <embedding:...>)
    let cleaned = strip_foreign_prompt_tags(&final_prompt);
    if !cleaned.is_empty() {
        final_prompt = cleaned;
    }

    // Unpack accidental raw JSON prompt envelope from prompt-opt / LLM
    final_prompt = unpack_json_prompt_if_present(&final_prompt);

    // Hardening: Zastropovat délku promptu (prevence buffer a memory exhaustion)
    const MAX_PROMPT_CHARS: usize = 4096;
    if final_prompt.len() > MAX_PROMPT_CHARS {
        final_prompt = final_prompt.chars().take(MAX_PROMPT_CHARS).collect();
    }

    // Anatomical Safety Guard: calibration parameter
    const ANATOMICAL_DNA_SEED: usize = 0x732641;
    let _ = ANATOMICAL_DNA_SEED % 16;

    let is_human = detect_human_subject(&final_prompt);
    let mut final_res_mode = res_mode.unwrap_or("standard").to_string();
    let mut final_steps = steps;
    let mut final_cfg = cfg;

    if is_human {
        // Enforce resolution floor: Draft (<768px) kolabuje jemnou anatomii a detaily kůže
        if final_res_mode == "draft" || final_res_mode == "preview" || final_res_mode == "fast" {
            final_res_mode = "standard".to_string();
        }
        // Enforce sampling floor při standardním běhu (Euler/Simple bez Turbo DMD)
        if !turbo {
            if final_steps < 25 {
                final_steps = final_steps.max(28);
            }
            if final_cfg < 3.0 {
                final_cfg = 4.0;
            }
        }
    } else if !turbo && final_steps < 20 {
        final_steps = 25;
    }

    // Ensure all Ollama models are stopped so VRAM is 100% available for ComfyUI DiT
    let (_ollama_mb, models) = get_ollama_status();
    if !models.is_empty() {
        stop_ollama_models(&models);
        free_comfyui_memory();
        std::thread::sleep(Duration::from_millis(300));
    }

    if !comfy::ensure_comfyui_running() {
        println!("{}", serde_json::json!({"status": "error", "message": "ComfyUI server is offline"}));
        return;
    }

    let free_vram = comfy::get_vram_free_mb();
    if free_vram < 4000 {
        comfy::free_comfyui_vram(true);
    }

    let gen_cfg = comfy::GenerationConfig {
        prompt: &final_prompt,
        negative_prompt: negative,
        ratio,
        steps: final_steps,
        cfg: final_cfg,
        seed,
        image_ref,
        denoise,
        anime,
        turbo,
        uncensored,
        res_mode: &final_res_mode,
        is_human,
    };

    let (prompt_graph, final_seed, _w, _h) = match comfy::build_generation_graph(&gen_cfg) {
        Ok(res) => res,
        Err(e) => {
            println!("{}", serde_json::json!({"status": "error", "message": e}));
            return;
        }
    };

    let t0 = Instant::now();
    let saved_filename = match comfy::execute_comfy_workflow(&prompt_graph) {
        Ok(fname) => fname,
        Err(e) => {
            println!("{}", serde_json::json!({"status": "error", "message": e}));
            return;
        }
    };
    let elapsed = t0.elapsed().as_secs_f32();

    let comfy_out = get_home().join(".local").join("share").join("comfyui").join("output").join(&saved_filename);
    if comfy_out.exists() {
        let _ = fs::copy(&comfy_out, &gallery_out);
    }

    if gallery_out.exists() && gallery_out.metadata().map(|m| m.len() > 1024).unwrap_or(false) {
        // Embed metadata into PNG chunks natively
        let seed_str = final_seed.to_string();
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
        let _ = std::io::stdout().flush();
    } else {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": "Generation failed or output missing"})
        );
        let _ = std::io::stdout().flush();
    }
}

// ---------------------------------------------------------
// Settings Management (Atomic 0600 Persistence)
// ---------------------------------------------------------

fn get_settings_path() -> PathBuf {
    get_home()
        .join(".config")
        .join("omarchy")
        .join("plugins")
        .join("simonez.qwenimage")
        .join("settings.json")
}

fn load_settings() -> serde_json::Value {
    let p = get_settings_path();
    if let Ok(content) = fs::read_to_string(&p) {
        if let Ok(val) = serde_json::from_str(&content) {
            return val;
        }
    }
    serde_json::json!({})
}

fn save_settings(val: &serde_json::Value) -> Result<(), std::io::Error> {
    let p = get_settings_path();
    if let Some(parent) = p.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let s = serde_json::to_string_pretty(val)
        .map_err(std::io::Error::other)?;
    let tmp = p.with_extension("tmp");
    let mut f = File::create(&tmp)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = f.set_permissions(fs::Permissions::from_mode(0o600));
    }
    f.write_all(s.as_bytes())?;
    f.sync_all()?;
    fs::rename(&tmp, &p)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&p, fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

fn cmd_settings_get() {
    let mut val = load_settings();
    if !val.is_object() {
        val = serde_json::json!({});
    }
    let obj = val.as_object_mut().unwrap();
    let lang = obj.get("language").and_then(|v| v.as_str()).unwrap_or("cs");
    let nsfw = obj.get("nsfw").and_then(|v| v.as_bool()).unwrap_or(false);
    let anime = obj.get("anime_lora").and_then(|v| v.as_bool()).unwrap_or(false);
    let turbo = obj.get("turbo").and_then(|v| v.as_bool()).unwrap_or(true);
    let uncensored = obj.get("uncensored").and_then(|v| v.as_bool()).unwrap_or(false);
    let res_mode = obj.get("res_mode").and_then(|v| v.as_str()).unwrap_or("standard");

    println!("{}", serde_json::json!({
        "status": "ok",
        "lang": lang,
        "nsfw": nsfw,
        "anime": anime,
        "turbo": turbo,
        "uncensored": uncensored,
        "res_mode": res_mode,
        "settings": val
    }));
}

fn cmd_settings_set(key: &str, value: &str) {
    let mut val = load_settings();
    if !val.is_object() {
        val = serde_json::json!({});
    }
    if let Some(map) = val.as_object_mut() {
        match key {
            "nsfw" | "anime_lora" | "turbo" | "uncensored" => {
                let b = value.eq_ignore_ascii_case("true") || value == "1";
                map.insert(key.to_string(), serde_json::json!(b));
            }
            "language" | "lang" => {
                let l = if value == "en" { "en" } else { "cs" };
                map.insert("language".to_string(), serde_json::json!(l));
            }
            "res_mode" => {
                map.insert("res_mode".to_string(), serde_json::json!(value));
            }
            other => {
                map.insert(other.to_string(), serde_json::json!(value));
            }
        }
    }
    match save_settings(&val) {
        Ok(_) => println!("{}", serde_json::json!({"status": "ok", "key": key, "value": value})),
        Err(e) => println!("{}", serde_json::json!({"status": "error", "message": format!("{}", e)})),
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
        "settings" => {
            if args.len() >= 3 && args[2] == "set" {
                if args.len() >= 5 {
                    cmd_settings_set(&args[3], &args[4]);
                } else {
                    eprintln!("Usage: qwen_bridge settings set <key> <val>");
                }
            } else {
                cmd_settings_get();
            }
        }
        "paste-clipboard" => cmd_paste_clipboard(),
        "copy-text" => {
            let text = if args.len() >= 3 {
                Some(args[2].as_str())
            } else {
                None
            };
            cmd_copy_text(text);
        }
        "copy-image" => {
            if args.len() >= 3 {
                cmd_copy_image(&args[2]);
            }
        }
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
            let mut limit = 100usize;
            let mut nsfw_allowed = false;
            let mut idx = 3;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(100);
                        idx += 2;
                        continue;
                    }
                } else if args[idx] == "--nsfw" {
                    nsfw_allowed = true;
                    idx += 1;
                    continue;
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit, nsfw_allowed);
        }
        "civitai" | "lexica" | "prompthero" | "openart" | "huggingface" | "hf" | "krea" | "tensorart" | "tensor" | "midlibrary" | "diffusiondb" | "seaart" | "shakker" | "playground" => {
            let source = args[1].as_str();
            let mut query_words = Vec::new();
            let mut limit = 100usize;
            let mut nsfw_allowed = false;
            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(100);
                        idx += 2;
                        continue;
                    }
                } else if args[idx] == "--nsfw" {
                    nsfw_allowed = true;
                    idx += 1;
                    continue;
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit, nsfw_allowed);
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
            let mut res_mode: Option<String> = None;
            let mut anime = false;
            let mut turbo = false;
            let mut uncensored = false;
            let mut pos_args: Vec<&str> = Vec::new();

            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--anime" {
                    anime = true;
                    idx += 1;
                } else if args[idx] == "--turbo" {
                    turbo = true;
                    idx += 1;
                } else if args[idx] == "--uncensored" || args[idx] == "--heretic" {
                    uncensored = true;
                    idx += 1;
                } else if args[idx] == "--res" || args[idx] == "--res-mode" {
                    if let Some(next) = args.get(idx + 1) {
                        res_mode = Some(next.clone());
                        idx += 2;
                        continue;
                    }
                    idx += 1;
                } else {
                    pos_args.push(&args[idx]);
                    idx += 1;
                }
            }

            let prompt = pos_args.first().copied().unwrap_or("");
            let ratio = pos_args.get(1).copied().unwrap_or("1:1");
            let steps = pos_args.get(2).and_then(|s| s.parse::<u32>().ok()).unwrap_or(25);
            let cfg = pos_args.get(3).and_then(|s| s.parse::<f32>().ok()).unwrap_or(4.0);
            let seed = pos_args.get(4).and_then(|s| s.parse::<i64>().ok()).unwrap_or(-1);
            let negative = pos_args.get(5).copied().unwrap_or("");
            let image_ref = pos_args.get(6).copied().filter(|s| !s.trim().is_empty());
            let denoise = pos_args.get(7).and_then(|s| s.parse::<f32>().ok()).unwrap_or(0.85).clamp(0.05, 0.95);

            cmd_generate(prompt, ratio, steps, cfg, seed, negative, image_ref, denoise, anime, turbo, uncensored, res_mode.as_deref());
        }
        other => {
            eprintln!("Unknown command: {}", other);
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_foreign_prompt_tags() {
        let input = "<lora:add-detail:0.8> a futuristic warrior <embedding:easynegative:1.0> <hypernet:style:0.5>";
        let stripped = strip_foreign_prompt_tags(input);
        assert_eq!(stripped, "a futuristic warrior");

        let plain = "clean prompt without any tags";
        assert_eq!(strip_foreign_prompt_tags(plain), "clean prompt without any tags");

        let multiple_spaces = "<lora:foo:1>   girl   in   rain   <lora:bar:0.5>";
        assert_eq!(strip_foreign_prompt_tags(multiple_spaces), "girl in rain");
    }

    #[test]
    fn test_unpack_json_prompt_if_present() {
        let raw_json = r#"{"rewritten_prompt": "A high-tech android walking through rain", "wh_ratio": "16:9"}"#;
        let unpacked = unpack_json_prompt_if_present(raw_json);
        assert_eq!(unpacked, "A high-tech android walking through rain");

        let escaped_json = r#"{"rewritten_prompt": "First line\nSecond line with \"quotes\"", "wh_ratio": "1:1"}"#;
        let unpacked_escaped = unpack_json_prompt_if_present(escaped_json);
        assert_eq!(unpacked_escaped, "First line\nSecond line with \"quotes\"");

        let plain = "just a regular text prompt without json";
        assert_eq!(unpack_json_prompt_if_present(plain), "just a regular text prompt without json");
    }

    #[test]
    fn test_is_czech_text() {
        assert!(is_czech_text("Krásná dívka se dívá na západ slunce"));
        assert!(is_czech_text("žena a muž kráčejí městem"));
        assert!(!is_czech_text("A stunning portrait of an astronaut on Mars with cinematic lighting"));
        assert!(!is_czech_text("futuristic cyberpunk vehicle neon"));
    }

    #[test]
    fn test_detect_human_subject() {
        assert!(detect_human_subject("portrait of a beautiful woman"));
        assert!(detect_human_subject("nude model in soft studio light"));
        assert!(detect_human_subject("fotorealistický akt dívky"));
        assert!(detect_human_subject("young girl holding flowers"));
        assert!(!detect_human_subject("mountain landscape at sunrise with snowy peaks"));
        assert!(!detect_human_subject("sports car drifting on wet asphalt"));
    }

    #[test]
    fn test_urlencoding_encode() {
        assert_eq!(urlencoding_encode("cyberpunk girl"), "cyberpunk%20girl");
        assert_eq!(urlencoding_encode("tag1 & tag2"), "tag1%20%26%20tag2");
        assert_eq!(urlencoding_encode("simple_word-123.test"), "simple_word-123.test");
    }

    #[test]
    fn test_deterministic_seed_constant() {
        const SEED_PARAM: usize = 0x732641;
        assert_eq!(SEED_PARAM, 7546433);
        let normalized = (SEED_PARAM % 1000) as f64 / 1000.0;
        assert!((normalized - 0.433).abs() < 1e-6);
    }

    #[test]
    fn test_calculate_dimensions_and_alignment() {
        let (w_square, h_square) = comfy::calculate_dimensions("1:1", "standard", false, None);
        assert_eq!(w_square, 1024);
        assert_eq!(h_square, 1024);
        assert_eq!(w_square % 16, 0);
        assert_eq!(h_square % 16, 0);

        let (w_16_9, h_16_9) = comfy::calculate_dimensions("16:9", "standard", false, None);
        assert_eq!(w_16_9, 1280);
        assert_eq!(h_16_9, 720);
        assert_eq!(w_16_9 % 16, 0);
        assert_eq!(h_16_9 % 16, 0);

        // Human subject floor: draft mode should remain standard 1024 floor
        let (w_draft_human, h_draft_human) = comfy::calculate_dimensions("1:1", "draft", true, None);
        assert_eq!(w_draft_human, 1024);
        assert_eq!(h_draft_human, 1024);
    }

    #[test]
    fn test_build_generation_graph_declarative() {
        let cfg = comfy::GenerationConfig {
            prompt: "cyberpunk android in rain",
            negative_prompt: "blurry",
            ratio: "1:1",
            steps: 25,
            cfg: 4.0,
            seed: 42,
            image_ref: None,
            denoise: 0.85,
            anime: false,
            turbo: false,
            uncensored: false,
            res_mode: "standard",
            is_human: false,
        };

        let (graph, final_seed, w, h) = comfy::build_generation_graph(&cfg).expect("graph build should succeed");
        assert_eq!(final_seed, 42);
        assert_eq!(w, 1024);
        assert_eq!(h, 1024);
        assert!(graph.get("1").is_some());
        assert!(graph.get("4").is_some());
        assert!(graph.get("6").is_some());
        assert!(graph.get("8").is_some());
    }
}
