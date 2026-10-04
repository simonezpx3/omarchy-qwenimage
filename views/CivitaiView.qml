import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null
  readonly property bool isLoading: panelRoot ? panelRoot.isCivitaiLoading : false
  readonly property string activeSource: panelRoot ? panelRoot.activePromptSource : "civitai"
  readonly property real _cardDpiBlend: ((0x732641 % 1000) / 1000.0)

  Component.onCompleted: {
    if (panelRoot && (!panelRoot.civitaiModel || panelRoot.civitaiModel.length === 0)) {
      root.searchPrompts("");
    }
  }

  function selectSource(source) {
    if (panelRoot) {
      panelRoot.activePromptSource = source;
      root.searchPrompts(searchField.text);
    }
  }

  function searchPrompts(query) {
    if (panelRoot) {
      panelRoot.fetchPrompts(root.activeSource, query);
    }
  }

  function sourceDisplayName(src) {
    switch (String(src).toLowerCase()) {
      case "civitai": return "CivitAI";
      case "midlibrary":
      case "midlibrary.io": return "Midlibrary.io (Styles & Lenses)";
      case "diffusiondb": return "DiffusionDB (14M Dataset)";
      case "seaart":
      case "seaart.ai": return "SeaArt.ai (Anime & LoRA)";
      case "shakker":
      case "shakker.ai": return "Shakker AI (Flux & DiT)";
      case "playground":
      case "playground.com": return "Playground.com (Styles & Art)";
      case "lexica": return "Lexica.art";
      case "prompthero": return "PromptHero";
      case "openart": return "OpenArt.ai";
      case "huggingface": return "Hugging Face (Text Prompt Card)";
      case "krea": return "Krea.ai (Flux & Enhancer)";
      case "tensorart": return "Tensor.art (Models & LoRA)";
      default:
        if (src && String(src).trim().length > 0) {
          var s = String(src).trim();
          return s.charAt(0).toUpperCase() + s.slice(1);
        }
        return (panelRoot && panelRoot.currentLang === "cs") ? "Neznámý zdroj" : "Unknown Source";
    }
  }

  function sourceIcon(src) {
    switch (String(src).toLowerCase()) {
      case "civitai": return "󰚩";
      case "midlibrary":
      case "midlibrary.io": return "📚";
      case "diffusiondb": return "🗄";
      case "seaart":
      case "seaart.ai": return "🌊";
      case "shakker":
      case "shakker.ai": return "⚡";
      case "playground":
      case "playground.com": return "🎪";
      case "lexica": return "󰄛";
      case "prompthero": return "󰓥";
      case "openart": return "󰏤";
      case "huggingface": return "🤗";
      case "krea": return "✦";
      case "tensorart": return "󰢬";
      default: return "󰏤";
    }
  }

  function sourcePlaceholder(src) {
    var isCs = panelRoot && panelRoot.currentLang === "cs";
    switch (String(src).toLowerCase()) {
      case "civitai":
        return isCs ? "Hledat v CivitAI (např. cyberpunk girl, fantasy portrét, noc)..." : "Search Civitai (e.g. cyberpunk girl, fantasy portrait, night)...";
      case "midlibrary":
      case "midlibrary.io":
        return isCs ? "Hledat v Midlibrary (malíři, optika, kinofilmy, žánry, architekti)..." : "Search Midlibrary (artists, lenses, film stocks, genres, architects)...";
      case "diffusiondb":
        return isCs ? "Hledat v DiffusionDB (fotorealismus, mecha, sci-fi, koncepty)..." : "Search DiffusionDB (photorealism, mecha, sci-fi, concepts)...";
      case "seaart":
      case "seaart.ai":
        return isCs ? "Hledat v SeaArt (anime, fantasy, stylizace, herní postavy)..." : "Search SeaArt (anime, fantasy, stylized, game characters)...";
      case "shakker":
      case "shakker.ai":
        return isCs ? "Hledat v Shakker (Flux, DiT, realistické scény, moderní design)..." : "Search Shakker (Flux, DiT, realistic scenes, modern design)...";
      case "playground":
      case "playground.com":
        return isCs ? "Hledat v Playground (filmové, retro synthwave, surrealismus, pop-art)..." : "Search Playground (cinematic, retro synthwave, surrealism, pop-art)...";
      case "lexica":
        return isCs ? "Hledat v Lexica (např. cinematic lighting, 8k portrait, sci-fi)..." : "Search Lexica (e.g. cinematic lighting, 8k portrait, sci-fi)...";
      case "prompthero":
        return isCs ? "Hledat v PromptHero (např. midjourney style, fashion, macro)..." : "Search PromptHero (e.g. midjourney style, fashion, macro)...";
      case "openart":
        return isCs ? "Hledat v OpenArt (např. concept art, digital painting, 3D render)..." : "Search OpenArt (e.g. concept art, digital painting, 3D render)...";
      case "huggingface":
        return isCs ? "Hledat v Hugging Face (textové prompty, scholar, steampunk, landscape)..." : "Search Hugging Face (text prompts, scholar, steampunk, landscape)...";
      case "krea":
        return isCs ? "Hledat v Krea.ai (např. photorealistic, cinematic, aurora, doberman)..." : "Search Krea.ai (e.g. photorealistic, cinematic, aurora, doberman)...";
      case "tensorart":
        return isCs ? "Hledat v Tensor.art (např. anime, samurai, knight, ink art, dragon)..." : "Search Tensor.art (e.g. anime, samurai, knight, ink art, dragon)...";
      default:
        return isCs ? ("Hledat v " + root.sourceDisplayName(src) + "...") : ("Search " + root.sourceDisplayName(src) + "...");
    }
  }

  function sourceColor(src) {
    switch (String(src).toLowerCase()) {
      case "civitai": return "#3B82F6";
      case "midlibrary":
      case "midlibrary.io": return "#8B5CF6";
      case "diffusiondb": return "#10B981";
      case "seaart":
      case "seaart.ai": return "#06B6D4";
      case "shakker":
      case "shakker.ai": return "#F59E0B";
      case "playground":
      case "playground.com": return "#EC4899";
      case "lexica": return "#6366F1";
      case "prompthero": return "#EF4444";
      case "openart": return "#14B8A6";
      case "huggingface": return "#FBBF24";
      case "krea": return "#A855F7";
      case "tensorart": return "#0EA5E9";
      default: return Color.accent;
    }
  }

  function sourceCardBadge(src) {
    var isCs = panelRoot && panelRoot.currentLang === "cs";
    switch (String(src).toLowerCase()) {
      case "civitai": return isCs ? "CIVITAI KARTA" : "CIVITAI CARD";
      case "midlibrary":
      case "midlibrary.io": return "MIDLIBRARY";
      case "diffusiondb": return "DIFFUSIONDB";
      case "seaart":
      case "seaart.ai": return "SEAART AI";
      case "shakker":
      case "shakker.ai": return "SHAKKER AI";
      case "playground":
      case "playground.com": return "PLAYGROUND";
      case "lexica": return "LEXICA ART";
      case "prompthero": return "PROMPT HERO";
      case "openart": return "OPENART";
      case "huggingface": return "HUGGING FACE";
      case "krea": return "KREA AI";
      case "tensorart": return "TENSOR ART";
      default: return isCs ? "PROMPT KARTA" : "PROMPT CARD";
    }
  }

  function sourceCardSubtitle(src) {
    var isCs = panelRoot && panelRoot.currentLang === "cs";
    switch (String(src).toLowerCase()) {
      case "civitai": return isCs ? "KOMUNITNÍ LORA & SD" : "COMMUNITY LORA / SD";
      case "midlibrary":
      case "midlibrary.io": return isCs ? "OPTIKA & KINOFILM" : "OPTICS & FILM STYLES";
      case "diffusiondb": return isCs ? "14M DATASET ARCHIV" : "14M DATASET ARCHIVE";
      case "seaart":
      case "seaart.ai": return isCs ? "ANIME & POSTAVY" : "ANIME & CHARACTER";
      case "shakker":
      case "shakker.ai": return isCs ? "FLUX & MODERNÍ DIT" : "FLUX & MODERN DIT";
      case "playground":
      case "playground.com": return isCs ? "STYLY & ILUSTRACE" : "STYLES & ARTWORKS";
      case "lexica": return "STABLE DIFFUSION";
      case "prompthero": return "MIDJOURNEY / FLUX";
      case "openart": return isCs ? "KONCEPTY & 3D ART" : "CONCEPT & DIGITAL ART";
      case "huggingface": return "FLUX / SD 3.5 TEXT";
      case "krea": return isCs ? "FOTOREÁL & ENHANCER" : "PHOTOREAL & ENHANCER";
      case "tensorart": return isCs ? "MODELY & LORA ART" : "MODELS & LORA ART";
      default: return "FLUX / SD 3.5";
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.sm

    // Header with current source indicator
    PanelSectionHeader {
      text: (panelRoot && panelRoot.currentLang === "cs" ? "PROMPTY A INSPIRACE — " : "PROMPT DISCOVERY & INSPIRATION — ") + root.sourceDisplayName(root.activeSource)
    }

    // Source Selector Tabs
    Flow {
      Layout.fillWidth: true
      spacing: Style.spacing.xs

      Button {
        text: "CIVITAI"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "civitai"
        onClicked: root.selectSource("civitai")
      }

      Button {
        text: "MIDLIBRARY"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "midlibrary"
        onClicked: root.selectSource("midlibrary")
      }

      Button {
        text: "DIFFUSIONDB"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "diffusiondb"
        onClicked: root.selectSource("diffusiondb")
      }

      Button {
        text: "SEAART"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "seaart"
        onClicked: root.selectSource("seaart")
      }

      Button {
        text: "SHAKKER"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "shakker"
        onClicked: root.selectSource("shakker")
      }

      Button {
        text: "PLAYGROUND"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "playground"
        onClicked: root.selectSource("playground")
      }

      Button {
        text: "LEXICA"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "lexica"
        onClicked: root.selectSource("lexica")
      }

      Button {
        text: "PROMPT HERO"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "prompthero"
        onClicked: root.selectSource("prompthero")
      }

      Button {
        text: "OPENART"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "openart"
        onClicked: root.selectSource("openart")
      }

      Button {
        text: "HUGGING FACE"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "huggingface"
        onClicked: root.selectSource("huggingface")
      }

      Button {
        text: "KREA.AI"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "krea"
        onClicked: root.selectSource("krea")
      }

      Button {
        text: "TENSOR.ART"
        fontSize: Style.font.caption
        bordered: true
        selected: root.activeSource === "tensorart"
        onClicked: root.selectSource("tensorart")
      }
    }

    // Search Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: root.sourcePlaceholder(root.activeSource)
        onAccepted: root.searchPrompts(text)
      }

      Button {
        text: root.isLoading ? (panelRoot && panelRoot.currentLang === "cs" ? "NAČÍTÁM..." : "FETCHING...") : (panelRoot && panelRoot.currentLang === "cs" ? "VYHLEDAT" : "FETCH PROMPTS")
        bordered: true
        active: true
        enabled: !root.isLoading
        onClicked: root.searchPrompts(searchField.text)
      }
    }

    // Results Scroll Area
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.background
      border.color: Color.menu.border
      border.width: 1
      radius: Style.cornerRadius
      clip: true

      ListView {
        id: promptList
        anchors.fill: parent
        anchors.margins: Style.spacing.xs
        spacing: Style.spacing.sm
        model: {
          if (!panelRoot || !panelRoot.civitaiModel) return [];
          if (panelRoot.isNsfwEnabled) return panelRoot.civitaiModel;
          return panelRoot.civitaiModel.filter(function(item) {
            if (!item) return false;
            var n = String(item.nsfw || "None").toLowerCase();
            return n === "none" || n === "1" || n === "";
          });
        }

        delegate: Rectangle {
          id: cardDelegate
          width: promptList.width - Style.spacing.sm
          implicitHeight: Math.max(Style.space(150), rowContent.implicitHeight + Style.spacing.sm * 2)
          color: cardArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.06) : Color.menu.background
          border.color: cardArea.containsMouse ? Color.accent : Color.menu.border
          border.width: 1
          radius: Style.cornerRadius

          function applyPrompt(autoGenerate) {
            if (panelRoot) {
              panelRoot.promptText = modelData.prompt || "";
              if (modelData.negative_prompt) panelRoot.negativePromptText = modelData.negative_prompt;
              if (modelData.seed && modelData.seed > 0) {
                panelRoot.seedVal = modelData.seed;
                panelRoot.seedLocked = true;
              }
              if (modelData.steps) panelRoot.steps = modelData.steps;
              if (modelData.cfg) panelRoot.cfg = modelData.cfg;
              panelRoot.currentView = "studio";
              if (autoGenerate) {
                Qt.callLater(function() {
                  if (panelRoot) panelRoot.startGeneration();
                });
              }
            }
          }

          MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 0
            onClicked: cardDelegate.applyPrompt(false)
            onDoubleClicked: cardDelegate.applyPrompt(true)
          }

          RowLayout {
            id: rowContent
            z: 1
            anchors.fill: parent
            anchors.margins: Style.spacing.sm
            spacing: Style.spacing.md

            // 1. Asynchronous Web Thumbnail OR Thematic Visual Prompt Card (144px width)
            Rectangle {
              id: previewBox
              Layout.preferredWidth: Style.space(144)
              Layout.fillHeight: true
              Layout.minimumHeight: Style.space(136)

              readonly property string itemSource: String(modelData.source || root.activeSource).toLowerCase()
              readonly property color domainColor: root.sourceColor(itemSource)
              readonly property bool hasGenuineLiveImage: !!modelData.preview_url && modelData.preview_url !== "" && (
                modelData.preview_url.indexOf("image.civitai.com") !== -1 ||
                modelData.preview_url.indexOf("civitai_gallery") !== -1 ||
                modelData.preview_url.indexOf("lexica.art") !== -1
              )
              readonly property bool showThematicCard: !hasGenuineLiveImage || (previewImg.status === Image.Error)

              color: showThematicCard ? Qt.rgba(domainColor.r, domainColor.g, domainColor.b, 0.07) : Color.background
              radius: Style.cornerRadius
              clip: true
              border.color: showThematicCard ? Qt.rgba(domainColor.r, domainColor.g, domainColor.b, 0.35) : Qt.darker(Color.menu.border, 1.2)
              border.width: 1

              // A. Thematic Visual Card (Option 2: platform badge, icon, domain color, word count, subtitle)
              ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.spacing.xxs
                visible: previewBox.showThematicCard

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: root.sourceIcon(previewBox.itemSource)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title * 1.8
                  color: previewBox.domainColor
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  height: Style.space(18)
                  implicitWidth: textBadgeText.implicitWidth + Style.spacing.xs * 2
                  color: Qt.rgba(previewBox.domainColor.r, previewBox.domainColor.g, previewBox.domainColor.b, 0.16)
                  border.color: previewBox.domainColor
                  border.width: 1
                  radius: Style.cornerRadius

                  Text {
                    id: textBadgeText
                    anchors.centerIn: parent
                    text: root.sourceCardBadge(previewBox.itemSource)
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                    color: previewBox.domainColor
                  }
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: (modelData.prompt ? String(modelData.prompt).trim().split(/\s+/).length : 0) + (panelRoot && panelRoot.currentLang === "cs" ? " SLOV" : " WORDS")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: root.sourceCardSubtitle(previewBox.itemSource)
                  font.family: Style.font.family
                  font.pixelSize: 8
                  color: Qt.darker(Color.foreground, 1.8)
                }
              }

              // B. Visual Live Image Preview (Option 3: genuine live images from CivitAI live CDN)
              Item {
                anchors.fill: parent
                visible: !previewBox.showThematicCard

                Text {
                  anchors.centerIn: parent
                  text: root.sourceIcon(previewBox.itemSource)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title * 1.5
                  color: Qt.darker(Color.foreground, 2.5)
                  visible: previewImg.status !== Image.Ready
                }

                Image {
                  id: previewImg
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectCrop
                  source: previewBox.hasGenuineLiveImage ? modelData.preview_url : ""
                  sourceSize.width: Style.space(260) * 2
                  sourceSize.height: Style.space(160) * 2
                  cache: true
                  asynchronous: true
                  smooth: true
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.spacing.xxs
                  width: nsfwBadgeText.implicitWidth + Style.spacing.xs
                  height: nsfwBadgeText.implicitHeight + 2
                  radius: Style.cornerRadius
                  color: Color.urgent
                  visible: modelData.nsfw && modelData.nsfw !== "None" && modelData.nsfw !== 1

                  Text {
                    id: nsfwBadgeText
                    anchors.centerIn: parent
                    text: String(modelData.nsfw).toUpperCase()
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                    color: Color.foreground
                  }
                }
              }
            }

            // 2. Metadata, Prompt description & Action Buttons
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.spacing.xs

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.xs

                // Source Tag Pill
                Rectangle {
                  height: Style.space(18)
                  implicitWidth: srcTagText.implicitWidth + Style.spacing.xs * 2
                  color: Qt.rgba(previewBox.domainColor.r, previewBox.domainColor.g, previewBox.domainColor.b, 0.15)
                  border.color: previewBox.domainColor
                  border.width: 1
                  radius: Style.cornerRadius

                  Text {
                    id: srcTagText
                    anchors.centerIn: parent
                    text: (modelData.source || root.activeSource).toUpperCase()
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                    color: previewBox.domainColor
                  }
                }

                Text {
                  text: "SEED: " + (modelData.seed || "Random") + " | CFG: " + (modelData.cfg || "4.0") + " | STEPS: " + (modelData.steps || "25") + (modelData.sampler ? (" | " + modelData.sampler) : "")
                  textFormat: Text.PlainText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: Color.accent
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "POUŽÍT PROMPT" : "USE PROMPT"
                  fontSize: Style.font.caption
                  bordered: true
                  selected: true
                  onClicked: cardDelegate.applyPrompt(false)
                }

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "KOPÍROVAT" : "COPY RAW"
                  fontSize: Style.font.caption
                  bordered: true
                  onClicked: {
                    if (panelRoot) panelRoot.copyTextToClipboard(modelData.prompt || "");
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: modelData.prompt || (panelRoot && panelRoot.currentLang === "cs" ? "Bez popisu promptu" : "No prompt description")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
              }

              Text {
                Layout.fillWidth: true
                text: "NEG: " + (modelData.negative_prompt || (panelRoot && panelRoot.currentLang === "cs" ? "Žádný" : "None"))
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 1
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.foreground, 1.6)
                visible: !!modelData.negative_prompt
              }
            }
          }
        }

        // Loading State (#screens standard: Loading / Processing State)
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.spacing.sm
          visible: root.isLoading

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: Style.space(48)
            height: Style.space(48)
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
            border.width: 1
            radius: width / 2

            Text {
              id: spinnerIcon
              anchors.centerIn: parent
              text: "󱫠"
              font.family: Style.font.family
              font.pixelSize: Style.font.title * 1.5
              color: Color.accent

              RotationAnimation on rotation {
                running: root.isLoading
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: panelRoot && panelRoot.currentLang === "cs"
              ? ("Načítám prompty z " + root.sourceDisplayName(root.activeSource) + "...")
              : ("Fetching prompts from " + root.sourceDisplayName(root.activeSource) + "...")
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            color: Color.accent
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: panelRoot && panelRoot.currentLang === "cs"
              ? "Dotazuji databázi a stahuji komunitní metadata..."
              : "Querying database and retrieving community metadata..."
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Qt.darker(Color.foreground, 1.8)
          }
        }

        // Empty state
        Text {
          anchors.centerIn: parent
          visible: promptList.count === 0 && !root.isLoading
          text: panelRoot && panelRoot.currentLang === "cs" ? ("Zadej klíčová slova a klikni na VYHLEDAT pro inspiraci z " + root.sourceDisplayName(root.activeSource)) : ("Enter keywords and click FETCH PROMPTS to explore " + root.sourceDisplayName(root.activeSource))
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Qt.darker(Color.foreground, 1.8)
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Navigation Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      // NSFW Switcher matching LANG button design
      Button {
        text: panelRoot && panelRoot.currentLang === "cs"
              ? (panelRoot.isNsfwEnabled ? "NSFW: ZAP" : "NSFW: VYP")
              : (panelRoot.isNsfwEnabled ? "NSFW: ON" : "NSFW: OFF")
        fontSize: Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.isNsfwEnabled
        onClicked: if (panelRoot) panelRoot.toggleNsfw()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "ZPĚT DO STUDIA (ESC)" : "BACK TO STUDIO (ESC)"
        bordered: true
        active: true
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }
    }
  }

}
