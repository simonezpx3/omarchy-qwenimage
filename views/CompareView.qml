import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null
  property real splitPosition: 0.5
  property real zoomScale: 1.0
  property real panX: 0.0
  property real panY: 0.0

  function resetZoom() {
    zoomScale = 1.0;
    panX = 0.0;
    panY = 0.0;
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.md

    PanelSectionHeader {
      text: "INTERACTIVE A/B SPLIT COMPARISON"
    }

    // Split Viewport Frame
    Rectangle {
      id: viewport
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Commons.Color.background
      border.color: Commons.Util.alpha(Commons.Color.menu.border, 0.35)
      border.width: 1
      radius: Commons.Style.cornerRadius
      clip: true

      property int decodeW: 1
      property int decodeH: 1
      Timer {
        id: decodeDebounce
        interval: 150
        onTriggered: {
          var dpr = Screen.devicePixelRatio;
          viewport.decodeW = Math.max(1, Math.ceil(viewport.width * dpr / 64) * 64);
          viewport.decodeH = Math.max(1, Math.ceil(viewport.height * dpr / 64) * 64);
        }
      }
      onWidthChanged: decodeDebounce.restart()
      onHeightChanged: decodeDebounce.restart()
      Component.onCompleted: decodeDebounce.triggered()

      // Bottom Layer: Generated Image (After)
      Image {
        id: imgAfter
        width: viewport.width
        height: viewport.height
        x: root.panX
        y: root.panY
        scale: root.zoomScale
        transformOrigin: Item.Center
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: viewport.decodeW
        sourceSize.height: viewport.decodeH
        retainWhileLoading: true
        source: panelRoot && panelRoot.generatedPath !== "" ? ("file://" + encodeURI(panelRoot.generatedPath)) : ""
        cache: false
        onSourceChanged: root.resetZoom()
      }

      // Top Layer: Original Reference Image (Before) clipped to splitPosition
      Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * root.splitPosition
        clip: true

        Image {
          id: imgBefore
          width: viewport.width
          height: viewport.height
          x: root.panX
          y: root.panY
          scale: root.zoomScale
          transformOrigin: Item.Center
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          sourceSize.width: viewport.decodeW
          sourceSize.height: viewport.decodeH
          retainWhileLoading: true
          source: panelRoot && panelRoot.referencePath !== "" ? ("file://" + encodeURI(panelRoot.referencePath)) : ""
          cache: false
        }
      }

      // Indikátor asynchronního načítání náhledů (#screens standard)
      RowLayout {
        anchors.centerIn: parent
        spacing: Commons.Style.spacing.sm
        visible: (imgAfter.status === Image.Loading && imgAfter.progress < 1.0 && imgAfter.paintedWidth === 0)
              || (imgBefore.status === Image.Loading && imgBefore.progress < 1.0 && imgBefore.paintedWidth === 0)

        Rectangle {
          implicitWidth: Commons.Style.space(8)
          implicitHeight: Commons.Style.space(8)
          radius: width / 2
          color: Commons.Color.accent

          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: (imgAfter.status === Image.Loading && imgAfter.progress < 1.0 && imgAfter.paintedWidth === 0)
                  || (imgBefore.status === Image.Loading && imgBefore.progress < 1.0 && imgBefore.paintedWidth === 0)
            NumberAnimation { from: 0.3; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "LOADING PREVIEW..."
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: Commons.Color.accent
        }
      }

      // Divider Line
      Rectangle {
        id: divider
        x: viewport.width * root.splitPosition - (width / 2)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Commons.Color.accent

        Rectangle {
          anchors.centerIn: parent
          width: Commons.Style.space(24)
          height: Commons.Style.space(24)
          radius: width / 2
          color: Commons.Color.background
          border.color: Commons.Color.accent
          border.width: 1

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "AB"
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            font.bold: true
            color: Commons.Color.accent
          }
        }
      }

      // Wheel Zoom (synchronized on Before & After)
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          var factor = event.angleDelta.y > 0 ? 1.15 : (1.0 / 1.15);
          var next = Math.max(0.5, Math.min(4.0, root.zoomScale * factor));
          root.zoomScale = next;
          if (next <= 1.01) {
            root.panX = 0.0;
            root.panY = 0.0;
          }
        }
      }

      // Mouse Drag Interaction: Left = Split, Right/Middle = Pan, DoubleClick = Reset Zoom
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: (pressedButtons & (Qt.RightButton | Qt.MiddleButton)) ? Qt.ClosedHandCursor : Qt.SplitHCursor
        property real lastPanX: 0
        property real lastPanY: 0
        onPressed: function(mouse) {
          if (mouse.button === Qt.LeftButton) {
            root.splitPosition = Math.max(0.05, Math.min(0.95, mouse.x / width));
          } else {
            lastPanX = mouse.x;
            lastPanY = mouse.y;
          }
        }
        onPositionChanged: function(mouse) {
          if (pressedButtons & Qt.LeftButton) {
            root.splitPosition = Math.max(0.05, Math.min(0.95, mouse.x / width));
          } else if (pressedButtons & (Qt.RightButton | Qt.MiddleButton)) {
            root.panX += (mouse.x - lastPanX);
            root.panY += (mouse.y - lastPanY);
            lastPanX = mouse.x;
            lastPanY = mouse.y;
          }
        }
        onDoubleClicked: root.resetZoom()
      }

      // Labels inside viewport
      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Commons.Style.spacing.md
        text: "BEFORE (ORIGINAL)"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: Commons.Color.foreground
      }

      Text {
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Commons.Style.spacing.md
        text: "AFTER (VARIATION)"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: Commons.Color.accent
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Action Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Button {
        text: Math.round(root.zoomScale * 100) + "% (RESET)"
        fontSize: Commons.Style.font.caption
        bordered: false
        visible: Math.abs(root.zoomScale - 1.0) > 0.02 || Math.abs(root.panX) > 1 || Math.abs(root.panY) > 1
        foreground: Commons.Color.accent
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        horizontalPadding: Commons.Style.space(6)
        onClicked: root.resetZoom()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "BACK TO STUDIO"
        fontSize: Commons.Style.font.caption
        bordered: false
        active: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }
    }
  }
}
