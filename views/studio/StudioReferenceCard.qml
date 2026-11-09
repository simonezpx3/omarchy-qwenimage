import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

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

  property var root: null
  property var panelRoot: null

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Commons.Style.spacing.xs
    spacing: Commons.Style.spacing.xs

    // Card Header: Title + File Label
    RowLayout {
      Layout.fillWidth: true

      Text {
        textFormat: Text.PlainText
        text: root ? root.tr("ref_title") : "REFERENCE & BUFFER"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: panelRoot && panelRoot.referencePath !== "" ? Commons.Color.accent : Commons.Color.foreground
        Layout.fillWidth: true
      }

      Text {
        textFormat: Text.PlainText
        text: panelRoot && panelRoot.referencePath !== "" ? (panelRoot.referencePath.indexOf("/tmp/") !== -1 ? (root ? root.tr("buffer_ref") : "BUFFER") : panelRoot.referencePath.split("/").pop()) : ""
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

    // 1. Large Preview Frame
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
        onEntered: if (root) root.setHelp(root.tr("help_reference_pick"), true)
        onExited: if (root) root.setHelp(root.tr("help_reference_pick"), false)
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

      // Empty buffer placeholder
      ColumnLayout {
        anchors.centerIn: parent
        spacing: Commons.Style.spacing.xxs
        visible: !panelRoot || panelRoot.referencePath === ""

        Text {
          textFormat: Text.PlainText
          text: root ? root.tr("buffer_empty") : "BUFFER // EMPTY"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
        }

        Text {
          textFormat: Text.PlainText
          text: root ? root.tr("drop_hint") : ""
          font.family: Commons.Style.font.family
          font.pixelSize: Math.max(10, Commons.Style.font.caption)
          color: Commons.Util.alpha(Commons.Color.foreground, 0.35)
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // 2. Action Buttons Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xs

      Button {
        text: root ? root.tr("paste") : "PASTE"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onHotChanged: if (root) root.setHelp(root.tr("help_paste"), hot)
        onClicked: if (panelRoot) panelRoot.pasteFromClipboard()
      }

      Button {
        text: root ? root.tr("snip") : "SNIP"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onHotChanged: if (root) root.setHelp(root.tr("help_snip"), hot)
        onClicked: if (panelRoot) panelRoot.triggerScreenSnip()
      }

      Button {
        text: root ? root.tr("clear") : "CLEAR"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        enabled: panelRoot && (panelRoot.referencePath !== "" || panelRoot.referenceMatchedRatio !== "") && !panelRoot.isGenerating && !panelRoot.isInterrogating && !panelRoot.isVisionLoading
        onHotChanged: if (root) root.setHelp(root.tr("help_clear"), hot)
        onClicked: if (panelRoot) panelRoot.clearReference()
      }

      Button {
        text: (panelRoot && panelRoot.isInterrogating) ? ((root ? root.tr("tagging") : "TAGGING...") + " (" + (root ? root.wd14ElapsedSeconds : 0) + "s)") : (root ? root.tr("interrogate_wd14") : "TAGY WD14")
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        active: panelRoot && panelRoot.isInterrogating
        selected: panelRoot && panelRoot.isInterrogating
        foreground: (panelRoot && panelRoot.isInterrogating) ? Commons.Color.accent : Commons.Color.foreground
        enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isInterrogating
        onHotChanged: if (root) root.setHelp(root.tr("help_interrogate"), hot)
        onClicked: if (panelRoot) panelRoot.interrogateWd14()
      }

      Button {
        text: (panelRoot && panelRoot.isVisionLoading) ? ((root ? root.tr("analyzing") : "ANALYZING...") + " (" + (root ? root.visionElapsedSeconds : 0) + "s)") : (root ? root.tr("vision_prompt") : "VISION PROMPT")
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        active: panelRoot && panelRoot.isVisionLoading
        selected: panelRoot && panelRoot.isVisionLoading
        foreground: (panelRoot && panelRoot.isVisionLoading) ? Commons.Color.accent : Commons.Color.foreground
        enabled: panelRoot && panelRoot.referencePath !== "" && !panelRoot.isVisionLoading
        onHotChanged: if (root) root.setHelp(root.tr("help_vision"), hot)
        onClicked: if (panelRoot) panelRoot.extractVisionPrompt()
      }
    }

    // 3. Denoise Slider Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xs

      Text {
        id: denoiseLabel
        textFormat: Text.PlainText
        text: (root ? root.tr("denoise") : "DENOISE: ") + (panelRoot ? panelRoot.denoise.toFixed(2) : "0.65")
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: panelRoot && panelRoot.referencePath !== "" ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.45)
        Layout.preferredWidth: Commons.Style.space(85)

        HoverHandler {
          onHoveredChanged: if (root) root.setHelp(root.tr("help_denoise"), hovered)
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
          onHoveredChanged: if (root) root.setHelp(root.tr("help_denoise"), hovered)
        }
      }
    }
  }
}
