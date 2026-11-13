use std::path::Path;
use serde_json::{json, Value};

use super::{get_comfy_dir, GenerationConfig, LoraLevel};

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

pub(crate) fn resolve_vae_model_name() -> &'static str {
    let vae_dir = get_comfy_dir().join("models/vae");
    if vae_dir.join("qwen_image_2.1_vae_active.safetensors").exists() {
        "qwen_image_2.1_vae_active.safetensors"
    } else if vae_dir.join("texture_fix_vae_for_qwen_image_2.1_bf16.safetensors").exists() {
        "texture_fix_vae_for_qwen_image_2.1_bf16.safetensors"
    } else {
        "qwen_image_2.1_vae_bf16.safetensors"
    }
}

/// Calibrated per-LoRA strength helper keeping stacked weights within creator-safe bounds.
pub(crate) fn lora_strength(level: LoraLevel, has_turbo: bool, is_anime: bool) -> f64 {
    match (level, has_turbo, is_anime) {
        (LoraLevel::Off, _, _) => 0.0,
        (LoraLevel::Light, true, _) => 0.40,
        (LoraLevel::Light, false, _) => 0.45,
        (LoraLevel::Medium, true, true) => 0.60,
        (LoraLevel::Medium, false, true) => 0.65,
        (LoraLevel::Medium, true, false) => 0.65,
        (LoraLevel::Medium, false, false) => 0.70,
        (LoraLevel::Heavy, true, true) => 0.75,
        (LoraLevel::Heavy, false, true) => 0.80,
        (LoraLevel::Heavy, true, false) => 0.80,
        (LoraLevel::Heavy, false, false) => 0.85,
    }
}

pub(crate) fn inject_viggle_turbo_nodes(
    graph: &mut Value,
    cfg: &GenerationConfig,
    current_model: Value,
    resolved_turbo_name: Option<&str>,
    final_seed: i64,
) {
    let turbo_name = resolved_turbo_name.unwrap_or("qwen-image-2.1-viggle-turbo.safetensors");
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
    let has_ref_image = cfg.image_ref.filter(|s| !s.trim().is_empty()).is_some();
    let latent_node = if has_ref_image { json!(["5b", 0]) } else { json!(["5", 0]) };
    let use_hybrid_9 = cfg.steps == 9;
    let turbo_nodes = if use_hybrid_9 {
        // Viggle v0.3 6+3 hybrid schedule: 6 official Turbo steps + 3 Base CFGGuider refinement steps
        "1.0, 0.9375, 0.875, 0.75, 0.5, 0.25, 0.1875, 0.125, 0.0625"
    } else if cfg.is_human || cfg.steps == 7 {
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
    if use_hybrid_9 {
        let hybrid_cfg = if cfg.cfg > 1.05 { ((cfg.cfg as f64) * 10.0).round() / 10.0 } else { 2.2 };
        let neg_cond = if has_ref_image { json!(["4b", 0]) } else { json!(["4", 1]) };
        graph["20s"] = json!({
            "class_type": "SplitSigmas",
            "inputs": {
                "sigmas": ["20", 0],
                "step": 6
            }
        });
        graph["6a"] = json!({
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["18", 0],
                "guider": ["17", 0],
                "sampler": ["19", 0],
                "sigmas": ["20s", 0],
                "latent_image": latent_node
            }
        });
        graph["24"] = json!({
            "class_type": "CFGGuider",
            "inputs": {
                "model": current_model,
                "positive": ["4", 0],
                "negative": neg_cond,
                "cfg": hybrid_cfg
            }
        });
        graph["25"] = json!({
            "class_type": "DisableNoise",
            "inputs": {}
        });
        graph["6"] = json!({
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["25", 0],
                "guider": ["24", 0],
                "sampler": ["19", 0],
                "sigmas": ["20s", 1],
                "latent_image": ["6a", 0]
            }
        });
    } else {
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
    }

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

pub fn calculate_dynamic_vram_reserve(
    vram: &crate::vram::VramInfo,
    has_turbo: bool,
    active_lora_count: usize,
    width: u32,
    height: u32,
) -> (f32, bool) {
    let is_high_res = (width * height > 1024 * 1024) || width > 1024 || height > 1024;
    let is_vram_constrained = vram.total_mb <= 8500 || vram.free_mb < 3500;

    if vram.total_mb >= 16000 && !is_vram_constrained {
        return (0.5, false);
    }

    if vram.total_mb >= 11500 && !is_vram_constrained {
        if has_turbo && active_lora_count == 0 {
            return (0.5, false);
        } else if active_lora_count >= 2 {
            return (1.2, true);
        } else if active_lora_count == 1 {
            return (0.9, true);
        } else {
            return (0.6, false);
        }
    }

    if active_lora_count >= 2 {
        (if is_high_res { 1.6 } else { 1.5 }, true)
    } else if active_lora_count == 1 {
        (if is_high_res { 1.4 } else { 1.3 }, true)
    } else {
        (if is_high_res { 1.0 } else { 0.9 }, true)
    }
}

pub(crate) fn apply_vae_and_inpaint_postprocess(
    graph: &mut Value,
    cfg: &GenerationConfig,
    vram_info: &crate::vram::VramInfo,
    width: u32,
    height: u32,
    is_i2i: bool,
) {
    let is_constrained = vram_info.total_mb < 12000 || vram_info.free_mb < 3500;
    let needs_tiling = (width * height > 1024 * 1024) || width > 1024 || height > 1024 || is_constrained;
    let vae_node_key = graph
        .as_object()
        .and_then(|obj| {
            obj.iter()
                .find(|(_, node)| {
                    let ct = node.get("class_type").and_then(|v| v.as_str()).unwrap_or("");
                    ct == "VAEDecode" || ct == "VAEDecodeTiled"
                })
                .map(|(k, _)| k.clone())
        })
        .unwrap_or_else(|| "7".to_string());

    if let Some(node) = graph.get_mut(&vae_node_key) {
        let samples_ref = node
            .get("inputs")
            .and_then(|i| i.get("samples"))
            .cloned()
            .unwrap_or_else(|| json!(["6", 0]));

        let vae_ref = node
            .get("inputs")
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

    if is_i2i && cfg.mask_ref.filter(|s| !s.trim().is_empty()).is_some() && graph.get("9m").is_some() {
        graph["9f"] = json!({
            "class_type": "FeatherMask",
            "inputs": {
                "mask": ["9m", 0],
                "left": 16,
                "top": 16,
                "right": 16,
                "bottom": 16
            }
        });
        graph["7m"] = json!({
            "class_type": "ImageCompositeMasked",
            "inputs": {
                "destination": ["5", 0],
                "source": [vae_node_key, 0],
                "x": 0,
                "y": 0,
                "resize_source": true,
                "mask": ["9f", 0]
            }
        });
        if let Some(save_node) = graph.get_mut("8").and_then(|n| n.get_mut("inputs")) {
            save_node["images"] = json!(["7m", 0]);
        }
    }
}
