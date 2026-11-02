use std::fs;
use std::path::Path;
use std::time::{Duration, Instant};

use serde_json::{json, Value};

use super::{ensure_comfyui_running, get_comfy_dir, SA_SIGNATURE_DNA};

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
