import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
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
    var lang = panelRoot ? panelRoot.currentLang : "cs";
    var strings = {
      // Prompt Box
      "prompt_title": {
        "cs": "PROMPT (ALT+↑/↓ HISTORIE, CTRL+ENTER RUN)",
        "en": "PROMPT (ALT+↑/↓ HISTORY, CTRL+ENTER RUN)"
      },
      "prompt_placeholder": {
        "cs": "Zadej prompt v angličtině (automatický lokální překlad)...",
        "en": "Enter prompt in English (automatic local translation)..."
      },
      "words": { "cs": "slov", "en": "words" },
      "optimize": { "cs": "VYLEPŠIT", "en": "OPTIMIZE" },
      "optimizing": { "cs": "VYLEPŠUJI...", "en": "OPTIMIZING..." },
      "help_optimize": {
        "cs": "VYLEPŠIT: Automaticky rozvine zadaný nápad do detailního difuzního promptu na RTX 3070 (0 tokenů).",
        "en": "OPTIMIZE: Automatically turns user idea into a rich diffusion prompt on RTX 3070 (0 tokens)."
      },
      "negative_title": { "cs": "NEGATIVNÍ PROMPT", "en": "NEGATIVE PROMPT" },
      "negative_placeholder": {
        "cs": "rozmazané, nízká kvalita, deformace, prsty navíc, text, vodoznak",
        "en": "blurry, low quality, deformed, extra fingers, text, watermark"
      },

      // Presets
      "desktop": { "cs": "PLOCHA", "en": "DESKTOP" },
      "mobile": { "cs": "MOBIL", "en": "MOBILE" },
      "avatar": { "cs": "AVATAR", "en": "AVATAR" },
      "ratio_auto_ref": { "cs": "AUTO (REF)", "en": "AUTO (REF)" },

      // Resolution
      "draft": { "cs": "NÁVRH (512)", "en": "DRAFT (512)" },
      "std": { "cs": "STD (1024)", "en": "STD (1024)" },
      "high": { "cs": "VYSOKÉ (1536)", "en": "HIGH (1536)" },

      // Seed & Steps
      "seed_random": { "cs": "SEED [NÁHODNÝ]", "en": "SEED [RANDOM]" },
      "seed_locked": { "cs": "SEED [ZAMČENÝ: ", "en": "SEED [LOCKED: " },
      "steps": { "cs": "KROKY: ", "en": "STEPS: " },

      // Reference & Buffer
      "ref_title": {
        "cs": "REFERENCE A BUFFER (DRAG & DROP / PASTE / SNIP)",
        "en": "REFERENCE & BUFFER (DRAG & DROP / PASTE / SNIP)"
      },
      "no_buffer": { "cs": "Bez bufferu", "en": "No Buffer" },
      "drop_hint": { "cs": "Přetáhni soubor nebo vlož ze schránky", "en": "Drop image file or paste clipboard" },
      "buffer_ref": { "cs": "󰅌 Reference z bufferu", "en": "󰅌 Buffer Reference" },
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
      "generating_img": { "cs": "GENEROVÁNÍ OBRAZU NA RTX 3070...", "en": "GENERATING IMAGE ON RTX 3070..." },
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
      "help_prompt": {
        "cs": "PROMPT: Zadej popis scény v angličtině (automatický transparentní překlad na RTX 3070 za 0 tokenů).",
        "en": "PROMPT: Enter scene description in English (automatic local translation on RTX 3070 at 0 tokens)."
      },
      "help_negative": {
        "cs": "NEGATIVNÍ PROMPT: Prvky, styly a vady, které nechceš v obraze mít (např. deformace, text, vodoznaky).",
        "en": "NEGATIVE PROMPT: Elements, styles, and flaws to exclude from the image (e.g., deformed, text, watermarks)."
      },
      "help_desktop": {
        "cs": "PLOCHA: Nastaví širokoúhlý poměr 16:9 (1344×768 px) ideální pro tapety pracovní plochy.",
        "en": "DESKTOP: Sets widescreen 16:9 ratio (1344×768 px) ideal for desktop wallpapers."
      },
      "help_mobile": {
        "cs": "MOBIL: Nastaví vertikální poměr stran 9:16 (768×1344 px) vhodný pro displeje telefonů.",
        "en": "MOBILE: Sets vertical 9:16 ratio (768×1344 px) suitable for phone displays."
      },
      "help_avatar": {
        "cs": "AVATAR: Nastaví čtvercový formát 1:1 a rychlý koncept pro avatary a profilové obrázky.",
        "en": "AVATAR: Sets square 1:1 format and fast draft for avatars and profile icons."
      },
      "help_ratio_1_1": { "cs": "1:1: Standardní čtvercový formát 1024×1024 px.", "en": "1:1: Standard square format 1024×1024 px." },
      "help_ratio_16_9": { "cs": "16:9: Širokoúhlý monitorový formát (1344×768 px).", "en": "16:9: Widescreen monitor format (1344×768 px)." },
      "help_ratio_9_16": { "cs": "9:16: Vertikální poměr stran 768×1344 px pro mobilní obrazovky.", "en": "9:16: Vertical 768×1344 px aspect ratio for mobile screens." },
      "help_ratio_21_9": { "cs": "21:9: Ultraširokoúhlý filmový poměr (1536×640 px).", "en": "21:9: Ultrawide cinematic aspect ratio (1536×640 px)." },
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
      "help_seed": {
        "cs": "SEED: Přepíná mezi náhodným generováním nového díla a fixací konkrétního seedu.",
        "en": "SEED: Toggles between random seed generation and locking a specific seed."
      },
      "help_steps": {
        "cs": "KROKY (STEPS): Počet difuzních vzorkovacích kroků (výchozí: 25). Vyšší hodnoty zjemňují detaily, nižší urychlují generování.",
        "en": "STEPS: Number of diffusion sampling steps (default: 25). Higher values refine detail, lower values speed up generation."
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
        "cs": "INTERROGATE WD14: Bleskově extrahuje Danbooru tagy z referenčního obrázku pomocí lokální sítě WD14 na RTX 3070.",
        "en": "INTERROGATE WD14: Blazingly extracts Danbooru tags from reference image via local WD14 network on RTX 3070."
      },
      "help_vision": {
        "cs": "VISION PROMPT: Zrekonstruuje a popíše scénu přirozeným jazykem pomocí multimodálního modelu Qwen-Vision na RTX 3070.",
        "en": "VISION PROMPT: Reconstructs and describes scene in natural language via local multimodal Qwen-Vision on RTX 3070."
      },
      "help_denoise": {
        "cs": "DENOISE: Míra přepracování referenčního obrázku (0.1 = jemná úprava, 0.65 = vyvážená změna, 1.0 = úplně nová syntéza).",
        "en": "DENOISE: Modification strength of reference image (0.1 = subtle edit, 0.65 = balanced redesign, 1.0 = completely new synthesis)."
      },
      "help_scale_2x": {
        "cs": "2X: Bleskově zvětší rozlišení obrázku na 200% pomocí nativního SIMD Lanczos algoritmu.",
        "en": "2X: Blazingly resizes image to 200% resolution using native SIMD Lanczos algorithm."
      },
      "help_scale_4x": {
        "cs": "4X: Čtyřnásobné zvětšení rozlišení na vysoké 4K rozlišení pomocí SIMD Lanczos filtru.",
        "en": "4X: Quadruple upscaling to 4K resolution using SIMD Lanczos filter."
      },
      "help_scale_ai": {
        "cs": "AI 2X: Difuzní zvětšení a domodelování mikroskopických detailů pomocí neuronové sítě na RTX 3070.",
        "en": "AI 2X: Neural super-resolution generating microscopic details on RTX 3070."
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
      "help_history": {
        "cs": "HISTORY: Otevře archiv dříve vygenerovaných děl v ~/Pictures/Qwen-Image/ s obnovením parametrů.",
        "en": "HISTORY: Displays archive of previously generated artworks in ~/Pictures/Qwen-Image with parameter restore."
      },
      "help_reset": {
        "cs": "RESET: Vyčistí všechna pole a vrátí studio do výchozího stavu.",
        "en": "RESET: Clears all text fields and resets studio to default values."
      },
      "help_lang": {
        "cs": "PŘEPÍNAČ JAZYKA: Přepíná rozhraní a nápovědu mezi češtinou (CZ) a angličtinou (EN).",
        "en": "LANGUAGE SWITCHER: Toggles interface and help text between English (EN) and Czech (CZ)."
      },
      "help_generate": {
        "cs": "GENERATE (Ctrl+Enter): Spustí generování obrazu na lokální GPU NVIDIA RTX 3070 za 0 tokenů.",
        "en": "GENERATE (Ctrl+Enter): Starts image generation on local NVIDIA RTX 3070 GPU at 0 tokens."
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
    spacing: Style.spacing.sm

    // Main 2-column studio layout
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.spacing.lg

      // ===================================================================
      // LEFT COLUMN: Parameters, Multiline Prompts & Static Buffer Box (460px)
      // ===================================================================
      ColumnLayout {
        Layout.preferredWidth: Style.space(460)
        Layout.fillHeight: true
        spacing: Style.spacing.xs

        // 1. Multiline Main Prompt Card (Spacious Unified Frame)
        Rectangle {
          id: promptCard
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(138)
          color: Qt.darker(Color.background, 1.15)
          border.color: promptInput.activeFocus ? Color.accent : (promptCardHover.hovered || promptInput.hovered ? Qt.lighter(Color.menu.border, 1.4) : Color.menu.border)
          border.width: 1
          radius: Style.cornerRadius
          clip: true

          HoverHandler {
            id: promptCardHover
            onHoveredChanged: root.setHelp(root.tr("help_prompt"), hovered)
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.xs
            spacing: Style.spacing.xxs

            // Card Header: Section Title + Word Counter
            RowLayout {
              Layout.fillWidth: true

              Text {
                text: root.tr("prompt_title")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: promptInput.activeFocus ? Color.accent : Color.foreground
                Layout.fillWidth: true
              }

              Button {
                visible: promptInput.text.trim() !== ""
                text: (panelRoot && panelRoot.isOptimizingPrompt) ? ("󱫠 " + root.tr("optimizing") + " (" + root.optElapsedSeconds + "s)") : root.tr("optimize")
                fontSize: Style.font.caption
                bordered: true
                active: panelRoot && panelRoot.isOptimizingPrompt
                enabled: panelRoot && !panelRoot.isOptimizingPrompt
                onHotChanged: root.setHelp(root.tr("help_optimize"), hot)
                onClicked: if (panelRoot) panelRoot.optimizePrompt(promptInput.text)
              }

              Text {
                visible: promptInput.text.trim() !== ""
                text: promptInput.text.trim().split(/\s+/).length + " " + root.tr("words")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.accent
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.25)
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              TextArea {
                id: promptInput
                width: parent.availableWidth
                wrapMode: TextEdit.Wrap
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.foreground
                selectionColor: Style.selectionFillFor(Color.foreground, Color.accent)
                selectedTextColor: Color.foreground
                placeholderTextColor: Qt.darker(Color.foreground, 1.8)
                placeholderText: root.tr("prompt_placeholder")
                text: panelRoot ? panelRoot.promptText : ""
                background: null
                leftPadding: Style.spacing.xs
                rightPadding: Style.spacing.xs
                topPadding: Style.spacing.xs
                bottomPadding: Style.spacing.xs

                onTextChanged: {
                  if (panelRoot && panelRoot.promptText !== text) {
                    panelRoot.promptText = text;
                  }
                }

                Keys.onPressed: function(event) {
                  if (event.modifiers & Qt.AltModifier) {
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
          Layout.preferredHeight: Style.space(80)
          color: Qt.darker(Color.background, 1.15)
          border.color: negativeInput.activeFocus ? Color.accent : (negativeCardHover.hovered || negativeInput.hovered ? Qt.lighter(Color.menu.border, 1.4) : Color.menu.border)
          border.width: 1
          radius: Style.cornerRadius
          clip: true

          HoverHandler {
            id: negativeCardHover
            onHoveredChanged: root.setHelp(root.tr("help_negative"), hovered)
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.xs
            spacing: Style.spacing.xxs

            Text {
              text: root.tr("negative_title")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: negativeInput.activeFocus ? Color.accent : Color.foreground
              Layout.fillWidth: true
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.25)
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              TextArea {
                id: negativeInput
                width: parent.availableWidth
                wrapMode: TextEdit.Wrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
                selectionColor: Style.selectionFillFor(Color.foreground, Color.accent)
                selectedTextColor: Color.foreground
                placeholderTextColor: Qt.darker(Color.foreground, 1.8)
                placeholderText: root.tr("negative_placeholder")
                text: panelRoot ? panelRoot.negativePromptText : ""
                background: null
                leftPadding: Style.spacing.xs
                rightPadding: Style.spacing.xs
                topPadding: Style.spacing.xs
                bottomPadding: Style.spacing.xs

                onTextChanged: {
                  if (panelRoot && panelRoot.negativePromptText !== text) {
                    panelRoot.negativePromptText = text;
                  }
                }
              }
            }
          }
        }

        // 3. Target Presets
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Button {
            text: root.tr("desktop")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_desktop"), hot)
            onClicked: {
              if (panelRoot) panelRoot.aspectRatio = "16:9";
            }
          }

          Button {
            text: root.tr("mobile")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_mobile"), hot)
            onClicked: {
              if (panelRoot) panelRoot.aspectRatio = "9:16";
            }
          }

          Button {
            text: root.tr("avatar")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_avatar"), hot)
            onClicked: {
              if (panelRoot) {
                panelRoot.aspectRatio = "1:1";
                panelRoot.resMode = "draft";
              }
            }
          }
        }

        // 4. Aspect Ratio Selection
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Button {
            text: root.tr("ratio_auto_ref")
            fontSize: Style.font.caption
            bordered: true
            visible: panelRoot && panelRoot.referencePath !== ""
            selected: panelRoot && panelRoot.aspectRatio === "auto"
            Layout.fillWidth: true
            onHotChanged: root.setHelp("Automaticky zachovat přesný poměr stran načteného referenčního obrázku bez ořezu", hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "auto"
          }
          Button {
            text: "1:1" + (panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === "1:1" ? " • REF" : "")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.aspectRatio === "1:1"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_ratio_1_1"), hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "1:1"
          }
          Button {
            text: "16:9" + (panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === "16:9" ? " • REF" : "")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.aspectRatio === "16:9"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_ratio_16_9"), hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "16:9"
          }
          Button {
            text: "9:16" + (panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === "9:16" ? " • REF" : "")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.aspectRatio === "9:16"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_ratio_9_16"), hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "9:16"
          }
          Button {
            text: "21:9" + (panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === "21:9" ? " • REF" : "")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.aspectRatio === "21:9"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_ratio_21_9"), hot)
            onClicked: if (panelRoot) panelRoot.aspectRatio = "21:9"
          }
        }

        // 5. Resolution Mode
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Button {
            text: root.tr("draft")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "draft"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_draft"), hot)
            onClicked: if (panelRoot) panelRoot.resMode = "draft"
          }
          Button {
            text: root.tr("std")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "standard"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_std"), hot)
            onClicked: if (panelRoot) panelRoot.resMode = "standard"
          }
          Button {
            text: root.tr("high")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.resMode === "high"
            Layout.fillWidth: true
            onHotChanged: root.setHelp(root.tr("help_res_high"), hot)
            onClicked: if (panelRoot) panelRoot.resMode = "high"
          }
        }

        // 6. Seed Control & Steps (with Steps Slider Hover Help)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.sm

          Button {
            text: panelRoot && panelRoot.seedLocked ? root.tr("seed_locked") + panelRoot.seedVal + "]" : root.tr("seed_random")
            fontSize: Style.font.caption
            bordered: true
            selected: panelRoot && panelRoot.seedLocked
            Layout.preferredWidth: Style.space(160)
            onHotChanged: root.setHelp(root.tr("help_seed"), hot)
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
            text: root.tr("steps") + (panelRoot ? panelRoot.steps : 25)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
            Layout.preferredWidth: Style.space(65)

            HoverHandler {
              onHoveredChanged: root.setHelp(root.tr("help_steps"), hovered)
            }
          }

          PanelSlider {
            id: stepsSlider
            Layout.fillWidth: true
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

        // 7. Static Reference & Buffer Card (Reorganized: Large Preview Above Buttons, No Icons)
        Rectangle {
          id: refCard
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: Style.space(210)
          Layout.minimumHeight: Style.space(160)
          color: dropArea.containsDrag ? Style.selectedFillFor(Color.foreground, Color.accent) : Qt.darker(Color.background, 1.15)
          border.color: dropArea.containsDrag ? Color.accent : Color.menu.border
          border.width: 1
          radius: Style.cornerRadius
          clip: true

          DropArea {
            id: dropArea
            anchors.fill: parent
            onDropped: function(drop) {
              if (drop.hasUrls && drop.urls.length > 0) {
                var urlStr = drop.urls[0].toString();
                var cleanPath = urlStr.replace(/^file:\/\//, "");
                if (panelRoot) panelRoot.setReferenceImage(cleanPath);
              }
            }
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.xs
            spacing: Style.spacing.xs

            // Card Header: Title + File Label
            RowLayout {
              Layout.fillWidth: true

              Text {
                text: root.tr("ref_title")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: panelRoot && panelRoot.referencePath !== "" ? Color.accent : Color.foreground
                Layout.fillWidth: true
              }

              Text {
                text: panelRoot && panelRoot.referencePath !== "" ? (panelRoot.referencePath.indexOf("/tmp/") !== -1 ? root.tr("buffer_ref") : panelRoot.referencePath.split("/").pop()) : ""
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.accent
                elide: Text.ElideMiddle
                Layout.maximumWidth: Style.space(180)
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.25)
            }

            // 1. Large Preview Frame (takes all remaining width and height above buttons)
            Rectangle {
              id: previewBox
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: Style.space(90)
              color: Qt.darker(Color.background, 1.4)
              border.color: panelRoot && panelRoot.referencePath !== "" ? Color.accent : Color.menu.border
              border.width: 1
              radius: Style.cornerRadius
              clip: true

              // Loaded buffer image
              Image {
                id: refThumb
                anchors.fill: parent
                anchors.margins: Style.spacing.xxs
                fillMode: Image.PreserveAspectFit
                source: panelRoot && panelRoot.referencePath !== "" ? "file://" + panelRoot.referencePath + (panelRoot.referenceRevision ? "?v=" + panelRoot.referenceRevision : "") : ""
                cache: false
                asynchronous: true
                smooth: true
                visible: panelRoot && panelRoot.referencePath !== ""
              }

              // Empty buffer placeholder
              ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.spacing.xxs
                visible: !panelRoot || panelRoot.referencePath === ""

                Text {
                  text: "󰅌"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title * 1.4
                  color: Qt.darker(Color.foreground, 2.2)
                  horizontalAlignment: Text.AlignHCenter
                  Layout.alignment: Qt.AlignHCenter
                }

                Text {
                  text: root.tr("drop_hint")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(Color.foreground, 2.0)
                  horizontalAlignment: Text.AlignHCenter
                  Layout.alignment: Qt.AlignHCenter
                }
              }
            }

            // 2. Action Buttons Row (Under preview, without icons)
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.xs

              Button {
                text: root.tr("paste")
                fontSize: Style.font.caption
                bordered: true
                Layout.fillWidth: true
                onHotChanged: root.setHelp(root.tr("help_paste"), hot)
                onClicked: if (panelRoot) panelRoot.pasteFromClipboard()
              }

              Button {
                text: root.tr("snip")
                fontSize: Style.font.caption
                bordered: true
                Layout.fillWidth: true
                onHotChanged: root.setHelp(root.tr("help_snip"), hot)
                onClicked: if (panelRoot) panelRoot.snipScreenArea()
              }

              Button {
                text: (panelRoot && panelRoot.isInterrogating) ? (root.tr("tagging") + " (" + root.wd14ElapsedSeconds + "s)") : root.tr("interrogate_wd14")
                fontSize: Style.font.caption
                bordered: true
                Layout.fillWidth: true
                active: panelRoot && panelRoot.isInterrogating
                enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isInterrogating
                onHotChanged: root.setHelp(root.tr("help_interrogate"), hot)
                onClicked: if (panelRoot) panelRoot.interrogateWd14()
              }

              Button {
                text: (panelRoot && panelRoot.isVisionLoading) ? (root.tr("analyzing") + " (" + root.visionElapsedSeconds + "s)") : root.tr("vision_prompt")
                fontSize: Style.font.caption
                bordered: true
                Layout.fillWidth: true
                active: panelRoot && panelRoot.isVisionLoading
                enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isVisionLoading
                onHotChanged: root.setHelp(root.tr("help_vision"), hot)
                onClicked: if (panelRoot) panelRoot.extractVisionPrompt()
              }
            }

            // 3. Denoise Slider Row (Bottom)
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.xs

              Text {
                id: denoiseLabel
                text: root.tr("denoise") + (panelRoot ? panelRoot.denoise.toFixed(2) : "0.65")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: panelRoot && panelRoot.referencePath !== "" ? Color.foreground : Qt.darker(Color.foreground, 2.0)
                Layout.preferredWidth: Style.space(85)

                HoverHandler {
                  onHoveredChanged: root.setHelp(root.tr("help_denoise"), hovered)
                }
              }

              PanelSlider {
                id: denoiseSlider
                Layout.fillWidth: true
                bar: panelRoot ? panelRoot.bar : null
                minimum: 0.1
                maximum: 1.0
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
        spacing: Style.spacing.xs

        // Image Canvas Card Frame (Symmetrical with left column cards)
        Rectangle {
          id: canvasFrame
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Qt.darker(Color.background, 1.15)
          border.color: Color.menu.border
          border.width: 1
          radius: Style.cornerRadius
          clip: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.xs
            spacing: Style.spacing.xxs

            // Card Header: Canvas Title + Telemetry Badge
            RowLayout {
              Layout.fillWidth: true

              Text {
                text: root.tr("canvas_title")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.foreground
                Layout.fillWidth: true
              }

              Text {
                text: panelRoot && panelRoot.generationTelemetry !== "" ? panelRoot.generationTelemetry : "1024x1024 | 25 STEPS | RTX 3070 (0 TOKENS)"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.foreground, 1.6)
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.25)
            }

            // Canvas Display Area
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              Image {
                id: mainPreview
                anchors.fill: parent
                anchors.margins: Style.spacing.xxs
                fillMode: Image.PreserveAspectFit
                source: panelRoot && panelRoot.generatedPath !== "" ? "file://" + panelRoot.generatedPath : ""
                cache: false
                asynchronous: true
              }

              // Placeholder when no image generated
              Column {
                anchors.centerIn: parent
                spacing: Style.spacing.xs
                visible: !mainPreview.source || mainPreview.status !== Image.Ready

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: panelRoot && panelRoot.isGenerating ? root.tr("generating_img") : root.tr("ready_to_synth")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  color: panelRoot && panelRoot.isGenerating ? Color.accent : Qt.darker(Color.foreground, 1.8)
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.tr("press_gen_hint")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(Color.foreground, 2.0)
                }
              }
            }
          }
        }

        // Image Scaling Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Text {
            text: root.tr("scale")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
            Layout.preferredWidth: Style.space(46)
          }

          Button {
            text: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 2.0) ? ("2X (" + root.genElapsedSeconds + "s)") : "2X"
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 2.0)
            enabled: panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_2x"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(2.0)
          }

          Button {
            text: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 4.0) ? ("4X (" + root.genElapsedSeconds + "s)") : "4X"
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 4.0)
            enabled: panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_4x"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(4.0)
          }

          Button {
            text: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "enhance") ? ("AI 2X (" + root.genElapsedSeconds + "s)") : "AI 2X"
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "enhance")
            enabled: panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_ai"), hot)
            onClicked: if (panelRoot) panelRoot.aiEnhance()
          }

          Button {
            text: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 0.5) ? ("0.5X (" + root.genElapsedSeconds + "s)") : "0.5X"
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 0.5)
            enabled: panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_half"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(0.5)
          }

          Button {
            text: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === -1.0) ? ("FIT 1K (" + root.genElapsedSeconds + "s)") : "FIT 1K"
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            active: (panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === -1.0)
            enabled: ((panelRoot && panelRoot.referencePath !== "") || (panelRoot && panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
            onHotChanged: root.setHelp(root.tr("help_scale_fit1k"), hot)
            onClicked: if (panelRoot) panelRoot.scaleImage(-1.0)
          }
        }

        // Actions Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Button {
            text: root.tr("set_wallpaper")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_set_wallpaper"), hot)
            onClicked: if (panelRoot) panelRoot.setAsWallpaper(panelRoot.generatedPath)
          }

          Button {
            text: root.tr("compare_ab")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.referencePath !== "" && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_compare_ab"), hot)
            onClicked: if (panelRoot) panelRoot.currentView = "compare"
          }

          Button {
            text: root.tr("copy_clipboard")
            fontSize: Style.font.caption
            bordered: true
            Layout.fillWidth: true
            enabled: panelRoot && panelRoot.generatedPath !== ""
            onHotChanged: root.setHelp(root.tr("help_copy_clipboard"), hot)
            onClicked: if (panelRoot) panelRoot.copyImageToClipboard(panelRoot.generatedPath)
          }

          Button {
            text: root.tr("open_viewer")
            fontSize: Style.font.caption
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
      Layout.preferredHeight: Style.space(26)
      color: Qt.darker(Color.background, 1.2)
      border.color: root.activeHelpText !== "" ? Qt.darker(Color.accent, 1.8) : Color.menu.border
      border.width: 1
      radius: Style.cornerRadius

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.sm
        anchors.rightMargin: Style.spacing.sm
        spacing: Style.spacing.xs

        Text {
          text: root.activeHelpText !== "" ? "󰛩" : "󰌌"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.activeHelpText !== "" ? Color.accent : Qt.darker(Color.foreground, 1.6)
        }

        Text {
          Layout.fillWidth: true
          text: root.activeHelpText !== "" ? root.activeHelpText : root.tr("default_tip")
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: root.activeHelpText !== ""
          color: root.activeHelpText !== "" ? Color.foreground : Qt.darker(Color.foreground, 1.8)
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
      spacing: Style.spacing.sm

      Button {
        text: root.tr("civitai_prompts")
        bordered: true
        onHotChanged: root.setHelp(root.tr("help_civitai_prompts"), hot)
        onClicked: if (panelRoot) panelRoot.currentView = "civitai"
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

      // Language Switcher (CZ <-> EN)
      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "LANG: CZ" : "LANG: EN"
        fontSize: Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.currentLang === "cs"
        onHotChanged: root.setHelp(root.tr("help_lang"), hot)
        onClicked: if (panelRoot) panelRoot.toggleLanguage()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: {
          if (panelRoot && panelRoot.isGenerating) {
            if (panelRoot.generatingMode === "scale") return root.tr("upscaling") + " (" + root.genElapsedSeconds + "s)";
            if (panelRoot.generatingMode === "enhance") return root.tr("enhancing") + " (" + root.genElapsedSeconds + "s)";
            return root.tr("generating") + " (" + root.genElapsedSeconds + "s)";
          }
          if (panelRoot && panelRoot.isGameLocked) return root.tr("locked_game");
          return root.tr("generate");
        }
        bordered: true
        active: panelRoot && panelRoot.isGenerating
        foreground: Color.accent
        enabled: panelRoot && !panelRoot.isGenerating && !panelRoot.isGameLocked
        onHotChanged: root.setHelp(root.tr("help_generate"), hot)
        onClicked: if (panelRoot) panelRoot.startGeneration()
      }
    }
  }
}
