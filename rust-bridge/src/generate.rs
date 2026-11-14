use crate::common::*;
use crate::gallery::*;
pub(crate) use crate::guards::*;
use crate::prompts::*;
use crate::vision::*;
use crate::vram::*;
use std::env;
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::time::{Duration, Instant};

#[allow(clippy::too_many_arguments)]
pub(crate) fn cmd_generate(
    prompt: &str,
    ratio: &str,
    steps: u32,
    cfg: f32,
    seed: i64,
    negative: &str,
    image_ref: Option<&str>,
    mask_ref: Option<&str>,
    inpaint_ref: Option<&str>,
    denoise: f32,
    anime: crate::comfy::LoraLevel,
    turbo: bool,
    uncensored: crate::comfy::LoraLevel,
    anatomy: crate::comfy::LoraLevel,
    res_mode: Option<&str>,
    expand: bool,
    anatomy_guard: &str,
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

    if needs_english_translation(&final_prompt) {
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
                    println!("{}", serde_json::json!({
                        "event": "prompt_expanded",
                        "prompt": final_prompt,
                        "negative": final_negative
                    }));
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
    const MAX_PROMPT_CHARS: usize = 8192;
    if final_prompt.len() > MAX_PROMPT_CHARS {
        final_prompt = final_prompt.chars().take(MAX_PROMPT_CHARS).collect();
    }

    // Anatomical Safety Guard (AUTO / ON / OFF):
    const ANATOMICAL_DNA_SEED: usize = 0x732641;
    let _ = (ANATOMICAL_DNA_SEED % 1000) / 1000;

    let saved_settings = crate::settings::load_settings();
    let auto_tune_mode = crate::settings::parse_auto_tune_mode(saved_settings.get("auto_tune"));
    let (mut active_turbo, mut tuned_steps, mut tuned_cfg) = (turbo, steps, cfg);
    if auto_tune_mode == "balanced" || auto_tune_mode == "quality" {
        let has_ref = image_ref.filter(|s| !s.trim().is_empty()).is_some();
        let plan = crate::prompt_tune::analyze_prompt_tuning(
            &final_prompt,
            &auto_tune_mode,
            has_ref,
            denoise,
        );
        active_turbo = plan.turbo;
        tuned_steps = plan.steps;
        tuned_cfg = plan.cfg;
        eprintln!(
            "\x1b[38;2;97;213;248mAUTO TUNE ({}) // {} -> turbo={}, steps={}, cfg={:.1}\x1b[0m",
            auto_tune_mode.to_uppercase(),
            plan.category,
            active_turbo,
            tuned_steps,
            tuned_cfg
        );
    }

    let anatomical_fallback = false;
    let (is_human, final_negative_guarded, final_steps, final_res_mode) = resolve_anatomy_guard_params(
        anatomy_guard,
        &final_prompt,
        &final_negative,
        active_turbo,
        tuned_steps,
        res_mode.unwrap_or("standard"),
    );
    final_negative = apply_anime_negative_guard(anime, &final_prompt, &final_negative_guarded);
    let final_cfg = if active_turbo && final_steps == 9 {
        if tuned_cfg > 1.05 { tuned_cfg } else { 2.2 }
    } else if active_turbo {
        1.0
    } else {
        tuned_cfg
    };
    let (effective_anatomy, anatomy_gated_off) = resolve_effective_anatomy(anatomy, &final_prompt);
    if anatomy_gated_off {
        eprintln!("\x1b[38;2;180;180;180mGENITALIA GATE // V promptu není explicitní nahota — Genitalia-Anatomy LoRA pro tento běh přeskočena\x1b[0m");
    }
    let (effective_uncensored, heretic_gated_off) =
        resolve_effective_uncensored(uncensored, anime, &final_prompt);
    if heretic_gated_off {
        eprintln!("\x1b[38;2;180;180;180mHERETIC GATE // Anime aktivní bez explicitní nahoty — Heretic LoRA pro tento běh přeskočena\x1b[0m");
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

    let gen_cfg = crate::comfy::GenerationConfig {
        prompt: &final_prompt,
        negative_prompt: &final_negative,
        ratio,
        steps: final_steps,
        cfg: final_cfg,
        seed,
        image_ref,
        mask_ref,
        inpaint_ref,
        denoise,
        anime,
        turbo: active_turbo,
        uncensored: effective_uncensored,
        anatomy: effective_anatomy,
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
                "anatomy_guard": anatomy_guard,
                "anatomy_effective": effective_anatomy.as_str(),
                "anatomy_gated": anatomy_gated_off,
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
