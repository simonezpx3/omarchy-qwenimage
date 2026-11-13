import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons

Item {
  id: overlaysRoot
  anchors.fill: parent
  z: 9

  property var root: null
  property var panelRoot: null

  // Standby / Generating Canvas Overlay
  Rectangle {
    anchors.fill: parent
    color: (panelRoot && panelRoot.isGenerating && panelRoot.generatedPath !== "")
      ? Commons.Util.alpha(Commons.Color.background, 0.65)
      : "transparent"
    visible: Boolean(!panelRoot || (panelRoot.isGenerating && panelRoot.livePreviewPath === "") || (panelRoot.generatedPath === "" && !panelRoot.isGenerating))

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
          running: Boolean(panelRoot && panelRoot.isGenerating)
          PropertyAnimation { to: 0.3; duration: 400 }
          PropertyAnimation { to: 1.0; duration: 400 }
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignHCenter
        text: panelRoot && panelRoot.isGenerating
          ? ((root ? root.tr("generating_img") : "GENERATING...") + (root && root.genElapsedSeconds > 0 ? " (" + root.genElapsedSeconds + "s)" : ""))
          : (root ? root.tr("ready_to_synth") : "READY TO SYNTHESIZE")
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
          : "Enter prompt to synthesize"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Util.alpha(Commons.Color.foreground, 0.35)
      }
    }
  }

  // Live Diffusion Step Badge
  Rectangle {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Commons.Style.spacing.sm
    visible: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewStep > 0)
    height: Commons.Style.space(24)
    width: liveStepRow.implicitWidth + Commons.Style.space(16)
    radius: Commons.Style.cornerRadius
    color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.90)
    border.color: Commons.Color.accent
    border.width: 1

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
          running: Boolean(panelRoot && panelRoot.isGenerating)
          PropertyAnimation { to: 0.25; duration: 350 }
          PropertyAnimation { to: 1.0; duration: 350 }
        }
      }

      Text {
        textFormat: Text.PlainText
        text: (root ? root.tr("step") : "STEP") + " " + (panelRoot ? panelRoot.livePreviewStep : 0) + "/" + (panelRoot ? panelRoot.livePreviewMaxSteps : 25) + (root && root.genElapsedSeconds > 0 ? (" (" + root.genElapsedSeconds + "s)") : "")
        font.family: Commons.Style.font.family
        font.features: { "tnum": 1 }
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: Commons.Color.accent
      }
    }
  }
}
