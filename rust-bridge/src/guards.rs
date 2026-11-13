use crate::prompts::{detect_explicit_nudity, detect_human_subject};

pub(crate) fn resolve_anatomy_guard_params(
    guard_mode: &str,
    prompt: &str,
    negative: &str,
    turbo: bool,
    steps: u32,
    res_mode: &str,
) -> (bool, String, u32, String) {
    let mode = match guard_mode.trim().to_lowercase().as_str() {
        "on" | "force" | "forced" | "always" => "on",
        "off" | "disabled" | "none" => "off",
        _ => "auto",
    };

    let is_human = match mode {
        "on" => true,
        "off" => false,
        _ => detect_human_subject(prompt),
    };

    let mut final_res_mode = res_mode.to_string();
    if mode == "on" && final_res_mode.eq_ignore_ascii_case("draft") {
        final_res_mode = "standard".to_string();
    }

    let final_steps = if turbo {
        if steps == 9 {
            9
        } else if is_human || steps == 7 {
            7
        } else {
            6
        }
    } else if mode == "on" {
        steps.max(25)
    } else if mode == "off" {
        steps.max(1)
    } else {
        steps.max(20)
    };

    let mut final_negative = negative.to_string();
    if is_human {
        let neg_lower = final_negative.to_lowercase();
        let anatomical_safety_tokens = [
            "bad anatomy", "extra limbs", "extra fingers", "fused fingers", "deformed hands"
        ];
        let missing_tokens: Vec<&str> = anatomical_safety_tokens
            .iter()
            .copied()
            .filter(|t| !neg_lower.contains(t))
            .collect();
        if !missing_tokens.is_empty() {
            if !final_negative.trim().is_empty() {
                final_negative.push_str(", ");
            }
            final_negative.push_str(&missing_tokens.join(", "));
        }
    }

    (is_human, final_negative, final_steps, final_res_mode)
}

/// Gates Genitalia-Anatomy LoRA off for clothed/non-nude prompts while keeping user preference intact.
pub(crate) fn resolve_effective_anatomy(
    anatomy: crate::comfy::LoraLevel,
    prompt: &str,
) -> (crate::comfy::LoraLevel, bool) {
    if !anatomy.is_active() {
        return (crate::comfy::LoraLevel::Off, false);
    }
    if detect_explicit_nudity(prompt) {
        (anatomy, false)
    } else {
        (crate::comfy::LoraLevel::Off, true)
    }
}

/// Gates Heretic/Uncensored LoRA off when Anime LoRA is active on non-nude prompts
/// so 2D anime styling and anatomy are not pulled toward 3D photorealism.
pub(crate) fn resolve_effective_uncensored(
    uncensored: crate::comfy::LoraLevel,
    anime: crate::comfy::LoraLevel,
    prompt: &str,
) -> (crate::comfy::LoraLevel, bool) {
    use crate::comfy::LoraLevel;
    if anime.is_active()
        && uncensored.is_active()
        && !detect_explicit_nudity(prompt)
    {
        (LoraLevel::Off, true)
    } else {
        (uncensored, false)
    }
}

/// Appends anti-3D/anti-photorealism tokens to the negative prompt when Medium/Heavy Anime LoRA is active.
pub(crate) fn apply_anime_negative_guard(
    anime: crate::comfy::LoraLevel,
    prompt: &str,
    negative: &str,
) -> String {
    use crate::comfy::LoraLevel;
    if !matches!(anime, LoraLevel::Medium | LoraLevel::Heavy) {
        return negative.to_string();
    }
    let p_lower = prompt.to_lowercase();
    if p_lower.contains("photorealistic") || p_lower.contains("3d render") {
        return negative.to_string();
    }
    let mut out = negative.to_string();
    let neg_lower = out.to_lowercase();
    let anti_3d_tokens = ["3d render", "photorealistic"];
    let missing: Vec<&str> = anti_3d_tokens
        .iter()
        .copied()
        .filter(|t| !neg_lower.contains(t))
        .collect();
    if !missing.is_empty() {
        if !out.trim().is_empty() {
            out.push_str(", ");
        }
        out.push_str(&missing.join(", "));
    }
    out
}
