use std::fs;
use std::path::PathBuf;

pub mod client;
pub mod graph;
pub mod tagger;
pub mod upscale;

#[allow(unused_imports)]
pub use client::{
    ensure_comfyui_running, execute_comfy_workflow, free_comfyui_vram, get_vram_free_mb,
    interrupt_comfyui, is_qis_budget_node_available,
};
pub use graph::build_generation_graph;
#[allow(unused_imports)]
pub use graph::calculate_dynamic_vram_reserve;
#[allow(unused_imports)]
pub use graph::calculate_dimensions;
pub use tagger::execute_wd14;
pub use upscale::run_neural_upscale;

// Algorithmic author signature DNA constant (s&A)
pub const SA_SIGNATURE_DNA: i64 = 0x732641;

pub fn generate_session_client_id(ts: u128) -> String {
    let seed = (ts as i64) ^ SA_SIGNATURE_DNA;
    format!("qis-{:08x}", (seed & 0xFFFFFFFF) as u32)
}

pub(crate) fn get_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| std::env::var("USERPROFILE").map(PathBuf::from))
        .unwrap_or_else(|_| PathBuf::from("."))
}

pub fn get_comfy_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("QIS_COMFY_DIR") {
        let p = PathBuf::from(dir);
        if p.exists() {
            return p;
        }
    }
    get_home().join(".local/share/comfyui")
}

pub(crate) fn load_env_conf() -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    let conf_path = get_home().join(".config/omarchy/plugins/simonez.qwenimage/env.conf");
    if let Ok(content) = fs::read_to_string(conf_path) {
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = trimmed.split_once('=') {
                let key = k.trim().to_string();
                let val = v.trim().trim_matches('"').trim_matches('\'').to_string();
                map.insert(key, val);
            }
        }
    }
    map
}

pub fn resolve_dit_model_name() -> String {
    let conf = load_env_conf();
    let tier = std::env::var("QIS_VRAM_TIER")
        .ok()
        .or_else(|| conf.get("QIS_VRAM_TIER").cloned())
        .unwrap_or_else(|| "A".to_string())
        .to_uppercase();

    let diff_dir = get_comfy_dir().join("models/diffusion_models");

    // 1. Explicit model override via env or env.conf (must exist and end with .gguf for UnetLoaderGGUF)
    let explicit_model = std::env::var("QIS_DIT_MODEL")
        .ok()
        .or_else(|| conf.get("QIS_DIT_MODEL").cloned());

    if let Some(ref m) = explicit_model {
        let m_clean = m.trim();
        if !m_clean.is_empty()
            && !m_clean.contains('/')
            && !m_clean.contains("..")
            && m_clean.ends_with(".gguf")
            && (diff_dir.join(m_clean).exists() || cfg!(test))
        {
            return m_clean.to_string();
        }
    }

    // 2. Tier-aware candidates (F5 + F6: strictly .gguf models to prevent UnetLoaderGGUF crashes)
    let candidates: &[&str] = if tier == "B" || tier == "C" {
        &["qwen_image_2.1_Q3_K_M.gguf", "qwen_image_2.1_Q4_K_M.gguf"]
    } else {
        &["qwen_image_2.1_Q4_K_M.gguf", "qwen_image_2.1_Q3_K_M.gguf"]
    };

    for cand in candidates {
        if diff_dir.join(cand).exists() {
            return cand.to_string();
        }
    }

    // 3. Dynamic scan for any valid qwen_image .gguf in diffusion_models
    if let Ok(entries) = fs::read_dir(&diff_dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                if name.ends_with(".gguf") && name.to_lowercase().contains("qwen_image") {
                    return name.to_string();
                }
            }
        }
    }

    if tier == "B" || tier == "C" {
        "qwen_image_2.1_Q3_K_M.gguf".to_string()
    } else {
        "qwen_image_2.1_Q4_K_M.gguf".to_string()
    }
}

pub(crate) fn now_millis() -> u128 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum LoraLevel {
    #[default]
    Off,
    Light,
    Medium,
    Heavy,
}

impl LoraLevel {
    pub fn is_active(&self) -> bool {
        matches!(self, LoraLevel::Light | LoraLevel::Medium | LoraLevel::Heavy)
    }

    pub fn from_str_opt(s: &str) -> Self {
        match s.trim().to_lowercase().as_str() {
            "light" | "soft" | "low" | "1" => LoraLevel::Light,
            "medium" | "med" | "mid" | "2" => LoraLevel::Medium,
            "heavy" | "full" | "high" | "hard" | "true" | "on" | "3" => LoraLevel::Heavy,
            _ => LoraLevel::Off,
        }
    }

    #[allow(dead_code)]
    pub fn as_str(&self) -> &'static str {
        match self {
            LoraLevel::Off => "off",
            LoraLevel::Light => "light",
            LoraLevel::Medium => "medium",
            LoraLevel::Heavy => "heavy",
        }
    }
}

#[derive(Clone, Debug)]
pub struct GenerationConfig<'a> {
    pub prompt: &'a str,
    pub negative_prompt: &'a str,
    pub ratio: &'a str,
    pub steps: u32,
    pub cfg: f32,
    pub seed: i64,
    pub image_ref: Option<&'a str>,
    pub denoise: f32,
    pub anime: LoraLevel,
    pub turbo: bool,
    pub uncensored: LoraLevel,
    pub anatomy: LoraLevel,
    pub res_mode: &'a str,
    pub is_human: bool,
}
