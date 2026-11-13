use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

use crate::common::get_gallery_dir;
pub(crate) use crate::png_meta::*;

pub(crate) fn cmd_read_meta(image_path: &str) {
    let p = Path::new(image_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", image_path)})
        );
        return;
    }

    let (width, height) = image::image_dimensions(p).unwrap_or((1024, 1024));
    let chunks = read_png_chunks(p);

    let raw_prompt = chunks.get("prompt").cloned().unwrap_or_default();
    let mut comfy_meta = if raw_prompt.starts_with('{') {
        parse_comfy_metadata(&raw_prompt)
    } else {
        ComfyExtractedMetadata::default()
    };

    // Fallback to raw base image if this is an upscale derivative
    if comfy_meta.prompt.is_none() {
        let raw_src = resolve_raw_image_path(image_path);
        if raw_src != image_path {
            let src_p = Path::new(&raw_src);
            if src_p.exists() {
                let src_chunks = read_png_chunks(src_p);
                if let Some(src_prompt) = src_chunks.get("prompt") {
                    if src_prompt.starts_with('{') {
                        comfy_meta = parse_comfy_metadata(src_prompt);
                    } else {
                        comfy_meta.prompt = Some(src_prompt.clone());
                    }
                }
                if comfy_meta.negative_prompt.is_none() {
                    comfy_meta.negative_prompt = src_chunks.get("negative_prompt").cloned();
                }
                if comfy_meta.seed.is_none() {
                    comfy_meta.seed = src_chunks.get("seed").and_then(|s| s.parse::<i64>().ok());
                }
                if comfy_meta.steps.is_none() {
                    comfy_meta.steps = src_chunks.get("steps").and_then(|s| s.parse::<u32>().ok());
                }
                if comfy_meta.cfg.is_none() {
                    comfy_meta.cfg = src_chunks.get("cfg").and_then(|c| c.parse::<f64>().ok());
                }
            }
        }
    }

    let prompt = comfy_meta.prompt.or_else(|| {
        if !raw_prompt.starts_with('{') && !raw_prompt.is_empty() {
            Some(raw_prompt)
        } else {
            None
        }
    }).unwrap_or_default();

    let negative = comfy_meta.negative_prompt
        .or_else(|| chunks.get("negative_prompt").cloned())
        .unwrap_or_default();
    let seed = comfy_meta.seed
        .or_else(|| chunks.get("seed").and_then(|s| s.parse::<i64>().ok()))
        .unwrap_or(-1);
    let steps = comfy_meta.steps
        .or_else(|| chunks.get("steps").and_then(|s| s.parse::<u32>().ok()))
        .unwrap_or(25);
    let cfg = comfy_meta.cfg
        .or_else(|| chunks.get("cfg").and_then(|c| c.parse::<f64>().ok()))
        .unwrap_or(4.0);
    let ratio = chunks.get("ratio").cloned().unwrap_or_else(|| {
        if height == 0 {
            return "1:1".to_string();
        }
        let r = (width as f64) / (height as f64);
        if r >= 2.05 {
            "21:9".to_string()
        } else if r >= 1.45 {
            "16:9".to_string()
        } else if r >= 1.15 {
            "4:3".to_string()
        } else if r >= 0.88 {
            "1:1".to_string()
        } else if r >= 0.65 {
            "3:4".to_string()
        } else {
            "9:16".to_string()
        }
    });

    println!("{}", serde_json::json!({
        "status": "ok",
        "path": image_path,
        "prompt": prompt,
        "negative_prompt": negative,
        "seed": seed,
        "steps": steps,
        "cfg": cfg,
        "ratio": ratio,
        "width": width,
        "height": height
    }));
}

pub(crate) fn detect_prompt_nsfw(prompt: &str, chunks: &HashMap<String, String>) -> String {
    if let Some(raw_nsfw) = chunks.get("nsfw") {
        let trimmed = raw_nsfw.trim();
        let lower = trimmed.to_lowercase();
        if !lower.is_empty() && lower != "none" && lower != "false" && lower != "0" {
            return if lower == "true" {
                "NSFW".to_string()
            } else {
                trimmed.to_string()
            };
        }
    }

    const NSFW_KEYWORDS: &[&str] = &[
        "nsfw",
        "nude",
        "nudity",
        "naked",
        "topless",
        "explicit",
        "erotic",
        "lingerie",
        "boudoir",
        "uncensored",
        "hentai",
        "porn",
        "nipple",
        "nipples",
        "breasts",
        "genitals",
        "bdsm",
        "fetish",
    ];

    let is_nsfw = prompt
        .split(|c: char| !c.is_alphanumeric())
        .any(|token| {
            let lower = token.to_lowercase();
            NSFW_KEYWORDS.contains(&lower.as_str())
        });

    if is_nsfw {
        "NSFW".to_string()
    } else {
        "None".to_string()
    }
}

pub(crate) fn cmd_history(limit: usize) {
    let gallery = get_gallery_dir();
    let mut items = Vec::new();

    if let Ok(entries) = fs::read_dir(&gallery) {
        let mut paths: Vec<PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.is_file() && p.extension().is_some_and(|ext| ext == "png"))
            .collect();

        paths.sort_by(|a, b| {
            let m_a = a.metadata().and_then(|m| m.modified()).unwrap_or(UNIX_EPOCH);
            let m_b = b.metadata().and_then(|m| m.modified()).unwrap_or(UNIX_EPOCH);
            m_b.cmp(&m_a)
        });

        for p in paths.into_iter().take(limit) {
            let filename = p.file_name().unwrap_or_default().to_string_lossy().to_string();
            let size_mb = p.metadata().map(|m| (m.len() as f64) / 1_048_576.0).unwrap_or(0.0);
            let (width, height) = image::image_dimensions(&p).unwrap_or((1024, 1024));
            let chunks = read_png_chunks(&p);

            let raw_prompt = chunks.get("prompt").cloned().unwrap_or_default();
            let mut comfy_meta = if raw_prompt.starts_with('{') {
                parse_comfy_metadata(&raw_prompt)
            } else {
                ComfyExtractedMetadata::default()
            };

            // Fallback to raw base image if this is an upscale derivative
            if comfy_meta.prompt.is_none() {
                let raw_src = resolve_raw_image_path(&p.to_string_lossy());
                if raw_src != p.to_string_lossy() {
                    let src_p = Path::new(&raw_src);
                    if src_p.exists() {
                        let src_chunks = read_png_chunks(src_p);
                        if let Some(src_prompt) = src_chunks.get("prompt") {
                            if src_prompt.starts_with('{') {
                                comfy_meta = parse_comfy_metadata(src_prompt);
                            } else {
                                comfy_meta.prompt = Some(src_prompt.clone());
                            }
                        }
                        if comfy_meta.negative_prompt.is_none() {
                            comfy_meta.negative_prompt = src_chunks.get("negative_prompt").cloned();
                        }
                        if comfy_meta.seed.is_none() {
                            comfy_meta.seed = src_chunks.get("seed").and_then(|s| s.parse::<i64>().ok());
                        }
                        if comfy_meta.steps.is_none() {
                            comfy_meta.steps = src_chunks.get("steps").and_then(|s| s.parse::<u32>().ok());
                        }
                        if comfy_meta.cfg.is_none() {
                            comfy_meta.cfg = src_chunks.get("cfg").and_then(|c| c.parse::<f64>().ok());
                        }
                    }
                }
            }

            let mut prompt = comfy_meta.prompt.unwrap_or_default();
            if prompt.is_empty() && !raw_prompt.starts_with('{') {
                prompt = raw_prompt;
            }
            if prompt.is_empty() {
                prompt = filename
                    .split('_')
                    .skip(2)
                    .collect::<Vec<&str>>()
                    .join(" ")
                    .trim_end_matches(".png")
                    .to_string();
                if prompt.is_empty() {
                    prompt = filename.clone();
                }
            }

            let negative = comfy_meta.negative_prompt
                .or_else(|| chunks.get("negative_prompt").cloned())
                .unwrap_or_default();
            let seed = comfy_meta.seed
                .or_else(|| chunks.get("seed").and_then(|s| s.parse::<i64>().ok()))
                .unwrap_or(-1);
            let steps = comfy_meta.steps
                .or_else(|| chunks.get("steps").and_then(|s| s.parse::<u32>().ok()))
                .unwrap_or(25);
            let cfg = comfy_meta.cfg
                .or_else(|| chunks.get("cfg").and_then(|c| c.parse::<f64>().ok()))
                .unwrap_or(4.0);
            let ratio = chunks.get("ratio").cloned().unwrap_or_else(|| "1:1".to_string());
            let nsfw = detect_prompt_nsfw(&prompt, &chunks);

            items.push(serde_json::json!({
                "path": p.to_string_lossy(),
                "filename": filename,
                "timestamp": "Recent",
                "width": width,
                "height": height,
                "prompt": prompt,
                "negative_prompt": negative,
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "ratio": ratio,
                "nsfw": nsfw,
                "size_mb": (size_mb * 100.0).round() / 100.0,
            }));
        }
    }

    println!("{}", serde_json::json!({"status": "ok", "items": items, "total": items.len()}));
}

pub(crate) fn delete_history_file_in_dir(raw_path: &str, gallery_dir: &Path) -> Result<String, String> {
    let trimmed = raw_path.trim().strip_prefix("file://").unwrap_or(raw_path.trim());
    if trimmed.is_empty() {
        return Err("Empty path".to_string());
    }
    let canon_dir = fs::canonicalize(gallery_dir)
        .map_err(|e| format!("Gallery dir unavailable: {}", e))?;
    let canon_target = fs::canonicalize(Path::new(trimmed))
        .map_err(|e| format!("File not found: {}", e))?;
    if !canon_target.starts_with(&canon_dir) {
        return Err("Refusing to delete file outside gallery directory".to_string());
    }
    if !canon_target.is_file() {
        return Err("Target is not a regular file".to_string());
    }
    fs::remove_file(&canon_target)
        .map_err(|e| format!("Failed to delete file: {}", e))?;
    Ok(canon_target.to_string_lossy().to_string())
}

pub(crate) fn cmd_delete_history(raw_path: &str) {
    match delete_history_file_in_dir(raw_path, &get_gallery_dir()) {
        Ok(deleted) => println!("{}", serde_json::json!({"status": "ok", "deleted": deleted})),
        Err(msg) => println!("{}", serde_json::json!({"status": "error", "message": msg})),
    }
}

#[cfg(test)]
mod tests {
    use super::detect_prompt_nsfw;
    use std::collections::HashMap;

    #[test]
    fn detects_nsfw_from_chunk_metadata() {
        let mut chunks = HashMap::new();
        chunks.insert("nsfw".to_string(), "Mature".to_string());
        assert_eq!(detect_prompt_nsfw("a quiet landscape", &chunks), "Mature");

        chunks.insert("nsfw".to_string(), "true".to_string());
        assert_eq!(detect_prompt_nsfw("a quiet landscape", &chunks), "NSFW");

        chunks.insert("nsfw".to_string(), "None".to_string());
        assert_eq!(detect_prompt_nsfw("a quiet landscape", &chunks), "None");
    }

    #[test]
    fn detects_nsfw_from_prompt_keywords_with_word_boundaries() {
        let chunks = HashMap::new();
        assert_eq!(detect_prompt_nsfw("editorial boudoir portrait, soft light", &chunks), "NSFW");
        assert_eq!(detect_prompt_nsfw("cyberpunk neon street at night", &chunks), "None");
    }
}
