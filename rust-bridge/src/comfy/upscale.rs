use std::fs;
use std::path::Path;
use std::time::{Duration, Instant};

use serde_json::{json, Value};

use super::{ensure_comfyui_running, get_comfy_dir, get_home};

pub fn run_neural_upscale(
    input_path: &str,
    model_choice: &str,
    is_anime: bool,
) -> Result<Value, String> {
    let p = Path::new(input_path);
    if !p.exists() {
        return Err(format!("File not found: {}", input_path));
    }

    if !ensure_comfyui_running() {
        return Err("ComfyUI server is offline".to_string());
    }

    let comfy_in_dir = get_comfy_dir().join("input");
    let _ = fs::create_dir_all(&comfy_in_dir);

    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or("input_upscale");
    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("png");
    let clean_stem: String = stem.chars().filter(|c| c.is_alphanumeric() || *c == '_' || *c == '-').take(48).collect();
    let dest_name = format!("upscale_{}_{}.{}", if clean_stem.is_empty() { "img" } else { &clean_stem }, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis() % 100000, ext);
    let dest_file = comfy_in_dir.join(&dest_name);
    let _ = fs::copy(p, &dest_file);

    // Read input dimensions
    let (src_w, src_h) = match image::open(p) {
        Ok(img) => {
            use image::GenericImageView;
            img.dimensions()
        }
        Err(e) => return Err(format!("Failed to read input image dimensions: {}", e)),
    };

    let target_w = src_w * 4;
    let target_h = src_h * 4;
    let factor_label = "4X";

    let models_dir = get_comfy_dir().join("models/upscale_models");
    let (preferred_file, model_tag) = match model_choice.to_lowercase().as_str() {
        "esrgan" | "realesrgan" => ("RealESRGAN_x4plus.safetensors", "esrgan"),
        "ultra" | "ultrasharp" => ("4x-UltraSharp.safetensors", "ultra"),
        "anime" | "animesharp" => ("4x-AnimeSharp.safetensors", "anime"),
        _ => {
            if is_anime {
                ("4x-AnimeSharp.safetensors", "anime")
            } else {
                ("4x-UltraSharp.safetensors", "ultra")
            }
        }
    };

    let mut selected_model = preferred_file.to_string();
    if !models_dir.join(&selected_model).exists() {
        // Fallback search
        for fallback in &["RealESRGAN_x4plus.safetensors", "4x-UltraSharp.safetensors", "4x-AnimeSharp.safetensors"] {
            if models_dir.join(fallback).exists() {
                selected_model = fallback.to_string();
                break;
            }
        }
    }

    let pfx = format!("QIS_4X_{}_{}x{}", model_tag.to_uppercase(), target_w, target_h);

    let graph = json!({
        "1": {
            "class_type": "LoadImage",
            "inputs": {
                "image": dest_name
            }
        },
        "2": {
            "class_type": "UpscaleModelLoader",
            "inputs": {
                "model_name": selected_model
            }
        },
        "3": {
            "class_type": "ImageUpscaleWithModel",
            "inputs": {
                "upscale_model": ["2", 0],
                "image": ["1", 0]
            }
        },
        "4": {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": pfx,
                "images": ["3", 0]
            }
        }
    });

    let agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(60)))
        .build()
        .new_agent();

    let resp_json: Value = agent.post("http://127.0.0.1:8188/prompt")
        .send_json(json!({"prompt": graph}))
        .map_err(|e| format!("Failed to submit upscale prompt: {}", e))?
        .body_mut()
        .read_json()
        .map_err(|e| format!("Invalid JSON from /prompt: {}", e))?;

    let prompt_id = resp_json.get("prompt_id").and_then(|p| p.as_str()).ok_or("No prompt_id returned for upscale")?;

    let poll_start = Instant::now();
    let hist_url = format!("http://127.0.0.1:8188/history/{}", prompt_id);

    let poll_limit = Duration::from_secs(90);
    while poll_start.elapsed() < poll_limit {
        if let Ok(mut h_resp) = agent.get(&hist_url).call() {
            if let Ok(h_val) = h_resp.body_mut().read_json::<Value>() {
                if let Some(p_info) = h_val.get(prompt_id) {
                    if let Some(outputs) = p_info.get("outputs").and_then(|o| o.as_object()) {
                        let save_node_out = outputs.get("4").or_else(|| {
                            outputs.values().find(|n| n.get("images").is_some())
                        });

                        if let Some(node_data) = save_node_out {
                            if let Some(images) = node_data.get("images").and_then(|i| i.as_array()) {
                                if let Some(first) = images.first() {
                                    if let Some(fn_str) = first.get("filename").and_then(|f| f.as_str()) {
                                        let subfolder = first.get("subfolder").and_then(|s| s.as_str()).unwrap_or("");
                                        let out_dir = get_comfy_dir().join("output");
                                        let src_out_file = if subfolder.is_empty() {
                                            out_dir.join(fn_str)
                                        } else {
                                            out_dir.join(subfolder).join(fn_str)
                                        };

                                        if src_out_file.exists() {
                                            let gallery_dir = get_home().join("Pictures").join("Qwen-Image");
                                            let _ = fs::create_dir_all(&gallery_dir);

                                            let mut clean_bname = stem;
                                            for tag in &["_4x_", "_2x_", "_ai2k_", "_ai4k_", "_0.5x_", "_fit1k_", "_scaled_"] {
                                                if let Some(idx) = clean_bname.find(tag) {
                                                    clean_bname = &clean_bname[..idx];
                                                }
                                            }

                                            let cand_name = format!("{}_4x_{}_{}x{}.png", clean_bname, model_tag, target_w, target_h);

                                            let final_path = if gallery_dir.join(&cand_name).exists() {
                                                let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis() % 100000;
                                                gallery_dir.join(format!("{}_4x_{}_{}x{}_{}.png", clean_bname, model_tag, target_w, target_h, ts))
                                            } else {
                                                gallery_dir.join(&cand_name)
                                            };

                                            let _ = fs::copy(&src_out_file, &final_path);

                                            return Ok(json!({
                                                "status": "ok",
                                                "path": final_path.to_string_lossy(),
                                                "filename": final_path.file_name().unwrap_or_default().to_string_lossy(),
                                                "width": target_w,
                                                "height": target_h,
                                                "model": selected_model,
                                                "factor": factor_label
                                            }));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        std::thread::sleep(Duration::from_millis(300));
    }

    Err("Upscale timed out".to_string())
}
