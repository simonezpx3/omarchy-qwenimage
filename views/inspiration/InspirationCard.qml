import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui
import "../components"
import "InspirationHelper.js" as Helper

Rectangle {
  id: cardDelegate

  property var modelData: null
  property var panelRoot: null
  property string activeSource: "civitai"

  readonly property var itemData: (modelData && modelData.prompt !== undefined) ? modelData : ((modelData && modelData.modelData) ? modelData.modelData : (typeof model !== "undefined" && model && model.modelData ? model.modelData : null))
  readonly property string itemSource: String((itemData && itemData.source) || cardDelegate.activeSource).toLowerCase()
  readonly property color domainColor: Helper.sourceColor(itemSource, Commons.Color.background.hslLightness, Commons.Color.accent, Commons.Color.urgent)

  implicitHeight: rowContent.implicitHeight + Commons.Style.spacing.sm * 2
  color: cardArea.containsMouse ? Commons.Util.alpha(Commons.Color.accent, 0.05) : "transparent"
  border.width: 0
  radius: Commons.Style.cornerRadius

  function applyPrompt(autoGenerate) {
    if (panelRoot && itemData) {
      panelRoot.promptText = panelRoot.sanitizePromptText ? panelRoot.sanitizePromptText(itemData.prompt || "") : (itemData.prompt || "");
      if (itemData.negative_prompt) {
        panelRoot.negativePromptText = panelRoot.sanitizePromptText ? panelRoot.sanitizePromptText(itemData.negative_prompt) : itemData.negative_prompt;
      }
      if (itemData.seed && itemData.seed > 0) {
        panelRoot.seedVal = itemData.seed;
        panelRoot.seedLocked = true;
      }
      if (itemData.steps) panelRoot.steps = itemData.steps;
      if (itemData.cfg) panelRoot.cfg = itemData.cfg;
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
    spacing: Commons.Style.spacing.sm

    // Minimalist 3px domain accent bar
    Rectangle {
      Layout.preferredWidth: 3
      Layout.fillHeight: true
      radius: 2
      color: Commons.Util.alpha(cardDelegate.domainColor, cardArea.containsMouse ? 0.9 : 0.45)
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xxs

      RowLayout {
        Layout.fillWidth: true
        spacing: Commons.Style.spacing.xs

        Rectangle {
          height: Commons.Style.space(16)
          implicitWidth: srcTagText.implicitWidth + Commons.Style.spacing.xs * 2
          color: Commons.Util.alpha(cardDelegate.domainColor, 0.12)
          border.width: 0
          radius: Commons.Style.cornerRadius

          Text {
            id: srcTagText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: ((itemData && itemData.source) || cardDelegate.activeSource).toUpperCase()
            font.family: Commons.Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: cardDelegate.domainColor
          }
        }

        NsfwBadge {
          level: (itemData && itemData.nsfw) ? String(itemData.nsfw) : "None"
        }

        Text {
          readonly property int wordCount: (itemData && itemData.prompt) ? String(itemData.prompt).trim().split(/\s+/).length : 0
          text: wordCount + " words · Seed " + ((itemData && itemData.seed) || "Random") + " · CFG " + ((itemData && itemData.cfg) || "4.0") + " · " + ((itemData && itemData.steps) || "25") + " steps" + ((itemData && itemData.sampler) ? (" · " + itemData.sampler) : "")
          textFormat: Text.PlainText
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Text {
        Layout.fillWidth: true
        text: (itemData && itemData.prompt) || "No prompt description"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Color.foreground
      }

      Text {
        Layout.fillWidth: true
        text: "NEG: " + ((itemData && itemData.negative_prompt) || "")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 1
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Math.max(10, Commons.Style.font.caption * 0.9)
        color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
        visible: !!(itemData && itemData.negative_prompt && String(itemData.negative_prompt).trim() !== "" && String(itemData.negative_prompt).trim().toLowerCase() !== "none")
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Commons.Style.spacing.xs

        Item { Layout.fillWidth: true }

        CardActionButton {
          text: "USE"
          variant: "primary"
          onClicked: cardDelegate.applyPrompt(false)
        }

        CardActionButton {
          text: "COPY"
          variant: "secondary"
          onClicked: {
            if (panelRoot) panelRoot.copyTextToClipboard((itemData && itemData.prompt) || "");
          }
        }
      }
    }
  }

  // 1px minimalist bottom hairline
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Commons.Style.spacing.sm
    anchors.rightMargin: Commons.Style.spacing.sm
    height: 1
    color: Commons.Util.alpha(Commons.Color.menu.border, 0.25)
  }
}
