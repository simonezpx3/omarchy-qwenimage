use std::fs::{self, File};
use std::io::{Read, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::path::Path;
use std::process::Command;
use std::time::Duration;
use fs2::FileExt;
use serde::Serialize;

use crate::common::get_http_agent;
use crate::comfy;

#[derive(Serialize, Clone, Debug, PartialEq)]
pub(crate) struct VramInfo {
    pub(crate) used_mb: u32,
    pub(crate) total_mb: u32,
    pub(crate) free_mb: u32,
    pub(crate) pct: u32,
    pub(crate) name: String,
}

pub(crate) struct VramLockGuard {
    file: File,
}

impl VramLockGuard {
    pub(crate) fn acquire(path: &Path) -> Result<Self, String> {
        let file = File::create(path).map_err(|e| format!("Lock file error: {}", e))?;
        file.try_lock_exclusive()
            .map_err(|_| "GENERATOR IS BUSY // TASK RUNNING".to_string())?;
        Ok(Self { file })
    }
}

impl Drop for VramLockGuard {
    fn drop(&mut self) {
        let _ = self.file.unlock();
    }
}

pub(crate) fn is_game_process_running() -> bool {
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

/// Detects whether llama-server is currently active (e.g. arci-moe35 or arci-qwen4b AI services).
pub(crate) fn is_llama_server_running() -> bool {
    let proc_dir = match fs::read_dir("/proc") {
        Ok(d) => d,
        Err(_) => return false,
    };

    for entry in proc_dir.flatten() {
        if let Ok(_pid) = entry.file_name().to_string_lossy().parse::<u32>() {
            let comm_path = entry.path().join("comm");
            if let Ok(comm_str) = fs::read_to_string(&comm_path) {
                if comm_str.trim() == "llama-server" {
                    return true;
                }
            }
        }
    }

    false
}

pub(crate) fn get_ollama_status() -> (u32, Vec<String>) {
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

pub(crate) fn stop_ollama_models(models: &[String]) {
    for m in models {
        let _ = Command::new("ollama")
            .args(["stop", m])
            .output();
    }
}

pub(crate) fn check_comfyui() -> bool {
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

pub(crate) fn check_ollama() -> bool {
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

pub(crate) fn check_wd14() -> bool {
    comfy::get_comfy_dir().join("custom_nodes/ComfyUI-WD14-Tagger").exists()
}

pub(crate) fn check_civitai() -> bool {
    if let Ok(mut addrs) = "civitai.com:443".to_socket_addrs() {
        if let Some(addr) = addrs.next() {
            return TcpStream::connect_timeout(&addr, Duration::from_millis(800)).is_ok();
        }
    }
    false
}

pub(crate) fn get_vram_info() -> VramInfo {
    let mut info = VramInfo {
        used_mb: 0,
        total_mb: 8192,
        free_mb: 8192,
        pct: 0,
        name: "Local NVIDIA GPU".to_string(),
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

pub(crate) fn check_gaming_hybrid(vram: &VramInfo) -> (bool, &'static str) {
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

        // If memory is shared with llama-server, it's cooperative AI workloads (not game lock)
        if is_llama_server_running() {
            return (false, "VRAM shared with local llama-server (cooperative AI workload)");
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
