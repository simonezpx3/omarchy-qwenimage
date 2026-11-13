use std::fs;
use std::path::Path;
use serde_json::{json, Value};

use super::budget::{
    apply_vae_and_inpaint_postprocess, inject_viggle_turbo_nodes, lora_strength,
    resolve_vae_model_name,
};
pub use super::budget::{calculate_dimensions, calculate_dynamic_vram_reserve};
use super::{get_comfy_dir, now_millis, resolve_dit_model_name, GenerationConfig, LoraLevel, SA_SIGNATURE_DNA};

const TEMPLATE_T2I: &str = include_str!("../../../assets/qwen_workflow_api.json");
const TEMPLATE_I2I: &str = include_str!("../../../assets/qwen_edit_workflow_api.json");

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
        if resolved_turbo_name.is_none() && cfg!(test) {
            resolved_turbo_name = Some(turbo_candidates[0].to_string());
        }
    }
    let has_turbo = resolved_turbo_name.is_some();
    let uncensored_lora_file = loras_dir.join("qwen-image-2.1-uncensored-lora.safetensors");
    let anime_lora_file = loras_dir.join("qwen-image-2.1-anime-lora.safetensors");
    let anatomy_lora_file = loras_dir.join("Genitalia-Anatomy-2.1-v1.safetensors");

    let has_uncensored = cfg.uncensored.is_active() && (uncensored_lora_file.exists() || cfg!(test));
    let has_anime = cfg.anime.is_active() && (anime_lora_file.exists() || cfg!(test));
    let has_anatomy = cfg.anatomy.is_active() && (anatomy_lora_file.exists() || cfg!(test));

    let final_seed = if cfg.seed >= 0 {
        cfg.seed
    } else {
        ((now_millis() as i64) ^ SA_SIGNATURE_DNA) & 0x7FFFFFFF
    };

    let mut prompt_text = cfg.prompt.to_string();
    let p_lower = prompt_text.to_lowercase();
    if has_anime && !p_lower.contains("cel shading") && !p_lower.contains("visual novel") {
        match cfg.anime {
            LoraLevel::Heavy => {
                prompt_text = format!("masterpiece, detailed anime visual novel illustration, cel shading, {}", prompt_text);
            }
            LoraLevel::Medium => {
                prompt_text = format!("masterpiece, clean stylized illustration, expressive anime aesthetic, {}", prompt_text);
            }
            LoraLevel::Light => {
                prompt_text = format!("clean anime subtle styling, {}", prompt_text);
            }
            LoraLevel::Off => {}
        }
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
            n6["cfg"] = json!(if has_turbo { 1.0 } else if cfg.cfg <= 1.05 { 4.0 } else { cfg.cfg });
            n6["denoise"] = json!(cfg.denoise);
        }

        // Inpainting: LoadImageMask + switch VAEEncode ("5b") -> VAEEncodeForInpaint
        if let Some(mask_path) = cfg.mask_ref.filter(|s| !s.trim().is_empty()) {
            let mp = Path::new(mask_path);
            if !mp.exists() {
                return Err(format!("Inpaint mask image not found: {}", mask_path));
            }
            let m_stem = mp.file_stem().and_then(|s| s.to_str()).unwrap_or("mask");
            let m_ext = mp.extension().and_then(|e| e.to_str()).unwrap_or("png");
            let m_clean: String = m_stem.chars().filter(|c| c.is_alphanumeric() || *c == '_' || *c == '-').take(48).collect();
            let mask_filename = format!("mask_{}.{}", if m_clean.is_empty() { "inpaint" } else { &m_clean }, m_ext);
            let mask_dest = comfy_in_dir.join(&mask_filename);
            let _ = fs::copy(mp, mask_dest);

            val["9m"] = json!({
                "class_type": "LoadImageMask",
                "inputs": {
                    "image": mask_filename,
                    "channel": "red"
                }
            });
            val["5b_enc"] = json!({
                "class_type": "VAEEncode",
                "inputs": {
                    "pixels": ["5", 0],
                    "vae": ["3", 0]
                }
            });
            val["5b"] = json!({
                "class_type": "SetLatentNoiseMask",
                "inputs": {
                    "samples": ["5b_enc", 0],
                    "mask": ["9m", 0]
                }
            });
        }
        val
    } else {
        let mut val: Value = serde_json::from_str(TEMPLATE_T2I).map_err(|e| format!("Failed to parse T2I template: {}", e))?;

        if let Some(n4) = val.get_mut("4").and_then(|n| n.get_mut("inputs")) {
            n4["prompt"] = json!(prompt_text);
            n4["negative_prompt"] = json!(if has_turbo && cfg.steps != 9 { "" } else { cfg.negative_prompt });
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

    // Dynamically assign resolved DiT model name (Q4_K_M vs Q3_K_M vs FP8/BF16) and active VAE
    let dit_model_name = resolve_dit_model_name();
    if let Some(n1) = graph.get_mut("1").and_then(|n| n.get_mut("inputs")) {
        n1["unet_name"] = json!(dit_model_name);
    }
    if let Some(n3) = graph.get_mut("3").and_then(|n| n.get_mut("inputs")) {
        n3["vae_name"] = json!(resolve_vae_model_name());
    }

    let mut current_model = json!(["1", 0]);

    if has_uncensored {
        let weight = lora_strength(cfg.uncensored, has_turbo, false);
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
        // Qwen2.1_Anime_consistency: creator-recommended ceiling is 0.6–0.8
        let weight = lora_strength(cfg.anime, has_turbo, true);
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

    if has_anatomy {
        let weight = lora_strength(cfg.anatomy, has_turbo, false);
        graph["22"] = json!({
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "lora_name": "Genitalia-Anatomy-2.1-v1.safetensors",
                "strength_model": weight,
                "model": current_model
            }
        });
        current_model = json!(["22", 0]);
    }

    // Dynamic per-request VRAM Budget Governor:
    // Calculates exact reserve budget based on active feature complexity (Turbo, LoRA count, resolution).
    let has_any_lora = has_uncensored || has_anime || has_anatomy;
    let active_lora_count = (if has_uncensored { 1 } else { 0 })
        + (if has_anime { 1 } else { 0 })
        + (if has_anatomy { 1 } else { 0 });

    let vram_info = crate::vram::get_vram_info();
    let (dynamic_reserve, purge_cache) = calculate_dynamic_vram_reserve(
        &vram_info,
        has_turbo,
        active_lora_count,
        width,
        height,
    );

    if super::client::is_qis_budget_node_available() {
        graph["23"] = json!({
            "class_type": "QISVramBudget",
            "inputs": {
                "model": current_model,
                "reserve_gb": dynamic_reserve,
                "purge_cache": purge_cache
            }
        });
        current_model = json!(["23", 0]);
    }

    // EasyCache integration for standard DiT sampling:
    // Empirically verified on RTX 3070: cuts 20-step generation from 103.7 s to 33.6 s (3.09x speedup)
    // with negligible +160 MB VRAM overhead. In 6-step Turbo mode, native schedule runs in 13.0 s without cache overhead.
    // Concurrently dequantizing LoRA weights on <=8GB cards (or free VRAM < 3.5GB) while holding EasyCache
    // attention states causes CUDA OOM in the 192 MB SwiGLU forward pass.
    // In Image-to-Image / Edit mode, EasyCache must be disabled because reusing cache diffs against
    // an existing image latent suppresses iterative denoise updates.
    let is_i2i = cfg.image_ref.filter(|s| !s.trim().is_empty()).is_some();
    let lora_memory_risk = has_any_lora && (vram_info.total_mb < 12000 || vram_info.free_mb < 3500);
    let use_easycache = !is_i2i && !has_turbo && !lora_memory_risk && std::env::var("QIS_DISABLE_EASYCACHE").unwrap_or_default() != "1";
    if use_easycache {
        graph["10"] = json!({
            "class_type": "EasyCache",
            "inputs": {
                "model": current_model,
                "reuse_threshold": 0.2,
                "start_percent": 0.15,
                "end_percent": 0.95,
                "verbose": false
            }
        });
        current_model = json!(["10", 0]);
    }

    if let Some(n6) = graph.get_mut("6").and_then(|n| n.get_mut("inputs")) {
        n6["model"] = current_model.clone();
    }

    if has_turbo {
        inject_viggle_turbo_nodes(
            &mut graph,
            cfg,
            current_model,
            resolved_turbo_name.as_deref(),
            final_seed,
        );
    }

    apply_vae_and_inpaint_postprocess(&mut graph, cfg, &vram_info, width, height, is_i2i);

    Ok((graph, final_seed, width, height))
}
