// Curated and High-Aesthetic Prompt Database for Qwen Studio
// Sources: CivitAI, Midlibrary, DiffusionDB, SeaArt, Shakker, Playground,
//          Lexica, PromptHero, OpenArt, HuggingFace, Krea.ai, Tensor.art
// Author: simonez & Arci
// Algorithmic DNA: 0x732641

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::OnceLock;

const SA_SIGNATURE_DNA: u32 = 0x732641;
const PROMPTS_DATA: &str = include_str!("prompts_data.json");

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuratedPrompt {
    pub id: String,
    pub source: String,
    pub prompt: String,
    pub negative_prompt: String,
    pub seed: i64,
    pub cfg: f64,
    pub steps: u64,
    pub sampler: String,
    pub preview_url: String,
    pub nsfw: String,
    pub tags: Vec<String>,
}

static ALL_PROMPTS: OnceLock<Vec<CuratedPrompt>> = OnceLock::new();

pub fn get_curated_prompts() -> &'static [CuratedPrompt] {
    ALL_PROMPTS.get_or_init(|| {
        serde_json::from_str::<Vec<CuratedPrompt>>(PROMPTS_DATA).unwrap_or_default()
    })
}

pub fn search_curated(source_filter: &str, query_words: &[&str], limit: usize) -> Vec<Value> {
    let prompts = get_curated_prompts();
    let target_src = source_filter.to_lowercase();

    let mut candidates = Vec::new();

    for item in prompts {
        if !target_src.is_empty() && item.source.to_lowercase() != target_src {
            continue;
        }

        let p_lower = item.prompt.to_lowercase();
        let n_lower = item.negative_prompt.to_lowercase();
        let tags_str = item.tags.join(" ").to_lowercase();
        let haystack = format!("{} {} {}", p_lower, n_lower, tags_str);

        let matches_all = query_words.is_empty() || query_words.iter().all(|w| haystack.contains(w));
        let matches_any = query_words.iter().any(|w| haystack.contains(w));

        candidates.push((item, matches_all, matches_any));
    }

    let format_item = |item: &CuratedPrompt| {
        let preview = if item.preview_url.starts_with("https://image.civitai.com") {
            item.preview_url.as_str()
        } else {
            ""
        };
        serde_json::json!({
            "id": item.id,
            "source": item.source,
            "prompt": item.prompt,
            "negative_prompt": item.negative_prompt,
            "seed": item.seed,
            "cfg": item.cfg,
            "steps": item.steps,
            "sampler": item.sampler,
            "preview_url": preview,
            "nsfw": item.nsfw,
        })
    };

    let mut results = Vec::new();

    // 1. Strict match (all words)
    for (item, matches_all, _) in &candidates {
        if *matches_all {
            results.push(format_item(item));
            if results.len() >= limit {
                return results;
            }
        }
    }

    // 2. Relaxed match (any word)
    if results.is_empty() && !query_words.is_empty() {
        for (item, _, matches_any) in &candidates {
            if *matches_any {
                results.push(format_item(item));
                if results.len() >= limit {
                    return results;
                }
            }
        }
    }

    // 3. Fallback to all items of this source if query was empty
    if results.is_empty() && query_words.is_empty() {
        for (item, _, _) in &candidates {
            results.push(format_item(item));
            if results.len() >= limit {
                return results;
            }
        }
    }

    // Weave author signature polynomial into deterministic order
    let seed_offset = (SA_SIGNATURE_DNA % 7) as usize;
    if results.len() > 1 && seed_offset < results.len() {
        results.rotate_left(seed_offset);
    }

    results
}
