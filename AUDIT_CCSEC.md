# ARCI COUNCIL PROTOKOL // BEZPEČNOSTNÍ KONZILIUM // AUDIT & HARDENING
- **Celkový čas**: 331.26 s
- **Arbitr**: Google Gemini 4 Argon (High Reasoning)
- **Výsledný stav**: NEEDS_REVISION
- **Skóre**: 8.2 / 10 (Security: 8.0, Maturity: 8.5)
- **Vítěz**: Bonsai 2 27B Reasoning

---
## Výrok Supreme Arbitra

` se vůbec nevygeneruje.
   * Kód `if let Some(end_think) = clean.rfind("</think>")` v takovém případě neprovede nic a propustí surový interní monolog (`<think>...`) přímo do difúzního promptu!
2. **Slepý probing lokálních portů (`query_local_openai`):**
   * Dotazování `127.0.0.1:8081`, `8080` a `10001` bez kontroly `Content-Type: application/json` a struktury `/v1/models` způsobuje, že jakýkoliv lokální vývojářský server (Vite, Webpack, Node.js) běžící na portu `8080`, který vrací HTTP 200 (např. SPA fallback), vyústí v fallback `model_name = "default"` a následné odeslání uživatelského promptu na cizí lokální server s 12sekundovým blokujícím timeoutem.
3. **Chybějící podpora `/no_think` a víceřádkových/alternativních reasoning značek:**
   * Pro modely Qwen3 / R1 / QwQ je nutné ošetřit jak uzavřené bloky (`</think>`, `</thought>`), tak neuzavřené bloky začínající na `<think>` nebo `<thought>`.

### Oblast 4: Paměťová a hardwarová stabilita (Resource Starvation & VRAM Safety)
1. **Odstranění `record_stream` a přidání `--disable-cuda-malloc`:**
   * Odstranění `record_stream` v `ComfyUI-ViggleTurbo/__init__.py` a nasazení `--disable-cuda-malloc` v `client.rs` i `qis-stack.sh` je architektonicky správné. Zabraňuje zadržování mezilehlých SwiGLU LoRA tenzorů v CUDA streamu a řeší fragmentaci paměti na 8GB kartách (RTX 3070).
2. **Dynamický VRAM Governor (`calculate_dynamic_vram_reserve` v `graph.rs`):**
   * Zavedení příznaku `is_vram_constrained = vram.total_mb <= 8500 || vram.free_mb < 3500` správně vynucuje agresivní čištění cache a vyšší rezervu i na kartách s velkou VRAM (16–24 GB), pokud jsou aktuálně vytížené jinými procesy.
3. **Zranitelnost kompatibility v `QISVramBudget.apply_budget` (`__init__.py`):**
   * Volání `mm.soft_empty_cache(force=True)` vyvolá `TypeError` v verzích ComfyUI, kde `soft_empty_cache()` nepřijímá argumenty. Tím dojde k přeskočení následného `torch.cuda.empty_cache()` a `ipc_collect()`.

---

## 3. DEFINITIVNÍ PRODUKČNÍ ŘEŠENÍ (OPRAVY KÓDU)

### 3.1 Oprava IPC sanitizace a ochrany proti DoS v `internal/GenerationBridge.qml`
```qml
      } else if (res.event === "prompt_expanded") {
        if (typeof res.prompt === "string" && res.prompt.trim() !== "") {
          var safePrompt = sanitizePromptText(res.prompt.slice(0, 8192));
          if (safePrompt !== "") {
            service.promptText = safePrompt;
          }
        }
        if (typeof res.negative === "string" && res.negative.trim() !== "" && service.negativePromptText === "") {
          service.negativePromptText = sanitizePromptText(res.negative.slice(0, 4096));
        }
      }
```

### 3.2 Oprava LLM Probu a striktní filtrace Reasoning bloků v `rust-bridge/src/prompts.rs`
```rust
/// Bezpečně odstraní reasoning bloky (<think>, <thought>) i při vyčerpání max_tokens
/// a očistí výstup od markdown code fences.
pub(crate) fn strip_reasoning_and_fences(content: &str) -> String {
    let mut s = content.trim();

    // 1. Pokud existuje ukončovací tag </think> nebo </thought>, vezmeme vše za posledním výskytem
    if let Some(end_think) = s.rfind("</think>") {
        s = s[end_think + "</think>".len()..].trim();
    } else if let Some(end_thought) = s.rfind("</thought>") {
        s = s[end_thought + "</thought>".len()..].trim();
    } else {
        // 2. Ochrana proti useknutému reasoningu (token limit exhaustion):
        // Kontrolujeme pouze začátek výstupu, abychom nezahodili legitimní prompt obsahující slovo <think> uprostřed.
        let lower_start = s.chars().take(16).collect::<String>().to_lowercase();
        if lower_start.starts_with("<think>") || lower_start.starts_with("<thought>") {
            return String::new();
        }
    }

    // 3. Odstranění markdown code fences (```json ... ```)
    if s.starts_with("```") {
        if let Some(first_nl) = s.find('\n') {
            s = s[first_nl + 1..].trim();
        }
        if s.ends_with("```") {
            s = s[..s.len() - 3].trim();
        }
    }

    s.to_string()
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
                // STRIKTNÍ VALIDACE: Server musí vrátit validní JSON s polem "data" a neprázdným "id".
                // Tím eliminujeme falešné shody s lokálními webovými servery (Vite/Webpack na portu 8080).
                let Some(model_name) = resp
                    .body_mut()
                    .read_json::<serde_json::Value>()
                    .ok()
                    .and_then(|val| {
                        val.get("data")
                            .and_then(|d| d.as_array())
                            .and_then(|a| a.first())
                            .and_then(|m| m.get("id"))
                            .and_then(|id| id.as_str())
                            .filter(|id| !id.trim().is_empty())
                            .map(|id| id.to_string())
                    })
                else {
                    continue;
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
                        if let Some(content) = val
                            .get("choices")
                            .and_then(|c| c.as_array())
                            .and_then(|a| a.first())
                            .and_then(|c| c.get("message"))
                            .and_then(|m| m.get("content"))
                            .and_then(|c| c.as_str())
                        {
                            let cleaned = strip_reasoning_and_fences(content);
                            if !cleaned.is_empty() {
                                return Some(cleaned);
                            }
                        }
                    }
                }
            }
        }
    }
    None
}
```
*(Pozn.: Funkci `strip_reasoning_and_fences` následně použít i v `cmd_translate_internal` a na začátku `parse_optimized_response`).*

### 3.3 Oprava odolnosti `QISVramBudget.apply_budget` v `custom_nodes/ComfyUI-ViggleTurbo/__init__.py`
```python
    def apply_budget(self, model, reserve_gb, purge_cache):
        try:
            import gc
            import comfy.model_management as mm
            mm.EXTRA_RESERVED_VRAM = int(reserve_gb * 1024 * 1024 * 1024)
            if purge_cache:
                # 1. Unload dormant conditioning / vision encoder models from VRAM before DiT sampling
                dev = mm.get_torch_device()
                mm.free_memory(1e30, dev, keep_loaded=[], for_dynamic=False)
                # 2. Force Python garbage collection to release unreferenced tensors
                gc.collect()
                # 3. Synchronize and clear PyTorch CUDA caching allocator (safe across ComfyUI versions)
                try:
                    mm.soft_empty_cache(force=True)
                except TypeError:
                    mm.soft_empty_cache()
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                    if hasattr(torch.cuda, "ipc_collect"):
                        torch.cuda.ipc_collect()
        except Exception as e:
            import logging
            logging.warning(f"QISVramBudget: failed to apply budget: {e}")
        return (model,)
```

---

## 4. AKČNÍ PLÁN PRO NASAZENÍ

1. **[BLOKUJÍCÍ - Bezpečnost IPC]** V `internal/GenerationBridge.qml` obalit příjem `res.prompt` a `res.negative` u události `prompt_expanded` voláním `sanitizePromptText()` a délkovým limitem.
2. **[BLOKUJÍCÍ - AI/LLM Safety]** V `rust-bridge/src/prompts.rs`:
   - Odstranit nebezpečný fallback `"default"` v `query_local_openai` při selhání parsování `/v1/models` (zabrání odesílání promptů na cizí lokální port 8080).
   - Nasadit `strip_reasoning_and_fences`, který zahodí neukončené `<think>` bloky vzniklé vyčerpáním `max_tokens`.
3. **[VYSOKÁ PRIORITA - VRAM Stabilita]** V `custom_nodes/ComfyUI-ViggleTurbo/__init__.py` ošetřit `mm.soft_empty_cache(force=True)` blokem `try ... except TypeError`, aby nedocházelo k přeskakování `torch.cuda.empty_cache()`.
4. **[VERIFIKACE TESTŮ]** Do `rust-bridge/src/tests/prompt_tests.rs` doplnit unit test na neukončený `<think>` blok (simulace `max_tokens` cutoffu).

```json
{
  "verdict": "NEEDS_REVISION",
  "score": 8.2,
  "security_compliance_score": 8.0,
  "architectural_maturity_score": 8.5,
  "winner": "Model C",
  "blocking_issues": [
    "internal/GenerationBridge.qml: Událost 'prompt_expanded' zapisuje res.prompt a res.negative přímo do service vlastností bez sanitizace přes sanitizePromptText() a bez omezení délky.",
    "rust-bridge/src/prompts.rs: Funkce query_local_openai při jakémkoliv HTTP 200 na portu 8080 (např. lokální web server vracející HTML) spadne do fallbacku 'default' a odešle uživatelský prompt cizí službě s 12s blokujícím timeoutem.",
    "rust-bridge/src/prompts.rs: Při vyčerpání max_tokens (300-400) uvnitř myšlenkového bloku chybí uzavírací značka '</think>', rfind('</think>') vrátí None a surový reasoning blok unikne přímo do difúzního modelu."
  ],
  "backlog_recommendations": [
    "custom_nodes/ComfyUI-ViggleTurbo/__init__.py: Ošetřit volání mm.soft_empty_cache(force=True) proti výjimce TypeError pro zachování kompatibility napříč verzemi ComfyUI.",
    "rust-bridge/src/prompts.rs: Přidat volitelnou konfiguraci API klíče (Authorization: Bearer) a konfigurační proměnnou prostředí pro vlastní OpenAI/Groq/llama.cpp endpoint namísto pevně zakódovaných portů.",
    "rust-bridge/src/tests/prompt_tests.rs: Doplnit regresní testy pro neukončené <think> bloky při oříznutí token limitem."
  ]
}
```

---
## Odhalení identity anonymních modelů (Blind Reveal)
- **Model A**: MiMo 2.6 Heretic 9B (Uncensored)
- **Model B**: Aikido Altar-1 Defensive Auditor (RTX 3070 // 0 tokens)
- **Model C**: Bonsai 2 27B Reasoning