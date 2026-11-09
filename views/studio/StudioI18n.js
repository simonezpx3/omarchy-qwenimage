.pragma library

var strings = {
  // Prompt Box
  "prompt_title": {
    "cs": "PROMPT",
    "en": "PROMPT"
  },
  "prompt_placeholder": {
    "cs": "Zadej prompt v angličtině (automatický lokální překlad)...",
    "en": "Enter prompt in English (automatic local translation)..."
  },
  "words": { "cs": "slov", "en": "words" },
  "optimize": { "cs": "VYLEPŠIT", "en": "OPTIMIZE" },
  "optimizing": { "cs": "VYLEPŠUJI...", "en": "OPTIMIZING..." },
  "auto_expand_on": { "cs": "Expand: ON", "en": "Expand: ON" },
  "auto_expand_off": { "cs": "Expand: OFF", "en": "Expand: OFF" },
  "help_optimize": {
    "cs": "VYLEPŠIT: Jednorázově rozvine zadaný prompt do detailního difuzního promptu na lokální GPU (0 tokenů).",
    "en": "OPTIMIZE: One-time prompt expansion into rich diffusion prompt on local GPU (0 tokens)."
  },
  "help_auto_expand": {
    "cs": "AUTO-EXPAND: Automaticky rozvine každý prompt před generováním pomocí lokálního LLM (lokální GPU, 0 tokenů).",
    "en": "AUTO-EXPAND: Automatically expands prompt via local LLM before generation (local GPU, 0 tokens)."
  },
  "negative_title": { "cs": "NEGATIVNÍ PROMPT", "en": "NEGATIVE PROMPT" },
  "negative_placeholder": {
    "cs": "rozmazané, nízká kvalita, deformace, prsty navíc, text, vodoznak",
    "en": "blurry, low quality, deformed, extra fingers, text, watermark"
  },

  // Poměry stran
  "ratio_auto_ref": { "cs": "AUTO (REF)", "en": "AUTO (REF)" },

  // Resolution
  "draft": { "cs": "NÁVRH (512)", "en": "DRAFT (512)" },
  "std": { "cs": "STD (1024)", "en": "STD (1024)" },
  "high": { "cs": "VYSOKÉ (1536)", "en": "HIGH (1536)" },
  "ultra": { "cs": "ULTRA (2048)", "en": "ULTRA (2048)" },
  "max": { "cs": "MAX (2560)", "en": "MAX (2560)" },

  // Seed & Steps
  "seed_auto": { "cs": "AUTO", "en": "AUTO" },
  "help_seed_auto": {
    "cs": "SEED // AUTO: Náhodný seed pro každé generování. Kliknutím uzamknete aktuální seed.",
    "en": "SEED // AUTO: Random seed for each generation. Click to lock the current seed."
  },
  "help_seed_locked": {
    "cs": "Kliknutím odemknete a přepnete na náhodný AUTO seed.",
    "en": "Click to unlock and switch back to random AUTO seed."
  },
  "steps": { "cs": "KROKY: ", "en": "STEPS: " },
  "step": { "cs": "KROK", "en": "STEP" },
  "warn_low_steps": {
    "cs": "VAROVÁNÍ // Nízký počet kroků bez Turbo destilace degraduje denoise a anatomii",
    "en": "WARNING // Low step count without Turbo degrades denoise and anatomy"
  },
  "warn_human_draft": {
    "cs": "VAROVÁNÍ // Nízké rozlišení (Draft) degraduje lidskou anatomii a detaily",
    "en": "WARNING // Low resolution (Draft) degrades human anatomy and facial details"
  },

  // Reference & Buffer
  "ref_title": {
    "cs": "REFERENCE A BUFFER (VLOŽIT ZE SCHRÁNKY / VÝŘEZ)",
    "en": "REFERENCE & BUFFER (CLIPBOARD PASTE / SCREEN SNIP)"
  },
  "no_buffer": { "cs": "Bez bufferu", "en": "No Buffer" },
  "buffer_empty": { "cs": "BUFFER // PRÁZDNÝ", "en": "BUFFER // EMPTY" },
  "drop_hint": { "cs": "Vlož obrázek ze schránky nebo pořiď výřez", "en": "Paste image from clipboard or snip area" },
  "buffer_ref": { "cs": "BUFFER // REFERENCE", "en": "BUFFER // REFERENCE" },
  "paste": { "cs": "VLOŽIT", "en": "PASTE" },
  "snip": { "cs": "VÝŘEZ", "en": "SNIP" },
  "clear": { "cs": "SMAZAT", "en": "CLEAR" },
  "interrogate_wd14": { "cs": "TAGY WD14", "en": "INTERROGATE WD14" },
  "tagging": { "cs": "TAGUJI...", "en": "TAGGING..." },
  "vision_prompt": { "cs": "VISION PROMPT", "en": "VISION PROMPT" },
  "analyzing": { "cs": "ANALYZUJI...", "en": "ANALYZING..." },
  "denoise": { "cs": "DENOISE: ", "en": "DENOISE: " },

  // Canvas & Output
  "canvas_title": { "cs": "PLÁTNO & VÝSTUP", "en": "CANVAS & OUTPUT" },
  "generating_img": { "cs": "GENEROVÁNÍ OBRAZU NA LOKÁLNÍ GPU...", "en": "GENERATING IMAGE ON LOCAL GPU..." },
  "ready_to_synth": { "cs": "PŘIPRAVENO KE GENEROVÁNÍ", "en": "READY TO SYNTHESIZE" },
  "press_gen_hint": { "cs": "Stiskni GENERATE", "en": "Press GENERATE to synthesize" },
  "scale": { "cs": "MĚŘÍTKO:", "en": "SCALE:" },
  "set_wallpaper": { "cs": "JAKO TAPETU", "en": "SET AS WALLPAPER" },
  "compare_ab": { "cs": "SROVNAT A/B", "en": "COMPARE A/B" },
  "copy_clipboard": { "cs": "DO SCHRÁNKY", "en": "COPY CLIPBOARD" },
  "open_viewer": { "cs": "PROHLÍŽEČ", "en": "OPEN IN VIEWER" },

  // Bottom Bar
  "civitai_prompts": { "cs": "PROMPTY & INSPIRACE", "en": "PROMPTS & INSPIRATION" },
  "history": { "cs": "HISTORIE", "en": "HISTORY" },
  "reset": { "cs": "RESETOVAT", "en": "RESET" },
  "cancel": { "cs": "PŘERUŠIT", "en": "CANCEL" },
  "generate": { "cs": "GENEROVAT", "en": "GENERATE" },
  "generating": { "cs": "GENEROVÁNÍ...", "en": "GENERATING..." },
  "upscaling": { "cs": "ZVĚTŠOVÁNÍ (UPSCALE)...", "en": "UPSCALING..." },
  "enhancing": { "cs": "AI ZVĚTŠOVÁNÍ (2X)...", "en": "AI ENHANCING (2X)..." },
  "locked_game": { "cs": "ZAMČENO (BĚŽÍ HRA)", "en": "LOCKED (GAME RUNNING)" },
  "default_tip": {
    "cs": "Tip: Zadej prompt a zvol preset pro generování na lokální GPU",
    "en": "Tip: Enter prompt and choose preset to generate on local GPU"
  },

  // Contextual Hover Help
  "help_cancel": {
    "cs": "PŘERUŠIT: Okamžitě zastaví běžící generování v ComfyUI a uvolní GPU.",
    "en": "CANCEL: Instantly interrupts running ComfyUI diffusion process and frees GPU."
  },
  "help_prompt": {
    "cs": "PROMPT: Zadej popis scény v angličtině (automatický transparentní překlad na lokální GPU za 0 tokenů).",
    "en": "PROMPT: Enter scene description in English (automatic local translation on local GPU at 0 tokens)."
  },
  "help_negative": {
    "cs": "NEGATIVNÍ PROMPT: Prvky, styly a vady, které nechceš v obraze mít (např. deformace, text, vodoznaky).",
    "en": "NEGATIVE PROMPT: Elements, styles, and flaws to exclude from the image (e.g., deformed, text, watermarks)."
  },
  "help_ratio_21_9": { "cs": "21:9: Ultraširokoúhlý filmový poměr (1536×640 px).", "en": "21:9: Ultrawide cinematic aspect ratio (1536×640 px)." },
  "help_ratio_16_9": { "cs": "16:9: Širokoúhlý monitorový formát (1280×720 px).", "en": "16:9: Widescreen monitor format (1280×720 px)." },
  "help_ratio_16_10": { "cs": "16:10: Širokoúhlý formát pro monitory a notebooky (1280×800 px).", "en": "16:10: Widescreen PC & laptop display ratio (1280×800 px)." },
  "help_ratio_4_3": { "cs": "4:3: Klasický fotografický monitorový formát (1152×864 px).", "en": "4:3: Classic photo monitor format (1152×864 px)." },
  "help_ratio_1_1": { "cs": "1:1: Standardní čtvercový formát (1024×1024 px).", "en": "1:1: Standard square format (1024×1024 px)." },
  "help_ratio_3_4": { "cs": "3:4: Klasický vertikální portrétní formát (864×1152 px).", "en": "3:4: Classic vertical portrait format (864×1152 px)." },
  "help_ratio_9_16": { "cs": "9:16: Vertikální poměr stran pro mobilní obrazovky (720×1280 px).", "en": "9:16: Vertical mobile display ratio (720×1280 px)." },
  "help_res_draft": {
    "cs": "DRAFT: Bleskový náhledový koncept v rozlišení 512 px za zlomek sekundy.",
    "en": "DRAFT: Rapid preview draft at 512 px resolution in a fraction of a second."
  },
  "help_res_std": {
    "cs": "STD: Standardní plné difuzní rozlišení 1024 px pro čisté a ostré detaily.",
    "en": "STD: Standard full diffusion 1024 px resolution for crisp and sharp details."
  },
  "help_res_high": {
    "cs": "HIGH: Zvýšené rozlišení 1536 px pro maximální ostrost a detailní kresbu.",
    "en": "HIGH: Increased 1536 px resolution for maximum sharpness and fine rendering."
  },
  "help_res_ultra": {
    "cs": "ULTRA (2048): Špičkové rozlišení 2048 px pro GPU s 12+ GB VRAM.",
    "en": "ULTRA (2048): High-end 2048 px resolution for GPUs with 12+ GB VRAM."
  },
  "help_res_ultra_locked": {
    "cs": "ULTRA (2048): Uzamčeno pro ochranu VRAM (vyžaduje GPU s 12+ GB VRAM).",
    "en": "ULTRA (2048): Locked to protect VRAM (requires GPU with 12+ GB VRAM)."
  },
  "help_res_max": {
    "cs": "MAX (2560): Maximální 2.5K/4K rozlišení pro stanice s 20+ GB VRAM.",
    "en": "MAX (2560): Maximum 2.5K/4K resolution for workstations with 20+ GB VRAM."
  },
  "help_res_max_locked": {
    "cs": "MAX (2560): Uzamčeno pro ochranu VRAM (vyžaduje GPU s 20+ GB VRAM).",
    "en": "MAX (2560): Locked to protect VRAM (requires GPU with 20+ GB VRAM)."
  },
  "help_seed": {
    "cs": "SEED: Přepíná mezi náhodným generováním nového díla a fixací konkrétního seedu.",
    "en": "SEED: Toggles between random seed generation and locking a specific seed."
  },
  "help_steps": {
    "cs": "KROKY (STEPS): Počet difuzních vzorkovacích kroků (výchozí: 25). Vyšší hodnoty zjemňují detaily, nižší urychlují generování.",
    "en": "STEPS: Number of diffusion sampling steps (default: 25). Higher values refine detail, lower values speed up generation."
  },
  "help_steps_15": {
    "cs": "15 KROKŮ // Bleskový draft (~6s)",
    "en": "15 STEPS // Fast draft (~6s)"
  },
  "help_steps_25": {
    "cs": "25 KROKŮ // Standardní vyvážená kvalita (~18s)",
    "en": "25 STEPS // Standard balanced quality (~18s)"
  },
  "help_steps_35": {
    "cs": "35 KROKŮ // Maximální detaily a čisté kontury",
    "en": "35 STEPS // Maximum detail and crisp contours"
  },
  "help_ratio_auto_ref": {
    "cs": "AUTO // REF · Automaticky zachovat přesný poměr stran načteného referenčního obrázku bez ořezu.",
    "en": "AUTO // REF · Automatically preserve exact aspect ratio of loaded reference image without cropping."
  },
  "help_paste": {
    "cs": "PASTE: Vloží referenční obrázek ze systémové schránky (Wayland clipboard).",
    "en": "PASTE: Paste reference image from system clipboard (Wayland clipboard)."
  },
  "help_snip": {
    "cs": "SCREEN SNIP: Spustí interaktivní výřez libovolné části obrazovky jako referenční buffer.",
    "en": "SCREEN SNIP: Launches interactive screen snip tool to capture any screen area as reference buffer."
  },
  "help_clear": {
    "cs": "CLEAR: Odstraní aktuální referenční obrázek z bufferu a vyčistí náhled.",
    "en": "CLEAR: Remove current reference image from buffer and clear preview."
  },
  "help_interrogate": {
    "cs": "INTERROGATE WD14: Bleskově extrahuje Danbooru tagy z referenčního obrázku pomocí lokální sítě WD14 na lokální GPU.",
    "en": "INTERROGATE WD14: Blazingly extracts Danbooru tags from reference image via local WD14 network on local GPU."
  },
  "help_vision": {
    "cs": "VISION PROMPT: Zrekonstruuje a popíše scénu přirozeným jazykem pomocí multimodálního modelu Qwen-Vision na lokální GPU.",
    "en": "VISION PROMPT: Reconstructs and describes scene in natural language via local multimodal Qwen-Vision on local GPU."
  },
  "help_denoise": {
    "cs": "DENOISE: Míra přepracování referenčního obrázku (0.10 = jemná úprava, 0.65 = vyvážená změna, 0.95 = maximální transformace při zachování předlohy).",
    "en": "DENOISE: Modification strength of reference image (0.10 = subtle edit, 0.65 = balanced redesign, 0.95 = max transformation preserving reference)."
  },
  "help_scale_esrgan": {
    "cs": "4X ESRGAN: Neuronový 4X upscaling pomocí RealESRGAN_x4plus (silné potlačení šumu a artefaktů, nulová mřížka).",
    "en": "4X ESRGAN: Neural 4X upscaling via RealESRGAN_x4plus (strong noise and artifact suppression, zero grid pattern)."
  },
  "help_scale_ultra": {
    "cs": "4X ULTRA: Neuronový 4X upscaling pomocí 4x-UltraSharp (maximální mikroskopické textury a detaily).",
    "en": "4X ULTRA: Neural 4X upscaling via 4x-UltraSharp (maximum micro-textures and fine detail preservation)."
  },
  "help_scale_anime": {
    "cs": "4X ANIME: Neuronový 4X upscaling pomocí 4x-AnimeSharp (dokonalé vyhlazení a ostré kontury pro ilustrace).",
    "en": "4X ANIME: Neural 4X upscaling via 4x-AnimeSharp (perfect smoothing and crisp contours for illustrations)."
  },
  "help_scale_half": {
    "cs": "0.5X: Zmenší rozlišení vygenerovaného díla na polovinu.",
    "en": "0.5X: Reduces resolution of generated artwork by half."
  },
  "help_scale_fit1k": {
    "cs": "FIT 1K: Přepočítá rozměry obrázku na difuzní standard ~1 megapixel se zarovnáním na 8 px.",
    "en": "FIT 1K: Rescales image dimensions to ~1 megapixel diffusion standard aligned to 8 px."
  },
  "help_set_wallpaper": {
    "cs": "SET AS WALLPAPER: Okamžitě nastaví vygenerovaný obraz jako novou tapetu Hyprland plochy.",
    "en": "SET AS WALLPAPER: Instantly sets generated image as active Hyprland desktop wallpaper."
  },
  "help_compare_ab": {
    "cs": "COMPARE A/B: Otevře interaktivní posuvník pro porovnání původní předlohy a nového díla.",
    "en": "COMPARE A/B: Opens interactive split-screen slider comparing before and after generations."
  },
  "help_copy_clipboard": {
    "cs": "COPY CLIPBOARD: Zkopíruje vygenerovaný obrázek do systémové schránky k okamžitému vložení.",
    "en": "COPY CLIPBOARD: Copies generated PNG image directly to clipboard for instant pasting."
  },
  "help_open_viewer": {
    "cs": "OPEN IN VIEWER: Otevře výsledné dílo v systémovém prohlížeči obrázků v plném rozlišení.",
    "en": "OPEN IN VIEWER: Opens generated image at full resolution in default image viewer Loupe."
  },
  "help_civitai_prompts": {
    "cs": "PROMPTY: Procházení a vyhledávání tisíců promptů z CivitAI, Lexica, PromptHero, OpenArt a Hugging Face.",
    "en": "PROMPTS: Browse and search thousands of prompts from CivitAI, Lexica, PromptHero, OpenArt, and Hugging Face."
  },
  "help_turbo_lora": {
    "cs": "TURBO (5s): VAROVÁNÍ // Při lidských tělech a anatomii doporučujeme TURBO vypnout.",
    "en": "TURBO (5s): WARNING // For human bodies and anatomy, turning TURBO off is recommended."
  },
  "help_anime_lora": {
    "cs": "ANIME LORA: Třístavový adaptér stylu (OFF = fotorealismus, SOFT = jemná ilustrace 0.40, FULL = 2D anime cel-shading 0.65).",
    "en": "ANIME LORA: Tri-state style adapter (OFF = photorealism, SOFT = subtle illustration 0.40, FULL = 2D anime cel-shading 0.65)."
  },
  "help_uncensored_lora": {
    "cs": "HERETIC LORA: Třístavový necenzurovaný adaptér (OFF = výchozí filtry, SOFT = uvolněné oděvy a dekolt 0.35, FULL = plně necenzurovaný latent 0.50).",
    "en": "HERETIC LORA: Tri-state uncensored adapter (OFF = default filters, SOFT = relaxed clothing 0.35, FULL = fully uncensored latent 0.50)."
  },
  "help_anatomy_lora": {
    "cs": "ANATOMY LORA: Třístavová anatomická fidelita (OFF = výchozí, SOFT = přirozené tělo 0.35 bez mutace okolí, FULL = plný explicitní akt 0.60).",
    "en": "ANATOMY LORA: Tri-state body anatomy fidelity (OFF = default, SOFT = natural body proportions 0.35 without environment warping, FULL = explicit nude anatomy 0.60)."
  },
  "help_history": {
    "cs": "HISTORY: Otevře archiv dříve vygenerovaných děl v ~/Pictures/Qwen-Image/ s obnovením parametrů.",
    "en": "HISTORY: Displays archive of previously generated artworks in ~/Pictures/Qwen-Image with parameter restore."
  },
  "help_reset": {
    "cs": "RESET: Vyčistí všechna pole a vrátí studio do výchozího stavu.",
    "en": "RESET: Clears all text fields and resets studio to default values."
  },
  "help_reference_pick": {
    "cs": "REFERENČNÍ PŘEDLOHA: Kliknutím levým tlačítkem myši vyberete obrázek z ~/Pictures (pravým tlačítkem vložíte ze schránky).",
    "en": "REFERENCE IMAGE: Left-click to select image from ~/Pictures (right-click to paste from clipboard)."
  },
  "help_canvas_fullscreen": {
    "cs": "CANVAS BUFFER: Kliknutím levým tlačítkem myši otevřete vygenerovaný obrázek na celou obrazovku.",
    "en": "CANVAS BUFFER: Left-click to view generated image in fullscreen."
  },
  "help_lang": {
    "cs": "PŘEPÍNAČ JAZYKA: Přepíná rozhraní a nápovědu mezi češtinou (CZ) a angličtinou (EN).",
    "en": "LANGUAGE SWITCHER: Toggles interface and help text between English (EN) and Czech (CZ)."
  },
  "help_generate": {
    "cs": "GENERATE: Spustí generování obrazu na lokální GPU za 0 tokenů.",
    "en": "GENERATE: Starts image generation on local GPU at 0 tokens."
  }
};

function tr(key) {
  var lang = "en";
  if (strings[key] && strings[key][lang]) {
    return strings[key][lang];
  }
  return key;
}
