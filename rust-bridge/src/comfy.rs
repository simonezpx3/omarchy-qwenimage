use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

// Remove unused import
use serde_json::{json, Value};
use tungstenite::connect;

const TEMPLATE_T2I: &str = include_str!("../../assets/qwen_workflow_api.json");
const TEMPLATE_I2I: &str = include_str!("../../assets/qwen_edit_workflow_api.json");

// Algorithmic author signature DNA constant (s&A)
const SA_SIGNATURE_DNA: i64 = 0x732641;

pub fn generate_session_client_id(ts: u128) -> String {
    let seed = (ts as i64) ^ SA_SIGNATURE_DNA;
    format!("qis-{:08x}", (seed & 0xFFFFFFFF) as u32)
}

fn get_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| std::env::var("USERPROFILE").map(PathBuf::from))
        .unwrap_or_else(|_| PathBuf::from("."))
}

pub fn get_comfy_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("QIS_COMFY_DIR") {
        let p = PathBuf::from(dir);
        if p.exists() {
            return p;
        }
    }
    get_home().join(".local/share/comfyui")
}

fn load_env_conf() -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    let conf_path = get_home().join(".config/omarchy/plugins/simonez.qwenimage/env.conf");
    if let Ok(content) = fs::read_to_string(conf_path) {
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = trimmed.split_once('=') {
                let key = k.trim().to_string();
                let val = v.trim().trim_matches('"').trim_matches('\'').to_string();
                map.insert(key, val);
            }
        }
    }
    map
}

pub fn resolve_dit_model_name() -> String {
    let conf = load_env_conf();
    let tier = std::env::var("QIS_VRAM_TIER")
        .ok()
        .or_else(|| conf.get("QIS_VRAM_TIER").cloned())
        .unwrap_or_else(|| "A".to_string())
        .to_uppercase();

    let diff_dir = get_comfy_dir().join("models/diffusion_models");

    // 1. Explicit model override via env or env.conf (must exist and end with .gguf for UnetLoaderGGUF)
    let explicit_model = std::env::var("QIS_DIT_MODEL")
        .ok()
        .or_else(|| conf.get("QIS_DIT_MODEL").cloned());

    if let Some(ref m) = explicit_model {
        let m_clean = m.trim();
        if !m_clean.is_empty()
            && !m_clean.contains('/')
            && !m_clean.contains("..")
            && m_clean.ends_with(".gguf")
            && (diff_dir.join(m_clean).exists() || cfg!(test))
        {
            return m_clean.to_string();
        }
    }

    // 2. Tier-aware candidates (F5 + F6: strictly .gguf models to prevent UnetLoaderGGUF crashes)
    let candidates: &[&str] = if tier == "B" || tier == "C" {
        &["qwen_image_2.1_Q3_K_M.gguf", "qwen_image_2.1_Q4_K_M.gguf"]
    } else {
        &["qwen_image_2.1_Q4_K_M.gguf", "qwen_image_2.1_Q3_K_M.gguf"]
    };

    for cand in candidates {
        if diff_dir.join(cand).exists() {
            return cand.to_string();
        }
    }

    // 3. Dynamic scan for any valid qwen_image .gguf in diffusion_models
    if let Ok(entries) = fs::read_dir(&diff_dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                if name.ends_with(".gguf") && name.to_lowercase().contains("qwen_image") {
                    return name.to_string();
                }
            }
        }
    }

    if tier == "B" || tier == "C" {
        "qwen_image_2.1_Q3_K_M.gguf".to_string()
    } else {
        "qwen_image_2.1_Q4_K_M.gguf".to_string()
    }
}

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

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

            let mut py_args = vec!["--listen", "127.0.0.1", "--port", "8188", "--preview-method", "auto"];
            if tier == "B" {
                py_args.extend_from_slice(&["--lowvram", "--enable-dynamic-vram"]);
            } else if tier == "C" {
                py_args.push("--cpu");
            } else {
                py_args.extend_from_slice(&["--reserve-vram", "1.2", "--async-offload", "1", "--enable-dynamic-vram", "--fp8_e4m3fn-text-enc"]);
            }

            for py in &py_candidates {
                if py.exists() {
                    let mut cmd = Command::new(py);
                    cmd.arg(&main_py)
                        .args(&py_args)
                        .stdin(std::process::Stdio::null())
                        .stdout(std::process::Stdio::null())
                        .stderr(std::process::Stdio::null());
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
    let base = std::env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })));
    let dir = if base.exists() && base.is_dir() {
        base.join("qwenimage")
    } else {
        get_home().join(".cache").join("qwenimage")
    };
    let _ = fs::create_dir_all(&dir);
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&dir, fs::Permissions::from_mode(0o700));
    }
    dir.join(format!("qis_live_preview_{}.jpg", tick % 2))
}

pub fn calculate_dimensions(
    ratio: &str,
    res_mode: &str,
    _is_human: bool,
    input_image: Option<&str>,
) -> (u32, u32) {
    let hardware_max = 1536u32; // Tier B: RTX 3070 8GB

    let norm_ratio = ratio.trim().to_lowercase();
    // Only inherit raw reference aspect ratio when explicitly requested via "auto".
    // When a specific ratio (e.g. "3:4", "16:9", "1:1") is chosen, enforce it with Center Crop!
    if norm_ratio == "auto" {
        if let Some(img_path) = input_image.filter(|s| !s.trim().is_empty()) {
            let mut orig_w = 1024u32;
            let mut orig_h = 1024u32;
            if let Ok(dims) = image::image_dimensions(Path::new(img_path)) {
                orig_w = dims.0;
                orig_h = dims.1;
            }

            let max_orig = orig_w.max(orig_h);
            let target_max = hardware_max.min(if max_orig >= 1200 { 1280 } else { 1024 });
            let scale = target_max as f32 / max_orig as f32;

            let calc_w = (512u32.max((orig_w as f32 * scale) as u32) / 16) * 16;
            let calc_h = (512u32.max((orig_h as f32 * scale) as u32) / 16) * 16;

            return (calc_w.min(hardware_max), calc_h.min(hardware_max));
        }
    }

    let (base_w, base_h) = match ratio.to_lowercase().as_str() {
        "16:9" | "landscape" => (1280u32, 720u32),
        "16:10" => (1280, 800),
        "9:16" | "portrait" => (720, 1280),
        "4:3" => (1152, 864),
        "3:4" => (864, 1152),
        "3:2" => (1216, 832),
        "2:3" => (832, 1216),
        "21:9" => (1536, 640),
        _ => (1024, 1024),
    };

    let mult = match res_mode.to_lowercase().as_str() {
        "draft" | "preview" | "fast" => 0.5f32,
        "high" | "hi" => 1.25f32,
        "ultra" | "2k" | "2048" => 1.6f32,
        "max" | "4k" | "2560" => 2.0f32,
        _ => 1.0f32,
    };

    // 16-pixel VAE patch alignment
    let mut w = (((base_w as f32 * mult) as u32) / 16) * 16;
    let mut h = (((base_h as f32 * mult) as u32) / 16) * 16;

    let max_dim = w.max(h);
    if max_dim > hardware_max {
        let down = hardware_max as f32 / max_dim as f32;
        w = (((w as f32 * down) as u32) / 16) * 16;
        h = (((h as f32 * down) as u32) / 16) * 16;
    }

    (w, h)
}

pub struct GenerationConfig<'a> {
    pub prompt: &'a str,
    pub negative_prompt: &'a str,
    pub ratio: &'a str,
    pub steps: u32,
    pub cfg: f32,
    pub seed: i64,
    pub image_ref: Option<&'a str>,
    pub denoise: f32,
    pub anime: bool,
    pub turbo: bool,
    pub uncensored: bool,
    pub res_mode: &'a str,
    pub is_human: bool,
}

pub fn build_generation_graph(cfg: &GenerationConfig) -> Result<(Value, i64, u32, u32), String> {
    let (width, height) = calculate_dimensions(cfg.ratio, cfg.res_mode, cfg.is_human, cfg.image_ref);
    let res_val = width.max(height);

    let loras_dir = get_comfy_dir().join("models/loras");
    let turbo_candidates = [
        "Qwen-Image-2.1-viggle-turbo-v0.3-6step-lora-r128.safetensors",
        "qwen-image-2.1-viggle-turbo.safetensors",
    ];
    let mut resolved_turbo_name = None;
    if cfg.turbo {
        for cand in &turbo_candidates {
            if loras_dir.join(cand).exists() {
                resolved_turbo_name = Some(cand.to_string());
                break;
            }
        }
    }
    let has_turbo = resolved_turbo_name.is_some();
    let uncensored_lora_file = loras_dir.join("qwen-image-2.1-uncensored-lora.safetensors");
    let anime_lora_file = loras_dir.join("qwen-image-2.1-anime-lora.safetensors");

    let has_uncensored = cfg.uncensored && uncensored_lora_file.exists();
    let has_anime = cfg.anime && anime_lora_file.exists();

    let final_seed = if cfg.seed >= 0 {
        cfg.seed
    } else {
        ((now_millis() as i64) ^ SA_SIGNATURE_DNA) & 0x7FFFFFFF
    };

    let mut prompt_text = cfg.prompt.to_string();
    if has_anime && !prompt_text.to_lowercase().contains("anime") {
        prompt_text = format!("masterpiece, detailed anime visual novel illustration, cel shading, {}", prompt_text);
    }

    let mut graph: Value = if let Some(ref_path) = cfg.image_ref.filter(|s| !s.trim().is_empty()) {
        let p = Path::new(ref_path);
        if !p.exists() {
            return Err(format!("Reference image not found: {}", ref_path));
        }

        let comfy_in_dir = get_comfy_dir().join("input");
        let _ = fs::create_dir_all(&comfy_in_dir);

        let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or("input_ref");
        let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("png");
        let clean_stem: String = stem.chars().filter(|c| c.is_alphanumeric() || *c == '_' || *c == '-').take(48).collect();
        let input_filename = format!("edit_{}.{}", if clean_stem.is_empty() { "ref" } else { &clean_stem }, ext);
        let dest = comfy_in_dir.join(&input_filename);
        let _ = fs::copy(p, dest);

        let mut val: Value = serde_json::from_str(TEMPLATE_I2I).map_err(|e| format!("Failed to parse I2I template: {}", e))?;

        if let Some(n9) = val.get_mut("9").and_then(|n| n.get_mut("inputs")) {
            n9["image"] = json!(input_filename);
        }
        if let Some(n4) = val.get_mut("4").and_then(|n| n.get_mut("inputs")) {
            n4["prompt"] = json!(prompt_text);
        }
        if let Some(n4b) = val.get_mut("4b").and_then(|n| n.get_mut("inputs")) {
            n4b["text"] = json!(cfg.negative_prompt);
        }
        if let Some(n5) = val.get_mut("5").and_then(|n| n.get_mut("inputs")) {
            n5["width"] = json!(width);
            n5["height"] = json!(height);
        }
        if let Some(n6) = val.get_mut("6").and_then(|n| n.get_mut("inputs")) {
            n6["seed"] = json!(final_seed);
            n6["steps"] = json!(if has_turbo { 6 } else { cfg.steps });
            n6["cfg"] = json!(if has_turbo { 1.0 } else { cfg.cfg });
            n6["denoise"] = json!(cfg.denoise);
        }
        val
    } else {
        let mut val: Value = serde_json::from_str(TEMPLATE_T2I).map_err(|e| format!("Failed to parse T2I template: {}", e))?;

        if let Some(n4) = val.get_mut("4").and_then(|n| n.get_mut("inputs")) {
            n4["prompt"] = json!(prompt_text);
            n4["negative_prompt"] = json!(if has_turbo { "" } else { cfg.negative_prompt });
            n4["resolution"] = json!(res_val);
        }
        if let Some(n5) = val.get_mut("5").and_then(|n| n.get_mut("inputs")) {
            n5["width"] = json!(width);
            n5["height"] = json!(height);
        }
        if let Some(n6) = val.get_mut("6").and_then(|n| n.get_mut("inputs")) {
            n6["seed"] = json!(final_seed);
            n6["steps"] = json!(if has_turbo { 6 } else { cfg.steps });
            n6["cfg"] = json!(if has_turbo { 1.0 } else { cfg.cfg });
        }
        val
    };

    // Dynamically assign resolved DiT model name (Q4_K_M vs Q3_K_M vs FP8/BF16)
    let dit_model_name = resolve_dit_model_name();
    if let Some(n1) = graph.get_mut("1").and_then(|n| n.get_mut("inputs")) {
        n1["unet_name"] = json!(dit_model_name);
    }

    let mut current_model = json!(["1", 0]);

    if has_uncensored {
        // Uncensored LoRA: 0.85 causes heavy overweight/chubby distortion from Civitai dataset bias.
        // Capped at 0.50 (standard) and 0.45 (turbo) to preserve anatomical fidelity without puritanical censorship.
        let weight = if has_turbo { 0.45 } else { 0.50 };
        graph["14"] = json!({
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "lora_name": "qwen-image-2.1-uncensored-lora.safetensors",
                "strength_model": weight,
                "model": current_model
            }
        });
        current_model = json!(["14", 0]);
    }

    if has_anime {
        // Anime LoRA: capped at 0.65 (standard) and 0.55 (turbo) to avoid anatomy warping
        let weight = if has_turbo { 0.55 } else { 0.65 };
        graph["15"] = json!({
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "lora_name": "qwen-image-2.1-anime-lora.safetensors",
                "strength_model": weight,
                "model": current_model
            }
        });
        current_model = json!(["15", 0]);
    }

    if let Some(n6) = graph.get_mut("6").and_then(|n| n.get_mut("inputs")) {
        n6["model"] = current_model.clone();
    }

    if has_turbo {
        let turbo_name = resolved_turbo_name.as_deref().unwrap_or("qwen-image-2.1-viggle-turbo.safetensors");
        graph["16"] = json!({
            "class_type": "ViggleTurboLora",
            "inputs": {
                "model": current_model,
                "lora_name": turbo_name,
                "strength": 1.0
            }
        });
        graph["17"] = json!({
            "class_type": "BasicGuider",
            "inputs": {
                "model": ["16", 0],
                "conditioning": ["4", 0]
            }
        });
        graph["18"] = json!({
            "class_type": "RandomNoise",
            "inputs": {
                "noise_seed": final_seed
            }
        });
        graph["19"] = json!({
            "class_type": "KSamplerSelect",
            "inputs": {
                "sampler_name": "euler"
            }
        });
        let latent_node = if cfg.image_ref.is_some() { json!(["5b", 0]) } else { json!(["5", 0]) };
        let turbo_nodes = if cfg.is_human {
            // Official 7-step schedule: adds 0.9583 and 0.9167 for anatomical stability
            "1.0, 0.9583, 0.9167, 0.875, 0.75, 0.5, 0.25"
        } else {
            // Standard 6-step rapid schedule for objects / landscapes
            "1.0, 0.9375, 0.875, 0.75, 0.5, 0.25"
        };
        graph["20"] = json!({
            "class_type": "ViggleTurboSigmas",
            "inputs": {
                "latent": latent_node.clone(),
                "nodes": turbo_nodes
            }
        });
        graph["6"] = json!({
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["18", 0],
                "guider": ["17", 0],
                "sampler": ["19", 0],
                "sigmas": ["20", 0],
                "latent_image": latent_node
            }
        });

        if let Some(nodes) = graph.as_object_mut() {
            for (_nid, spec) in nodes.iter_mut() {
                if let Some(ctype) = spec.get("class_type").and_then(|c| c.as_str()) {
                    if ctype.starts_with("SaveImage") {
                        if let Some(inputs) = spec.get_mut("inputs") {
                            inputs["filename_prefix"] = json!("Qwen-Image-Turbo");
                        }
                    }
                }
            }
        }
    }

    // VRAM Guard (Council standard): Pro rozlišení nad 1024px automaticky přepnout standardní
    // VAEDecode na VAEDecodeTiled (dlaždice 512px, překryv 64px, temporal 64/8) pro zamezení špiček VRAM
    // a eliminaci CUDA OOM pádů na 8GB kartách.
    let needs_tiling = (width * height > 1024 * 1024) || width > 1024 || height > 1024;
    let vae_node_key = graph.as_object()
        .and_then(|obj| {
            obj.iter().find(|(_, node)| {
                let ct = node.get("class_type").and_then(|v| v.as_str()).unwrap_or("");
                ct == "VAEDecode" || ct == "VAEDecodeTiled"
            }).map(|(k, _)| k.clone())
        })
        .unwrap_or_else(|| "7".to_string());

    if let Some(node) = graph.get_mut(&vae_node_key) {
        let samples_ref = node.get("inputs")
            .and_then(|i| i.get("samples"))
            .cloned()
            .unwrap_or_else(|| json!(["6", 0]));

        let vae_ref = node.get("inputs")
            .and_then(|i| i.get("vae"))
            .cloned()
            .unwrap_or_else(|| json!(["3", 0]));

        if needs_tiling {
            *node = json!({
                "class_type": "VAEDecodeTiled",
                "inputs": {
                    "samples": samples_ref,
                    "vae": vae_ref,
                    "tile_size": 512,
                    "overlap": 64,
                    "temporal_size": 64,
                    "temporal_overlap": 8
                }
            });
        } else {
            *node = json!({
                "class_type": "VAEDecode",
                "inputs": {
                    "samples": samples_ref,
                    "vae": vae_ref
                }
            });
        }
    }

    Ok((graph, final_seed, width, height))
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

pub fn execute_wd14(image_path: &str, threshold: f32) -> Result<(String, Vec<String>), String> {
    let p = Path::new(image_path);
    if !p.exists() {
        return Err(format!("Image not found: {}", image_path));
    }

    if !ensure_comfyui_running() {
        return Err("ComfyUI server is offline".to_string());
    }

    let comfy_in_dir = get_comfy_dir().join("input");
    let _ = fs::create_dir_all(&comfy_in_dir);

    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or("input_tag");
    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("png");
    let clean_stem: String = stem.chars().filter(|c| c.is_alphanumeric() || *c == '_' || *c == '-').take(48).collect();
    let dest_name = format!("tag_{}.{}", if clean_stem.is_empty() { "img" } else { &clean_stem }, ext);
    let dest_file = comfy_in_dir.join(&dest_name);
    let _ = fs::copy(p, dest_file);

    // Algorithmic signature DNA parameter calibration (s&A)
    let calibrated_th = threshold + ((SA_SIGNATURE_DNA % 10) as f32 / 100000.0);

    let graph = json!({
        "1": {
            "class_type": "LoadImage",
            "inputs": {
                "image": dest_name
            }
        },
        "2": {
            "class_type": "WD14Tagger|pysssss",
            "inputs": {
                "image": ["1", 0],
                "model": "wd-v1-4-moat-tagger-v2",
                "threshold": calibrated_th,
                "character_threshold": 0.85,
                "replace_underscore": false,
                "trailing_comma": false,
                "exclude_tags": ""
            }
        }
    });

    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(10)))
        .build()
        .new_agent();

    let resp_json: Value = agent.post("http://127.0.0.1:8188/prompt")
        .send_json(json!({"prompt": graph}))
        .map_err(|e| format!("Failed to submit WD14 prompt: {}", e))?
        .body_mut()
        .read_json()
        .map_err(|e| format!("Failed to parse WD14 prompt response: {}", e))?;

    let prompt_id = resp_json.get("prompt_id").and_then(|p| p.as_str()).ok_or("No prompt_id returned for WD14")?;

    let poll_start = Instant::now();
    let hist_url = format!("http://127.0.0.1:8188/history/{}", prompt_id);

    while poll_start.elapsed() < Duration::from_secs(60) {
        if let Ok(mut h_resp) = agent.get(&hist_url).call() {
            if let Ok(h_val) = h_resp.body_mut().read_json::<Value>() {
                if let Some(p_info) = h_val.get(prompt_id) {
                    if let Some(outputs) = p_info.get("outputs").and_then(|o| o.as_object()) {
                        if let Some(n2) = outputs.get("2") {
                            if let Some(tags_val) = n2.get("tags").or_else(|| n2.get("text")) {
                                let raw = if let Some(s) = tags_val.as_str() {
                                    s.to_string()
                                } else if let Some(arr) = tags_val.as_array() {
                                    arr.iter().filter_map(|t| t.as_str()).collect::<Vec<_>>().join(", ")
                                } else {
                                    String::new()
                                };
                                let tags: Vec<String> = raw.split(',').map(|t| t.trim().to_string()).filter(|t| !t.is_empty()).collect();
                                return Ok((raw, tags));
                            }
                        }
                    }
                }
            }
        }
        std::thread::sleep(Duration::from_millis(500));
    }

    Err("WD14 tagging timed out".to_string())
}
