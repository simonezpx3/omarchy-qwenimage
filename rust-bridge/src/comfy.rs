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

fn get_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| std::env::var("USERPROFILE").map(PathBuf::from))
        .unwrap_or_else(|_| PathBuf::from("."))
}

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
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

    let comfy_bin = get_home().join(".local").join("bin").join("comfy");
    if comfy_bin.exists() {
        let _ = Command::new(&comfy_bin)
            .args(["start", "--bg"])
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    } else {
        let _ = Command::new("comfy")
            .args(["start", "--bg"])
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    }

    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(15) {
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

fn get_preview_file_path() -> PathBuf {
    let uid_dir = PathBuf::from("/run/user/1000");
    if uid_dir.is_dir() {
        uid_dir.join("qis_live_preview.jpg")
    } else {
        std::env::temp_dir().join("qis_live_preview.jpg")
    }
}

pub fn calculate_dimensions(
    ratio: &str,
    res_mode: &str,
    is_human: bool,
    input_image: Option<&str>,
) -> (u32, u32) {
    let hardware_max = 1536u32; // Tier B: RTX 3070 8GB

    if let Some(img_path) = input_image {
        let mut orig_w = 1024u32;
        let mut orig_h = 1024u32;
        if let Ok(dims) = image::image_dimensions(Path::new(img_path)) {
            orig_w = dims.0;
            orig_h = dims.1;
        }

        let max_orig = orig_w.max(orig_h);
        let target_max = hardware_max.min(if max_orig >= 1200 { 1280 } else { 1024 });
        let scale = target_max as f32 / max_orig as f32;

        let calc_w = (512u32.max((orig_w as f32 * scale) as u32) / 8) * 8;
        let calc_h = (512u32.max((orig_h as f32 * scale) as u32) / 8) * 8;

        return (calc_w.min(hardware_max), calc_h.min(hardware_max));
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

    let mut mult = match res_mode.to_lowercase().as_str() {
        "draft" | "preview" | "fast" => 0.5f32,
        "high" | "hi" => 1.25f32,
        "ultra" | "2k" | "2048" => 1.6f32,
        "max" | "4k" | "2560" => 2.0f32,
        _ => 1.0f32,
    };

    // Anatomical Safety Guard: draft mode under 768px degrades fine facial anatomy
    if is_human && mult < 1.0 {
        mult = 1.0;
    }

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

    let loras_dir = get_home().join(".local/share/comfyui/models/loras");
    let turbo_lora_file = loras_dir.join("qwen-image-2.1-viggle-turbo.safetensors");
    let uncensored_lora_file = loras_dir.join("qwen-image-2.1-uncensored-lora.safetensors");
    let anime_lora_file = loras_dir.join("qwen-image-2.1-anime-lora.safetensors");

    let has_turbo = cfg.turbo && turbo_lora_file.exists();
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

    let mut graph: Value = if let Some(ref_path) = cfg.image_ref {
        let p = Path::new(ref_path);
        if !p.exists() {
            return Err(format!("Reference image not found: {}", ref_path));
        }

        let comfy_in_dir = get_home().join(".local/share/comfyui/input");
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

    let mut current_model = json!(["1", 0]);

    if has_uncensored {
        let weight = if has_turbo { 0.55 } else { 0.85 };
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
        let weight = if has_turbo { 0.60 } else { 0.85 };
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
        graph["16"] = json!({
            "class_type": "ViggleTurboLora",
            "inputs": {
                "model": current_model,
                "lora_name": "qwen-image-2.1-viggle-turbo.safetensors",
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
        graph["20"] = json!({
            "class_type": "ViggleTurboSigmas",
            "inputs": {
                "latent": latent_node.clone(),
                "nodes": "1.0, 0.9375, 0.875, 0.75, 0.5, 0.25"
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

    Ok((graph, final_seed, width, height))
}

pub fn execute_comfy_workflow(prompt_graph: &Value) -> Result<String, String> {
    let client_id = format!("qis_{}", now_millis());
    let preview_file = get_preview_file_path();

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
                let _ = s.set_read_timeout(Some(Duration::from_secs(60)));
            }

            loop {
                let msg = match socket.read() {
                    Ok(m) => m,
                    Err(_) => break,
                };

                match msg {
                    tungstenite::Message::Binary(bin) => {
                        // ComfyUI Binary Frame:
                        // Bytes 0..4 = event_type (1 = PREVIEW_IMAGE, 2 = PREVIEW_IMAGE_WITH_METADATA)
                        // If type 1: JPEG payload starts at offset 8
                        // If type 2: metadata length at 4..8, payload starts at 8 + meta_len
                        if bin.len() > 8 {
                            let event_type = u32::from_be_bytes(bin[0..4].try_into().unwrap_or([0, 0, 0, 0]));
                            let img_bytes = if event_type == 1 {
                                &bin[8..]
                            } else if event_type == 2 && bin.len() > 12 {
                                let meta_len = u32::from_be_bytes(bin[4..8].try_into().unwrap_or([0, 0, 0, 0])) as usize;
                                if bin.len() > 8 + meta_len {
                                    &bin[8 + meta_len..]
                                } else {
                                    &bin[8..]
                                }
                            } else {
                                &bin[8..]
                            };

                            let tmp_p = preview_file.with_extension("tmp");
                            if fs::write(&tmp_p, img_bytes).is_ok() {
                                let _ = fs::rename(&tmp_p, &preview_file);
                                println!(
                                    "{}",
                                    json!({
                                        "event": "preview",
                                        "step": current_step,
                                        "max_steps": max_steps,
                                        "path": preview_file.to_string_lossy()
                                    })
                                );
                                let _ = std::io::stdout().flush();
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
                                    println!(
                                        "{}",
                                        json!({
                                            "event": "preview",
                                            "step": current_step,
                                            "max_steps": max_steps,
                                            "path": preview_file.to_string_lossy()
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

    let comfy_in_dir = get_home().join(".local/share/comfyui/input");
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
