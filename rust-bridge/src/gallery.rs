use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

use crate::common::{
    get_gallery_dir, get_is_cs, MAX_IMG_BYTES,
};

pub(crate) fn crc32(buf: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &byte in buf {
        crc ^= byte as u32;
        for _ in 0..8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ 0xEDB8_8320;
            } else {
                crc >>= 1;
            }
        }
    }
    !crc
}

pub(crate) fn create_text_chunk(keyword: &str, text: &str) -> Vec<u8> {
    let mut data = Vec::new();
    data.extend_from_slice(keyword.as_bytes());
    data.push(0);
    data.extend_from_slice(text.as_bytes());

    let len = (data.len() as u32).to_be_bytes();
    let mut chunk = Vec::new();
    chunk.extend_from_slice(&len);
    chunk.extend_from_slice(b"tEXt");
    chunk.extend_from_slice(&data);

    let mut crc_data = Vec::new();
    crc_data.extend_from_slice(b"tEXt");
    crc_data.extend_from_slice(&data);
    let crc = crc32(&crc_data).to_be_bytes();
    chunk.extend_from_slice(&crc);

    chunk
}

pub(crate) fn embed_png_metadata<P: AsRef<Path>>(
    path: P,
    meta_pairs: &[(&str, &str)],
) -> std::io::Result<()> {
    let file_bytes = fs::read(&path)?;
    if file_bytes.len() < 8 || file_bytes[..8] != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        return Ok(());
    }

    let mut out = Vec::with_capacity(file_bytes.len() + 1024);
    out.extend_from_slice(&file_bytes[..8]);

    let mut cursor = 8;
    let mut inserted = false;

    while cursor + 8 <= file_bytes.len() {
        let chunk_len = u32::from_be_bytes(file_bytes[cursor..cursor + 4].try_into().unwrap()) as usize;
        let chunk_type = &file_bytes[cursor + 4..cursor + 8];
        let total_chunk_len = 12 + chunk_len;

        if cursor + total_chunk_len > file_bytes.len() {
            out.extend_from_slice(&file_bytes[cursor..]);
            break;
        }

        out.extend_from_slice(&file_bytes[cursor..cursor + total_chunk_len]);
        cursor += total_chunk_len;

        if chunk_type == b"IHDR" && !inserted {
            for &(k, v) in meta_pairs {
                let chunk = create_text_chunk(k, v);
                out.extend_from_slice(&chunk);
            }
            inserted = true;
        }
    }

    fs::write(path, out)?;
    Ok(())
}

pub(crate) fn read_png_chunks<P: AsRef<Path>>(path: P) -> HashMap<String, String> {
    let mut meta = HashMap::new();
    let mut file = match File::open(path) {
        Ok(f) => f,
        Err(_) => return meta,
    };

    let mut sig = [0u8; 8];
    if file.read_exact(&mut sig).is_err() || sig != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        return meta;
    }

    let mut len_buf = [0u8; 4];
    let mut type_buf = [0u8; 4];

    while file.read_exact(&mut len_buf).is_ok() && file.read_exact(&mut type_buf).is_ok() {
        let length = u32::from_be_bytes(len_buf) as usize;
        let chunk_type = &type_buf;

        if chunk_type == b"IEND" {
            break;
        }

        if chunk_type == b"tEXt" {
            if length < 10 * 1024 * 1024 {
                let mut data = vec![0u8; length];
                if file.read_exact(&mut data).is_ok() {
                    if let Some(null_pos) = data.iter().position(|&b| b == 0) {
                        let key = String::from_utf8_lossy(&data[..null_pos]).to_string();
                        let val = String::from_utf8_lossy(&data[null_pos + 1..]).to_string();
                        meta.insert(key, val);
                    }
                }
            } else {
                let _ = file.seek(SeekFrom::Current(length as i64));
            }
        } else if chunk_type == b"iTXt" {
            if length < 10 * 1024 * 1024 {
                let mut data = vec![0u8; length];
                if file.read_exact(&mut data).is_ok() {
                    if let Some(null_pos) = data.iter().position(|&b| b == 0) {
                        let key = String::from_utf8_lossy(&data[..null_pos]).to_string();
                        let mut p = null_pos + 1;
                        if p + 2 <= data.len() {
                            let _comp_flag = data[p];
                            p += 2;
                            if let Some(l_null) = data[p..].iter().position(|&b| b == 0) {
                                p += l_null + 1;
                                if let Some(t_null) = data[p..].iter().position(|&b| b == 0) {
                                    p += t_null + 1;
                                    let val = String::from_utf8_lossy(&data[p..]).to_string();
                                    meta.insert(key, val);
                                }
                            }
                        }
                    }
                }
            } else {
                let _ = file.seek(SeekFrom::Current(length as i64));
            }
        } else {
            let _ = file.seek(SeekFrom::Current(length as i64));
        }

        let _ = file.seek(SeekFrom::Current(4));
    }

    meta
}

#[derive(Default)]
pub(crate) struct ComfyExtractedMetadata {
    pub(crate) prompt: Option<String>,
    pub(crate) negative_prompt: Option<String>,
    pub(crate) seed: Option<i64>,
    pub(crate) steps: Option<u32>,
    pub(crate) cfg: Option<f64>,
}

pub(crate) fn parse_comfy_metadata(raw_json: &str) -> ComfyExtractedMetadata {
    let mut meta = ComfyExtractedMetadata::default();
    let val: serde_json::Value = match serde_json::from_str(raw_json) {
        Ok(v) => v,
        Err(_) => return meta,
    };

    let obj = match val.as_object() {
        Some(o) => o,
        None => return meta,
    };

    for (_node_id, node) in obj {
        let class_type = node.get("class_type").and_then(|c| c.as_str()).unwrap_or("");
        let inputs = match node.get("inputs").and_then(|i| i.as_object()) {
            Some(i) => i,
            None => continue,
        };

        // 1. Text prompts (Qwen TextEncode node)
        if class_type.contains("TextEncode") {
            if let Some(p) = inputs.get("prompt").and_then(|s| s.as_str()) {
                if !p.is_empty() && meta.prompt.is_none() {
                    meta.prompt = Some(p.to_string());
                }
            }
            if let Some(n) = inputs.get("negative_prompt").and_then(|s| s.as_str()) {
                if !n.is_empty() && meta.negative_prompt.is_none() {
                    meta.negative_prompt = Some(n.to_string());
                }
            }
            if let Some(text) = inputs.get("text").and_then(|s| s.as_str()) {
                if !text.is_empty() && meta.prompt.is_none() {
                    meta.prompt = Some(text.to_string());
                }
            }
        }

        // 2. KSampler attributes (seed, steps, cfg)
        if class_type.contains("Sampler") {
            if meta.seed.is_none() {
                if let Some(seed) = inputs.get("seed").and_then(|s| s.as_i64()) {
                    meta.seed = Some(seed);
                } else if let Some(seed) = inputs.get("noise_seed").and_then(|s| s.as_i64()) {
                    meta.seed = Some(seed);
                }
            }
            if meta.steps.is_none() {
                if let Some(steps) = inputs.get("steps").and_then(|s| s.as_u64()) {
                    meta.steps = Some(steps as u32);
                }
            }
            if meta.cfg.is_none() {
                if let Some(cfg) = inputs.get("cfg").and_then(|c| c.as_f64()) {
                    meta.cfg = Some(cfg);
                }
            }
        }

        // 3. Fallback for Turbo custom schedules (e.g. ViggleTurboSigmas has comma-separated steps)
        if class_type.contains("TurboSigmas") && meta.steps.is_none() {
            if let Some(nodes_str) = inputs.get("nodes").and_then(|n| n.as_str()) {
                let count = nodes_str.split(',').filter(|s| !s.trim().is_empty()).count();
                if count > 0 {
                    meta.steps = Some(count as u32);
                }
            }
        }
    }

    meta
}

pub(crate) fn sniff_image_magic(b: &[u8]) -> Option<&'static str> {
    if b.len() < 12 {
        return None;
    }
    match b {
        [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, ..] => Some("png"),
        [0xFF, 0xD8, 0xFF, ..] => Some("jpg"),
        [b'R', b'I', b'F', b'F', _, _, _, _, b'W', b'E', b'B', b'P', ..] => Some("webp"),
        [b'B', b'M', ..] => Some("bmp"),
        [b'I', b'I', 42, 0, ..] | [b'M', b'M', 0, 42, ..] => Some("tiff"),
        _ => None,
    }
}

pub(crate) fn validate_image_file(p: &Path) -> Result<PathBuf, String> {
    let is_cs = get_is_cs();
    let canonical = p.canonicalize().map_err(|e| {
        if is_cs { format!("Neplatná cesta: {}", e) } else { format!("Invalid path: {}", e) }
    })?;
    let meta = fs::symlink_metadata(&canonical).map_err(|e| {
        if is_cs { format!("Nelze přečíst metadata: {}", e) } else { format!("Cannot read metadata: {}", e) }
    })?;
    if !meta.is_file() {
        return Err(if is_cs { "Cesta neodkazuje na běžný soubor".to_string() } else { "Path does not point to a regular file".to_string() });
    }
    if meta.len() > MAX_IMG_BYTES {
        return Err(if is_cs { "Soubor překračuje limit 32 MB".to_string() } else { "File exceeds 32 MB limit".to_string() });
    }
    let mut file = File::open(&canonical).map_err(|e| {
        if is_cs { format!("Nelze otevřít soubor: {}", e) } else { format!("Cannot open file: {}", e) }
    })?;
    let mut header = [0u8; 16];
    let n = file.read(&mut header).map_err(|e| {
        if is_cs { format!("Nelze načíst hlavičku: {}", e) } else { format!("Cannot read header: {}", e) }
    })?;
    if sniff_image_magic(&header[..n]).is_none() {
        return Err(if is_cs { "Nepodporovaný formát obrázku (neplatné Magic bytes)".to_string() } else { "Unsupported image format (invalid magic bytes)".to_string() });
    }
    Ok(canonical)
}

pub(crate) fn resolve_raw_image_path(input_path: &str) -> String {
    let p = Path::new(input_path);
    if !p.exists() {
        return input_path.to_string();
    }

    let stem = match p.file_stem().and_then(|s| s.to_str()) {
        Some(s) => s,
        None => return input_path.to_string(),
    };

    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("png");
    let parent = p.parent().unwrap_or_else(|| Path::new("."));

    for tag in &["_ai2k_", "_ai4k_", "_4k_", "_2k_", "_4x_", "_2x_", "_fit1k_", "_scaled_"] {
        if let Some(pos) = stem.find(tag) {
            let base_stem = &stem[..pos];
            let candidate = parent.join(format!("{}.{}", base_stem, ext));
            if candidate.exists() {
                return candidate.to_string_lossy().to_string();
            }
        }
    }

    input_path.to_string()
}

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
                "size_mb": (size_mb * 100.0).round() / 100.0,
            }));
        }
    }

    println!("{}", serde_json::json!({"status": "ok", "items": items, "total": items.len()}));
}
