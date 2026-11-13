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
  property real zoomScale: 1.0
  property real panX: 0.0
  property real panY: 0.0

  function resetZoom() {
    zoomScale = 1.0;
    panX = 0.0;
    panY = 0.0;
  }

  // Image Canvas Card Frame
  Rectangle {
    id: canvasFrame
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Commons.Style.space(380)
    color: Commons.Util.alpha(Commons.Color.foreground, 0.03)
    border.color: Commons.Util.alpha(Commons.Color.menu.border, 0.35)
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

        // Zoom percentage & FIT reset button
        Text {
          textFormat: Text.PlainText
          visible: Boolean(panelRoot && panelRoot.generatedPath !== "" && Math.abs(canvasRoot.zoomScale - 1.0) > 0.02)
          text: Math.round(canvasRoot.zoomScale * 100) + "%"
          font.family: Commons.Style.font.family
          font.features: { "tnum": 1 }
          font.pixelSize: Commons.Style.font.caption
          color: Commons.Util.alpha(Commons.Color.foreground, 0.7)
        }

        Button {
          text: "FIT"
          fontSize: Commons.Style.font.caption
          bordered: false
          visible: Boolean(panelRoot && panelRoot.generatedPath !== "" && (Math.abs(canvasRoot.zoomScale - 1.0) > 0.02 || Math.abs(canvasRoot.panX) > 1.0 || Math.abs(canvasRoot.panY) > 1.0))
          Layout.preferredHeight: Commons.Style.space(18)
          verticalPadding: Commons.Style.space(1)
          horizontalPadding: Commons.Style.space(6)
          onHotChanged: if (root) root.setHelp(root.tr("help_canvas_fit"), hot)
          onClicked: canvasRoot.resetZoom()
        }

        Button {
          text: panelRoot && panelRoot.inpaintMode ? "MASK: ON" : "MASK"
          fontSize: Commons.Style.font.caption
          bordered: false
          selected: Boolean(panelRoot && panelRoot.inpaintMode)
          foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
          accent: Commons.Color.accent
          visible: Boolean(panelRoot && !panelRoot.isGenerating && (panelRoot.referencePath !== "" || panelRoot.generatedPath !== ""))
          Layout.preferredHeight: Commons.Style.space(18)
          verticalPadding: Commons.Style.space(1)
          horizontalPadding: Commons.Style.space(6)
          onHotChanged: if (root) root.setHelp(root.tr("help_mask_toggle"), hot)
          onClicked: {
            if (!panelRoot) return;
            if (!panelRoot.inpaintMode && panelRoot.referencePath === "" && panelRoot.generatedPath !== "") {
              panelRoot.setReferenceImage(panelRoot.generatedPath);
            }
            panelRoot.inpaintMode = !panelRoot.inpaintMode;
          }
        }
      }

      // Inline Inpainting Mask Toolbar
      StudioMaskToolbar {
        visible: Boolean(panelRoot && panelRoot.inpaintMode && !panelRoot.isGenerating)
        root: canvasRoot.root
        panelRoot: canvasRoot.panelRoot
        maskCanvas: maskCanvas
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g, Commons.Color.menu.border.b, 0.25)
      }

      // Visual Canvas Display Area (borderless inside canvasFrame to avoid box-in-a-box clutter)
      Rectangle {
        id: canvasBox
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Commons.Util.alpha(Commons.Color.background, 0.45)
        border.width: 0
        radius: Commons.Style.cornerRadius
        clip: true

        // Standby / Generating Canvas Overlay
        Rectangle {
          anchors.fill: parent
          z: 9
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

        Item {
          id: zoomContainer
          anchors.fill: parent
          anchors.margins: Commons.Style.spacing.xxs
          visible: Boolean(!(panelRoot && panelRoot.isGenerating && panelRoot.livePreviewPath !== ""))

          Image {
            id: mainPreview
            width: zoomContainer.width
            height: zoomContainer.height
            x: canvasRoot.panX
            y: canvasRoot.panY
            scale: canvasRoot.zoomScale
            transformOrigin: Item.Center
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(Math.min(Math.max(width * (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0), 1280), 2560), 0)
            source: panelRoot && panelRoot.generatedPath !== "" ? ("file://" + encodeURI(panelRoot.generatedPath)) : ""
            cache: false
            asynchronous: true
            onSourceChanged: {
              canvasRoot.resetZoom();
              if (typeof maskCanvas !== "undefined" && maskCanvas) maskCanvas.clearMask();
            }
          }

          // Interactive Inpainting Mask Layer (aligned 1:1 to painted image bounds)
          StudioMaskCanvas {
            id: maskCanvas
            readonly property real paintedW: mainPreview.paintedWidth > 0 ? mainPreview.paintedWidth : mainPreview.width
            readonly property real paintedH: mainPreview.paintedHeight > 0 ? mainPreview.paintedHeight : mainPreview.height
            x: mainPreview.x + (mainPreview.width - paintedW) / 2
            y: mainPreview.y + (mainPreview.height - paintedH) / 2
            width: paintedW
            height: paintedH
            scale: mainPreview.scale
            transformOrigin: Item.Center
            visible: Boolean(panelRoot && panelRoot.inpaintMode && !panelRoot.isGenerating)
            panelRoot: canvasRoot.panelRoot
          }

          WheelHandler {
            enabled: Boolean(panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating)
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
              var factor = event.angleDelta.y > 0 ? 1.15 : (1.0 / 1.15);
              var next = Math.max(0.5, Math.min(4.0, canvasRoot.zoomScale * factor));
              canvasRoot.zoomScale = next;
              if (next <= 1.01) {
                canvasRoot.panX = 0.0;
                canvasRoot.panY = 0.0;
              }
            }
          }

          DragHandler {
            id: panHandler
            target: null
            acceptedButtons: Qt.RightButton | Qt.MiddleButton
            enabled: Boolean(panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating && canvasRoot.zoomScale > 1.01)
            property real startPanX: 0
            property real startPanY: 0
            onActiveChanged: {
              if (active) {
                startPanX = canvasRoot.panX;
                startPanY = canvasRoot.panY;
              }
            }
            onTranslationChanged: {
              if (active) {
                var maxOffsetX = zoomContainer.width * (canvasRoot.zoomScale - 1.0) * 0.5;
                var maxOffsetY = zoomContainer.height * (canvasRoot.zoomScale - 1.0) * 0.5;
                canvasRoot.panX = Math.max(-maxOffsetX, Math.min(maxOffsetX, startPanX + translation.x));
                canvasRoot.panY = Math.max(-maxOffsetY, Math.min(maxOffsetY, startPanY + translation.y));
              }
            }
          }

          HoverHandler {
            enabled: Boolean(panelRoot && panelRoot.generatedPath !== "" && !panelRoot.isGenerating)
            onHoveredChanged: {
              if (!root) return;
              var maskMsg = root.tr("help_canvas_image_mask");
              var viewMsg = root.tr("help_canvas_image");
              if (hovered) {
                root.setHelp((panelRoot && panelRoot.inpaintMode) ? maskMsg : viewMsg, true);
              } else {
                root.setHelp(maskMsg, false);
                root.setHelp(viewMsg, false);
              }
            }
          }
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
