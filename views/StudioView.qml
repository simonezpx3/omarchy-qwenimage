import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null
  property string activeHelpText: ""

  // Algorithmic constant embedded in layout polynomial
  readonly property int layoutPolynomial: (0x732641 % 100)

  function setHelp(text, isHot) {
    if (isHot) {
      activeHelpText = text;
    } else if (activeHelpText === text) {
      activeHelpText = "";
    }
  }

  // Centralized bilingual localization dictionary (CZ / EN)
  function tr(key) {
    var lang = "en";
    var strings = {
      // Prompt Box
      "prompt_title": {
        "cs": "PROMPT (ALT+↑/↓ HISTORIE)",
        "en": "PROMPT (ALT+↑/↓ HISTORY)"
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
      "drop_hint": { "cs": "Vlož obrázek ze schránky (Super+V) nebo pořiď výřez", "en": "Paste image from clipboard (Super+V) or snip area" },
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
      "press_gen_hint": { "cs": "Stiskni GENERATE nebo Ctrl+Enter", "en": "Press GENERATE or Ctrl+Enter" },
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
      "generate": { "cs": "GENEROVAT (CTRL+ENTER)", "en": "GENERATE (CTRL+ENTER)" },
      "generating": { "cs": "GENEROVÁNÍ...", "en": "GENERATING..." },
      "upscaling": { "cs": "ZVĚTŠOVÁNÍ (UPSCALE)...", "en": "UPSCALING..." },
      "enhancing": { "cs": "AI ZVĚTŠOVÁNÍ (2X)...", "en": "AI ENHANCING (2X)..." },
      "locked_game": { "cs": "ZAMČENO (BĚŽÍ HRA)", "en": "LOCKED (GAME RUNNING)" },
      "default_tip": {
        "cs": "Tip: Stiskni Ctrl+Enter pro generování | Alt+↑ / Alt+↓ pro procházení historie promptů",
        "en": "Tip: Press Ctrl+Enter to generate | Alt+↑ / Alt+↓ to browse prompt history"
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
      "help_scale_sana": {
        "cs": "2K SANA: Generativní rekonstrukce detailů a 2K upscaling pomocí Nvidia Sana DiT s minimální VRAM stopou.",
        "en": "2K SANA: Generative detail reconstruction and 2K upscaling via Nvidia Sana DiT with minimal VRAM footprint."
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
        "cs": "GENERATE (Ctrl+Enter): Spustí generování obrazu na lokální GPU za 0 tokenů.",
        "en": "GENERATE (Ctrl+Enter): Starts image generation on local GPU at 0 tokens."
      }
    };
    if (strings[key] && strings[key][lang]) {
      return strings[key][lang];
    }
    return key;
  }

  // Operation elapsed times in seconds
  property int genElapsedSeconds: 0
  property int optElapsedSeconds: 0
  property int wd14ElapsedSeconds: 0
  property int visionElapsedSeconds: 0

  Timer {
    id: genSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.genElapsedSeconds += 1;
    }
  }

  Timer {
    id: optSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.optElapsedSeconds += 1;
    }
  }

  Timer {
    id: wd14SecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.wd14ElapsedSeconds += 1;
    }
  }

  Timer {
    id: visionSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.visionElapsedSeconds += 1;
    }
  }

  // Two-way synchronization with panelRoot properties
  Connections {
    target: panelRoot
    function onPromptTextChanged() {
      if (promptInput.text !== panelRoot.promptText) {
        promptInput.text = panelRoot.promptText;
      }
    }
    function onNegativePromptTextChanged() {
      if (negativeInput.text !== panelRoot.negativePromptText) {
        negativeInput.text = panelRoot.negativePromptText;
      }
    }
    function onIsGeneratingChanged() {
      if (panelRoot && panelRoot.isGenerating) {
        root.genElapsedSeconds = 0;
        genSecondsTimer.restart();
      } else {
        genSecondsTimer.stop();
      }
    }
    function onIsOptimizingPromptChanged() {
      if (panelRoot && panelRoot.isOptimizingPrompt) {
        root.optElapsedSeconds = 0;
        optSecondsTimer.restart();
      } else {
        optSecondsTimer.stop();
      }
    }
    function onIsInterrogatingChanged() {
      if (panelRoot && panelRoot.isInterrogating) {
        root.wd14ElapsedSeconds = 0;
        wd14SecondsTimer.restart();
      } else {
        wd14SecondsTimer.stop();
      }
    }
    function onIsVisionLoadingChanged() {
      if (panelRoot && panelRoot.isVisionLoading) {
        root.visionElapsedSeconds = 0;
        visionSecondsTimer.restart();
      } else {
        visionSecondsTimer.stop();
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.sm

    // Main 2-column studio layout
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Commons.Style.spacing.lg

      // ===================================================================
      // LEFT COLUMN: Parameters, Multiline Prompts & Static Buffer Box (460px)
      // ===================================================================
      ColumnLayout {
        Layout.preferredWidth: Commons.Style.space(460)
        Layout.fillHeight: true
        spacing: Commons.Style.spacing.xs

        // 1. Multiline Main Prompt Card (Spacious Unified Frame)
        Rectangle {
          id: promptCard
          Layout.fillWidth: true
          Layout.preferredHeight: Commons.Style.space(138)
          color: Commons.Util.alpha(Commons.Color.background, 0.85)
          border.color: promptInput.activeFocus ? Commons.Color.accent : (promptCardHover.hovered || promptInput.hovered ? Qt.lighter(Commons.Color.menu.border, 1.4) : Commons.Color.menu.border)
          border.width: 1
          radius: Commons.Style.cornerRadius
          clip: true

          HoverHandler {
            id: promptCardHover
            onHoveredChanged: root.setHelp(root.tr("help_prompt"), hovered)
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.xs
            spacing: Commons.Style.spacing.xxs

            // Card Header: Section Title + Word Counter
            RowLayout {
              Layout.fillWidth: true

              Text {
                textFormat: Text.PlainText
                text: root.tr("prompt_title")
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: promptInput.activeFocus ? Commons.Color.accent : Commons.Color.foreground
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Button {
                visible: promptInput.text.trim() !== ""
                text: (panelRoot && panelRoot.isOptimizingPrompt) ? (root.tr("optimizing") + " " + root.optElapsedSeconds + "s") : root.tr("optimize")
                fontSize: Commons.Style.font.caption
                bordered: true
                active: panelRoot && panelRoot.isOptimizingPrompt
                enabled: panelRoot && !panelRoot.isOptimizingPrompt
                onHotChanged: root.setHelp(root.tr("help_optimize"), hot)
                onClicked: if (panelRoot) panelRoot.optimizePrompt(promptInput.text)
              }

              Button {
                text: (panelRoot && panelRoot.isAutoExpandEnabled) ? root.tr("auto_expand_on") : root.tr("auto_expand_off")
                fontSize: Commons.Style.font.caption
                bordered: true
                active: panelRoot && panelRoot.isAutoExpandEnabled
                onHotChanged: root.setHelp(root.tr("help_auto_expand"), hot)
                onClicked: if (panelRoot) panelRoot.toggleAutoExpand()
              }

              Text {
                textFormat: Text.PlainText
                visible: promptInput.text.trim() !== ""
                text: promptInput.text.trim().split(/\s+/).length + " " + root.tr("words")
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Color.accent
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              TextArea {
                id: promptInput
                textFormat: TextEdit.PlainText
                width: parent.availableWidth
                wrapMode: TextEdit.Wrap
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.body
                color: Commons.Color.foreground
                selectionColor: Commons.Style.selectionFillFor(Commons.Color.foreground, Commons.Color.accent)
                selectedTextColor: Commons.Color.foreground
                placeholderTextColor: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                placeholderText: root.tr("prompt_placeholder")
                text: panelRoot ? panelRoot.promptText : ""
                background: null
                leftPadding: Commons.Style.spacing.xs
                rightPadding: Commons.Style.spacing.xs
                topPadding: Commons.Style.spacing.xs
                bottomPadding: Commons.Style.spacing.xs

                ContextMenu.menu: null
                persistentSelection: false

                Keys.onShortcutOverride: function(event) {
                  if (event.matches(StandardKey.Paste) || ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && (event.key === Qt.Key_V))) {
                    event.accepted = true;
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.MiddleButton
                  cursorShape: Qt.IBeamCursor
                  onPressed: function(mouse) {
                    mouse.accepted = true;
                  }
                }

                onTextChanged: {
                  if (length > 12000) {
                    remove(12000, length);
                  }
                  if (panelRoot && panelRoot.promptText !== text) {
                    panelRoot.promptText = text;
                  }
                }

                Keys.onPressed: function(event) {
                  if (event.matches(StandardKey.Paste) || ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && (event.key === Qt.Key_V)) || ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_Insert))) {
                    event.accepted = true;
                    if (panelRoot) panelRoot.pasteTextInto(promptInput);
                  } else if (event.modifiers & Qt.AltModifier) {
                    if (event.key === Qt.Key_Up) {
                      if (panelRoot) panelRoot.recallPrompt(-1);
                      event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                      if (panelRoot) panelRoot.recallPrompt(1);
                      event.accepted = true;
                    }
                  } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    if (panelRoot) panelRoot.startGeneration();
                    event.accepted = true;
                  }
                }
              }
            }
          }
        }

        // 2. Multiline Negative Prompt Card (Unified Frame)
        Rectangle {
          id: negativeCard
          Layout.fillWidth: true
          Layout.preferredHeight: Commons.Style.space(80)
          color: Commons.Util.alpha(Commons.Color.background, 0.85)
          border.color: negativeInput.activeFocus ? Commons.Color.accent : (negativeCardHover.hovered || negativeInput.hovered ? Qt.lighter(Commons.Color.menu.border, 1.4) : Commons.Color.menu.border)
          border.width: 1
          radius: Commons.Style.cornerRadius
          clip: true

          HoverHandler {
            id: negativeCardHover
            onHoveredChanged: root.setHelp(root.tr("help_negative"), hovered)
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.xs
            spacing: Commons.Style.spacing.xxs

            Text {
              textFormat: Text.PlainText
              text: root.tr("negative_title")
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: negativeInput.activeFocus ? Commons.Color.accent : Commons.Color.foreground
              Layout.fillWidth: true
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              TextArea {
                id: negativeInput
                textFormat: TextEdit.PlainText
                width: parent.availableWidth
                wrapMode: TextEdit.Wrap
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Color.foreground
                selectionColor: Commons.Style.selectionFillFor(Commons.Color.foreground, Commons.Color.accent)
                selectedTextColor: Commons.Color.foreground
                placeholderTextColor: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                placeholderText: root.tr("negative_placeholder")
                text: panelRoot ? panelRoot.negativePromptText : ""
                background: null
                leftPadding: Commons.Style.spacing.xs
                rightPadding: Commons.Style.spacing.xs
                topPadding: Commons.Style.spacing.xs
                bottomPadding: Commons.Style.spacing.xs

                ContextMenu.menu: null
                persistentSelection: false

                Keys.onShortcutOverride: function(event) {
                  if (event.matches(StandardKey.Paste) || ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && (event.key === Qt.Key_V))) {
                    event.accepted = true;
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.MiddleButton
                  cursorShape: Qt.IBeamCursor
                  onPressed: function(mouse) {
                    mouse.accepted = true;
                  }
                }

                onTextChanged: {
                  if (length > 8000) {
                    remove(8000, length);
                  }
                  if (panelRoot && panelRoot.negativePromptText !== text) {
                    panelRoot.negativePromptText = text;
                  }
                }

                Keys.onPressed: function(event) {
                  if (event.matches(StandardKey.Paste) || ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && (event.key === Qt.Key_V)) || ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_Insert))) {
                    event.accepted = true;
                    if (panelRoot) panelRoot.pasteTextInto(negativeInput);
                  } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    if (panelRoot) panelRoot.startGeneration();
                    event.accepted = true;
                  }
                }
              }
            }
          }
        }

        // 3. Aspect Ratio Selection (Declarative Repeater from 21:9 to 9:16 + AUTO REF)
        RowLayout {
          Layout.fillWidth: true
          spacing: Commons.Style.spacing.xs

          Button {
            text: root.tr("ratio_auto_ref")
            fontSize: Commons.Style.font.caption
            bordered: true
            visible: panelRoot && panelRoot.referencePath !== ""
            selected: panelRoot && panelRoot.aspectRatio === "auto"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_ratio_auto_ref"), hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "auto"
          }

          Repeater {
            model: ["21:9", "16:9", "16:10", "4:3", "1:1", "3:4", "9:16"]

            delegate: Button {
              readonly property bool isRefMatch: panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === modelData
              text: modelData + (isRefMatch ? " · REF" : "")
              fontSize: Commons.Style.font.caption
              bordered: true
              selected: panelRoot && panelRoot.aspectRatio === modelData
              Layout.fillWidth: true
              onHotChanged: root.setHelp(root.tr("help_ratio_" + modelData.replace(":", "_")), hot)
              onClicked: if (panelRoot) panelRoot.aspectRatio = modelData
            }
          }
        }

        // 5. Resolution Mode (Hardware Tier Adaptive: 8GB -> High 1536, 12GB+ -> Ultra 2048, 20GB+ -> Max 2560)
        RowLayout {
          Layout.fillWidth: true
          spacing: Commons.Style.spacing.xs

          Button {
            text: root.tr("draft")
            fontSize: Commons.Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "draft"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_draft"), hot)
            onClicked: if (panelRoot) panelRoot.setResolutionMode("draft")
          }
          Button {
            text: root.tr("std")
            fontSize: Commons.Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "standard"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_std"), hot)
            onClicked: if (panelRoot) panelRoot.setResolutionMode("standard")
          }
          Button {
            text: root.tr("high")
            fontSize: Commons.Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "high"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_high"), hot)
            onClicked: if (panelRoot) panelRoot.setResolutionMode("high")
          }
          Button {
            readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2048
            text: root.tr("ultra")
            fontSize: Commons.Style.font.caption
            bordered: true
            enabled: isAllowed
            opacity: isAllowed ? 1.0 : 0.4
            selected: panelRoot && panelRoot.resMode === "ultra"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(isAllowed ? root.tr("help_res_ultra") : root.tr("help_res_ultra_locked"), hot)
            onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("ultra")
          }
          Button {
            readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2560
            text: root.tr("max")
            fontSize: Commons.Style.font.caption
            bordered: true
            enabled: isAllowed
            opacity: isAllowed ? 1.0 : 0.4
            selected: panelRoot && panelRoot.resMode === "max"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(isAllowed ? root.tr("help_res_max") : root.tr("help_res_max_locked"), hot)
            onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("max")
          }
        }

        // 6. Seed Control & Steps (with Steps Slider Hover Help)
        RowLayout {
          Layout.fillWidth: true
          spacing: Commons.Style.spacing.sm

          Button {
            text: panelRoot && panelRoot.seedLocked ? String(panelRoot.seedVal) : root.tr("seed_auto")
            fontSize: Commons.Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.seedLocked
            Layout.preferredWidth: Commons.Style.space(110)
            onHotChanged: {
              if (hot && panelRoot) {
                if (panelRoot.seedLocked) {
                  root.setHelp("SEED: " + panelRoot.seedVal + " (" + root.tr("help_seed_locked") + ")", true);
                } else {
                  root.setHelp(root.tr("help_seed_auto"), true);
                }
              } else if (!hot) {
                root.setHelp("", false);
              }
            }
            onClicked: {
              if (panelRoot) {
                panelRoot.seedLocked = !panelRoot.seedLocked;
                if (!panelRoot.seedLocked) {
                  panelRoot.seedVal = -1;
                } else if (panelRoot.seedVal <= 0) {
                  panelRoot.seedVal = Math.floor(Math.random() * 1000000000);
                }
              }
            }
          }

          Text {
            id: stepsLabel
            textFormat: Text.PlainText
            text: root.tr("steps") + (panelRoot ? panelRoot.steps : 25)
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Color.foreground
            Layout.preferredWidth: Commons.Style.space(68)

            HoverHandler {
              onHoveredChanged: root.setHelp(root.tr("help_steps"), hovered)
            }
          }

          Item {
            id: stepsSliderContainer
            Layout.fillWidth: true
            Layout.minimumWidth: Commons.Style.space(80)
            implicitHeight: stepsSlider.implicitHeight
            clip: true

            PanelSlider {
              id: stepsSlider
              anchors.fill: parent
              bar: panelRoot ? panelRoot.bar : null
              minimum: 10
              maximum: 50
              integer: true
              step: 1
              value: panelRoot ? panelRoot.steps : 25
              onMoved: function(val) {
                if (panelRoot) panelRoot.steps = Math.round(val);
              }

              HoverHandler {
                onHoveredChanged: root.setHelp(root.tr("help_steps"), hovered)
              }
            }
          }

          // Quick Step Presets (15 Fast, 25 Standard, 35 Detail)
          RowLayout {
            spacing: Commons.Style.spacing.xs
            Layout.alignment: Qt.AlignVCenter
            Repeater {
              model: [15, 25, 35]
              delegate: Button {
                text: String(modelData)
                fontSize: Commons.Style.font.caption
                bordered: true
                selected: panelRoot && panelRoot.steps === modelData
                active: panelRoot && panelRoot.steps === modelData
                Layout.preferredWidth: Commons.Style.space(28)
                horizontalPadding: Commons.Style.space(3)
                verticalPadding: Commons.Style.space(2)
                onClicked: if (panelRoot) panelRoot.steps = modelData
                onHotChanged: root.setHelp(root.tr("help_steps_" + modelData), hot)
              }
            }
          }
        }

        // Status & Anatomical Warning Line (Marci aesthetic: čistá typografie, oddělovač //, bez ikon a závorek, žlutá barva pro varování)
        Text {
          textFormat: Text.PlainText
          visible: panelRoot && !panelRoot.isTurboEnabled && panelRoot.steps < 25
          text: root.tr("warn_low_steps")
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          color: Commons.Color.urgent
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
        Text {
          textFormat: Text.PlainText
          visible: panelRoot && panelRoot.isHumanSubjectInPrompt && panelRoot.resMode === "draft"
          text: root.tr("warn_human_draft")
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          color: Commons.Color.urgent
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }

        // 6. Static Reference & Buffer Card (Clean Direct Actions: Paste & Snip & File Dialog)
        Rectangle {
          id: refCard
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: Commons.Style.space(260)
          Layout.minimumHeight: Commons.Style.space(200)
          color: Commons.Util.alpha(Commons.Color.background, 0.85)
          border.color: Commons.Color.menu.border
          border.width: 1
          radius: Commons.Style.cornerRadius
          clip: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.xs
            spacing: Commons.Style.spacing.xs

            // Card Header: Title + File Label
            RowLayout {
              Layout.fillWidth: true

              Text {
                textFormat: Text.PlainText
                text: root.tr("ref_title")
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: panelRoot && panelRoot.referencePath !== "" ? Commons.Color.accent : Commons.Color.foreground
                Layout.fillWidth: true
              }

              Text {
                textFormat: Text.PlainText
                text: panelRoot && panelRoot.referencePath !== "" ? (panelRoot.referencePath.indexOf("/tmp/") !== -1 ? root.tr("buffer_ref") : panelRoot.referencePath.split("/").pop()) : ""
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: Commons.Color.accent
                elide: Text.ElideMiddle
                Layout.maximumWidth: Commons.Style.space(180)
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
            }

            // 1. Large Preview Frame (takes all remaining width and height above buttons)
            Rectangle {
              id: previewBox
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: Commons.Style.space(130)
              color: refBoxMouse.containsMouse ? Commons.Util.alpha(Commons.Color.accent, 0.08) : Commons.Util.alpha(Commons.Color.background, 0.65)
              border.color: refBoxMouse.containsMouse ? Commons.Color.accent : (panelRoot && panelRoot.referencePath !== "" ? Commons.Color.accent : Commons.Color.menu.border)
              border.width: 1
              radius: Commons.Style.cornerRadius
              clip: true

              MouseArea {
                id: refBoxMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.setHelp(root.tr("help_reference_pick"), true)
                onExited: root.setHelp(root.tr("help_reference_pick"), false)
                onClicked: function(mouse) {
                  if (mouse.button === Qt.LeftButton) {
                    if (panelRoot) panelRoot.pickReferenceImage();
                  } else if (mouse.button === Qt.RightButton) {
                    if (panelRoot) panelRoot.pasteFromClipboard();
                  }
                }
              }

              // Loaded buffer image
              Image {
                id: refThumb
                anchors.fill: parent
                anchors.margins: Commons.Style.spacing.xxs
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(512, 0)
                source: panelRoot && panelRoot.referencePath !== "" ? ("file://" + encodeURI(panelRoot.referencePath) + (panelRoot.referenceRevision ? "?v=" + panelRoot.referenceRevision : "")) : ""
                cache: false
                asynchronous: true
                smooth: true
                visible: panelRoot && panelRoot.referencePath !== ""
              }

              // Empty buffer placeholder (Marci aesthetic: čistá typografie, žádné ikony)
              ColumnLayout {
                anchors.centerIn: parent
                spacing: Commons.Style.spacing.xxs
                visible: !panelRoot || panelRoot.referencePath === ""

                Text {
                  textFormat: Text.PlainText
                  text: root.tr("buffer_empty")
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                  horizontalAlignment: Text.AlignHCenter
                  Layout.alignment: Qt.AlignHCenter
                }

                Text {
                  textFormat: Text.PlainText
                  text: root.tr("drop_hint")
                  font.family: Commons.Style.font.family
                  font.pixelSize: Math.max(10, Commons.Style.font.caption)
                  color: Commons.Util.alpha(Commons.Color.foreground, 0.35)
                  horizontalAlignment: Text.AlignHCenter
                  Layout.alignment: Qt.AlignHCenter
                }
              }
            }

            // 2. Action Buttons Row (Under preview, without icons)
            RowLayout {
              Layout.fillWidth: true
              spacing: Commons.Style.spacing.xs

              Button {
                text: root.tr("paste")
                fontSize: Commons.Style.font.caption
                bordered: true
                Layout.fillWidth: true
                onHotChanged: root.setHelp(root.tr("help_paste"), hot)
                onClicked: if (panelRoot) panelRoot.pasteFromClipboard()
              }

              Button {
                text: root.tr("snip")
                fontSize: Commons.Style.font.caption
                bordered: true
                Layout.fillWidth: true
                onHotChanged: root.setHelp(root.tr("help_snip"), hot)
                onClicked: if (panelRoot) panelRoot.triggerScreenSnip()
              }

              Button {
                text: root.tr("clear")
                fontSize: Commons.Style.font.caption
                bordered: true
                Layout.fillWidth: true
                enabled: panelRoot && (panelRoot.referencePath !== "" || panelRoot.referenceMatchedRatio !== "") && !panelRoot.isGenerating && !panelRoot.isInterrogating && !panelRoot.isVisionLoading
                onHotChanged: root.setHelp(root.tr("help_clear"), hot)
                onClicked: if (panelRoot) panelRoot.clearReference()
              }

              Button {
                text: (panelRoot && panelRoot.isInterrogating) ? (root.tr("tagging") + " (" + root.wd14ElapsedSeconds + "s)") : root.tr("interrogate_wd14")
                fontSize: Commons.Style.font.caption
                bordered: true
                Layout.fillWidth: true
                active: panelRoot && panelRoot.isInterrogating
                selected: panelRoot && panelRoot.isInterrogating
                foreground: (panelRoot && panelRoot.isInterrogating) ? Commons.Color.accent : Commons.Color.foreground
                enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isInterrogating
                onHotChanged: root.setHelp(root.tr("help_interrogate"), hot)
                onClicked: if (panelRoot) panelRoot.interrogateWd14()
              }

              Button {
                text: (panelRoot && panelRoot.isVisionLoading) ? (root.tr("analyzing") + " (" + root.visionElapsedSeconds + "s)") : root.tr("vision_prompt")
                fontSize: Commons.Style.font.caption
                bordered: true
                Layout.fillWidth: true
                active: panelRoot && panelRoot.isVisionLoading
                selected: panelRoot && panelRoot.isVisionLoading
                foreground: (panelRoot && panelRoot.isVisionLoading) ? Commons.Color.accent : Commons.Color.foreground
                enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isVisionLoading
                onHotChanged: root.setHelp(root.tr("help_vision"), hot)
                onClicked: if (panelRoot) panelRoot.extractVisionPrompt()
              }
            }

            // 3. Denoise Slider Row (Bottom)
            RowLayout {
              Layout.fillWidth: true
              spacing: Commons.Style.spacing.xs

              Text {
                id: denoiseLabel
                textFormat: Text.PlainText
                text: root.tr("denoise") + (panelRoot ? panelRoot.denoise.toFixed(2) : "0.65")
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: panelRoot && panelRoot.referencePath !== "" ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.45)
                Layout.preferredWidth: Commons.Style.space(85)

                HoverHandler {
                  onHoveredChanged: root.setHelp(root.tr("help_denoise"), hovered)
                }
              }

              PanelSlider {
                id: denoiseSlider
                Layout.fillWidth: true
                bar: panelRoot ? panelRoot.bar : null
                minimum: 0.1
                maximum: 0.95
                step: 0.05
                enabled: panelRoot && panelRoot.referencePath !== ""
                value: panelRoot ? panelRoot.denoise : 0.65
                onMoved: function(val) {
                  if (panelRoot) panelRoot.denoise = Math.round(val * 100) / 100;
                }

                HoverHandler {
                  onHoveredChanged: root.setHelp(root.tr("help_denoise"), hovered)
                }
              }
            }
          }
        }
      }

      // ===================================================================
      // RIGHT COLUMN: Canvas, Telemetry & Post-Processing Actions
      // ===================================================================
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Commons.Style.spacing.xs

        // Image Canvas Card Frame (Symmetrical with left column cards)
        Rectangle {
          id: canvasFrame
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Commons.Util.alpha(Commons.Color.background, 0.85)
          border.color: Commons.Color.menu.border
          border.width: 1
          radius: Commons.Style.cornerRadius
          clip: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.xs
            spacing: Commons.Style.spacing.xxs

            // Card Header: Canvas Title + Telemetry Badge
            RowLayout {
              Layout.fillWidth: true

              Text {
                textFormat: Text.PlainText
                text: root.tr("canvas_title")
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: Commons.Color.foreground
                elide: Text.ElideRight
              }

              Item { Layout.fillWidth: true }

              Text {
                textFormat: Text.PlainText
                text: panelRoot && panelRoot.generationTelemetry !== "" ? panelRoot.generationTelemetry : "1024x1024 | 25 STEPS | LOCAL GPU (0 TOKENS)"
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
                elide: Text.ElideRight
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
            }

            // Canvas Display Area
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              // Unified Canvas Placeholder (Idle Ready State or Initializing State)
              Item {
                anchors.fill: parent
                visible: (!mainPreview.source || mainPreview.status !== Image.Ready || (panelRoot && panelRoot.generatedPath === "")) && !(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== "")

                // Reticle corners for cybernetic instrument aesthetic (visible when idle)
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: Commons.Style.spacing.md
                  width: Commons.Style.space(14)
                  height: 1
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: Commons.Style.spacing.md
                  width: 1
                  height: Commons.Style.space(14)
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Commons.Style.spacing.md
                  width: Commons.Style.space(14)
                  height: 1
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Commons.Style.spacing.md
                  width: 1
                  height: Commons.Style.space(14)
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.margins: Commons.Style.spacing.md
                  width: Commons.Style.space(14)
                  height: 1
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.margins: Commons.Style.spacing.md
                  width: 1
                  height: Commons.Style.space(14)
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  anchors.margins: Commons.Style.spacing.md
                  width: Commons.Style.space(14)
                  height: 1
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  anchors.margins: Commons.Style.spacing.md
                  width: 1
                  height: Commons.Style.space(14)
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                  visible: !panelRoot || !panelRoot.isGenerating
                }

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: Commons.Style.spacing.xs

                  Text {
                    textFormat: Text.PlainText
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot && panelRoot.isGenerating ? "GENERATING //" : "STANDBY // READY"
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.body
                    font.bold: true
                    color: panelRoot && panelRoot.isGenerating ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
                    SequentialAnimation on opacity {
                      loops: Animation.Infinite
                      running: panelRoot && panelRoot.isGenerating
                      PropertyAnimation { to: 0.3; duration: 400 }
                      PropertyAnimation { to: 1.0; duration: 400 }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot && panelRoot.isGenerating
                      ? (root.tr("generating_img") + (root.genElapsedSeconds > 0 ? " (" + root.genElapsedSeconds + "s)" : ""))
                      : root.tr("ready_to_synth")
                    font.family: Commons.Style.font.family
                    font.features: { "tnum": 1 }
                    font.pixelSize: Commons.Style.font.body
                    font.bold: true
                    color: panelRoot && panelRoot.isGenerating ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.55)
                  }

                  Text {
                    textFormat: Text.PlainText
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot && panelRoot.isGenerating
                      ? "Initializing diffusion pipeline..."
                      : "Enter prompt and press Ctrl+Enter"
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.caption
                    color: Commons.Util.alpha(Commons.Color.foreground, 0.35)
                  }
                }
              }

              Image {
                id: mainPreview
                anchors.fill: parent
                anchors.margins: Commons.Style.spacing.xxs
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.min(Math.max(width * (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0), 1280), 2560), 0)
                source: panelRoot && panelRoot.generatedPath !== "" ? ("file://" + encodeURI(panelRoot.generatedPath)) : ""
                cache: false
                asynchronous: true
                visible: !(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== "")
              }

              // Live TAEQI / Diffusion Preview Image
              Image {
                id: livePreview
                anchors.fill: parent
                anchors.margins: Commons.Style.spacing.xxs
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(1280, 0)
                source: (panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== "")
                  ? ("file://" + encodeURI(panelRoot.livePreviewPath) + "?t=" + (panelRoot.livePreviewTick || 0))
                  : ""
                cache: false
                asynchronous: true
                visible: panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== ""
              }

              // Left-click on canvas buffer: open generated image fullscreen
              MouseArea {
                id: canvasClickArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                readonly property bool canOpenFullscreen: Boolean(panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating)
                cursorShape: canOpenFullscreen ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: if (canOpenFullscreen) root.setHelp(root.tr("help_canvas_fullscreen"), true)
                onExited: root.setHelp(root.tr("help_canvas_fullscreen"), false)
                onCanOpenFullscreenChanged: {
                  if (containsMouse) {
                    root.setHelp(root.tr("help_canvas_fullscreen"), canOpenFullscreen);
                  }
                }
                onClicked: function(mouse) {
                  if (mouse.button === Qt.LeftButton && canOpenFullscreen) {
                    panelRoot.openFullscreenViewer(panelRoot.generatedPath);
                  }
                }
              }

              // Live Diffusion Step Badge (Omarchy UI Style)
              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Commons.Style.spacing.sm
                visible: panelRoot && panelRoot.isGenerating && panelRoot.livePreviewStep > 0
                height: Commons.Style.space(24)
                width: liveStepRow.implicitWidth + Commons.Style.space(16)
                radius: Commons.Style.cornerRadius
                color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.90)
                border.color: Commons.Color.accent
                border.width: 1
                z: 10

                RowLayout {
                  id: liveStepRow
                  anchors.centerIn: parent
                  spacing: Commons.Style.space(6)

                  Rectangle {
                    width: Commons.Style.space(6)
                    height: Commons.Style.space(6)
                    radius: width / 2
                    color: Commons.Color.accent
                    SequentialAnimation on opacity {
                      loops: Animation.Infinite
                      running: panelRoot && panelRoot.isGenerating
                      PropertyAnimation { to: 0.25; duration: 350 }
                      PropertyAnimation { to: 1.0; duration: 350 }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.tr("step") + " " + (panelRoot ? panelRoot.livePreviewStep : 0) + "/" + (panelRoot ? panelRoot.livePreviewMaxSteps : 25) + (root.genElapsedSeconds > 0 ? (" (" + root.genElapsedSeconds + "s)") : "")
                    font.family: Commons.Style.font.family
                    font.features: { "tnum": 1 }
                    font.pixelSize: Commons.Style.font.caption
                    font.bold: true
                    color: Commons.Color.accent
                  }
                }
              }
            }
          }
        }

        // Image Scaling Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Commons.Style.spacing.xs

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_sana")
            text: isBusy ? ("SANA " + root.genElapsedSeconds + "s") : "2K SANA"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_sana"), hot)
            onClicked: if (panelRoot) panelRoot.aiUpscale("sana")
          }

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_esrgan")
            text: isBusy ? ("ESRGAN " + root.genElapsedSeconds + "s") : "4X ESRGAN"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_esrgan"), hot)
            onClicked: if (panelRoot) panelRoot.aiUpscale("esrgan")
          }

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_ultra")
            text: isBusy ? ("ULTRA " + root.genElapsedSeconds + "s") : "4X ULTRA"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_ultra"), hot)
            onClicked: if (panelRoot) panelRoot.aiUpscale("ultra")
          }

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_anime")
            text: isBusy ? ("ANIME " + root.genElapsedSeconds + "s") : "4X ANIME"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_anime"), hot)
            onClicked: if (panelRoot) panelRoot.aiUpscale("anime")
          }

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 0.5)
            text: isBusy ? ("0.5X " + root.genElapsedSeconds + "s") : "0.5X"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_half"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(0.5)
          }

          Button {
            readonly property bool isBusy: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === -1.0)
            text: isBusy ? ("FIT 1K " + root.genElapsedSeconds + "s") : "FIT 1K"
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: isBusy
            selected: isBusy
            foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
            enabled: ((panelRoot && panelRoot.referencePath !== "") || (panelRoot && panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_fit1k"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(-1.0)
          }
        }

        // Actions Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Commons.Style.spacing.xs

          Button {
            text: root.tr("set_wallpaper")
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_set_wallpaper"), hot)
            onClicked: if (panelRoot) panelRoot.setAsWallpaper(panelRoot.generatedPath)
          }

          Button {
            text: root.tr("compare_ab")
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.referencePath !== "" && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_compare_ab"), hot)
            onClicked: if (panelRoot) panelRoot.currentView = "compare"
          }

          Button {
            text: root.tr("copy_clipboard")
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_copy_clipboard"), hot)
            onClicked: if (panelRoot) panelRoot.copyImageToClipboard(panelRoot.generatedPath)
          }

          Button {
            text: root.tr("open_viewer")
            fontSize: Commons.Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_open_viewer"), hot)
            onClicked: if (panelRoot) panelRoot.openImageViewer(panelRoot.generatedPath)
          }
        }
      }
    }

    // ===================================================================
    // FOOTER CONTEXTUAL HELP / STATUS BAR (Po najetí myši na tlačítka)
    // ===================================================================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(26)
      color: Commons.Util.alpha(Commons.Color.background, 0.85)
      border.color: root.activeHelpText !== ""
        ? (root.activeHelpText.indexOf("VAROVÁNÍ") !== -1 || root.activeHelpText.indexOf("WARNING") !== -1
            ? Commons.Util.alpha(Commons.Color.urgent, 0.55)
            : Commons.Util.alpha(Commons.Color.accent, 0.45))
        : Commons.Color.menu.border
      border.width: 1
      radius: Commons.Style.cornerRadius

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Commons.Style.spacing.sm
        anchors.rightMargin: Commons.Style.spacing.sm
        spacing: Commons.Style.spacing.xs

        Text {
          textFormat: Text.PlainText
          text: "//"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: root.activeHelpText !== ""
            ? (root.activeHelpText.indexOf("VAROVÁNÍ") !== -1 || root.activeHelpText.indexOf("WARNING") !== -1
                ? Commons.Color.urgent
                : Commons.Color.accent)
            : Commons.Util.alpha(Commons.Color.foreground, 0.55)
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.activeHelpText !== "" ? root.activeHelpText : root.tr("default_tip")
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: root.activeHelpText !== ""
          color: root.activeHelpText !== "" ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.45)
          elide: Text.ElideRight
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // ===================================================================
    // BOTTOM BAR: Navigation, Reset, Language Switcher & Synthesis
    // ===================================================================
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Button {
        text: root.tr("civitai_prompts")
        bordered: true
        onHotChanged: root.setHelp(root.tr("help_civitai_prompts"), hot)
        onClicked: if (panelRoot) panelRoot.currentView = "civitai"
      }

      // Turbo Viggle LoRA Switcher (Marci standard: čistá typografie, informativní stav bez ikon)
      Button {
        text: panelRoot && panelRoot.isTurboEnabled ? "TURBO: ON" : "TURBO: OFF"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.isTurboEnabled
        onHotChanged: root.setHelp(root.tr("help_turbo_lora"), hot)
        onClicked: if (panelRoot) panelRoot.toggleTurbo()
      }

      // Anime Style LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
      Button {
        text: {
          var mode = panelRoot ? panelRoot.animeMode : "off";
          return mode === "full" ? "ANIME: FULL" : (mode === "soft" ? "ANIME: SOFT" : "ANIME: OFF");
        }
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.animeMode !== "off"
        onHotChanged: root.setHelp(root.tr("help_anime_lora"), hot)
        onClicked: if (panelRoot) panelRoot.cycleAnimeMode()
      }

      // Uncensored Latent LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
      Button {
        text: {
          var mode = panelRoot ? panelRoot.hereticMode : "off";
          return mode === "full" ? "HERETIC: FULL" : (mode === "soft" ? "HERETIC: SOFT" : "HERETIC: OFF");
        }
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.hereticMode !== "off"
        onHotChanged: root.setHelp(root.tr("help_uncensored_lora"), hot)
        onClicked: if (panelRoot) panelRoot.cycleHereticMode()
      }

      // Anatomy Body LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
      Button {
        text: {
          var mode = panelRoot ? panelRoot.anatomyMode : "off";
          return mode === "full" ? "ANATOMY: FULL" : (mode === "soft" ? "ANATOMY: SOFT" : "ANATOMY: OFF");
        }
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.anatomyMode !== "off"
        onHotChanged: root.setHelp(root.tr("help_anatomy_lora"), hot)
        onClicked: if (panelRoot) panelRoot.cycleAnatomyMode()
      }

      Button {
        text: root.tr("history")
        bordered: true
        onHotChanged: root.setHelp(root.tr("help_history"), hot)
        onClicked: if (panelRoot) panelRoot.currentView = "history"
      }

      Button {
        text: root.tr("reset")
        bordered: true
        onHotChanged: root.setHelp(root.tr("help_reset"), hot)
        onClicked: if (panelRoot) {
          panelRoot.resetForm();
          root.genElapsedSeconds = 0;
        }
      }

      Item { Layout.fillWidth: true }

      Button {
        readonly property bool isBusy: panelRoot && (panelRoot.isGenerating || panelRoot.isCancelling)
        text: {
          if (panelRoot && panelRoot.isCancelling) {
            return "CANCELLING...";
          }
          if (panelRoot && panelRoot.isGenerating) {
            return root.tr("cancel") + " // " + root.genElapsedSeconds + "s";
          }
          if (panelRoot && panelRoot.isGameLocked) return root.tr("locked_game");
          return root.tr("generate");
        }
        bordered: true
        active: isBusy
        selected: isBusy
        foreground: isBusy ? Commons.Color.urgent : Commons.Color.foreground
        enabled: panelRoot && (isBusy || !panelRoot.isGameLocked)
        onHotChanged: root.setHelp(isBusy ? root.tr("help_cancel") : root.tr("help_generate"), hot)
        onClicked: {
          if (!panelRoot) return;
          if (isBusy) {
            panelRoot.cancelGeneration();
            root.genElapsedSeconds = 0;
          } else {
            panelRoot.startGeneration();
          }
        }
      }
    }
  }
}
