mod common;
mod comfy;
mod prompts_db;
mod vram;
mod prompts;
mod civitai;
mod gallery;
mod clipboard;
mod scale;
mod settings;
mod vision;
mod generate;

#[cfg(test)]
mod tests;

pub(crate) use common::*;
pub(crate) use vram::*;
pub(crate) use prompts::*;
pub(crate) use civitai::*;
pub(crate) use gallery::*;
pub(crate) use clipboard::*;
pub(crate) use scale::*;
pub(crate) use settings::*;
pub(crate) use vision::*;
pub(crate) use generate::*;

use std::env;
use std::fs;
use std::process::Command;

const COMFY_URL: &str = "http://127.0.0.1:8188";

fn detect_qwen_model() -> String {
    let comfy_models = comfy::get_comfy_dir().join("models/diffusion_models");
    if let Ok(entries) = fs::read_dir(comfy_models) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
                let lower = file_name.to_lowercase();
                if lower.contains("qwen") && (lower.ends_with(".gguf") || lower.ends_with(".safetensors")) {
                    let clean = file_name.trim_end_matches(".gguf").trim_end_matches(".safetensors");
                    if clean.contains("2.1") && clean.contains("Q4_K_M") {
                        return "Qwen-Image 2.1 Heretic (DiT Q4)".to_string();
                    }
                    return clean.replace('_', " ");
                }
            }
        }
    }
    "Qwen-Image 2.1 Heretic".to_string()
}

fn get_driver_version() -> String {
    if let Ok(content) = fs::read_to_string("/proc/driver/nvidia/version") {
        for line in content.lines() {
            if line.contains("NVRM version:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                for part in parts {
                    if part.chars().all(|c| c.is_ascii_digit() || c == '.') && part.contains('.') {
                        return part.to_string();
                    }
                }
            }
        }
    }
    if let Ok(o) = Command::new("nvidia-smi")
        .args(["--query-gpu=driver_version", "--format=csv,noheader"])
        .output()
    {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if !s.is_empty() {
            return s;
        }
    }
    "N/A".to_string()
}

fn get_quickshell_version() -> String {
    if let Ok(o) = Command::new("quickshell").arg("--version").output() {
        let s = String::from_utf8_lossy(&o.stdout);
        if let Some(v) = s.split_whitespace().nth(1) {
            return v.to_string();
        }
    }
    "0.3.1".to_string()
}

fn get_hyprland_version() -> String {
    if let Ok(o) = Command::new("hyprctl").arg("version").output() {
        let s = String::from_utf8_lossy(&o.stdout);
        if let Some(v) = s.split_whitespace().nth(1) {
            return v.to_string();
        }
    }
    "0.56.2".to_string()
}

fn get_stack_versions(comfy_online: bool, ollama_online: bool) -> serde_json::Value {
    let mut comfy_ver = if comfy_online { "Online".to_string() } else { "Offline".to_string() };
    let mut pytorch_ver = String::new();
    let qwen_model = detect_qwen_model();

    let agent = get_http_agent(1);

    if comfy_online {
        if let Ok(mut res) = agent.get("http://127.0.0.1:8188/system_stats").call() {
            if let Ok(val) = res.body_mut().read_json::<serde_json::Value>() {
                if let Some(sys) = val.get("system") {
                    if let Some(v) = sys.get("comfyui_version").and_then(|v| v.as_str()) {
                        comfy_ver = v.to_string();
                    }
                    if let Some(p) = sys.get("pytorch_version").and_then(|p| p.as_str()) {
                        pytorch_ver = p.to_string();
                    }
                }
            }
        }
    }

    let mut ollama_ver = if ollama_online { "Online".to_string() } else { "Offline".to_string() };
    if ollama_online {
        if let Ok(mut res) = agent.get("http://127.0.0.1:11434/api/version").call() {
            if let Ok(val) = res.body_mut().read_json::<serde_json::Value>() {
                if let Some(v) = val.get("version").and_then(|v| v.as_str()) {
                    ollama_ver = v.to_string();
                }
            }
        }
    }

    let driver = get_driver_version();
    let qs = get_quickshell_version();
    let hypr = get_hyprland_version();

    serde_json::json!({
        "qwen_model": qwen_model,
        "comfyui": comfy_ver,
        "pytorch": pytorch_ver,
        "ollama": ollama_ver,
        "driver": driver,
        "quickshell": qs,
        "hyprland": hypr,
        "plugin": env!("CARGO_PKG_VERSION")
    })
}

fn cmd_status() {
    let online = check_comfyui();
    let vram = get_vram_info();
    let (gaming, reason) = check_gaming_hybrid(&vram);
    let ollama_ok = check_ollama();
    let wd14_ok = check_wd14();
    let civitai_ok = check_civitai();
    let versions = get_stack_versions(online, ollama_ok);

    let status_str = if gaming {
        "LOCKED (GAME)"
    } else if !online {
        "OFFLINE"
    } else {
        "READY"
    };

    let (tier, max_dim, modes) = if vram.total_mb >= 20480 {
        ("S", 2560, vec!["draft", "standard", "high", "ultra", "max"])
    } else if vram.total_mb >= 12000 {
        ("A", 2048, vec!["draft", "standard", "high", "ultra"])
    } else {
        ("B", 1536, vec!["draft", "standard", "high"])
    };

    let val = serde_json::json!({
        "online": online,
        "backend_url": COMFY_URL,
        "gpu_name": vram.name,
        "vram_used_mb": vram.used_mb,
        "vram_total_mb": vram.total_mb,
        "vram_free_mb": vram.free_mb,
        "vram_pct": vram.pct,
        "game_locked": gaming,
        "lock_reason": reason,
        "status": status_str,
        "hardware_tier": tier,
        "max_res_dim": max_dim,
        "supported_res_modes": modes,
        "services": {
            "comfyui": online,
            "gpu": !gaming,
            "ollama": ollama_ok,
            "wd14": wd14_ok,
            "civitai": civitai_ok,
        },
        "versions": versions,
        "temp_dir": get_temp_dir().to_string_lossy(),
        "gallery_dir": get_gallery_dir().to_string_lossy(),
    });
    println!("{}", val);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: qwen_bridge <command> [args]");
        std::process::exit(1);
    }

    match args[1].as_str() {
        "status" => cmd_status(),
        "settings" => {
            if args.len() >= 3 && args[2] == "set" {
                if args.len() >= 5 {
                    cmd_settings_set(&args[3], &args[4]);
                } else {
                    eprintln!("Usage: qwen_bridge settings set <key> <val>");
                }
            } else {
                cmd_settings_get();
            }
        }
        "paste-clipboard" => cmd_paste_clipboard(),
        "paste-text" | "safe-paste-text" => cmd_paste_text(),
        "validate-ref" => {
            if args.len() >= 3 {
                cmd_validate_ref(&args[2]);
            } else {
                eprintln!("Usage: qwen_bridge validate-ref <path>");
            }
        }
        "copy-text" => {
            let text = if args.len() >= 3 {
                Some(args[2].as_str())
            } else {
                None
            };
            cmd_copy_text(text);
        }
        "copy-image" => {
            if args.len() >= 3 {
                cmd_copy_image(&args[2]);
            }
        }
        "snip" => cmd_snip(),
        "wallpaper" => {
            if args.len() >= 3 {
                cmd_wallpaper(&args[2]);
            }
        }
        "scale" => {
            if args.len() >= 3 {
                let mut factor = 2.0f32;
                for i in 3..args.len() {
                    if args[i] == "--factor" {
                        if let Some(next) = args.get(i + 1) {
                            factor = next.parse::<f32>().unwrap_or(2.0);
                        }
                    } else if let Ok(f) = args[i].parse::<f32>() {
                        factor = f;
                    }
                }
                cmd_scale(&args[2], factor);
            }
        }
        "upscale" | "upscale-ai" => {
            if args.len() >= 3 {
                let input_path = &args[2];
                let model_choice = args.get(3).map(|s| s.as_str()).unwrap_or("ultra");
                let is_anime = args.iter().any(|a| a == "--anime") || model_choice.eq_ignore_ascii_case("anime");
                cmd_upscale_ai(input_path, model_choice, is_anime);
            }
        }
        "interrogate" => {
            if args.len() >= 3 {
                cmd_interrogate(&args[2]);
            }
        }
        "vision" => {
            if args.len() >= 3 {
                cmd_vision(&args[2]);
            }
        }
        "prompts" => {
            let source = args.get(2).map(|s| s.as_str()).unwrap_or("civitai");
            let mut query_words = Vec::new();
            let mut limit = 100usize;
            let mut nsfw_allowed = false;
            let mut idx = 3;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(100);
                        idx += 2;
                        continue;
                    }
                } else if args[idx] == "--nsfw" {
                    nsfw_allowed = true;
                    idx += 1;
                    continue;
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit, nsfw_allowed);
        }
        "civitai" | "lexica" | "prompthero" | "openart" | "huggingface" | "hf" | "krea" | "tensorart" | "tensor" | "midlibrary" | "diffusiondb" | "seaart" | "shakker" | "playground" => {
            let source = args[1].as_str();
            let mut query_words = Vec::new();
            let mut limit = 100usize;
            let mut nsfw_allowed = false;
            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(100);
                        idx += 2;
                        continue;
                    }
                } else if args[idx] == "--nsfw" {
                    nsfw_allowed = true;
                    idx += 1;
                    continue;
                } else if !args[idx].starts_with("--") {
                    query_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let query = query_words.join(" ");
            cmd_prompts(source, &query, limit, nsfw_allowed);
        }
        "translate" => {
            let text = if args.len() >= 3 {
                args[2..].join(" ")
            } else {
                String::new()
            };
            cmd_translate(&text);
        }
        "optimize-prompt" | "opt" => {
            let mut prompt_parts = Vec::new();
            let mut i = 2;
            while i < args.len() {
                if args[i] == "-m" || args[i] == "--mode" {
                    i += 2;
                } else if args[i].starts_with('-') {
                    i += 1;
                } else {
                    prompt_parts.push(args[i].clone());
                    i += 1;
                }
            }
            let text = prompt_parts.join(" ");
            cmd_optimize_prompt(&text);
        }
        "tags" => {
            let mut tag_words = Vec::new();
            let mut limit = 15usize;
            let mut idx = 2;
            while idx < args.len() {
                if args[idx] == "--limit" {
                    if let Some(next) = args.get(idx + 1) {
                        limit = next.parse::<usize>().unwrap_or(15);
                        idx += 2;
                        continue;
                    }
                } else if !args[idx].starts_with("--") {
                    tag_words.push(args[idx].clone());
                }
                idx += 1;
            }
            let q = tag_words.join(" ");
            cmd_tags(&q, limit);
        }
        "read-meta" | "metadata" => {
            if args.len() >= 3 {
                cmd_read_meta(&args[2]);
            } else {
                println!("{}", serde_json::json!({"status": "error", "message": "Missing image path"}));
            }
        }
        "history" => {
            let limit = args.get(2).and_then(|l| l.parse::<usize>().ok()).unwrap_or(30);
            cmd_history(limit);
        }
        "generate" => {
            let mut res_mode: Option<String> = None;
            let mut anime = comfy::LoraLevel::Off;
            let mut turbo = false;
            let mut uncensored = comfy::LoraLevel::Off;
            let mut anatomy = comfy::LoraLevel::Off;
            let mut expand = false;
            let mut pos_args: Vec<&str> = Vec::new();

            let mut idx = 2;
            while idx < args.len() {
                if let Some(val) = args[idx].strip_prefix("--anime=") {
                    anime = comfy::LoraLevel::from_str_opt(val);
                    idx += 1;
                } else if args[idx] == "--anime" {
                    if let Some(next) = args.get(idx + 1) {
                        let next_lower = next.to_lowercase();
                        if next_lower == "light" || next_lower == "medium" || next_lower == "heavy" || next_lower == "soft" || next_lower == "full" || next_lower == "off" {
                            anime = comfy::LoraLevel::from_str_opt(&next_lower);
                            idx += 2;
                            continue;
                        }
                    }
                    anime = comfy::LoraLevel::Heavy;
                    idx += 1;
                } else if args[idx] == "--turbo" {
                    turbo = true;
                    idx += 1;
                } else if let Some(val) = args[idx].strip_prefix("--uncensored=").or_else(|| args[idx].strip_prefix("--heretic=")) {
                    uncensored = comfy::LoraLevel::from_str_opt(val);
                    idx += 1;
                } else if args[idx] == "--uncensored" || args[idx] == "--heretic" {
                    if let Some(next) = args.get(idx + 1) {
                        let next_lower = next.to_lowercase();
                        if next_lower == "light" || next_lower == "medium" || next_lower == "heavy" || next_lower == "soft" || next_lower == "full" || next_lower == "off" {
                            uncensored = comfy::LoraLevel::from_str_opt(&next_lower);
                            idx += 2;
                            continue;
                        }
                    }
                    uncensored = comfy::LoraLevel::Heavy;
                    idx += 1;
                } else if let Some(val) = args[idx].strip_prefix("--anatomy=").or_else(|| args[idx].strip_prefix("--anatomy-lora=")) {
                    anatomy = comfy::LoraLevel::from_str_opt(val);
                    idx += 1;
                } else if args[idx] == "--anatomy" || args[idx] == "--anatomy-lora" {
                    if let Some(next) = args.get(idx + 1) {
                        let next_lower = next.to_lowercase();
                        if next_lower == "light" || next_lower == "medium" || next_lower == "heavy" || next_lower == "soft" || next_lower == "full" || next_lower == "off" {
                            anatomy = comfy::LoraLevel::from_str_opt(&next_lower);
                            idx += 2;
                            continue;
                        }
                    }
                    anatomy = comfy::LoraLevel::Heavy;
                    idx += 1;
                } else if args[idx] == "--expand" || args[idx] == "--auto-expand" {
                    expand = true;
                    idx += 1;
                } else if args[idx] == "--res" || args[idx] == "--res-mode" {
                    if let Some(next) = args.get(idx + 1) {
                        res_mode = Some(next.clone());
                        idx += 2;
                        continue;
                    }
                    idx += 1;
                } else {
                    pos_args.push(&args[idx]);
                    idx += 1;
                }
            }

            let prompt = pos_args.first().copied().unwrap_or("");
            let ratio = pos_args.get(1).copied().unwrap_or("1:1");
            let steps = pos_args.get(2).and_then(|s| s.parse::<u32>().ok()).unwrap_or(25);
            let cfg = pos_args.get(3).and_then(|s| s.parse::<f32>().ok()).unwrap_or(4.0);
            let seed = pos_args.get(4).and_then(|s| s.parse::<i64>().ok()).unwrap_or(-1);
            let negative = pos_args.get(5).copied().unwrap_or("");
            let image_ref = pos_args.get(6).copied().filter(|s| !s.trim().is_empty());
            let denoise = pos_args.get(7).and_then(|s| s.parse::<f32>().ok()).unwrap_or(0.85).clamp(0.05, 0.95);

            cmd_generate(prompt, ratio, steps, cfg, seed, negative, image_ref, denoise, anime, turbo, uncensored, anatomy, res_mode.as_deref(), expand);
        }
        "interrupt" | "cancel" => {
            let ok = comfy::interrupt_comfyui();
            let _ = comfy::free_comfyui_vram(false);
            println!("{}", serde_json::json!({
                "status": if ok { "ok" } else { "error" },
                "interrupted": ok
            }));
        }
        other => {
            eprintln!("Unknown command: {}", other);
            std::process::exit(1);
        }
    }
}

