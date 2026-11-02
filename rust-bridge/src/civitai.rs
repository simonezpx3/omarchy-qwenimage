use crate::common::get_http_agent;
use crate::prompts_db;
use crate::vram::check_comfyui;

pub(crate) fn urlencoding_encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.' || b == b'~' {
            out.push(b as char);
        } else if b == b' ' {
            out.push_str("%20");
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

pub(crate) fn fetch_civitai_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(8);
    let mut items = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let nsfw_filter = if nsfw_allowed { "true" } else { "None" };

    // 1. Try local ComfyUI civitai discovery gallery if online
    if check_comfyui() {
        let local_url = format!(
            "http://127.0.0.1:8188/civitai_gallery/images_stream?query={}&min_batch={}&nsfw={}&hide_no_prompt=true&sort=Most%20Reactions&period={}&withMeta=true",
            urlencoding_encode(&q_lower),
            limit.max(10),
            nsfw_filter,
            if q_lower.is_empty() { "Month" } else { "AllTime" }
        );
        if let Ok(mut resp) = agent.get(&local_url).call() {
            if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                if let Some(arr) = val.get("items").and_then(|v| v.as_array()) {
                    for it in arr {
                        let meta = it.get("meta").unwrap_or(&serde_json::Value::Null);
                        let prompt = meta.get("prompt")
                            .or_else(|| meta.get("Prompt"))
                            .or_else(|| meta.get("positive"))
                            .and_then(|p| p.as_str())
                            .unwrap_or("");

                        if !prompt.is_empty() {
                            let p_norm = prompt.trim().to_lowercase();
                            if !seen.insert(p_norm) {
                                continue;
                            }

                            let nsfw_str = it.get("nsfwLevel").and_then(|v| v.as_str()).unwrap_or("None");
                            if !nsfw_allowed
                                && (nsfw_str.eq_ignore_ascii_case("x")
                                    || nsfw_str.eq_ignore_ascii_case("mature")
                                    || nsfw_str.eq_ignore_ascii_case("soft"))
                            {
                                continue;
                            }

                            let neg = meta.get("negativePrompt")
                                .or_else(|| meta.get("NegativePrompt"))
                                .or_else(|| meta.get("negative"))
                                .and_then(|n| n.as_str())
                                .unwrap_or("");
                            let seed = meta.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                            let cfg = meta.get("cfgScale").and_then(|c| c.as_f64()).unwrap_or(4.0);
                            let steps = meta.get("steps").and_then(|s| s.as_u64()).unwrap_or(25);
                            let sampler = meta.get("sampler").and_then(|s| s.as_str()).unwrap_or("Euler");
                            let preview_url = it.get("url").and_then(|u| u.as_str()).unwrap_or("");

                            items.push(serde_json::json!({
                                "id": it.get("id"),
                                "source": "CivitAI",
                                "prompt": prompt,
                                "negative_prompt": neg,
                                "seed": seed,
                                "cfg": cfg,
                                "steps": steps,
                                "sampler": sampler,
                                "preview_url": preview_url,
                                "nsfw": nsfw_str,
                            }));
                            if items.len() >= limit {
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Direct upstream CivitAI API fallback
    if items.is_empty() {
        let fetch_count = (limit * 2).clamp(50, 200);
        let upstream_url = if q_lower.is_empty() {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=Month&nsfw={}&withMeta=true",
                fetch_count,
                nsfw_filter
            )
        } else {
            format!(
                "https://civitai.com/api/v1/images?limit={}&sort=Most%20Reactions&period=AllTime&nsfw={}&withMeta=true&query={}",
                fetch_count,
                nsfw_filter,
                urlencoding_encode(&q_lower)
            )
        };

        let res = agent.get(&upstream_url)
            .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) Omarchy-Qwen/1.0")
            .header("Accept", "application/json")
            .call();

        if let Ok(mut resp) = res {
            if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                if let Some(arr) = val.get("items").and_then(|v| v.as_array()) {
                    let mut candidate_items = Vec::new();
                    for it in arr {
                        let meta = it.get("meta").unwrap_or(&serde_json::Value::Null);
                        let prompt = meta.get("prompt")
                            .or_else(|| meta.get("Prompt"))
                            .or_else(|| meta.get("positive"))
                            .and_then(|p| p.as_str())
                            .unwrap_or("");

                        if !prompt.is_empty() {
                            let p_norm = prompt.trim().to_lowercase();
                            if !seen.insert(p_norm) {
                                continue;
                            }

                            let nsfw_str = it.get("nsfwLevel").and_then(|v| v.as_str()).unwrap_or("None");
                            if !nsfw_allowed
                                && (nsfw_str.eq_ignore_ascii_case("x")
                                    || nsfw_str.eq_ignore_ascii_case("mature")
                                    || nsfw_str.eq_ignore_ascii_case("soft"))
                            {
                                continue;
                            }

                            let neg = meta.get("negativePrompt")
                                .or_else(|| meta.get("NegativePrompt"))
                                .or_else(|| meta.get("negative"))
                                .and_then(|n| n.as_str())
                                .unwrap_or("");
                            let seed = meta.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                            let cfg = meta.get("cfgScale").and_then(|c| c.as_f64()).unwrap_or(4.0);
                            let steps = meta.get("steps").and_then(|s| s.as_u64()).unwrap_or(25);
                            let sampler = meta.get("sampler").and_then(|s| s.as_str()).unwrap_or("Euler");
                            let preview_url = it.get("url").and_then(|u| u.as_str()).unwrap_or("");

                            let p_lower = prompt.to_lowercase();
                            let n_lower = neg.to_lowercase();
                            let haystack = format!("{} {}", p_lower, n_lower);

                            let item_json = serde_json::json!({
                                "id": it.get("id"),
                                "source": "CivitAI",
                                "prompt": prompt,
                                "negative_prompt": neg,
                                "seed": seed,
                                "cfg": cfg,
                                "steps": steps,
                                "sampler": sampler,
                                "preview_url": preview_url,
                                "nsfw": nsfw_str,
                            });

                            candidate_items.push((item_json, haystack));
                        }
                    }

                    // Strict pass: match ALL query words
                    for (item_json, haystack) in &candidate_items {
                        if words.is_empty() || words.iter().all(|w| haystack.contains(w)) {
                            items.push(item_json.clone());
                            if items.len() >= limit {
                                break;
                            }
                        }
                    }

                    // Relaxed pass: if multiple words and strict pass matched nothing, match ANY word
                    if items.is_empty() && words.len() > 1 {
                        for (item_json, haystack) in &candidate_items {
                            if words.iter().any(|w| haystack.contains(w)) {
                                items.push(item_json.clone());
                                if items.len() >= limit {
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if items.is_empty() {
        return prompts_db::search_curated("CivitAI", &words, limit, nsfw_allowed);
    }

    items
}

pub(crate) fn fetch_lexica_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    let agent = get_http_agent(3);
    let mut items = Vec::new();
    let mut seen = std::collections::HashSet::new();

    // 1. Attempt live API
    if !q_lower.is_empty() {
        let url = format!("https://lexica.art/api/v1/search?q={}", urlencoding_encode(&q_lower));
        if let Ok(mut resp) = agent.get(&url)
            .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            .header("Accept", "application/json")
            .call()
        {
            if resp.status().as_u16() == 200 {
                if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                    if let Some(images) = val.get("images").and_then(|i| i.as_array()) {
                        for img in images {
                            let prompt = img.get("prompt").and_then(|p| p.as_str()).unwrap_or("");
                            if !prompt.is_empty() {
                                let p_norm = prompt.trim().to_lowercase();
                                if !seen.insert(p_norm) {
                                    continue;
                                }

                                let id = img.get("id").and_then(|i| i.as_str()).unwrap_or("");
                                let preview_url = img.get("srcSmall")
                                    .or_else(|| img.get("src"))
                                    .and_then(|s| s.as_str())
                                    .unwrap_or("");
                                let seed = img.get("seed").and_then(|s| s.as_i64()).unwrap_or(0);
                                let cfg = img.get("guidance").and_then(|g| g.as_f64()).unwrap_or(4.5);

                                items.push(serde_json::json!({
                                    "id": id,
                                    "source": "Lexica",
                                    "prompt": prompt,
                                    "negative_prompt": "blurry, low quality, deformed, extra fingers, text, watermark",
                                    "seed": seed,
                                    "cfg": cfg,
                                    "steps": 25,
                                    "sampler": "Euler a",
                                    "preview_url": preview_url,
                                    "nsfw": "None",
                                }));
                                if items.len() >= limit {
                                    return items;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Curated Lexica high-aesthetic collection fallback
    if items.is_empty() {
        return prompts_db::search_curated("Lexica", &words, limit, nsfw_allowed);
    }
    items
}

pub(crate) fn fetch_prompthero_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("PromptHero", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_openart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("OpenArt", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_huggingface_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("HuggingFace", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_krea_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Krea.ai", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_tensorart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Tensor.art", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_midlibrary_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Midlibrary", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_diffusiondb_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("DiffusionDB", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_seaart_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("SeaArt", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_shakker_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Shakker", &words, limit, nsfw_allowed)
}

pub(crate) fn fetch_playground_items(query: &str, limit: usize, nsfw_allowed: bool) -> Vec<serde_json::Value> {
    let q_lower = query.trim().to_lowercase();
    let words: Vec<&str> = q_lower.split_whitespace().collect();
    prompts_db::search_curated("Playground", &words, limit, nsfw_allowed)
}

pub(crate) fn cmd_prompts(source: &str, query: &str, limit: usize, nsfw_allowed: bool) {
    let src = source.to_lowercase();
    let (src_name, items) = match src.as_str() {
        "midlibrary" | "midlib" | "midlibrary.io" => ("Midlibrary", fetch_midlibrary_items(query, limit, nsfw_allowed)),
        "diffusiondb" | "diffdb" => ("DiffusionDB", fetch_diffusiondb_items(query, limit, nsfw_allowed)),
        "seaart" | "seaart.ai" => ("SeaArt", fetch_seaart_items(query, limit, nsfw_allowed)),
        "shakker" | "shakker.ai" => ("Shakker", fetch_shakker_items(query, limit, nsfw_allowed)),
        "playground" | "playground.com" => ("Playground", fetch_playground_items(query, limit, nsfw_allowed)),
        "lexica" => ("Lexica", fetch_lexica_items(query, limit, nsfw_allowed)),
        "prompthero" => ("PromptHero", fetch_prompthero_items(query, limit, nsfw_allowed)),
        "openart" => ("OpenArt", fetch_openart_items(query, limit, nsfw_allowed)),
        "huggingface" | "hf" => ("HuggingFace", fetch_huggingface_items(query, limit, nsfw_allowed)),
        "krea" | "krea.ai" => ("Krea.ai", fetch_krea_items(query, limit, nsfw_allowed)),
        "tensorart" | "tensor" | "tensor.art" => ("Tensor.art", fetch_tensorart_items(query, limit, nsfw_allowed)),
        _ => ("CivitAI", fetch_civitai_items(query, limit, nsfw_allowed)),
    };

    println!("{}", serde_json::json!({
        "status": "ok",
        "source": src_name,
        "items": items
    }));
}

#[allow(dead_code)]
pub(crate) fn cmd_civitai(query: &str, limit: usize, nsfw_allowed: bool) {
    cmd_prompts("civitai", query, limit, nsfw_allowed);
}
