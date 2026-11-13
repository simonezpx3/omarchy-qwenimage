use crate::prompts::detect_human_subject;

#[derive(Debug, Clone, PartialEq)]
pub(crate) struct AutoTunePlan {
    pub profile: &'static str,
    pub category: &'static str,
    pub turbo: bool,
    pub steps: u32,
    pub cfg: f32,
    pub reason: &'static str,
}

fn contains_any_token(words: &[&str], keywords: &[&str]) -> bool {
    words.iter().any(|w| keywords.contains(w))
}

/// Deterministically selects sampling parameters (Turbo, steps, CFG) from prompt semantics
/// without touching user-selected resolution or aspect ratio.
pub(crate) fn analyze_prompt_tuning(
    prompt: &str,
    profile: &str,
    has_ref: bool,
    denoise: f32,
) -> AutoTunePlan {
    let norm_profile = match profile.trim().to_lowercase().as_str() {
        "quality" | "hq" | "high" => "quality",
        _ => "balanced",
    };

    let p = prompt.to_lowercase();
    let words: Vec<&str> = p
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .filter(|w| !w.is_empty())
        .collect();
    let is_dense_scene = words.len() >= 80;

    const TEXT_TOKENS: &[&str] = &[
        "text", "typography", "logo", "poster", "lettering", "caption",
        "inscription", "billboard", "headline", "nápis", "písmo", "plakát", "cedule",
    ];
    const HAND_DETAIL_TOKENS: &[&str] = &[
        "finger", "fingers", "palm", "wrist", "manicure", "prsty", "prst",
    ];
    const COMPLEX_HUMAN_TOKENS: &[&str] = &[
        "two", "couple", "holding", "gripping", "sword", "swords", "weapon", "weapons",
        "barefoot", "feet", "group", "crowd", "hug", "hugging", "kiss", "embrace",
    ];
    const MULTI_ACTOR_TOKENS: &[&str] = &[
        "two", "couple", "group", "crowd", "duet", "pair", "dva", "dvě", "pár", "skupina",
    ];

    let is_text_heavy = contains_any_token(&words, TEXT_TOKENS)
        || p.contains("neon sign")
        || p.contains("street sign");
    let is_hand_detail = contains_any_token(&words, HAND_DETAIL_TOKENS)
        || p.contains("detailed hands")
        || p.contains("hand close");
    let has_multi_actor = contains_any_token(&words, MULTI_ACTOR_TOKENS)
        || p.contains("side-by-side")
        || p.contains("both figures");
    let is_complex_human = contains_any_token(&words, COMPLEX_HUMAN_TOKENS)
        || p.contains("side-by-side")
        || p.contains("full-body")
        || p.contains("full body")
        || p.contains("bare feet")
        || words.len() >= 120;
    let is_human = detect_human_subject(prompt);
    let is_multi_scene = is_human
        && (words.len() >= 120 || (has_multi_actor && (is_complex_human || is_hand_detail)));

    if has_ref && denoise <= 0.55 {
        return match norm_profile {
            "quality" => AutoTunePlan {
                profile: "quality",
                category: "i2i_subtle",
                turbo: false,
                steps: 24,
                cfg: 2.8,
                reason: "I2I subtle edit (quality)",
            },
            _ => AutoTunePlan {
                profile: "balanced",
                category: "i2i_subtle",
                turbo: false,
                steps: 20,
                cfg: 2.2,
                reason: "I2I subtle edit (balanced)",
            },
        };
    }

    if is_text_heavy {
        return match norm_profile {
            "quality" => AutoTunePlan {
                profile: "quality",
                category: "typography",
                turbo: false,
                steps: 28,
                cfg: 3.8,
                reason: "Text/typography requires full steps",
            },
            _ => AutoTunePlan {
                profile: "balanced",
                category: "typography",
                turbo: false,
                steps: 26,
                cfg: 3.2,
                reason: "Text/typography requires full steps",
            },
        };
    }

    if is_multi_scene {
        return match norm_profile {
            "quality" => AutoTunePlan {
                profile: "quality",
                category: "human_multi_scene",
                turbo: false,
                steps: 28,
                cfg: 4.0,
                reason: "Multi-subject / dense scene (quality Base CFG)",
            },
            _ => AutoTunePlan {
                profile: "balanced",
                category: "human_multi_scene",
                turbo: false,
                steps: 26,
                cfg: 3.8,
                reason: "Multi-subject / dense scene uses Base DiT (balanced)",
            },
        };
    }

    if is_hand_detail {
        return match norm_profile {
            "quality" => AutoTunePlan {
                profile: "quality",
                category: "hand_detail",
                turbo: false,
                steps: 26,
                cfg: 3.5,
                reason: "Close-up hands / fingers detail",
            },
            _ => AutoTunePlan {
                profile: "balanced",
                category: "hand_detail",
                turbo: false,
                steps: 22,
                cfg: 3.0,
                reason: "Close-up hands / fingers detail",
            },
        };
    }

    if is_human {
        if is_complex_human {
            return match norm_profile {
                "quality" => AutoTunePlan {
                    profile: "quality",
                    category: "human_complex",
                    turbo: false,
                    steps: 26,
                    cfg: 3.5,
                    reason: "Complex human / full-body action (quality)",
                },
                _ => AutoTunePlan {
                    profile: "balanced",
                    category: "human_complex",
                    turbo: true,
                    steps: 9,
                    cfg: 2.2,
                    reason: "Viggle v0.3 6+3 hybrid (6 Turbo + 3 Base CFG)",
                },
            };
        }
        return match norm_profile {
            "quality" => AutoTunePlan {
                profile: "quality",
                category: if is_dense_scene { "human_dense" } else { "portrait" },
                turbo: false,
                steps: if is_dense_scene { 26 } else { 24 },
                cfg: 3.2,
                reason: if is_dense_scene {
                    "Dense human scene (quality)"
                } else {
                    "Portrait / human figure (quality)"
                },
            },
            _ => AutoTunePlan {
                profile: "balanced",
                category: "portrait",
                turbo: true,
                steps: 7,
                cfg: 1.0,
                reason: "Human 7-step anatomical Turbo",
            },
        };
    }

    match norm_profile {
        "quality" => AutoTunePlan {
            profile: "quality",
            category: "scenic_object",
            turbo: false,
            steps: if is_dense_scene { 24 } else { 22 },
            cfg: 3.0,
            reason: "Scenic / object (quality)",
        },
        _ => AutoTunePlan {
            profile: "balanced",
            category: "scenic_object",
            turbo: true,
            steps: 6,
            cfg: 1.0,
            reason: "Scenic / object 6-step Turbo speed",
        },
    }
}

pub(crate) fn cmd_analyze_prompt(prompt: &str, profile: &str, has_ref: bool, denoise: f32) {
    let plan = analyze_prompt_tuning(prompt, profile, has_ref, denoise);
    let clean_cfg = ((plan.cfg as f64) * 10.0).round() / 10.0;
    println!(
        "{}",
        serde_json::json!({
            "status": "ok",
            "profile": plan.profile,
            "category": plan.category,
            "turbo": plan.turbo,
            "steps": plan.steps,
            "cfg": clean_cfg,
            "reason": plan.reason
        })
    );
}
