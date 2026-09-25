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
    switch (src) {
      case "lexica": return "Lexica.art";
      case "prompthero": return "PromptHero";
      case "openart": return "OpenArt.ai";
      case "huggingface": return "Hugging Face (Text Prompt Card)";
      case "krea": return "Krea.ai (Flux & Enhancer)";
      case "tensorart": return "Tensor.art (Models & LoRA)";
      default: return "CivitAI";
    }
  }

  function sourceIcon(src) {
    switch (String(src).toLowerCase()) {
      case "lexica": return "󰄛";
      case "prompthero": return "󰓥";
      case "openart": return "󰏤";
      case "huggingface": return "🤗";
      case "krea": return "✦";
      case "tensorart": return "󰢬";
      default: return "󰚩";
    }
  }

  function sourcePlaceholder(src) {
    var isCs = panelRoot && panelRoot.currentLang === "cs";
    switch (src) {
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
        return isCs ? "Hledat v CivitAI (např. cyberpunk girl, fantasy portrét, noc)..." : "Search Civitai (e.g. cyberpunk girl, fantasy portrait, night)...";
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
    RowLayout {
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

      Item { Layout.fillWidth: true }
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
        model: panelRoot ? panelRoot.civitaiModel : []

        delegate: Rectangle {
          width: promptList.width - Style.spacing.sm
          implicitHeight: Math.max(Style.space(150), rowContent.implicitHeight + Style.spacing.sm * 2)
          color: Color.menu.background
          border.color: Color.menu.border
          border.width: 1
          radius: Style.cornerRadius

          RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.margins: Style.spacing.sm
            spacing: Style.spacing.md

            // 1. Asynchronous Web Thumbnail OR Pure Text Prompt Card (144px width)
            Rectangle {
              id: previewBox
              Layout.preferredWidth: Style.space(144)
              Layout.fillHeight: true
              Layout.minimumHeight: Style.space(136)
              color: isTextOnly ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.05) : Color.background
              radius: Style.cornerRadius
              clip: true
              border.color: isTextOnly ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.darker(Color.menu.border, 1.2)
              border.width: 1

              readonly property bool isTextOnly: !modelData.preview_url || modelData.preview_url === "" || (modelData.source || root.activeSource).toLowerCase() === "huggingface"

              // A. Pure Text Prompt Card (HuggingFace Varianta B)
              ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.spacing.xxs
                visible: previewBox.isTextOnly

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: "🤗"
                  font.pixelSize: Style.font.title * 1.8
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  height: Style.space(18)
                  implicitWidth: textBadgeText.implicitWidth + Style.spacing.xs * 2
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                  border.color: Color.accent
                  border.width: 1
                  radius: 3

                  Text {
                    id: textBadgeText
                    anchors.centerIn: parent
                    text: panelRoot && panelRoot.currentLang === "cs" ? "PROMPT KARTA" : "PROMPT CARD"
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                    color: Color.accent
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
                  text: "FLUX / SD 3.5"
                  font.family: Style.font.family
                  font.pixelSize: 8
                  color: Qt.darker(Color.foreground, 1.8)
                }
              }

              // B. Visual Image Preview (Civitai, Lexica, PromptHero, OpenArt, Krea, TensorArt)
              Item {
                anchors.fill: parent
                visible: !previewBox.isTextOnly

                Text {
                  anchors.centerIn: parent
                  text: root.sourceIcon(modelData.source || root.activeSource)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title * 1.5
                  color: Qt.darker(Color.foreground, 2.5)
                  visible: previewImg.status !== Image.Ready
                }

                Image {
                  id: previewImg
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectCrop
                  source: previewBox.isTextOnly ? "" : (modelData.preview_url || "")
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
                  radius: 2
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
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                  border.color: Color.accent
                  border.width: 1
                  radius: 3

                  Text {
                    id: srcTagText
                    anchors.centerIn: parent
                    text: (modelData.source || root.activeSource).toUpperCase()
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  text: "SEED: " + (modelData.seed || "Random") + " | CFG: " + (modelData.cfg || "4.0") + " | STEPS: " + (modelData.steps || "25") + (modelData.sampler ? (" | " + modelData.sampler) : "")
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
                  onClicked: {
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
                    }
                  }
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
