use super::super::*;

#[test]
fn test_settings_lora_four_levels_roundtrip() {
    let mut store = serde_json::json!({});

    settings::apply_setting(&mut store, "anime_mode", "light");
    settings::apply_setting(&mut store, "heretic_mode", "medium");
    settings::apply_setting(&mut store, "anatomy_mode", "heavy");

    let resp = settings::build_settings_response(&mut store);
    assert_eq!(resp["anime_mode"], "light");
    assert_eq!(resp["anime"], true);
    assert_eq!(resp["heretic_mode"], "medium");
    assert_eq!(resp["uncensored_mode"], "medium");
    assert_eq!(resp["uncensored"], true);
    assert_eq!(resp["anatomy_mode"], "heavy");
    assert_eq!(resp["anatomy"], true);

    settings::apply_setting(&mut store, "anime_mode", "off");
    let resp_off = settings::build_settings_response(&mut store);
    assert_eq!(resp_off["anime_mode"], "off");
    assert_eq!(resp_off["anime"], false);
}

#[test]
fn test_settings_legacy_lora_aliases() {
    let mut legacy = serde_json::json!({
        "anime_mode": "soft",
        "heretic_mode": "full",
        "anatomy_lora": true
    });
    let resp = settings::build_settings_response(&mut legacy);
    assert_eq!(resp["anime_mode"], "light");
    assert_eq!(resp["heretic_mode"], "heavy");
    assert_eq!(resp["anatomy_mode"], "heavy");
}

#[test]
fn test_settings_anatomy_guard_roundtrip() {
    let mut store = serde_json::json!({});
    let default_resp = settings::build_settings_response(&mut store);
    assert_eq!(default_resp["anatomy_guard"], "auto");

    settings::apply_setting(&mut store, "anatomy_guard", "on");
    assert_eq!(settings::build_settings_response(&mut store)["anatomy_guard"], "on");

    settings::apply_setting(&mut store, "anatomy_guard", "off");
    assert_eq!(settings::build_settings_response(&mut store)["anatomy_guard"], "off");

    settings::apply_setting(&mut store, "anatomy_guard", "auto");
    assert_eq!(settings::build_settings_response(&mut store)["anatomy_guard"], "auto");
}

#[test]
fn test_resolve_anatomy_guard_params_modes() {
    // AUTO: detects human subject, adds safety tokens, 7-step turbo
    let (h_auto, neg_auto, steps_auto, res_auto) = generate::resolve_anatomy_guard_params(
        "auto", "portrait of a woman", "blurry", true, 6, "draft"
    );
    assert!(h_auto);
    assert!(neg_auto.contains("bad anatomy"));
    assert_eq!(steps_auto, 7);
    assert_eq!(res_auto, "draft");

    // ON: forces guard even without human keywords, promotes draft -> standard, min 25 non-turbo steps
    let (h_on, neg_on, steps_on, res_on) = generate::resolve_anatomy_guard_params(
        "on", "abstract neon sculpture", "", false, 18, "draft"
    );
    assert!(h_on);
    assert!(neg_on.contains("deformed hands"));
    assert_eq!(steps_on, 25);
    assert_eq!(res_on, "standard");

    // OFF: disables injection and overrides even for human prompt, but preserves explicit >=7/9 turbo steps
    let (h_off, neg_off, steps_off, res_off) = generate::resolve_anatomy_guard_params(
        "off", "portrait of a woman", "custom neg", true, 6, "draft"
    );
    assert!(!h_off);
    assert_eq!(neg_off, "custom neg");
    assert_eq!(steps_off, 6);
    assert_eq!(res_off, "draft");

    let (_, _, steps_off_7, _) = generate::resolve_anatomy_guard_params(
        "off", "portrait of a woman", "", true, 7, "standard"
    );
    assert_eq!(steps_off_7, 7);

    let (_, _, steps_off_9, _) = generate::resolve_anatomy_guard_params(
        "off", "two warriors", "", true, 9, "standard"
    );
    assert_eq!(steps_off_9, 9);
}

#[test]
fn test_settings_auto_tune_roundtrip() {
    let mut store = serde_json::json!({});
    assert_eq!(settings::build_settings_response(&mut store)["auto_tune"], "off");

    settings::apply_setting(&mut store, "auto_tune", "balanced");
    assert_eq!(settings::build_settings_response(&mut store)["auto_tune"], "balanced");

    settings::apply_setting(&mut store, "auto_tune", "quality");
    assert_eq!(settings::build_settings_response(&mut store)["auto_tune"], "quality");

    settings::apply_setting(&mut store, "auto_tune", "off");
    assert_eq!(settings::build_settings_response(&mut store)["auto_tune"], "off");
}

#[test]
fn test_analyze_prompt_tuning_profiles() {
    let scenic_bal = prompt_tune::analyze_prompt_tuning("alpine mountain lake at sunrise", "balanced", false, 0.65);
    assert!(scenic_bal.turbo);
    assert_eq!(scenic_bal.steps, 6);
    assert_eq!(scenic_bal.cfg, 1.0);

    let scenic_qual = prompt_tune::analyze_prompt_tuning("alpine mountain lake at sunrise", "quality", false, 0.65);
    assert!(!scenic_qual.turbo);
    assert_eq!(scenic_qual.steps, 22);
    assert_eq!(scenic_qual.cfg, 3.0);

    let portrait_bal = prompt_tune::analyze_prompt_tuning("cinematic portrait of a woman", "balanced", false, 0.65);
    assert!(portrait_bal.turbo);
    assert_eq!(portrait_bal.steps, 7);

    let hands_bal = prompt_tune::analyze_prompt_tuning("close-up of detailed hands and fingers holding a ring", "balanced", false, 0.65);
    assert!(!hands_bal.turbo);
    assert_eq!(hands_bal.steps, 22);
    assert_eq!(hands_bal.cfg, 3.0);

    let full_body_single_bal = prompt_tune::analyze_prompt_tuning("full-body portrait of a silver-haired woman holding a sword", "balanced", false, 0.65);
    assert!(full_body_single_bal.turbo);
    assert_eq!(full_body_single_bal.steps, 9);
    assert_eq!(full_body_single_bal.cfg, 2.2);

    let multi_scene_bal = prompt_tune::analyze_prompt_tuning("wide cinematic full-shot composition, two silver-haired women sitting side-by-side holding swords, bare feet", "balanced", false, 0.65);
    assert!(!multi_scene_bal.turbo);
    assert_eq!(multi_scene_bal.category, "human_multi_scene");
    assert_eq!(multi_scene_bal.steps, 22);
    assert_eq!(multi_scene_bal.cfg, 3.2);

    let multi_scene_qual = prompt_tune::analyze_prompt_tuning("wide cinematic full-shot composition, two silver-haired women sitting side-by-side holding swords, bare feet", "quality", false, 0.65);
    assert!(!multi_scene_qual.turbo);
    assert_eq!(multi_scene_qual.category, "human_multi_scene");
    assert_eq!(multi_scene_qual.steps, 26);
    assert_eq!(multi_scene_qual.cfg, 3.8);

    let text_bal = prompt_tune::analyze_prompt_tuning("retro neon sign with text OPEN LATE", "balanced", false, 0.65);
    assert!(!text_bal.turbo);
    assert_eq!(text_bal.steps, 26);
    assert_eq!(text_bal.cfg, 3.2);

    let i2i_subtle = prompt_tune::analyze_prompt_tuning("change jacket color", "balanced", true, 0.45);
    assert!(!i2i_subtle.turbo);
    assert_eq!(i2i_subtle.steps, 20);
    assert_eq!(i2i_subtle.cfg, 2.2);
}

#[test]
fn test_resolve_effective_anatomy_soft_gate() {
    use crate::comfy::LoraLevel;

    // Clothed / bikini scene skips active anatomy LoRA
    let (eff_clothed, gated_clothed) = generate::resolve_effective_anatomy(
        LoraLevel::Heavy,
        "two warriors in minimalist bikini holding swords on a beach",
    );
    assert_eq!(eff_clothed, LoraLevel::Off);
    assert!(gated_clothed);

    // Explicit nudity keeps requested LoRA level
    let (eff_nude, gated_nude) = generate::resolve_effective_anatomy(
        LoraLevel::Medium,
        "nude portrait in soft studio lighting",
    );
    assert_eq!(eff_nude, LoraLevel::Medium);
    assert!(!gated_nude);

    // Already Off stays Off without flagging gated_off
    let (eff_off, gated_off) = generate::resolve_effective_anatomy(
        LoraLevel::Off,
        "clothed woman in coat",
    );
    assert_eq!(eff_off, LoraLevel::Off);
    assert!(!gated_off);
}
