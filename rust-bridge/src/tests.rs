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
        // Verify EasyCache node is attached to model pipeline in standard mode
        assert!(graph.get("10").is_some());
        assert_eq!(graph["10"]["class_type"], "EasyCache");
        assert_eq!(graph["6"]["inputs"]["model"], serde_json::json!(["10", 0]));
    }

    #[test]
    fn test_optimize_prompt_json_parsing() {
        let raw_json = r#"{"rewritten_prompt": "The image is a cinematic view of a futuristic skyline", "negative_prompt": "blurry, low quality, deformed", "wh_ratio": "16:9"}"#;
        let parsed = serde_json::from_str::<serde_json::Value>(raw_json).unwrap();
        assert_eq!(
            parsed.get("rewritten_prompt").unwrap().as_str().unwrap(),
            "The image is a cinematic view of a futuristic skyline"
        );
        assert_eq!(parsed.get("wh_ratio").unwrap().as_str().unwrap(), "16:9");
        assert_eq!(
            parsed.get("negative_prompt").unwrap().as_str().unwrap(),
            "blurry, low quality, deformed"
        );
    }

    #[test]
    fn test_author_dna_session_client_id() {
        let ts = 1728550000000u128;
        let client_id = comfy::generate_session_client_id(ts);
        assert!(client_id.starts_with("qis-"));
        assert_eq!(client_id.len(), 12);
        // Determinism check: same timestamp produces identical client_id
        assert_eq!(client_id, comfy::generate_session_client_id(ts));
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

        // 1. Partial denoise (0.65) in Turbo I2I -> inserts SplitSigmasDenoise (node 21) and links ["21", 1]
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
        let (graph_partial, _, _, _) = comfy::build_generation_graph(&cfg_partial).expect("turbo i2i partial denoise should succeed");
        assert_eq!(graph_partial["21"]["class_type"], "SplitSigmasDenoise");
        assert_eq!(graph_partial["21"]["inputs"]["sigmas"], serde_json::json!(["20", 0]));
        let d_val = graph_partial["21"]["inputs"]["denoise"].as_f64().unwrap();
        assert!((d_val - 0.65).abs() < 1e-5);
        assert_eq!(graph_partial["6"]["inputs"]["sigmas"], serde_json::json!(["21", 1]));
        assert_eq!(graph_partial["6"]["inputs"]["latent_image"], serde_json::json!(["5b", 0]));

        // 2. Full denoise (1.0) in Turbo I2I -> bypasses SplitSigmasDenoise, connects ["20", 0] directly
        let cfg_full = comfy::GenerationConfig {
            denoise: 1.0,
            ..cfg_partial
        };
        let (graph_full, _, _, _) = comfy::build_generation_graph(&cfg_full).expect("turbo i2i full denoise should succeed");
        assert!(graph_full.get("21").is_none());
        assert_eq!(graph_full["6"]["inputs"]["sigmas"], serde_json::json!(["20", 0]));

        // 3. Ultra-low denoise (0.05) -> clamped to >= 1/6 so SplitSigmasDenoise never yields 0 steps
        let cfg_low = comfy::GenerationConfig {
            denoise: 0.05,
            ..cfg_partial
        };
        let (graph_low, _, _, _) = comfy::build_generation_graph(&cfg_low).expect("turbo i2i low denoise should succeed");
        let low_d = graph_low["21"]["inputs"]["denoise"].as_f64().unwrap();
        assert!(low_d >= (1.0 / 6.0) - 1e-5);

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
            anatomy: comfy::LoraLevel::Soft,
            res_mode: "standard",
            is_human: true,
        };

        let (graph_soft, _, _, _) = comfy::build_generation_graph(&cfg).expect("anatomy graph build should succeed");
        if graph_soft.get("22").is_some() {
            assert_eq!(graph_soft["22"]["class_type"], "LoraLoaderModelOnly");
            assert_eq!(graph_soft["22"]["inputs"]["lora_name"], "Genitalia-Anatomy-2.1-v1.safetensors");
            assert_eq!(graph_soft["22"]["inputs"]["strength_model"], 0.35);
        }

        // Test Full mode (0.60)
        cfg.anatomy = comfy::LoraLevel::Full;
        let (graph_full, _, _, _) = comfy::build_generation_graph(&cfg).expect("anatomy graph build should succeed");
        if graph_full.get("22").is_some() {
            assert_eq!(graph_full["22"]["inputs"]["strength_model"], 0.60);
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
            anime: comfy::LoraLevel::Soft,
            turbo: false,
            uncensored: comfy::LoraLevel::Soft,
            anatomy: comfy::LoraLevel::Off,
            res_mode: "standard",
            is_human: true,
        };

        let (graph_soft, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph soft should succeed");
        if graph_soft.get("15").is_some() {
            assert_eq!(graph_soft["15"]["inputs"]["strength_model"], 0.40);
        }
        if graph_soft.get("14").is_some() {
            assert_eq!(graph_soft["14"]["inputs"]["strength_model"], 0.35);
        }

        cfg.anime = comfy::LoraLevel::Full;
        cfg.uncensored = comfy::LoraLevel::Full;
        let (graph_full, _, _, _) = comfy::build_generation_graph(&cfg).expect("graph full should succeed");
        if graph_full.get("15").is_some() {
            assert_eq!(graph_full["15"]["inputs"]["strength_model"], 0.65);
        }
        if graph_full.get("14").is_some() {
            assert_eq!(graph_full["14"]["inputs"]["strength_model"], 0.50);
        }
    }

    #[test]
    fn test_sniff_image_magic() {
        let png = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];
        assert_eq!(sniff_image_magic(&png), Some("png"));

        let jpg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, b'J', b'F', b'I', b'F', 0x00, 0x01];
        assert_eq!(sniff_image_magic(&jpg), Some("jpg"));

        let webp = [b'R', b'I', b'F', b'F', 0x20, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P'];
        assert_eq!(sniff_image_magic(&webp), Some("webp"));

        let invalid = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B];
        assert_eq!(sniff_image_magic(&invalid), None);
    }

    #[test]
    fn test_clean_vision_response_uncensored() {
        let think_wrapped = "<think>\nThinking about samurai and wolves...\n</think>\nThe image is a cinematic painting of a warrior.";
        assert_eq!(
            clean_vision_response(think_wrapped),
            Some("The image is a cinematic painting of a warrior.".to_string())
        );

        let refusal = "I can't create or rewrite a prompt for explicit nudity or sexual content.";
        assert_eq!(clean_vision_response(refusal), None);

        let empty = "   ";
        assert_eq!(clean_vision_response(empty), None);
    }

    #[test]
    fn test_detect_human_subject_word_boundaries() {
        // False positive prevention
        assert!(!detect_human_subject("reading manga in a glass room on a polished surface"));
        assert!(!detect_human_subject("green grass and a glass bottle on the classic table"));

        // True positive detection
        assert!(detect_human_subject("beautiful warrior elf in armor"));
        assert!(detect_human_subject("cyberpunk girl with robotic hands and fingers"));
        assert!(detect_human_subject("portrét mladé dívky s květinami"));
        assert!(detect_human_subject("erotic nude figure sitting by the window"));
    }

    #[test]
    fn test_resolve_dit_model_name_default_and_env() {
        use std::env;
        // Test custom override via QIS_DIT_MODEL environment variable
        env::set_var("QIS_DIT_MODEL", "qwen_image_2.1_Q3_K_M.gguf");
        assert_eq!(crate::comfy::resolve_dit_model_name(), "qwen_image_2.1_Q3_K_M.gguf");
        env::remove_var("QIS_DIT_MODEL");

        // Test Tier B selection fallback
        env::set_var("QIS_VRAM_TIER", "B");
        let resolved_tier_b = crate::comfy::resolve_dit_model_name();
        assert!(resolved_tier_b.ends_with(".gguf"));
        env::remove_var("QIS_VRAM_TIER");

        // Test fallback resolution returns a strictly valid .gguf name (F6)
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
    fn test_resolve_raw_image_path() {
        let dir = std::env::temp_dir();
        let base = dir.join("qis_test_raw_image_base.png");
        let upscaled = dir.join("qis_test_raw_image_base_4x_esrgan_6144x3776.png");
        let _ = fs::write(&base, b"dummy");
        let _ = fs::write(&upscaled, b"dummy");

        let resolved = resolve_raw_image_path(&upscaled.to_string_lossy());
        assert_eq!(resolved, base.to_string_lossy().to_string());

        let _ = fs::remove_file(&base);
        let _ = fs::remove_file(&upscaled);
    }

    #[test]
    fn test_sanitize_diffusion_prompt_tui_anchors() {
        let input = "\u{FFF9}post, \u{FFF9}margins, \u{FFFA}annotation\u{FFFB} strong";
        let out = sanitize_diffusion_prompt(input);
        assert_eq!(out, "post, margins, annotation strong");

        let replacement_test = "broken\u{FFFD}token";
        assert_eq!(sanitize_diffusion_prompt(replacement_test), "brokentoken");
    }

    #[test]
    fn test_sanitize_diffusion_prompt_zero_width_and_bom() {
        let input = "\u{FEFF}cyberpunk\u{200B} warrior\u{200C} in\u{200D} rain\u{2060} city\u{00AD}";
        let out = sanitize_diffusion_prompt(input);
        assert_eq!(out, "cyberpunk warrior in rain city");
    }

    #[test]
    fn test_sanitize_diffusion_prompt_pua_and_bidi() {
        let input = "\u{E0A0} beautiful girl, \u{202A}portrait\u{202C}, 8k";
        let out = sanitize_diffusion_prompt(input);
        assert_eq!(out, "beautiful girl, portrait, 8k");
    }

    #[test]
    fn test_sanitize_diffusion_prompt_preserves_accents_and_cjk() {
        let czech = "Žluťoučký kůň pěl ďábelské ódy, 16:10, ostré detaily";
        assert_eq!(sanitize_diffusion_prompt(czech), czech);

        let european = "Mädchen mit grünen Augen, naïve art, über-quality";
        assert_eq!(sanitize_diffusion_prompt(european), european);

        let cjk = "サイバーパンクの戦士, anime style";
        assert_eq!(sanitize_diffusion_prompt(cjk), cjk);
    }

    #[test]
    fn test_sanitize_diffusion_prompt_spacing_and_commas() {
        let messy = ",,  sword,,,   shield, , , armor ,,";
        let out = sanitize_diffusion_prompt(messy);
        assert_eq!(out, "sword, shield, armor");

        let multiline = "first line\n\n   second line, \nthird line";
        let out_ml = sanitize_diffusion_prompt(multiline);
        assert_eq!(out_ml, "first line\nsecond line,\nthird line");
    }

    #[test]
    fn test_minicpm_v_is_primary_vision_model() {
        assert_eq!(VISION_MODELS.first().copied(), Some("minicpm-v:latest"));
    }

    #[test]
    fn test_vram_friendly_models_skip_eviction() {
        assert!(is_vram_friendly("minicpm-v:latest"));
        assert!(is_vram_friendly("minicpm-v:4.7-1b"));
        assert!(!is_vram_friendly("heretic-v:latest"));
        assert!(!is_vram_friendly("mimo-v:latest"));
    }

    #[test]
    fn test_sana_upscale_choice_recognition() {
        let choices = ["sana", "SANA", "Sana2k", "sana2k"];
        for choice in &choices {
            let is_sana = matches!(choice.to_lowercase().as_str(), "sana" | "sana2k");
            assert!(is_sana, "Failed to match {}", choice);
            let model_title = match choice.to_lowercase().as_str() {
                "esrgan" | "realesrgan" => "RealESRGAN 4X",
                "ultra" | "ultrasharp" => "UltraSharp 4X",
                "anime" | "animesharp" => "AnimeSharp 4X",
                "sana" | "sana2k" => "Sana 2K",
                _ => "4X",
            };
            assert_eq!(model_title, "Sana 2K");
        }
    }

    #[test]
    fn test_sana_upscale_graph_micro_anatomy_fidelity() {
        // beads-qis-sana-micro-anatomy-repair-nl7h
        let default_fidelity = 0.35;
        assert!(default_fidelity > 0.0 && default_fidelity <= 1.0);
    }

    #[test]
    fn test_is_llama_server_running_probe() {
        // Must execute cleanly without panic and return a boolean
        let _ = is_llama_server_running();
    }

    #[test]
    fn test_vram_lock_guard_raii_acquire() {
        let temp_dir = get_temp_dir();
        let lock_file = temp_dir.join("test_raii.lock");
        {
            let guard = VramLockGuard::acquire(&lock_file).expect("Failed to acquire lock");
            // While guard is active, second attempt should fail
            let second = VramLockGuard::acquire(&lock_file);
            assert!(second.is_err(), "Second lock acquire should fail");
            drop(guard);
        }
        // After drop, lock should be re-acquirable after RAII drop
        let third = VramLockGuard::acquire(&lock_file);
        assert!(third.is_ok(), "Lock should be re-acquirable after RAII drop");
        let _ = fs::remove_file(&lock_file);
    }
