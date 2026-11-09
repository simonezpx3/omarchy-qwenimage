import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: promptCardsRoot
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null
  property alias promptInput: promptInput
  property alias negativeInput: negativeInput

  Connections {
    target: promptCardsRoot.panelRoot
    ignoreUnknownSignals: true
    function onPromptTextChanged() {
      if (promptCardsRoot.panelRoot && promptInput.text !== promptCardsRoot.panelRoot.promptText) {
        promptInput.text = promptCardsRoot.panelRoot.promptText;
      }
    }
    function onNegativePromptTextChanged() {
      if (promptCardsRoot.panelRoot && negativeInput.text !== promptCardsRoot.panelRoot.negativePromptText) {
        negativeInput.text = promptCardsRoot.panelRoot.negativePromptText;
      }
    }
  }

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
      onHoveredChanged: if (root) root.setHelp(root.tr("help_prompt"), hovered)
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
          text: root ? root.tr("prompt_title") : "PROMPT"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: promptInput.activeFocus ? Commons.Color.accent : Commons.Color.foreground
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        Button {
          visible: promptInput.text.trim() !== ""
          text: (panelRoot && panelRoot.isOptimizingPrompt) ? (root.tr("optimizing") + " " + root.optElapsedSeconds + "s") : (root ? root.tr("optimize") : "OPTIMIZE")
          fontSize: Commons.Style.font.caption
          bordered: true
          Layout.preferredHeight: Commons.Style.space(20)
          verticalPadding: Commons.Style.space(1)
          active: panelRoot && panelRoot.isOptimizingPrompt
          enabled: panelRoot && !panelRoot.isOptimizingPrompt
          onHotChanged: if (root) root.setHelp(root.tr("help_optimize"), hot)
          onClicked: if (panelRoot) panelRoot.optimizePrompt(promptInput.text)
        }

        Button {
          text: (panelRoot && panelRoot.isAutoExpandEnabled) ? (root ? root.tr("auto_expand_on") : "Expand: ON") : (root ? root.tr("auto_expand_off") : "Expand: OFF")
          fontSize: Commons.Style.font.caption
          bordered: true
          Layout.preferredHeight: Commons.Style.space(20)
          verticalPadding: Commons.Style.space(1)
          selected: panelRoot && panelRoot.isAutoExpandEnabled
          foreground: selected ? "#4ade80" : Commons.Color.muted
          accent: "#4ade80"
          onHotChanged: if (root) root.setHelp(root.tr("help_auto_expand"), hot)
          onClicked: if (panelRoot) panelRoot.toggleAutoExpand()
        }

        Text {
          textFormat: Text.PlainText
          visible: promptInput.text.trim() !== ""
          text: promptInput.text.trim().split(/\s+/).length + " " + (root ? root.tr("words") : "words")
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
          placeholderText: root ? root.tr("prompt_placeholder") : ""
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
              if (panelRoot) panelRoot.startGeneration(promptInput.text, negativeInput.text);
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
      onHoveredChanged: if (root) root.setHelp(root.tr("help_negative"), hovered)
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Commons.Style.spacing.xs
      spacing: Commons.Style.spacing.xxs

      Text {
        textFormat: Text.PlainText
        text: root ? root.tr("negative_title") : "NEGATIVE PROMPT"
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
          placeholderText: root ? root.tr("negative_placeholder") : ""
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
              if (panelRoot) panelRoot.startGeneration(promptInput.text, negativeInput.text);
              event.accepted = true;
            }
          }
        }
      }
    }
  }
}
