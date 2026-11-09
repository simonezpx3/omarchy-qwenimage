import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: canvasRoot
  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null

  // Image Canvas Card Frame
  Rectangle {
    id: canvasFrame
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Commons.Style.space(380)
    color: Commons.Util.alpha(Commons.Color.background, 0.85)
    border.color: Commons.Color.menu.border
    border.width: 1
    radius: Commons.Style.cornerRadius
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Commons.Style.spacing.xs
      spacing: Commons.Style.spacing.xs

      // Card Header: Title + Telemetry Status
      RowLayout {
        Layout.fillWidth: true

        Text {
          textFormat: Text.PlainText
          text: root ? root.tr("canvas_title") : "CANVAS & OUTPUT"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: panelRoot && panelRoot.generatedPath !== "" ? Commons.Color.accent : Commons.Color.foreground
          Layout.fillWidth: true
        }

        // Resolution / Dimensions Label
        Text {
          textFormat: Text.PlainText
          visible: Boolean(panelRoot && panelRoot.generatedWidth > 0 && panelRoot.generatedHeight > 0)
          text: panelRoot ? (panelRoot.generatedWidth + "×" + panelRoot.generatedHeight + " PX") : ""
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: Commons.Color.accent
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
      }

      // Visual Canvas Display Area
      Rectangle {
        id: canvasBox
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Commons.Util.alpha(Commons.Color.background, 0.65)
        border.color: Commons.Color.menu.border
        border.width: 1
        radius: Commons.Style.cornerRadius
        clip: true

        // Standby / Empty Canvas Overlay
        Item {
          anchors.fill: parent
          visible: Boolean(!panelRoot || (panelRoot.generatedPath === "" && !panelRoot.isGenerating))

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

        Image {
          id: mainPreview
          anchors.fill: parent
          anchors.margins: Commons.Style.spacing.xxs
          fillMode: Image.PreserveAspectFit
          sourceSize: Qt.size(Math.min(Math.max(width * (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0), 1280), 2560), 0)
          source: panelRoot && panelRoot.generatedPath !== "" ? ("file://" + encodeURI(panelRoot.generatedPath)) : ""
          cache: false
          asynchronous: true
          visible: Boolean(!(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== ""))
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
          visible: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== "")
        }

        // Left-click on canvas buffer: open generated image fullscreen
        MouseArea {
          id: canvasClickArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          hoverEnabled: true
          readonly property bool canOpenFullscreen: Boolean(panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating)
          cursorShape: canOpenFullscreen ? Qt.PointingHandCursor : Qt.ArrowCursor
          onEntered: if (canOpenFullscreen && root) root.setHelp(root.tr("help_canvas_fullscreen"), true)
          onExited: if (root) root.setHelp(root.tr("help_canvas_fullscreen"), false)
          onCanOpenFullscreenChanged: {
            if (containsMouse && root) {
              root.setHelp(root.tr("help_canvas_fullscreen"), canOpenFullscreen);
            }
          }
          onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton && canOpenFullscreen) {
              panelRoot.openFullscreenViewer(panelRoot.generatedPath);
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
    }
  }

  // Image Scaling & Actions Toolbar
  StudioCanvasToolbar {
    Layout.fillWidth: true
    root: canvasRoot.root
    panelRoot: canvasRoot.panelRoot
  }
}
