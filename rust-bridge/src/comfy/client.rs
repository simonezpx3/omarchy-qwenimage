use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

use serde_json::{json, Value};
use tungstenite::connect;

use super::{generate_session_client_id, get_comfy_dir, get_home, load_env_conf, now_millis};

fn run_launcher_and_check(mut cmd: Command) -> bool {
    cmd.stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());

    match cmd.spawn() {
        Ok(mut child) => {
            // Verify within 1.5s that launcher didn't crash or exit with error (F1)
            for i in 0..5 {
                std::thread::sleep(Duration::from_millis(300));
                match child.try_wait() {
                    Ok(Some(status)) => {
                        // Exited cleanly after backgrounding
                        return status.success();
                    }
                    Ok(None) => {
                        // Still running in background
                        if i == 4 {
                            return true;
                        }
                    }
                    Err(_) => return false,
                }
            }
            true
        }
        Err(_) => false,
    }
}

pub fn ensure_comfyui_running() -> bool {
    let url = "http://127.0.0.1:8188/system_stats";
    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_millis(800)))
        .build()
        .new_agent();

    if let Ok(resp) = agent.get(url).call() {
        if resp.status().as_u16() == 200 {
            return true;
        }
    }

    // Stage 1: Try standalone helper launchers (~/.local/bin/qis, ~/.local/bin/comfy, or PATH)
    let mut launched = false;
    let qis_bin = get_home().join(".local").join("bin").join("qis");
    let comfy_bin = get_home().join(".local").join("bin").join("comfy");

    if qis_bin.exists() {
        let mut cmd = Command::new(&qis_bin);
        cmd.args(["start", "--bg"]);
        launched = run_launcher_and_check(cmd);
    }

    if !launched && comfy_bin.exists() {
        let mut cmd = Command::new(&comfy_bin);
        cmd.args(["start", "--bg"]);
        launched = run_launcher_and_check(cmd);
    }

    if !launched {
        let mut cmd = Command::new("comfy");
        cmd.args(["start", "--bg"]);
        launched = run_launcher_and_check(cmd);
    }

    // Stage 2: Direct fallback to ComfyUI Python runtime in ~/.local/share/comfyui
    if !launched {
        let comfy_dir = get_comfy_dir();
        let py_candidates = [
            comfy_dir.join("venv/bin/python"),
            comfy_dir.join(".venv/bin/python"),
            comfy_dir.join("venv/bin/python3"),
        ];
        let main_py = comfy_dir.join("main.py");

        if main_py.exists() {
            let conf = load_env_conf();
            let tier = std::env::var("QIS_VRAM_TIER")
                .ok()
                .or_else(|| conf.get("QIS_VRAM_TIER").cloned())
                .unwrap_or_else(|| "A".to_string())
                .to_uppercase();

            let reserve_str = std::env::var("QIS_VRAM_RESERVE_GB")
                .ok()
                .or_else(|| conf.get("QIS_VRAM_RESERVE_GB").cloned())
                .unwrap_or_else(|| {
                    let vram = crate::vram::get_vram_info();
                    if vram.total_mb >= 14000 {
                        "0.5".to_string()
                    } else if vram.total_mb >= 10000 {
                        "0.8".to_string()
                    } else {
                        "1.2".to_string()
                    }
                });

            let mut py_args = vec!["--listen", "127.0.0.1", "--port", "8188", "--preview-method", "auto", "--disable-cuda-malloc"];
            if tier == "B" {
                py_args.extend_from_slice(&["--lowvram", "--enable-dynamic-vram"]);
            } else if tier == "C" {
                py_args.push("--cpu");
            } else {
                py_args.extend_from_slice(&["--reserve-vram", &reserve_str, "--enable-dynamic-vram", "--fp8_e4m3fn-text-enc"]);
            }

            if tier != "C" {
                py_args.push("--use-sage-attention");
            }

            for py in &py_candidates {
                if py.exists() {
                    let mut cmd = Command::new(py);
                    cmd.arg(&main_py)
                        .args(&py_args)
                        .env("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True,garbage_collection_threshold:0.8")
                        .env("CUDA_MODULE_LOADING", "LAZY")
                        .env("OMP_NUM_THREADS", "8")
                        .env("MKL_NUM_THREADS", "8")
                        .env("OPENBLAS_NUM_THREADS", "8")
                        .stdin(std::process::Stdio::null())
                        .stdout(std::process::Stdio::null())
                        .stderr(std::process::Stdio::null());

                    #[cfg(target_os = "linux")]
                    {
                        use std::os::unix::process::CommandExt;
                        let parent_pid = unsafe { libc::getpid() };
                        unsafe {
                            cmd.pre_exec(move || {
                                if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL) != 0 {
                                    return Err(std::io::Error::last_os_error());
                                }
                                if libc::getppid() != parent_pid {
                                    libc::raise(libc::SIGKILL);
                                }
                                Ok(())
                            });
                        }
                    }

                    if let Ok(child) = cmd.spawn() {
                        let _ = fs::write(comfy_dir.join("comfyui.pid"), child.id().to_string());
                        launched = true;
                        break;
                    }
                }
            }
        }
    }

    if !launched {
        return false;
    }

    let start = Instant::now();
    // Cold start timeout extended to 45s for diverse hardware and clean installs
    while start.elapsed() < Duration::from_secs(45) {
        std::thread::sleep(Duration::from_millis(800));
        if let Ok(resp) = agent.get(url).call() {
            if resp.status().as_u16() == 200 {
                return true;
            }
        }
    }

    false
}

pub fn get_vram_free_mb() -> u64 {
    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_millis(800)))
        .build()
        .new_agent();

    if let Ok(mut resp) = agent.get("http://127.0.0.1:8188/system_stats").call() {
        if let Ok(val) = resp.body_mut().read_json::<Value>() {
            if let Some(devices) = val.get("devices").and_then(|d| d.as_array()) {
                if let Some(dev) = devices.first() {
                    if let Some(free) = dev.get("vram_free").and_then(|f| f.as_u64()) {
                        return free / (1024 * 1024);
                    }
                }
            }
        }
    }
    8192
}

pub fn interrupt_comfyui() -> bool {
    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_millis(1200)))
        .build()
        .new_agent();

    if let Ok(resp) = agent.post("http://127.0.0.1:8188/interrupt").send_json(json!({})) {
        return resp.status().as_u16() == 200;
    }
    false
}

pub fn free_comfyui_vram(force_unload: bool) -> bool {
    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_millis(1500)))
        .build()
        .new_agent();

    let body = json!({
        "unload_models": force_unload,
        "free_memory": true
    });

    if let Ok(resp) = agent.post("http://127.0.0.1:8188/free").send_json(&body) {
        return resp.status().as_u16() == 200;
    }
    false
}

fn get_preview_file_path(tick: u64) -> PathBuf {
    let uid = unsafe { libc::getuid() };
    let shm_dir = PathBuf::from(format!("/dev/shm/qis_preview_{}", uid));
    let dir = if Path::new("/dev/shm").is_dir() {
        let _ = fs::create_dir_all(&shm_dir);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&shm_dir, fs::Permissions::from_mode(0o700));
        }
        shm_dir
    } else {
        let base = std::env::var("XDG_RUNTIME_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", uid)));
        let d = if base.exists() && base.is_dir() {
            base.join("qwenimage")
        } else {
            get_home().join(".cache").join("qwenimage")
        };
        let _ = fs::create_dir_all(&d);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&d, fs::Permissions::from_mode(0o700));
        }
        d
    };
    dir.join(format!("qis_live_preview_{}.jpg", tick % 2))
}

pub fn execute_comfy_workflow(prompt_graph: &Value) -> Result<String, String> {
    let client_id = generate_session_client_id(now_millis());
    let mut preview_counter: u64 = 0;
    let _ = fs::remove_file(get_preview_file_path(0));
    let _ = fs::remove_file(get_preview_file_path(1));

    let mut output_nodes = Vec::new();
    if let Some(obj) = prompt_graph.as_object() {
        for (nid, nspec) in obj {
            if let Some(ctype) = nspec.get("class_type").and_then(|c| c.as_str()) {
                if ctype.contains("SaveImage") || ctype.contains("PreviewImage") || ctype.to_lowercase().contains("save") {
                    output_nodes.push(nid.clone());
                }
            }
        }
    }
    if output_nodes.is_empty() {
        output_nodes.push("8".to_string());
    }

    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(12)))
        .build()
        .new_agent();

    // Pre-flight memory cleanup if free VRAM is under pressure (< 3.2 GB)
    let vram_free_mb = crate::vram::get_vram_info().free_mb;
    if vram_free_mb < 3200 {
        free_comfyui_vram(false);
    }

    // 2-pass auto-recovery on CUDA OOM
    for attempt in 1..=2 {
        if attempt > 1 {
            eprintln!("\x1b[38;2;250;204;21mVRAM RECOVERY // Detekována paměťová kolize v ComfyUI. Čistím VRAM a opakuji pokus 2/2...\x1b[0m");
            free_comfyui_vram(true);
            std::thread::sleep(Duration::from_millis(500));
        }

        // 1. Submit prompt via HTTP POST
        let req_body = json!({
            "prompt": prompt_graph,
            "client_id": client_id
        });

        let resp_json: Value = match agent.post("http://127.0.0.1:8188/prompt").send_json(&req_body) {
            Ok(mut resp) => match resp.body_mut().read_json() {
                Ok(v) => v,
                Err(e) => return Err(format!("Failed to parse /prompt response: {}", e)),
            },
            Err(e) => return Err(format!("Failed to send POST /prompt to ComfyUI: {}", e)),
        };

        let prompt_id = match resp_json.get("prompt_id").and_then(|p| p.as_str()) {
            Some(id) => id.to_string(),
            None => return Err(format!("No prompt_id in ComfyUI response: {:?}", resp_json)),
        };

        // 2. Connect WebSocket for live streaming
        let ws_url = format!("ws://127.0.0.1:8188/ws?clientId={}", client_id);
        let mut saved_filename: Option<String> = None;
        let mut current_step = 0u32;
        let mut max_steps = 25u32;
        let mut execution_error: Option<String> = None;

        if let Ok((mut socket, _)) = connect(&ws_url) {
            if let tungstenite::stream::MaybeTlsStream::Plain(ref s) = socket.get_ref() {
                let _ = s.set_read_timeout(Some(Duration::from_secs(120)));
            }

            loop {
                let msg = match socket.read() {
                    Ok(m) => m,
                    Err(_) => break,
                };

                match msg {
                    tungstenite::Message::Binary(bin) => {
                        let img_bytes: Option<&[u8]> = if let Some(pos) = bin.windows(2).position(|w| w == [0xFF, 0xD8]) {
                            Some(&bin[pos..])
                        } else if let Some(pos) = bin.windows(4).position(|w| w == [0x89, 0x50, 0x4E, 0x47]) {
                            Some(&bin[pos..])
                        } else {
                            None
                        };

                        if let Some(payload) = img_bytes {
                            let target_path = get_preview_file_path(preview_counter);
                            let tmp_p = target_path.with_extension("tmp");
                            if fs::write(&tmp_p, payload).is_ok() {
                                let _ = fs::rename(&tmp_p, &target_path);
                                println!(
                                    "{}",
                                    json!({
                                        "event": "preview",
                                        "step": current_step,
                                        "max_steps": max_steps,
                                        "path": target_path.to_string_lossy(),
                                        "tick": preview_counter
                                    })
                                );
                                let _ = std::io::stdout().flush();
                                preview_counter = preview_counter.wrapping_add(1);
                            }
                        }
                    }
                    tungstenite::Message::Text(txt) => {
                        if let Ok(val) = serde_json::from_str::<Value>(&txt) {
                            let mtype = val.get("type").and_then(|t| t.as_str()).unwrap_or("");
                            let data = val.get("data");

                            if mtype == "progress" {
                                if let Some(d) = data {
                                    current_step = d.get("value").and_then(|v| v.as_u64()).unwrap_or(current_step as u64) as u32;
                                    max_steps = d.get("max").and_then(|m| m.as_u64()).unwrap_or(max_steps as u64) as u32;
                                    let active_path = if preview_counter > 0 {
                                        get_preview_file_path(preview_counter.saturating_sub(1)).to_string_lossy().to_string()
                                    } else {
                                        String::new()
                                    };
                                    println!(
                                        "{}",
                                        json!({
                                            "event": "preview",
                                            "step": current_step,
                                            "max_steps": max_steps,
                                            "path": active_path,
                                            "tick": preview_counter
                                        })
                                    );
                                    let _ = std::io::stdout().flush();
                                }
                            } else if mtype == "execution_error" {
                                let msg = data.and_then(|d| d.get("exception_message")).and_then(|m| m.as_str()).unwrap_or("Unknown execution error");
                                execution_error = Some(msg.to_string());
                                break;
                            } else if mtype == "executed" {
                                if let Some(d) = data {
                                    let ex_node = d.get("node").and_then(|n| n.as_str()).unwrap_or("");
                                    if output_nodes.contains(&ex_node.to_string()) || output_nodes.is_empty() {
                                        if let Some(output) = d.get("output") {
                                            if let Some(images) = output.get("images").and_then(|i| i.as_array()) {
                                                if let Some(first_img) = images.first() {
                                                    if let Some(fname) = first_img.get("filename").and_then(|f| f.as_str()) {
                                                        saved_filename = Some(fname.to_string());
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    tungstenite::Message::Close(_) => break,
                    _ => {}
                }
            }
            let _ = socket.close(None);
        }

        // Fallback to /history/{prompt_id} polling if WebSocket disconnected early
        if saved_filename.is_none() && execution_error.is_none() {
            let hist_url = format!("http://127.0.0.1:8188/history/{}", prompt_id);
            let poll_start = Instant::now();
            while poll_start.elapsed() < Duration::from_secs(120) {
                if let Ok(mut h_resp) = agent.get(&hist_url).call() {
                    if let Ok(h_val) = h_resp.body_mut().read_json::<Value>() {
                        if let Some(p_info) = h_val.get(&prompt_id) {
                            let status_str = p_info.get("status").and_then(|s| s.get("status_str")).and_then(|s| s.as_str());
                            if status_str == Some("error") {
                                execution_error = Some("ComfyUI history reported execution error".to_string());
                                break;
                            }
                            if let Some(outputs) = p_info.get("outputs").and_then(|o| o.as_object()) {
                                for out_nid in &output_nodes {
                                    if let Some(n_out) = outputs.get(out_nid) {
                                        if let Some(imgs) = n_out.get("images").and_then(|i| i.as_array()) {
                                            if let Some(f) = imgs.first().and_then(|i| i.get("filename")).and_then(|fn_| fn_.as_str()) {
                                                saved_filename = Some(f.to_string());
                                                break;
                                            }
                                        }
                                    }
                                }
                                if saved_filename.is_none() {
                                    for (_nid, n_out) in outputs {
                                        if let Some(imgs) = n_out.get("images").and_then(|i| i.as_array()) {
                                            if let Some(f) = imgs.first().and_then(|i| i.get("filename")).and_then(|fn_| fn_.as_str()) {
                                                saved_filename = Some(f.to_string());
                                                break;
                                            }
                                        }
                                    }
                                }
                                if saved_filename.is_some() {
                                    break;
                                }
                            }
                        }
                    }
                }
                std::thread::sleep(Duration::from_millis(800));
            }
        }

        if let Some(err) = execution_error {
            let is_oom = err.to_lowercase().contains("out of memory")
                || err.to_lowercase().contains("oom")
                || err.to_lowercase().contains("cuda")
                || err.to_lowercase().contains("allocation");
            if attempt == 1 && is_oom {
                continue;
            }
            return Err(format!("ComfyUI generation error: {}", err));
        }

        if let Some(fname) = saved_filename {
            return Ok(fname);
        }
    }

    Err("ComfyUI timeout: no output image returned".to_string())
}

pub fn is_qis_budget_node_available() -> bool {
    static AVAILABLE: std::sync::atomic::AtomicI8 = std::sync::atomic::AtomicI8::new(-1);
    let cached = AVAILABLE.load(std::sync::atomic::Ordering::Relaxed);
    if cached >= 0 {
        return cached == 1;
    }

    if cfg!(test) {
        return true;
    }

    let url = "http://127.0.0.1:8188/object_info/QISVramBudget";
    let agent = crate::common::get_http_agent(1);
    let found = if let Ok(mut resp) = agent.get(url).call() {
        if let Ok(json) = resp.body_mut().read_json::<serde_json::Value>() {
            json.get("QISVramBudget").is_some()
        } else {
            false
        }
    } else {
        false
    };

    AVAILABLE.store(if found { 1 } else { 0 }, std::sync::atomic::Ordering::Relaxed);
    found
}


