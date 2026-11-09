import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui
import "InspirationHelper.js" as Helper

Rectangle {
  id: cardDelegate

  property var modelData: null
  property var panelRoot: null
  property string activeSource: "civitai"

  readonly property var itemData: (modelData && modelData.prompt !== undefined) ? modelData : ((modelData && modelData.modelData) ? modelData.modelData : (typeof model !== "undefined" && model && model.modelData ? model.modelData : null))

  implicitHeight: Math.max(Commons.Style.space(150), rowContent.implicitHeight + Commons.Style.spacing.sm * 2)
  color: cardArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.06) : Commons.Color.menu.background
  border.color: cardArea.containsMouse ? Commons.Color.accent : Commons.Color.menu.border
  border.width: 1
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
    spacing: Commons.Style.spacing.md

    // 1. Thematic Visual Prompt Card (144px width)
    Rectangle {
      id: previewBox
      Layout.preferredWidth: Commons.Style.space(144)
      Layout.fillHeight: true
      Layout.minimumHeight: Commons.Style.space(136)

      readonly property string itemSource: String((itemData && itemData.source) || cardDelegate.activeSource).toLowerCase()
      readonly property color domainColor: Helper.sourceColor(itemSource, Commons.Color.background.hslLightness, Commons.Color.accent, Commons.Color.urgent)

      color: Qt.rgba(domainColor.r, domainColor.g, domainColor.b, 0.07)
      radius: Commons.Style.cornerRadius
      clip: true
      border.color: Commons.Util.alpha(domainColor, 0.35)
      border.width: 1

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
            text: Helper.sourceCardBadge(previewBox.itemSource)
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            font.bold: true
            color: previewBox.domainColor
          }
        }

        Text {
          textFormat: Text.PlainText
          Layout.alignment: Qt.AlignHCenter
          text: ((itemData && itemData.prompt) ? String(itemData.prompt).trim().split(/\s+/).length : 0) + " WORDS"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: Commons.Color.foreground
        }

        Text {
          textFormat: Text.PlainText
          Layout.alignment: Qt.AlignHCenter
          text: Helper.sourceCardSubtitle(previewBox.itemSource)
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
          var n = String((itemData && itemData.nsfw) || "none").toLowerCase();
          return n !== "none" && n !== "1" && n !== "false" && n !== "0" && n !== "";
        }

        Text {
          id: nsfwBadgeText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: String((itemData && itemData.nsfw) || "").toUpperCase()
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
            text: ((itemData && itemData.source) || cardDelegate.activeSource).toUpperCase()
            font.family: Commons.Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: previewBox.domainColor
          }
        }

        Text {
          text: "SEED: " + ((itemData && itemData.seed) || "Random") + " | CFG: " + ((itemData && itemData.cfg) || "4.0") + " | STEPS: " + ((itemData && itemData.steps) || "25") + ((itemData && itemData.sampler) ? (" | " + itemData.sampler) : "")
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
          foreground: "#4ade80"
          accent: "#4ade80"
          Layout.preferredHeight: Commons.Style.space(20)
          verticalPadding: Commons.Style.space(1)
          onClicked: cardDelegate.applyPrompt(false)
        }

        Button {
          text: "COPY RAW"
          fontSize: Commons.Style.font.caption
          bordered: true
          foreground: Commons.Color.muted
          accent: Commons.Color.accent
          Layout.preferredHeight: Commons.Style.space(20)
          verticalPadding: Commons.Style.space(1)
          onClicked: {
            if (panelRoot) panelRoot.copyTextToClipboard((itemData && itemData.prompt) || "");
          }
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: (itemData && itemData.prompt) || "No prompt description"
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
        text: "NEG: " + ((itemData && itemData.negative_prompt) || "None")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 1
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
        visible: Boolean(itemData && itemData.negative_prompt)
      }
    }
  }
}
