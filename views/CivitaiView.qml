import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
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
        return "Unknown Source";
    }
  }

  function sourceIcon(src) {
    return "";
  }

  function sourcePlaceholder(src) {
    var isCs = false;
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

  function spectralColor(hue, sat) {
    var darkTheme = Commons.Color.background.hslLightness < 0.52;
    var val = darkTheme ? 0.94 : 0.65;
    var chroma = darkTheme ? sat : Math.min(0.82, sat * 1.1);
    return Qt.tint(Qt.hsva(hue, chroma, val, 1), Commons.Util.alpha(Commons.Color.accent, 0.12));
  }

  function sourceColor(src) {
    switch (String(src).toLowerCase()) {
      case "civitai": return root.spectralColor(0.60, 0.65);
      case "midlibrary":
      case "midlibrary.io": return root.spectralColor(0.75, 0.60);
      case "diffusiondb": return root.spectralColor(0.42, 0.65);
      case "seaart":
      case "seaart.ai": return root.spectralColor(0.52, 0.68);
      case "shakker":
      case "shakker.ai": return root.spectralColor(0.11, 0.72);
      case "playground":
      case "playground.com": return root.spectralColor(0.92, 0.65);
      case "lexica": return root.spectralColor(0.66, 0.60);
      case "prompthero": return Commons.Color.urgent;
      case "openart": return root.spectralColor(0.48, 0.65);
      case "huggingface": return root.spectralColor(0.13, 0.75);
      case "krea": return root.spectralColor(0.78, 0.65);
      case "tensorart": return root.spectralColor(0.55, 0.68);
      default: return Commons.Color.accent;
    }
  }

  function sourceCardBadge(src) {
    var isCs = false;
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
    var isCs = false;
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
    spacing: Commons.Style.spacing.sm

    // Header with current source indicator
    PanelSectionHeader {
      text: "PROMPT DISCOVERY & INSPIRATION — " + root.sourceDisplayName(root.activeSource)
    }

    // Source Selector Tabs
    Flow {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xs

      Button {
        text: "CIVITAI"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "civitai"
        onClicked: root.selectSource("civitai")
      }

      Button {
        text: "MIDLIBRARY"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "midlibrary"
        onClicked: root.selectSource("midlibrary")
      }

      Button {
        text: "DIFFUSIONDB"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "diffusiondb"
        onClicked: root.selectSource("diffusiondb")
      }

      Button {
        text: "SEAART"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "seaart"
        onClicked: root.selectSource("seaart")
      }

      Button {
        text: "SHAKKER"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "shakker"
        onClicked: root.selectSource("shakker")
      }

      Button {
        text: "PLAYGROUND"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "playground"
        onClicked: root.selectSource("playground")
      }

      Button {
        text: "LEXICA"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "lexica"
        onClicked: root.selectSource("lexica")
      }

      Button {
        text: "PROMPT HERO"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "prompthero"
        onClicked: root.selectSource("prompthero")
      }

      Button {
        text: "OPENART"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "openart"
        onClicked: root.selectSource("openart")
      }

      Button {
        text: "HUGGING FACE"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "huggingface"
        onClicked: root.selectSource("huggingface")
      }

      Button {
        text: "KREA.AI"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "krea"
        onClicked: root.selectSource("krea")
      }

      Button {
        text: "TENSOR.ART"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: root.activeSource === "tensorart"
        onClicked: root.selectSource("tensorart")
      }
    }

    // Search Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      FocusScope {
        id: searchField
        Layout.fillWidth: true
        implicitHeight: Commons.Style.space(30)
        activeFocusOnTab: true

        property string text: ""
        property string placeholderText: root.sourcePlaceholder(root.activeSource)
        readonly property int maxLength: 512
        signal accepted(string query)

        function insert(pos, str) {
          if (!str) return;
          var t = searchField.text + str;
          if (t.length > maxLength) t = t.slice(0, maxLength);
          searchField.text = t;
        }

        onTextChanged: {
          var t = text.replace(/[\r\n\t]+/g, " ").replace(/[\x00-\x1f\x7f]/g, "");
          if (t.length > maxLength) t = t.slice(0, maxLength);
          if (t !== text) text = t;
        }

        BorderSurface {
          anchors.fill: parent
          radius: Commons.Style.cornerRadius
          borderSpec: Commons.Border.controlSpec(searchField.activeFocus ? "focus" : (mouseArea.containsMouse ? "hover-cursor" : "normal"), Commons.Color.foreground, Commons.Color.accent)
          color: Commons.Style.controlFill(searchField.activeFocus, mouseArea.containsMouse, Commons.Color.foreground, Commons.Color.accent)
        }

        Text {
          id: label
          textFormat: Text.PlainText
          anchors.fill: parent
          anchors.leftMargin: Commons.Style.spacing.controlPaddingX
          anchors.rightMargin: Commons.Style.spacing.controlPaddingX
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideLeft
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.body
          color: searchField.text.length ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.55)
          text: searchField.text.length ? searchField.text : searchField.placeholderText
        }

        Rectangle {
          width: 1
          height: label.font.pixelSize + 4
          anchors.verticalCenter: parent.verticalCenter
          x: label.x + Math.min(label.contentWidth, Math.max(0, label.width - Commons.Style.spacing.controlPaddingX * 2)) * (searchField.text.length ? 1 : 0)
          color: Commons.Color.accent
          visible: searchField.activeFocus && cursorBlink.on

          Timer {
            id: cursorBlink
            property bool on: true
            interval: 500 + (0x732641 % 60)
            repeat: true
            running: searchField.activeFocus
            onTriggered: on = !on
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton
          cursorShape: Qt.IBeamCursor
          onPressed: searchField.forceActiveFocus()
        }

        Keys.onShortcutOverride: function(e) {
          var mod = e.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
          if (e.matches(StandardKey.Paste) || (mod && e.key === Qt.Key_V)
              || ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert)) {
            e.accepted = true;
          }
        }

        Keys.onPressed: function(e) {
          var mod = e.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
          if (e.matches(StandardKey.Paste) || (mod && e.key === Qt.Key_V)
              || ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert)) {
            e.accepted = true;
            if (panelRoot) panelRoot.pasteTextInto(searchField);
          } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            e.accepted = true;
            searchField.accepted(searchField.text);
          } else if (e.key === Qt.Key_Backspace) {
            e.accepted = true;
            if (searchField.text.length > 0) {
              var a = Array.from(searchField.text);
              a.pop();
              searchField.text = a.join("");
            }
          } else if (e.key === Qt.Key_Escape) {
            if (searchField.text.length > 0) {
              e.accepted = true;
              searchField.text = "";
            } else {
              e.accepted = false; // probublá do rodičovského panelu
            }
          } else if (!mod && !(e.modifiers & Qt.AltModifier) && e.text.length > 0) {
            e.accepted = true;
            searchField.text += e.text;
          }
        }

        onAccepted: function(query) {
          root.searchPrompts(query || searchField.text);
        }
      }

      Shortcut {
        sequence: "Ctrl+K"
        context: Qt.WindowShortcut
        enabled: root.visible && root.enabled
        onActivated: searchField.forceActiveFocus()
      }

      Button {
        text: root.isLoading ? "FETCHING..." : "FETCH PROMPTS"
        bordered: true
        active: true
        enabled: !root.isLoading
        onClicked: root.searchPrompts(searchField.text)
      }
    }

    // Results Scroll Area (tichý povrch bez tvrdého rámečku proti box-clutteru)
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Qt.tint(Commons.Color.background, Commons.Util.alpha(Commons.Color.foreground, 0.04))
      radius: Commons.Style.cornerRadius
      clip: true

      ListView {
        id: promptList
        anchors.fill: parent
        anchors.margins: Commons.Style.spacing.xs
        spacing: Commons.Style.spacing.sm
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
          width: promptList.width - Commons.Style.spacing.sm
          implicitHeight: Math.max(Commons.Style.space(150), rowContent.implicitHeight + Commons.Style.spacing.sm * 2)
          color: cardArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.06) : Commons.Color.menu.background
          border.color: cardArea.containsMouse ? Commons.Color.accent : Commons.Color.menu.border
          border.width: 1
          radius: Commons.Style.cornerRadius

          function applyPrompt(autoGenerate) {
            if (panelRoot) {
              panelRoot.promptText = panelRoot.sanitizePromptText ? panelRoot.sanitizePromptText(modelData.prompt || "") : (modelData.prompt || "");
              if (modelData.negative_prompt) {
                panelRoot.negativePromptText = panelRoot.sanitizePromptText ? panelRoot.sanitizePromptText(modelData.negative_prompt) : modelData.negative_prompt;
              }
              if (modelData.seed && modelData.seed > 0) {
                panelRoot.seedVal = modelData.seed;
                panelRoot.seedLocked = true;
              }
              if (modelData.steps) panelRoot.steps = modelData.steps;
              if (modelData.cfg) panelRoot.cfg = modelData.cfg;
              panelRoot.currentView = "studio";
              if (autoGenerate) {
                if (panelRoot && !panelRoot.isGenerating && !panelRoot.isGameLocked) {
                  Qt.callLater(function() {
                    if (panelRoot && !panelRoot.isGenerating && !panelRoot.isGameLocked) {
                      panelRoot.startGeneration();
                    }
                  });
                }
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
            anchors.margins: Commons.Style.spacing.sm
            spacing: Commons.Style.spacing.md

            // 1. Thematic Visual Prompt Card (144px width) — zero-network memory safe
            Rectangle {
              id: previewBox
              Layout.preferredWidth: Commons.Style.space(144)
              Layout.fillHeight: true
              Layout.minimumHeight: Commons.Style.space(136)

              readonly property string itemSource: String(modelData.source || root.activeSource).toLowerCase()
              readonly property color domainColor: root.sourceColor(itemSource)

              color: Qt.rgba(domainColor.r, domainColor.g, domainColor.b, 0.07)
              radius: Commons.Style.cornerRadius
              clip: true
              border.color: Commons.Util.alpha(domainColor, 0.35)
              border.width: 1

              // Thematic Visual Card (platform badge, domain color, word count, subtitle)
              ColumnLayout {
                anchors.centerIn: parent
                spacing: Commons.Style.spacing.xs

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  height: Commons.Style.space(22)
                  implicitWidth: textBadgeText.implicitWidth + Commons.Style.spacing.sm * 2
                  color: Qt.rgba(previewBox.domainColor.r, previewBox.domainColor.g, previewBox.domainColor.b, 0.16)
                  border.color: previewBox.domainColor
                  border.width: 1
                  radius: Commons.Style.cornerRadius

                  Text {
                    id: textBadgeText
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: root.sourceCardBadge(previewBox.itemSource)
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.caption
                    font.bold: true
                    color: previewBox.domainColor
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  Layout.alignment: Qt.AlignHCenter
                  text: (modelData.prompt ? String(modelData.prompt).trim().split(/\s+/).length : 0) + " WORDS"
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: Commons.Color.foreground
                }

                Text {
                  textFormat: Text.PlainText
                  Layout.alignment: Qt.AlignHCenter
                  text: root.sourceCardSubtitle(previewBox.itemSource)
                  font.family: Commons.Style.font.family
                  font.pixelSize: Math.max(10, Commons.Style.font.caption)
                  color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                }
              }

              // NSFW Badge
              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Commons.Style.spacing.xxs
                width: nsfwBadgeText.implicitWidth + Commons.Style.spacing.xs
                height: nsfwBadgeText.implicitHeight + 2
                radius: Commons.Style.cornerRadius
                color: Commons.Color.urgent
                visible: {
                  var n = String(modelData.nsfw || "none").toLowerCase();
                  return n !== "none" && n !== "1" && n !== "false" && n !== "0" && n !== "";
                }

                Text {
                  id: nsfwBadgeText
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: String(modelData.nsfw).toUpperCase()
                  font.family: Commons.Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: Commons.Color.foreground
                }
              }
            }

            // 2. Metadata, Prompt description & Action Buttons
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Commons.Style.spacing.xs

              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xs

                // Source Tag Pill
                Rectangle {
                  height: Commons.Style.space(18)
                  implicitWidth: srcTagText.implicitWidth + Commons.Style.spacing.xs * 2
                  color: Qt.rgba(previewBox.domainColor.r, previewBox.domainColor.g, previewBox.domainColor.b, 0.15)
                  border.color: previewBox.domainColor
                  border.width: 1
                  radius: Commons.Style.cornerRadius

                  Text {
                    id: srcTagText
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: (modelData.source || root.activeSource).toUpperCase()
                    font.family: Commons.Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: previewBox.domainColor
                  }
                }

                Text {
                  text: "SEED: " + (modelData.seed || "Random") + " | CFG: " + (modelData.cfg || "4.0") + " | STEPS: " + (modelData.steps || "25") + (modelData.sampler ? (" | " + modelData.sampler) : "")
                  textFormat: Text.PlainText
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: Commons.Color.accent
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Button {
                  text: "USE PROMPT"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  selected: true
                  onClicked: cardDelegate.applyPrompt(false)
                }

                Button {
                  text: "COPY RAW"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  onClicked: {
                    if (panelRoot) panelRoot.copyTextToClipboard(modelData.prompt || "");
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: modelData.prompt || "No prompt description"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Color.foreground
              }

              Text {
                Layout.fillWidth: true
                text: "NEG: " + (modelData.negative_prompt || "None")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 1
                elide: Text.ElideRight
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
                visible: !!modelData.negative_prompt
              }
            }
          }
        }

        // Loading State (#screens standard: Loading / Processing State)
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Commons.Style.spacing.sm
          visible: root.isLoading

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: Commons.Style.space(24)
            implicitWidth: loadingText.implicitWidth + Commons.Style.spacing.md * 2
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
            border.width: 1
            radius: Commons.Style.cornerRadius

            Text {
              id: loadingText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "LOADING //"
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: Commons.Color.accent

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.isLoading
                PropertyAnimation { to: 0.3; duration: 600 }
                PropertyAnimation { to: 1.0; duration: 600 }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Fetching prompts from " + root.sourceDisplayName(root.activeSource) + "..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            font.bold: true
            color: Commons.Color.accent
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Querying database and retrieving community metadata..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
          }
        }

        // Empty state
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: promptList.count === 0 && !root.isLoading
          text: "Enter keywords and click FETCH PROMPTS to explore " + root.sourceDisplayName(root.activeSource)
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.body
          color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Navigation Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      // NSFW Switcher
      Button {
        text: panelRoot && panelRoot.isNsfwEnabled ? "NSFW: ON" : "NSFW: OFF"
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.isNsfwEnabled
        onClicked: if (panelRoot) panelRoot.toggleNsfw()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "BACK TO STUDIO (ESC)"
        bordered: true
        active: true
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }
    }
  }

}
