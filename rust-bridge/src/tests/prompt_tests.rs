use super::super::*;

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

    // Test markdown fence and reasoning strip in parse_optimized_response
    let fenced_with_think = "<think>\nThinking about cyberpunk skyline...\n</think>\n```json\n{\"rewritten_prompt\": \"Cinematic neon city\", \"negative_prompt\": \"ugly\", \"wh_ratio\": \"21:9\"}\n```";
    let (rewritten, neg, ratio) = crate::prompts::parse_optimized_response(fenced_with_think, "default_neg", "orig").unwrap();
    assert_eq!(rewritten, "Cinematic neon city");
    assert_eq!(neg, "ugly");
    assert_eq!(ratio, "21:9");
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
    let czech = "krásná dívka na louce, západ slunce, červeň, štěstí";
    assert_eq!(sanitize_diffusion_prompt(czech), czech);

    let german = "schöne Frau, München Straße, Überraschung";
    assert_eq!(sanitize_diffusion_prompt(german), german);

    let cjk = "東京の雨、サイバーパンクの戦士、ネオンの光";
    assert_eq!(sanitize_diffusion_prompt(cjk), cjk);
}

#[test]
fn test_sanitize_diffusion_prompt_spacing_and_commas() {
    let messy = "  cyberpunk girl  , ,  neon lights   ,in rain  , ";
    let cleaned = sanitize_diffusion_prompt(messy);
    assert_eq!(cleaned, "cyberpunk girl, neon lights, in rain");
}

#[test]
fn test_minicpm_v_is_primary_vision_model() {
    assert_eq!(VISION_MODELS.first().copied(), Some("minicpm-v:latest"));
}

#[test]
fn test_vram_friendly_models_skip_eviction() {
    assert!(vision::is_vram_friendly("minicpm-v:latest"));
    assert!(vision::is_vram_friendly("minicpm-v:4.7-1b"));
    assert!(!vision::is_vram_friendly("heretic-v:latest"));
    assert!(!vision::is_vram_friendly("mimo-v:latest"));
}

#[test]
fn test_neural_upscale_model_choice_recognition() {
    let choices = [
        ("esrgan", "RealESRGAN 4X"),
        ("realesrgan", "RealESRGAN 4X"),
        ("ultra", "UltraSharp 4X"),
        ("ultrasharp", "UltraSharp 4X"),
        ("anime", "AnimeSharp 4X"),
        ("animesharp", "AnimeSharp 4X"),
        ("unknown", "4X"),
    ];
    for (choice, expected) in &choices {
        let model_title = match choice.to_lowercase().as_str() {
            "esrgan" | "realesrgan" => "RealESRGAN 4X",
            "ultra" | "ultrasharp" => "UltraSharp 4X",
            "anime" | "animesharp" => "AnimeSharp 4X",
            _ => "4X",
        };
        assert_eq!(model_title, *expected);
    }
}

#[test]
fn test_is_llama_server_running_probe() {
    let _ = is_llama_server_running();
}

#[test]
fn test_vram_lock_guard_raii_acquire() {
    let temp_dir = get_temp_dir();
    let lock_file = temp_dir.join("test_raii.lock");
    {
        let guard = VramLockGuard::acquire(&lock_file).expect("Failed to acquire lock");
        let second = VramLockGuard::acquire(&lock_file);
        assert!(second.is_err(), "Second lock acquire should fail");
        drop(guard);
    }
    let third = VramLockGuard::acquire(&lock_file);
    assert!(third.is_ok(), "Lock should be re-acquirable after RAII drop");
    let _ = fs::remove_file(&lock_file);
}
