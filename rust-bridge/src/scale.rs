use crate::common::*;
use crate::gallery::{embed_png_metadata, read_png_chunks, resolve_raw_image_path};
use image::imageops::FilterType;
use image::GenericImageView;
use std::path::Path;

pub(crate) fn cmd_scale(input_path: &str, factor: f32) {
    let resolved = resolve_raw_image_path(input_path);
    let p = Path::new(&resolved);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", resolved)})
        );
        return;
    }

    let img_res = image::open(p);
    if let Ok(img) = img_res {
        let (w, h) = img.dimensions();
        let (new_w, new_h) = if factor <= 0.0 {
            let max_dim = w.max(h) as f32;
            let scale_ratio = if max_dim <= 1024.0 { 1.0 } else { 1024.0 / max_dim };
            let nw = (w as f32 * scale_ratio) as u32;
            let nh = (h as f32 * scale_ratio) as u32;
            (nw.max(64), nh.max(64))
        } else {
            let nw = (w as f32 * factor) as u32;
            let nh = (h as f32 * factor) as u32;
            (nw.max(64), nh.max(64))
        };

        let final_w = (new_w / 8) * 8;
        let final_h = (new_h / 8) * 8;

        let scaled = img.resize_exact(final_w, final_h, FilterType::Lanczos3);
        let factor_str = if (factor - 4.0).abs() < 0.01 {
            "4x"
        } else if (factor - 2.0).abs() < 0.01 {
            "2x"
        } else if (factor - 0.5).abs() < 0.01 {
            "0.5x"
        } else if factor <= 0.0 {
            "fit1k"
        } else {
            "scaled"
        };
        let ts = now_millis();
        let base_name = p.file_stem().and_then(|s| s.to_str()).unwrap_or("image");
        let mut clean_base = base_name;
        for sfx in &["_ai2k_", "_ai4k_", "_4x_", "_2x_", "_0.5x_", "_fit1k_", "_scaled_"] {
            if let Some(idx) = clean_base.find(sfx) {
                clean_base = &clean_base[..idx];
            }
        }

        let candidate_name = format!("{}_{}_{}x{}.png", clean_base, factor_str, final_w, final_h);
        let gallery_dir = get_gallery_dir();
        let out_path = if gallery_dir.join(&candidate_name).exists() {
            gallery_dir.join(format!("{}_{}_{}x{}_{}.png", clean_base, factor_str, final_w, final_h, ts % 100000))
        } else {
            gallery_dir.join(&candidate_name)
        };
        let final_filename = out_path.file_name().unwrap_or_default().to_string_lossy().to_string();

        if scaled.save(&out_path).is_ok() {
            let existing_meta = read_png_chunks(p);
            let mut meta_vec: Vec<(&str, &str)> = Vec::new();
            for (k, v) in &existing_meta {
                meta_vec.push((k.as_str(), v.as_str()));
            }
            let w_str = final_w.to_string();
            let h_str = final_h.to_string();
            let auth_dna = format!("0x{:X}", SA_SIGNATURE_DNA);
            meta_vec.push(("scale_factor", factor_str));
            meta_vec.push(("scaled_width", &w_str));
            meta_vec.push(("scaled_height", &h_str));
            meta_vec.push(("author_dna", &auth_dna));
            let _ = embed_png_metadata(&out_path, &meta_vec);

            play_chime();
            let is_cs = get_is_cs();
            let notif_title = if is_cs {
                format!("Upscale {} Dokončen", factor_str.to_uppercase())
            } else {
                format!("Upscale {} Complete", factor_str.to_uppercase())
            };
            let notif_body = if is_cs {
                format!("Uloženo do Qwen-Image: {}\nRozlišení: {}x{} (Lanczos3)", final_filename, final_w, final_h)
            } else {
                format!("Saved to Qwen-Image: {}\nResolution: {}x{} (Lanczos3)", final_filename, final_w, final_h)
            };
            send_notification(&notif_title, &notif_body, out_path.to_str());

            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "path": out_path.to_string_lossy(),
                    "filename": final_filename,
                    "width": final_w,
                    "height": final_h,
                    "factor": factor
                })
            );
            return;
        }
    }

    println!(
        "{}",
        serde_json::json!({"status": "error", "message": "Failed to process image"})
    );
}
