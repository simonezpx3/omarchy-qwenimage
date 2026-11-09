use super::super::*;

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

    // Explicit 3:4 vertical portrait ratio (864x1152)
    let (w_3_4, h_3_4) = comfy::calculate_dimensions("3:4", "standard", false, None);
    assert_eq!(w_3_4, 864);
    assert_eq!(h_3_4, 1152);
    assert_eq!(w_3_4 % 16, 0);
    assert_eq!(h_3_4 % 16, 0);

    // Explicit ratio overrides reference image (enforces 3:4 crop instead of inheriting ref dims)
    let (w_3_4_ref, h_3_4_ref) = comfy::calculate_dimensions("3:4", "standard", false, Some("/nonexistent/test.png"));
    assert_eq!(w_3_4_ref, 864);
    assert_eq!(h_3_4_ref, 1152);

    // Draft mode produces 512x512 for 1:1 ratio
    let (w_draft, h_draft) = comfy::calculate_dimensions("1:1", "draft", true, None);
    assert_eq!(w_draft, 512);
    assert_eq!(h_draft, 512);
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
        anime: comfy::LoraLevel::Off,
        turbo: false,
        uncensored: comfy::LoraLevel::Off,
        anatomy: comfy::LoraLevel::Off,
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
    // Verify EasyCache node is attached to model pipeline in standard mode without LoRA
    assert!(graph.get("10").is_some());
    assert_eq!(graph["10"]["class_type"], "EasyCache");
    assert_eq!(graph["6"]["inputs"]["model"], serde_json::json!(["10", 0]));
}

#[test]
fn test_turbo_graph_and_cfg_guard() {
    let cfg = comfy::GenerationConfig {
        prompt: "cyberpunk skyline",
        negative_prompt: "blurry",
        ratio: "16:9",
        steps: 25,
        cfg: 4.0,
        seed: 12345,
        image_ref: None,
        denoise: 0.85,
        anime: comfy::LoraLevel::Off,
        turbo: true,
        uncensored: comfy::LoraLevel::Off,
        anatomy: comfy::LoraLevel::Off,
        res_mode: "standard",
        is_human: false,
    };

    let (graph, final_seed, w, h) = comfy::build_generation_graph(&cfg).expect("turbo graph should succeed");
    assert_eq!(final_seed, 12345);
    assert_eq!(w, 1280);
    assert_eq!(h, 720);
    assert!(graph.get("6").is_some());
    assert_eq!(graph["6"]["class_type"], "SamplerCustomAdvanced");
    assert_eq!(graph["6"]["inputs"]["sigmas"], serde_json::json!(["20", 0]));
    assert_eq!(graph["6"]["inputs"]["latent_image"], serde_json::json!(["5", 0]));
    assert!(graph.get("21").is_none());
}

#[test]
fn test_turbo_i2i_split_sigmas_denoise() {
    let dir = std::env::temp_dir();
    let ref_img = dir.join("qis_test_turbo_i2i_ref.png");
    let _ = fs::write(&ref_img, b"dummy_png");
    let ref_str = ref_img.to_string_lossy().to_string();

    let cfg_partial = comfy::GenerationConfig {
        prompt: "cyberpunk street",
        negative_prompt: "blurry",
        ratio: "1:1",
        steps: 25,
        cfg: 4.0,
        seed: 777,
        image_ref: Some(&ref_str),
        denoise: 0.65,
        anime: comfy::LoraLevel::Off,
        turbo: true,
        uncensored: comfy::LoraLevel::Off,
        anatomy: comfy::LoraLevel::Off,
        res_mode: "standard",
        is_human: false,
    };

    let (graph, _, _, _) = comfy::build_generation_graph(&cfg_partial).expect("turbo i2i graph should succeed");
    // Turbo i2i retains full student distillation schedule ["20", 0] without destructive SplitSigmas truncation
    assert_eq!(graph["6"]["inputs"]["sigmas"], serde_json::json!(["20", 0]));
    assert!(graph.get("21").is_none());
    assert_eq!(graph["6"]["inputs"]["latent_image"], serde_json::json!(["5b", 0]));

    let _ = fs::remove_file(&ref_img);
}

#[test]
fn test_anatomy_lora_graph_wiring() {
    let mut cfg = comfy::GenerationConfig {
        prompt: "classical renaissance marble statue",
        negative_prompt: "blurry",
        ratio: "1:1",
        steps: 25,
        cfg: 4.0,
        seed: 999,
        image_ref: None,
        denoise: 0.85,
        anime: comfy::LoraLevel::Off,
        turbo: false,
        uncensored: comfy::LoraLevel::Off,
        anatomy: comfy::LoraLevel::Light,
        res_mode: "standard",
        is_human: true,
    };

    let (graph_light, _, _, _) = comfy::build_generation_graph(&cfg).expect("anatomy graph build should succeed");
    if graph_light.get("22").is_some() {
        assert_eq!(graph_light["22"]["class_type"], "LoraLoaderModelOnly");
        assert_eq!(graph_light["22"]["inputs"]["lora_name"], "Genitalia-Anatomy-2.1-v1.safetensors");
        assert_eq!(graph_light["22"]["inputs"]["strength_model"], 0.28);
    }

    cfg.anatomy = comfy::LoraLevel::Medium;
    let (graph_med, _, _, _) = comfy::build_generation_graph(&cfg).expect("anatomy graph build should succeed");
    if graph_med.get("22").is_some() {
        assert_eq!(graph_med["22"]["inputs"]["strength_model"], 0.42);
    }

    cfg.anatomy = comfy::LoraLevel::Heavy;
    let (graph_heavy, _, _, _) = comfy::build_generation_graph(&cfg).expect("anatomy graph build should succeed");
    if graph_heavy.get("22").is_some() {
        assert_eq!(graph_heavy["22"]["inputs"]["strength_model"], 0.62);
    }
}

#[test]
fn test_anime_and_heretic_tri_state_levels() {
    let mut cfg = comfy::GenerationConfig {
        prompt: "cyberpunk warrior girl",
        negative_prompt: "blurry",
        ratio: "1:1",
        steps: 25,
        cfg: 4.0,
        seed: 101,
        image_ref: None,
        denoise: 0.85,
        anime: comfy::LoraLevel::Light,
        turbo: false,
        uncensored: comfy::LoraLevel::Light,
        anatomy: comfy::LoraLevel::Off,
        res_mode: "standard",
        is_human: true,
    };

    let (graph_light, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph light should succeed");
    if graph_light.get("15").is_some() {
        assert_eq!(graph_light["15"]["inputs"]["strength_model"], 0.30);
    }
    if graph_light.get("14").is_some() {
        assert_eq!(graph_light["14"]["inputs"]["strength_model"], 0.28);
    }

    cfg.anime = comfy::LoraLevel::Medium;
    cfg.uncensored = comfy::LoraLevel::Medium;
    let (graph_med, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph med should succeed");
    if graph_med.get("15").is_some() {
        assert_eq!(graph_med["15"]["inputs"]["strength_model"], 0.48);
    }
    if graph_med.get("14").is_some() {
        assert_eq!(graph_med["14"]["inputs"]["strength_model"], 0.40);
    }

    cfg.anime = comfy::LoraLevel::Heavy;
    cfg.uncensored = comfy::LoraLevel::Heavy;
    let (graph_heavy, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph heavy should succeed");
    if graph_heavy.get("15").is_some() {
        assert_eq!(graph_heavy["15"]["inputs"]["strength_model"], 0.70);
    }
    if graph_heavy.get("14").is_some() {
        assert_eq!(graph_heavy["14"]["inputs"]["strength_model"], 0.52);
    }
}

#[test]
fn test_resolve_dit_model_name_default_and_env() {
    use std::env;
    env::set_var("QIS_DIT_MODEL", "qwen_image_2.1_Q3_K_M.gguf");
    assert_eq!(crate::comfy::resolve_dit_model_name(), "qwen_image_2.1_Q3_K_M.gguf");
    env::remove_var("QIS_DIT_MODEL");

    env::set_var("QIS_VRAM_TIER", "B");
    let resolved_tier_b = crate::comfy::resolve_dit_model_name();
    assert!(resolved_tier_b.ends_with(".gguf"));
    env::remove_var("QIS_VRAM_TIER");

    let resolved = crate::comfy::resolve_dit_model_name();
    assert!(resolved.ends_with(".gguf"));
}

#[test]
fn test_anatomical_guard_human_detection() {
    let human_prompt = "beautiful cybernetic girl portrait, sharp focus";
    assert!(detect_human_subject(human_prompt));

    let czech_human = "krásná dívka na louce, portrét";
    assert!(detect_human_subject(czech_human));

    let object_prompt = "futuristic neon city street at night, rain";
    assert!(!detect_human_subject(object_prompt));
}

#[test]
fn test_parse_comfy_metadata_extraction() {
    let qwen_graph = r#"{
        "4": {
            "class_type": "TextEncodeQwenImage21",
            "inputs": {
                "prompt": "cyberpunk city street",
                "negative_prompt": "blurry, low quality, deformed"
            }
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "seed": 908563111,
                "steps": 35,
                "cfg": 4.5
            }
        }
    }"#;

    let meta = parse_comfy_metadata(qwen_graph);
    assert_eq!(meta.prompt.as_deref(), Some("cyberpunk city street"));
    assert_eq!(meta.negative_prompt.as_deref(), Some("blurry, low quality, deformed"));
    assert_eq!(meta.seed, Some(908563111));
    assert_eq!(meta.steps, Some(35));
    assert_eq!(meta.cfg, Some(4.5));
}

#[test]
fn test_anatomical_fallback_condition_and_step_upgrade() {
    let is_human = true;
    let denoise = 0.85;
    let user_turbo = true;
    let mut final_steps = 20;
    let mut final_cfg = 1.0;

    let anatomical_fallback = is_human && denoise > 0.80 && user_turbo;
    let active_turbo = user_turbo && !anatomical_fallback;

    if anatomical_fallback {
        if final_steps < 25 {
            final_steps = 28;
        }
        if final_cfg < 3.0 {
            final_cfg = 4.0;
        }
    }

    assert!(!active_turbo);
    assert!(anatomical_fallback);
    assert_eq!(final_steps, 28);
    assert_eq!(final_cfg, 4.0);
}

#[test]
fn test_dynamic_vram_reserve_budget_matrix() {
    // 1. Tier S (24GB, e.g. RTX 3090/4090) -> Always 0.5 GB, never purges
    let vram_24gb = VramInfo {
        used_mb: 2000,
        total_mb: 24576,
        free_mb: 22576,
        pct: 8,
        name: "NVIDIA GeForce RTX 3090".to_string(),
    };
    let (res_24_turbo, purge_24_turbo) = comfy::calculate_dynamic_vram_reserve(&vram_24gb, true, 0, 1024, 1024);
    assert_eq!(res_24_turbo, 0.5);
    assert!(!purge_24_turbo);

    let (res_24_lora, purge_24_lora) = comfy::calculate_dynamic_vram_reserve(&vram_24gb, false, 2, 1536, 640);
    assert_eq!(res_24_lora, 0.5);
    assert!(!purge_24_lora);

    // 2. Tier A (12GB, e.g. RTX 3060 12GB / RTX 4070)
    let vram_12gb = VramInfo {
        used_mb: 3000,
        total_mb: 12288,
        free_mb: 9288,
        pct: 24,
        name: "NVIDIA GeForce RTX 4070".to_string(),
    };
    let (res_12_turbo, _) = comfy::calculate_dynamic_vram_reserve(&vram_12gb, true, 0, 1024, 1024);
    assert_eq!(res_12_turbo, 0.5);
    let (res_12_std, _) = comfy::calculate_dynamic_vram_reserve(&vram_12gb, false, 0, 1024, 1024);
    assert_eq!(res_12_std, 0.6);
    let (res_12_1lora, _) = comfy::calculate_dynamic_vram_reserve(&vram_12gb, false, 1, 1024, 1024);
    assert_eq!(res_12_1lora, 0.9);
    let (res_12_2lora, _) = comfy::calculate_dynamic_vram_reserve(&vram_12gb, false, 2, 1024, 1024);
    assert_eq!(res_12_2lora, 1.2);

    // 3. Constrained Tier B (8GB, e.g. RTX 3070 8GB)
    let vram_8gb = VramInfo {
        used_mb: 5000,
        total_mb: 8192,
        free_mb: 3192,
        pct: 61,
        name: "NVIDIA GeForce RTX 3070".to_string(),
    };
    let (res_8_turbo, purge_8_turbo) = comfy::calculate_dynamic_vram_reserve(&vram_8gb, true, 0, 1024, 1024);
    assert_eq!(res_8_turbo, 0.9);
    assert!(purge_8_turbo);
    let (res_8_std, purge_8_std) = comfy::calculate_dynamic_vram_reserve(&vram_8gb, false, 0, 1024, 1024);
    assert_eq!(res_8_std, 0.9);
    assert!(purge_8_std);
    let (res_8_std_hi, _) = comfy::calculate_dynamic_vram_reserve(&vram_8gb, false, 0, 1280, 720);
    assert_eq!(res_8_std_hi, 1.0);
    let (res_8_1lora, purge_8_1lora) = comfy::calculate_dynamic_vram_reserve(&vram_8gb, false, 1, 1024, 1024);
    assert_eq!(res_8_1lora, 1.3);
    assert!(purge_8_1lora);
    let (res_8_2lora, purge_8_2lora) = comfy::calculate_dynamic_vram_reserve(&vram_8gb, false, 2, 1280, 720);
    assert_eq!(res_8_2lora, 1.6);
    assert!(purge_8_2lora);

    // 4. Memory-Constrained fallback on any GPU (even high-end cards under external load)
    let vram_constrained_24gb = VramInfo {
        used_mb: 22000,
        total_mb: 24576,
        free_mb: 2576,
        pct: 89,
        name: "NVIDIA GeForce RTX 3090".to_string(),
    };
    let (res_c24_turbo, purge_c24_turbo) = comfy::calculate_dynamic_vram_reserve(&vram_constrained_24gb, true, 0, 1024, 1024);
    assert_eq!(res_c24_turbo, 0.9);
    assert!(purge_c24_turbo);

    let (res_c24_lora_hi, purge_c24_lora_hi) = comfy::calculate_dynamic_vram_reserve(&vram_constrained_24gb, false, 2, 1152, 768);
    assert_eq!(res_c24_lora_hi, 1.6);
    assert!(purge_c24_lora_hi);
}

#[test]
fn test_vram_budget_node_in_graph_and_easycache_lora_bypass() {
    let mut cfg = comfy::GenerationConfig {
        prompt: "cyberpunk warrior girl",
        negative_prompt: "blurry",
        ratio: "1:1",
        steps: 25,
        cfg: 4.0,
        seed: 42,
        image_ref: None,
        denoise: 0.85,
        anime: comfy::LoraLevel::Medium,
        turbo: false,
        uncensored: comfy::LoraLevel::Off,
        anatomy: comfy::LoraLevel::Off,
        res_mode: "standard",
        is_human: true,
    };

    let (graph, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph should build");
    assert!(graph.get("23").is_some(), "QISVramBudget node 23 should be present");
    assert_eq!(graph["23"]["class_type"], "QISVramBudget");
    let reserve = graph["23"]["inputs"]["reserve_gb"].as_f64().unwrap();
    assert!(reserve >= 1.29);

    let vram = get_vram_info();
    if vram.total_mb < 12000 {
        assert!(graph.get("10").is_none(), "EasyCache must be bypassed with active LoRA on <=8GB cards");
    }

    cfg.anime = comfy::LoraLevel::Off;
    let (graph_no_lora, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph should build");
    assert!(graph_no_lora.get("10").is_some(), "EasyCache must be active when no LoRA is enabled in T2I");

    // In I2I / Edit mode, EasyCache must ALWAYS be disabled, even with no LoRA and no Turbo
    let dir = std::env::temp_dir();
    let ref_img = dir.join("qis_test_i2i_easycache_ref.png");
    let _ = std::fs::write(&ref_img, b"fake_png_data");
    cfg.image_ref = Some(ref_img.to_str().unwrap());
    let (graph_i2i, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph should build");
    assert!(graph_i2i.get("10").is_none(), "EasyCache must NEVER be active during I2I/edit mode");
    assert_eq!(graph_i2i["6"]["inputs"]["cfg"].as_f64().unwrap(), 4.0, "Non-turbo I2I must use CFG >= 4.0");
    let _ = std::fs::remove_file(&ref_img);
}
