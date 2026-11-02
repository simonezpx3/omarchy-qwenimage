use std::fs::File;
use std::io::{BufRead, BufReader};

use crate::common::{get_http_agent, SA_SIGNATURE_DNA};
use crate::comfy;

pub(crate) fn is_czech_text(s: &str) -> bool {
    let mut cz_chars = 0;
    for c in s.chars() {
        if "ěščřžýáíéúůťďňóĚŠČŘŽÝÁÍÉÚŮŤĎŇÓ".contains(c) {
            cz_chars += 1;
        }
    }
    if cz_chars >= 2 {
        return true;
    }

    let cz_words = [
        "a", "i", "v", "s", "z", "k", "o", "u", "se", "si", "na", "do", "od", "po", "za", "pro",
        "ve", "ze", "ke", "ku", "to", "ta", "ten", "ti", "ty", "je", "jsou", "byl", "byla", "bylo",
        "bude", "budou", "jako", "jak", "ale", "nebo", "ani", "když", "protože", "který", "která",
        "které", "kteří", "co", "kdo", "kde", "kam", "odkud", "kdy", "proč", "jaký", "jaká", "jaké",
        "obraz", "fotka", "žena", "muž", "dívka", "chlapec", "auto", "les", "strom", "dům", "město",
        "kočka", "pes", "styl", "barva", "světlo", "stín", "detail", "pozadí", "popředí", "krásný",
        "krásná", "krásné", "velký", "velká", "malý", "malá", "černý", "bílý", "červený", "modrý",
        "zelený", "žlutý", "zlatý", "stříbrný", "portrét", "krajina", "digitální", "malba", "kresba",
    ];

    let en_words = [
        "the", "and", "in", "of", "to", "a", "is", "that", "for", "it", "as", "was", "with",
        "on", "at", "by", "this", "be", "are", "from", "or", "an", "not", "but", "what", "all",
        "were", "when", "we", "there", "can", "an", "your", "which", "their", "if", "do", "will",
        "each", "about", "how", "up", "out", "them", "then", "she", "many", "some", "so", "these",
        "would", "other", "into", "has", "more", "her", "two", "like", "him", "see", "time",
        "could", "no", "make", "than", "first", "been", "its", "who", "now", "people", "my",
        "made", "over", "did", "down", "only", "way", "find", "use", "may", "water", "long",
        "very", "after", "words", "called", "just", "where", "most", "know", "portrait", "photo",
        "photograph", "cinematic", "lighting", "ultra", "realistic", "detailed", "render",
        "digital", "art", "style", "illustration", "concept", "octane", "unreal", "engine",
    ];

    let lower = s.to_lowercase();
    let words: Vec<&str> = lower
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .collect();

    if words.is_empty() {
        return false;
    }

    let mut cz_count = 0;
    let mut en_count = 0;

    for w in &words {
        if cz_words.contains(w) {
            cz_count += 1;
        }
        if en_words.contains(w) {
            en_count += 1;
        }
    }

    if cz_chars > 0 && en_count == 0 {
        return true;
    }
    cz_count > en_count
}

fn query_local_openai(
    sys_prompt: &str,
    user_content: &str,
    temperature: f64,
    max_tokens: usize,
) -> Option<String> {
    let endpoints = [
        "http://127.0.0.1:8081",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:10001",
    ];

    let probe_agent = get_http_agent(1);
    for base in endpoints {
        let models_url = format!("{}/v1/models", base);
        if let Ok(mut resp) = probe_agent.get(&models_url).call() {
            if resp.status().as_u16() == 200 {
                let model_name = if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
                    val.get("data")
                        .and_then(|d| d.as_array())
                        .and_then(|a| a.first())
                        .and_then(|m| m.get("id"))
                        .and_then(|id| id.as_str())
                        .unwrap_or("default")
                        .to_string()
                } else {
                    "default".to_string()
                };

                let chat_agent = get_http_agent(12);
                let chat_url = format!("{}/v1/chat/completions", base);
                let req_body = serde_json::json!({
                    "model": model_name,
                    "messages": [
                        {"role": "system", "content": sys_prompt},
                        {"role": "user", "content": user_content}
                    ],
                    "temperature": temperature,
                    "max_tokens": max_tokens
                });

                if let Ok(mut chat_resp) = chat_agent.post(&chat_url).send_json(&req_body) {
                    if let Ok(val) = chat_resp.body_mut().read_json::<serde_json::Value>() {
                        if let Some(content) = val.get("choices")
                            .and_then(|c| c.as_array())
                            .and_then(|a| a.first())
                            .and_then(|c| c.get("message"))
                            .and_then(|m| m.get("content"))
                            .and_then(|c| c.as_str())
                        {
                            return Some(content.to_string());
                        }
                    }
                }
            }
        }
    }
    None
}

pub(crate) fn cmd_translate_internal(text: &str) -> Result<String, String> {
    let sys_prompt = "You are an expert diffusion prompt engineer. If the input is in Czech, accurately translate and expand it into descriptive, photorealistic English tags and scene modifiers suitable for DiT diffusion models (Qwen-Image). If the input is in English, enhance it with lighting, composition, and aesthetic modifiers. Output ONLY the final enhanced English prompt string, without any quotation marks, preamble, or conversational text.";

    // Tier 1: Probe fast local OpenAI-compatible server (port 8081/8080/10001)
    if let Some(content) = query_local_openai(sys_prompt, text, 0.4, 300) {
        let mut clean = content.trim();
        if let Some(end_think) = clean.rfind("</think>") {
            clean = clean[end_think + "</think>".len()..].trim();
        }
        if !clean.is_empty() {
            return Ok(clean.to_string());
        }
    }

    // Tier 2: Ollama fallback with suppressed thinking overhead
    let agent = get_http_agent(15);
    let req_body = serde_json::json!({
        "model": get_best_llm_model(),
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": text}
        ],
        "stream": false,
        "think": false,
        "options": {
            "temperature": 0.4,
            "num_predict": 300,
            "seed": SA_SIGNATURE_DNA
        }
    });

    let res = agent.post("http://127.0.0.1:11434/api/chat")
        .send_json(&req_body);

    match res {
        Ok(mut response) => {
            if let Ok(val) = response.body_mut().read_json::<serde_json::Value>() {
                if let Some(content) = val.get("message").and_then(|m| m.get("content")).and_then(|c| c.as_str()) {
                    let mut clean = content.trim();
                    if let Some(end_think) = clean.rfind("</think>") {
                        clean = clean[end_think + "</think>".len()..].trim();
                    }
                    if !clean.is_empty() {
                        return Ok(clean.to_string());
                    }
                }
            }
            Err("Empty or invalid response from Ollama".to_string())
        }
        Err(e) => Err(format!("Ollama connection error: {}", e)),
    }
}

pub(crate) fn cmd_translate(text: &str) {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        println!("{}", serde_json::json!({"status": "ok", "prompt": ""}));
        return;
    }

    let is_cz = is_czech_text(trimmed);
    match cmd_translate_internal(trimmed) {
        Ok(enhanced) => {
            println!("{}", serde_json::json!({
                "status": "ok",
                "prompt": enhanced,
                "is_cz": is_cz
            }));
        }
        Err(err) => {
            println!("{}", serde_json::json!({
                "status": "ok",
                "prompt": trimmed,
                "fallback": true,
                "error": err
            }));
        }
    }
}

pub(crate) fn get_best_llm_model() -> &'static str {
    let candidate_models = [
        "qwen2.5-coder:7b",
        "minicpm-v:latest",
        "heretic-v:latest",
        "maternion/mimo-v2.6-heretic:9b",
        "mimo:latest",
        "coder:latest",
        "arci:latest",
    ];
    let agent = get_http_agent(3);
    if let Ok(mut resp) = agent.get("http://127.0.0.1:11434/api/tags").call() {
        if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
            if let Some(models) = val.get("models").and_then(|m| m.as_array()) {
                let installed: Vec<String> = models.iter()
                    .filter_map(|m| m.get("name").and_then(|n| n.as_str()).map(|s| s.to_string()))
                    .collect();
                for cand in &candidate_models {
                    if installed.iter().any(|m| m == cand || m.starts_with(&format!("{}:", cand.split(':').next().unwrap_or("")))) {
                        return cand;
                    }
                }
            }
        }
    }
    "mimo:latest"
}

pub(crate) fn parse_optimized_response(
    content: &str,
    default_neg: &str,
    trimmed_input: &str,
) -> Option<(String, String, String)> {
    let mut clean = content.trim();
    // 1. Strip reasoning block </think> if present
    if let Some(end_think) = clean.rfind("</think>") {
        clean = clean[end_think + "</think>".len()..].trim();
    }

    // 2. Strip markdown code fence ```json ... ```
    if clean.starts_with("```") {
        if let Some(first_nl) = clean.find('\n') {
            clean = clean[first_nl + 1..].trim();
        }
        if clean.ends_with("```") {
            clean = clean[..clean.len() - 3].trim();
        }
    }

    let lower = clean.to_lowercase();
    if lower.contains("i can't")
        || lower.contains("i cannot")
        || lower.contains("violates my safety")
        || lower.contains("safety guidelines")
        || lower.contains("safety policy")
        || lower.contains("explicit sexual content")
    {
        return Some((trimmed_input.to_string(), default_neg.to_string(), "16:10".to_string()));
    }

    // 3. Direct JSON parsing
    if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(clean) {
        let rewritten = parsed.get("rewritten_prompt")
            .or_else(|| parsed.get("optimized_prompt"))
            .and_then(|r| r.as_str());
        if let Some(r) = rewritten {
            let ratio = parsed.get("wh_ratio").and_then(|w| w.as_str()).unwrap_or("16:10");
            let neg = parsed.get("negative_prompt").and_then(|n| n.as_str()).unwrap_or(default_neg);
            return Some((r.to_string(), neg.to_string(), ratio.to_string()));
        }
    }

    // 4. Substring JSON extraction
    if let Some(start) = clean.find('{') {
        if let Some(end) = clean.rfind('}') {
            if start < end {
                let slice = &clean[start..=end];
                if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(slice) {
                    let rewritten = parsed.get("rewritten_prompt")
                        .or_else(|| parsed.get("optimized_prompt"))
                        .and_then(|r| r.as_str());
                    if let Some(r) = rewritten {
                        let ratio = parsed.get("wh_ratio").and_then(|w| w.as_str()).unwrap_or("16:10");
                        let neg = parsed.get("negative_prompt").and_then(|n| n.as_str()).unwrap_or(default_neg);
                        return Some((r.to_string(), neg.to_string(), ratio.to_string()));
                    }
                }
            }
        }
    }

    if !clean.is_empty() {
        return Some((clean.to_string(), default_neg.to_string(), "16:10".to_string()));
    }

    None
}

fn try_openai_optimize(
    trimmed: &str,
    sys_prompt: &str,
    default_neg: &str,
) -> Option<(String, String, String)> {
    if let Some(content) = query_local_openai(sys_prompt, trimmed, 0.6, 400) {
        if let Some(res) = parse_optimized_response(&content, default_neg, trimmed) {
            return Some(res);
        }
    }
    None
}

pub(crate) fn optimize_prompt_internal(text: &str) -> Result<(String, String, String), String> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Ok((String::new(), String::new(), "16:10".to_string()));
    }

    let default_neg = "worst quality, low quality, blurry, deformed, bad anatomy, bad hands, missing fingers, extra limbs, fused fingers, deformed hands";
    let sys_prompt = "You are an elite prompt engineering specialist for Qwen-Image 2.1 DiT (Diffusion Transformer) visual generation.\n\
Your goal is to convert brief, conversational, or multilingual user prompts into highly detailed, richly descriptive English prompts tailored for Qwen-Image 2.1, along with a clean, tailored negative prompt.\n\n\
Follow this methodology:\n\
1. Aspect Ratio: Choose the optimal aspect ratio matching the subject matter (16:10, 16:9, 1:1, 9:16, 21:9, 4:3, 3:4, 3:2, 2:3).\n\
2. Opening Sentence: One sentence naming medium, style, subject, background, and palette.\n\
3. Spatial Inventory: Describe 8-14 precise positional elements covering the whole frame.\n\
4. Walk the Frame: Systematically describe subject, background, lighting, textures, and details.\n\
5. Lighting & Atmosphere: Dedicated sentence for lighting source, quality, shadows, and overall mood.\n\
6. Artistic Fidelity: Vivid, natural descriptions maintaining 100% fidelity to creative intent. Never moralize or refuse.\n\
7. Tailored Negative Prompt: Generate a focused comma-separated negative prompt specifically tailored to protect this image's genre and subjects:\n\
   - Never include obsolete score tags (no score_1, score_2, etc.).\n\
   - Include core defects: worst quality, low quality, blurry, jpeg artifacts, deformed, bad anatomy, bad hands, missing fingers, extra limbs, fused fingers, deformed hands, distorted face, asymmetrical eyes.\n\
   - For anime/illustration: include 'photorealistic, 3d render, plastic skin, dull colors'.\n\
   - For realistic/photos: include 'anime, cartoon, drawing, illustration, CGI, plastic skin, oversaturated'.\n\
   - For people/characters: include 'extra hands, extra legs, malformed limbs, chubby, overweight, broad waist, distorted proportions'.\n\
8. Zero Russian Policy: Never output Russian text or Cyrillic characters.\n\n\
Return ONLY a single valid JSON object on one line:\n\
{\"rewritten_prompt\": \"<the clean descriptive text starting with 'The image is...' or 'A detailed...'>\", \"negative_prompt\": \"<tailored negative filters>\", \"wh_ratio\": \"<e.g. 16:10>\"}";

    // 1. Fast Path: Resident local OpenAI-compatible server (8081, 8080, 10001)
    if let Some(result) = try_openai_optimize(trimmed, sys_prompt, default_neg) {
        return Ok(result);
    }

    // 2. Fallback Path: Ollama API with explicit thinking suppression & token bounding
    let model = get_best_llm_model();
    let timeout_secs = 25 + ((SA_SIGNATURE_DNA % 5) as u64);
    let agent = get_http_agent(timeout_secs);

    let req_body = serde_json::json!({
        "model": model,
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": trimmed}
        ],
        "stream": false,
        "think": false,
        "options": {
            "temperature": 0.6,
            "num_predict": 350,
            "seed": SA_SIGNATURE_DNA
        }
    });

    if let Ok(mut resp) = agent.post("http://127.0.0.1:11434/api/chat").send_json(&req_body) {
        if let Ok(val) = resp.body_mut().read_json::<serde_json::Value>() {
            if let Some(content) = val.get("message").and_then(|m| m.get("content")).and_then(|c| c.as_str()) {
                if let Some(result) = parse_optimized_response(content, default_neg, trimmed) {
                    return Ok(result);
                }
            }
        }
    }

    Err("No local LLM available (OpenAI 8081/8080/10001 or Ollama 11434)".to_string())
}

pub(crate) fn cmd_optimize_prompt(text: &str) {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        println!("{}", serde_json::json!({
            "status": "ok",
            "rewritten_prompt": "",
            "wh_ratio": "16:10"
        }));
        return;
    }

    let default_neg = "worst quality, low quality, blurry, deformed, bad anatomy, bad hands, missing fingers, extra limbs, fused fingers, deformed hands";
    match optimize_prompt_internal(trimmed) {
        Ok((rewritten, neg, ratio)) => {
            println!("{}", serde_json::json!({
                "status": "ok",
                "rewritten_prompt": rewritten,
                "negative_prompt": neg,
                "wh_ratio": ratio,
                "model": get_best_llm_model()
            }));
        }
        Err(err) => {
            println!("{}", serde_json::json!({
                "status": "fallback",
                "rewritten_prompt": trimmed,
                "negative_prompt": default_neg,
                "wh_ratio": "16:10",
                "message": err
            }));
        }
    }
}

pub(crate) fn cmd_tags(query: &str, limit: usize) {
    let csv_path = comfy::get_comfy_dir()
        .join("custom_nodes/ComfyUI-Autocomplete-Plus/data/danbooru_tags.csv");

    if !csv_path.exists() {
        println!("{}", serde_json::json!({"status": "ok", "tags": []}));
        return;
    }

    let q = query.trim().to_lowercase();
    let mut matches = Vec::new();

    if let Ok(file) = File::open(csv_path) {
        let reader = BufReader::new(file);
        for line in reader.lines().map_while(Result::ok) {
            let tag = line.split(',').next().unwrap_or("").trim();
            if !tag.is_empty() && (tag.starts_with(&q) || tag.contains(&q)) {
                matches.push(tag.to_string());
                if matches.len() >= limit {
                    break;
                }
            }
        }
    }

    println!("{}", serde_json::json!({"status": "ok", "tags": matches}));
}

pub(crate) fn detect_human_subject(prompt: &str) -> bool {
    let p = prompt.to_ascii_lowercase();
    const HUMAN_TOKENS: &[&str] = &[
        "woman", "women", "man", "men", "girl", "girls", "boy", "boys",
        "person", "people", "human", "body", "nude", "naked", "erotic",
        "portrait", "skin", "breasts", "legs", "face", "buttocks", "ass",
        "waist", "hips", "thighs", "female", "male", "model", "hand", "hands",
        "finger", "fingers", "child", "children", "character", "warrior", "elf",
        // Czech anatomical / character tokens
        "dívka", "dívky", "žena", "ženy", "muž", "muži", "tělo", "nahá", "nahý",
        "nahé", "akt", "ruce", "ruka", "prsty", "prst", "obličej", "tvář", "postava"
    ];

    let words: Vec<&str> = p
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .filter(|w| !w.is_empty())
        .collect();

    words.iter().any(|w| HUMAN_TOKENS.contains(w))
}

pub(crate) fn strip_foreign_prompt_tags(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut in_tag = false;
    for c in s.chars() {
        if c == '<' {
            in_tag = true;
        } else if c == '>' && in_tag {
            in_tag = false;
        } else if !in_tag {
            out.push(c);
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(crate) fn unpack_json_prompt_if_present(s: &str) -> String {
    if s.contains("rewritten_prompt") {
        if let Some(pos) = s.find("\"rewritten_prompt\"") {
            let rest = &s[pos + 18..];
            if let Some(colon) = rest.find(':') {
                let after_colon = rest[colon + 1..].trim_start();
                if let Some(stripped) = after_colon.strip_prefix('"') {
                    let mut extracted = String::new();
                    let mut chars = stripped.chars();
                    while let Some(c) = chars.next() {
                        if c == '\\' {
                            if let Some(next_c) = chars.next() {
                                if next_c == 'n' {
                                    extracted.push('\n');
                                } else {
                                    extracted.push(next_c);
                                }
                            }
                        } else if c == '"' {
                            break;
                        } else {
                            extracted.push(c);
                        }
                    }
                    if extracted.len() > 20 {
                        return extracted;
                    }
                }
            }
        }
    }
    s.to_string()
}

/// Two-layer defensive prompt sanitization against invisible TUI anchors, format characters,
/// zero-width sequences, PUA icons, Bidi overrides, and C0/C1 control codes.
/// Preserves legitimate multilingual text (Czech, European accents, CJK) and standard punctuation.
pub fn sanitize_diffusion_prompt(input: &str) -> String {
    if input.is_empty() {
        return String::new();
    }

    let mut filtered = String::with_capacity(input.len());
    for c in input.chars() {
        // 1. TUI anchors (Interlinear Annotation Anchors U+FFF9..U+FFFB) & replacement char U+FFFD
        if ('\u{FFF9}'..='\u{FFFB}').contains(&c) || c == '\u{FFFD}' {
            continue;
        }

        // 2. Zero-width, BOM, Word Joiners & Soft Hyphen
        if c == '\u{FEFF}' || c == '\u{200B}' || c == '\u{200C}' || c == '\u{200D}' || c == '\u{2060}' || c == '\u{00AD}' {
            continue;
        }

        // 3. Bidi directional overrides and isolates
        if ('\u{202A}'..='\u{202E}').contains(&c) || ('\u{2066}'..='\u{2069}').contains(&c) || c == '\u{200E}' || c == '\u{200F}' {
            continue;
        }

        // 4. Private Use Area (PUA icons, Nerd Font glyphs)
        if ('\u{E000}'..='\u{F8FF}').contains(&c) {
            continue;
        }

        // 5. C0 / C1 control characters (strip all except \n, \t, and \r)
        if c.is_control() && c != '\n' && c != '\r' && c != '\t' {
            continue;
        }

        // Convert carriage return to space
        if c == '\r' {
            filtered.push(' ');
            continue;
        }

        filtered.push(c);
    }

    // 6. Normalization: collapse repeated spaces, collapse repeated commas, normalize comma spacing
    let mut normalized = String::with_capacity(filtered.len());
    let mut last_was_space = false;
    let mut last_was_comma = false;

    for c in filtered.chars() {
        if c == ' ' || c == '\t' {
            if !last_was_space && !last_was_comma && !normalized.is_empty() {
                normalized.push(' ');
                last_was_space = true;
            }
        } else if c == '\n' {
            if normalized.ends_with(' ') {
                normalized.pop();
            }
            if !normalized.ends_with('\n') && !normalized.is_empty() {
                normalized.push('\n');
                last_was_space = true;
                last_was_comma = false;
            }
        } else if c == ',' {
            if !last_was_comma && !normalized.is_empty() {
                if last_was_space && normalized.ends_with(' ') {
                    normalized.pop();
                }
                normalized.push(',');
                normalized.push(' ');
                last_was_comma = true;
                last_was_space = true;
            }
        } else {
            normalized.push(c);
            last_was_space = false;
            last_was_comma = false;
        }
    }

    let trimmed = normalized.trim().trim_matches(',').trim();
    trimmed.to_string()
}
