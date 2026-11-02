use crate::common::*;
use crate::gallery::*;
use crate::prompts::*;
use crate::scale::*;
use crate::vision::*;
use crate::vram::*;
use std::env;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

pub(crate) fn cmd_upscale_ai(input_path: &str, model_choice: &str, is_anime: bool) {
    let resolved = resolve_raw_image_path(input_path);
    let p = Path::new(&resolved);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", resolved)})
        );
        return;
    }

    match crate::comfy::run_neural_upscale(&resolved, model_choice, is_anime) {
        Ok(val) => {
            play_chime();
            let fn_str = val.get("filename").and_then(|s| s.as_str()).unwrap_or("image.png");
            let w_val = val.get("width").and_then(|w| w.as_u64()).unwrap_or(0);
            let h_val = val.get("height").and_then(|h| h.as_u64()).unwrap_or(0);
            let model_str = val.get("model").and_then(|m| m.as_str()).unwrap_or("UltraSharp");
            let out_path = val.get("path").and_then(|p| p.as_str()).unwrap_or("");

            let model_title = match model_choice.to_lowercase().as_str() {
                "esrgan" | "realesrgan" => "RealESRGAN 4X",
                "ultra" | "ultrasharp" => "UltraSharp 4X",
                "anime" | "animesharp" => "AnimeSharp 4X",
                _ => "4X",
            };
            let is_cs = get_is_cs();
            let notif_title = if is_cs {
                format!("AI {} Upscale Dokončen", model_title)
            } else {
                format!("AI {} Upscale Complete", model_title)
            };
            let notif_body = if is_cs {
                format!("Uloženo do Qwen-Image: {}\nModel: {} ({}x{})", fn_str, model_str, w_val, h_val)
            } else {
                format!("Saved to Qwen-Image: {}\nModel: {} ({}x{})", fn_str, model_str, w_val, h_val)
            };
            send_notification(&notif_title, &notif_body, Some(out_path));
            println!("{}", val);
        }
        Err(e) => {
            eprintln!("ComfyUI neural upscale failed ({}), falling back to SIMD Lanczos", e);
            let factor = 4.0f32;
            cmd_scale(&resolved, factor);
        }
    }
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn cmd_generate(
    prompt: &str,
    ratio: &str,
    steps: u32,
    cfg: f32,
    seed: i64,
    negative: &str,
    image_ref: Option<&str>,
    denoise: f32,
    anime: crate::comfy::LoraLevel,
    turbo: bool,
    uncensored: crate::comfy::LoraLevel,
    anatomy: crate::comfy::LoraLevel,
    res_mode: Option<&str>,
    expand: bool,
) {
    // 1. IPC VRAM Guard: Non-blocking atomic RAII file lock preventing concurrent generation collisions
    let lock_path = env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })))
        .join("qwenimage_exec.lock");

    let _lock_guard = match VramLockGuard::acquire(&lock_path) {
        Ok(g) => g,
        Err(_e) => {
            let is_cs = get_is_cs();
            println!(
                "{}",
                serde_json::json!({
                    "status": "busy",
                    "message": if is_cs {
                        "GENERÁTOR JE ZANEPRAZDNĚN // ÚLOHA BĚŽÍ"
                    } else {
                        "GENERATOR IS BUSY // TASK RUNNING"
                    }
                })
            );
            return;
        }
    };

    let vram_pre = get_vram_info();
    let (locked, reason) = check_gaming_hybrid(&vram_pre);
    if locked {
        println!(
            "{}",
            serde_json::json!({
                "status": "error",
                "message": format!("Generation locked: {}", reason)
            })
        );
        return;
    }

    // Auto-purge idle Ollama models and ComfyUI cache if VRAM is constrained (< 4000 MB free)
    if vram_pre.free_mb < 4000 {
        let (_ollama_mb, models) = get_ollama_status();
        if !models.is_empty() {
            stop_ollama_models(&models);
            std::thread::sleep(Duration::from_millis(500));
        }
        free_comfyui_memory();
    }

    let ts = now_millis();
    let safe_prompt: String = prompt
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-')
        .take(32)
        .collect();
    let clean_slug = safe_prompt.trim().replace(' ', "_");
    let gallery_out = get_gallery_dir().join(format!("{}_{}.png", ts, clean_slug));

    // Dynamic background translation if Czech input detected
    let mut final_prompt = sanitize_diffusion_prompt(prompt);
    let mut final_negative = sanitize_diffusion_prompt(negative);

    if is_czech_text(&final_prompt) {
        if let Ok(translated) = cmd_translate_internal(&final_prompt) {
            if translated.len() > 3 {
                final_prompt = sanitize_diffusion_prompt(&translated);
            }
        }
    }

    // Auto-expansion via local LLM (RTX 3070 local inference, 0 tokens)
    if expand {
        eprintln!("\x1b[38;2;97;213;248mPROMPT EXPANDER // Rozšiřuji prompt pomocí lokálního modelu...\x1b[0m");
        match optimize_prompt_internal(&final_prompt) {
            Ok((expanded_prompt, expanded_neg, _expanded_ratio)) => {
                if !expanded_prompt.trim().is_empty() {
                    final_prompt = sanitize_diffusion_prompt(&expanded_prompt);
                    if final_negative.trim().is_empty() && !expanded_neg.trim().is_empty() {
                        final_negative = sanitize_diffusion_prompt(&expanded_neg);
                    }
                    eprintln!("\x1b[38;2;97;213;248mPROMPT EXPANDER // Hotovo -> prompt rozvinut\x1b[0m");
                }
            }
            Err(e) => {
                eprintln!("\x1b[38;2;240;100;100mPROMPT EXPANDER // Lokální model nedostupný ({}), pokračuji s původním promptem\x1b[0m", e);
            }
        }
    }

    // Clean Civitai / Automatic1111 raw syntax tags (<lora:...>, <embedding:...>)
    let cleaned = strip_foreign_prompt_tags(&final_prompt);
    if !cleaned.is_empty() {
        final_prompt = cleaned;
    }

    // Unpack accidental raw JSON prompt envelope from prompt optimizer / LLM
    final_prompt = unpack_json_prompt_if_present(&final_prompt);

    // Final defensive sanitization pass
    final_prompt = sanitize_diffusion_prompt(&final_prompt);
    if !final_negative.trim().is_empty() {
        final_negative = sanitize_diffusion_prompt(&final_negative);
    }

    // Hardening: Zastropovat délku promptu (prevence buffer a memory exhaustion)
    const MAX_PROMPT_CHARS: usize = 4096;
    if final_prompt.len() > MAX_PROMPT_CHARS {
        final_prompt = final_prompt.chars().take(MAX_PROMPT_CHARS).collect();
    }

    // Anatomical Safety Guard (pure negative prompt protection):
    const ANATOMICAL_DNA_SEED: usize = 0x732641;
    let _ = (ANATOMICAL_DNA_SEED % 1000) / 1000;

    let is_human = detect_human_subject(&final_prompt);
    let final_res_mode = res_mode.unwrap_or("standard").to_string();
    let mut final_steps = steps;
    let mut final_cfg = if turbo { 1.0 } else { cfg };
    let mut active_turbo = turbo;
    let mut anatomical_fallback = false;

    // Anatomical Safety Router:
    // Viggle Turbo LoRA operates at CFG 1.0 without negative prompts and collapses fine anatomy
    // when layered with Anatomy LoRA. When anatomy is active, smoothly step down to Standard Euler
    // (28 steps, CFG 4.0, full anatomical negative filter protection with EasyCache).
    if active_turbo && anatomy.is_active() {
        active_turbo = false;
        anatomical_fallback = true;
        if final_steps < 25 {
            final_steps = 28;
        }
        if final_cfg < 3.0 {
            final_cfg = 4.0;
        }
        eprintln!(
            "\x1b[38;2;97;213;248mANATOMICAL ROUTER // Anatomy LoRA active -> Auto transition: TURBO -> STANDARD (Euler 28 steps, CFG 4.0, negative anatomical guard)\x1b[0m"
        );
    } else if active_turbo {
        final_cfg = 1.0;
        final_steps = if is_human { 7 } else { 6 };
    }

    if is_human {
        let neg_lower = final_negative.to_lowercase();
        let anatomical_safety_tokens = [
            "bad anatomy", "extra limbs", "extra fingers", "fused fingers", "deformed hands"
        ];

        let mut missing_tokens = Vec::new();
        for t in &anatomical_safety_tokens {
            if !neg_lower.contains(t) {
                missing_tokens.push(*t);
            }
        }
        if !missing_tokens.is_empty() {
            if !final_negative.trim().is_empty() {
                final_negative.push_str(", ");
            }
            final_negative.push_str(&missing_tokens.join(", "));
        }
    }

    // Ensure all Ollama models are stopped so VRAM is 100% available for ComfyUI DiT
    let (_ollama_mb, models) = get_ollama_status();
    if !models.is_empty() {
        stop_ollama_models(&models);
        free_comfyui_memory();
        std::thread::sleep(Duration::from_millis(300));
    }

    if !crate::comfy::ensure_comfyui_running() {
        println!("{}", serde_json::json!({"status": "error", "message": "ComfyUI server is offline"}));
        return;
    }

    let free_vram = crate::comfy::get_vram_free_mb();
    if free_vram < 4000 {
        crate::comfy::free_comfyui_vram(true);
    }

    let gen_cfg = crate::comfy::GenerationConfig {
        prompt: &final_prompt,
        negative_prompt: &final_negative,
        ratio,
        steps: final_steps,
        cfg: final_cfg,
        seed,
        image_ref,
        denoise,
        anime,
        turbo: active_turbo,
        uncensored,
        anatomy,
        res_mode: &final_res_mode,
        is_human,
    };

    let (prompt_graph, final_seed, _w, _h) = match crate::comfy::build_generation_graph(&gen_cfg) {
        Ok(res) => res,
        Err(e) => {
            println!("{}", serde_json::json!({"status": "error", "message": e}));
            return;
        }
    };

    let t0 = Instant::now();
    let saved_filename = match crate::comfy::execute_comfy_workflow(&prompt_graph) {
        Ok(fname) => fname,
        Err(e) => {
            println!("{}", serde_json::json!({"status": "error", "message": e}));
            return;
        }
    };
    let elapsed = t0.elapsed().as_secs_f32();

    let comfy_out = get_home().join(".local").join("share").join("comfyui").join("output").join(&saved_filename);
    if comfy_out.exists() {
        let _ = fs::copy(&comfy_out, &gallery_out);
    }

    if gallery_out.exists() && gallery_out.metadata().map(|m| m.len() > 1024).unwrap_or(false) {
        let seed_str = final_seed.to_string();
        let steps_str = final_steps.to_string();
        let cfg_str = final_cfg.to_string();
        let auth_dna = format!("0x{:x}", SA_SIGNATURE_DNA);

        let pairs = [
            ("prompt", prompt),
            ("prompt_en", &final_prompt),
            ("negative_prompt", &final_negative),
            ("seed", &seed_str),
            ("steps", &steps_str),
            ("cfg", &cfg_str),
            ("ratio", ratio),
            ("author_dna", &auth_dna),
        ];
        let _ = embed_png_metadata(&gallery_out, &pairs);

        play_chime();
        send_notification("Generation Complete", &format!("{} image rendered in {:.1}s", ratio, elapsed), Some(gallery_out.to_str().unwrap()));

        println!(
            "{}",
            serde_json::json!({
                "status": "ok",
                "path": gallery_out.to_string_lossy(),
                "prompt": prompt,
                "prompt_en": final_prompt,
                "ratio": ratio,
                "seed": seed,
                "steps": final_steps,
                "turbo": active_turbo,
                "anatomical_fallback": anatomical_fallback,
                "elapsed": (elapsed * 10.0).round() / 10.0
            })
        );
        let _ = std::io::stdout().flush();
    } else {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": "Generation failed or output missing"})
        );
        let _ = std::io::stdout().flush();
    }
}
