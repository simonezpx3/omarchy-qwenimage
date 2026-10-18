import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null
  property real splitPosition: 0.5

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.md

    PanelSectionHeader {
      text: panelRoot && panelRoot.currentLang === "cs" ? "INTERAKTIVNÍ ROZDĚLENÉ SROVNÁNÍ A/B" : "INTERACTIVE A/B SPLIT COMPARISON"
    }

    // Split Viewport Frame
    Rectangle {
      id: viewport
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Commons.Color.background
      border.color: Commons.Color.menu.border
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
        anchors.fill: parent
        anchors.margins: Commons.Style.spacing.xs
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: viewport.decodeW
        sourceSize.height: viewport.decodeH
        retainWhileLoading: true
        source: panelRoot && panelRoot.generatedPath !== "" ? ("file://" + encodeURI(panelRoot.generatedPath)) : ""
        cache: false
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
          text: panelRoot && panelRoot.currentLang === "cs" ? "NAČÍTÁM NÁHLED..." : "LOADING PREVIEW..."
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
        width: 2
        color: Commons.Color.accent

        Rectangle {
          anchors.centerIn: parent
          width: Commons.Style.space(24)
          height: Commons.Style.space(24)
          radius: width / 2
          color: Commons.Color.background
          border.color: Commons.Color.accent
          border.width: 2

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

      // Mouse Drag Interaction for Split
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SplitHCursor
        onPositionChanged: function(mouse) {
          if (pressed) {
            root.splitPosition = Math.max(0.05, Math.min(0.95, mouse.x / width));
          }
        }
        onPressed: function(mouse) {
          root.splitPosition = Math.max(0.05, Math.min(0.95, mouse.x / width));
        }
      }

      // Labels inside viewport
      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Commons.Style.spacing.md
        text: panelRoot && panelRoot.currentLang === "cs" ? "PŘEDTÍM (ORIGINÁL)" : "BEFORE (ORIGINAL)"
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
        text: panelRoot && panelRoot.currentLang === "cs" ? "POTOM (VARIACE)" : "AFTER (VARIATION)"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: Commons.Color.accent
      }
    }

    // Split Slider Control Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Text {
        textFormat: Text.PlainText
        text: (panelRoot && panelRoot.currentLang === "cs" ? "POMĚR ROZDĚLENÍ: " : "SPLIT RATIO: ") + Math.round(root.splitPosition * 100) + "%"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Color.foreground
      }

      PanelSlider {
        Layout.fillWidth: true
        bar: panelRoot ? panelRoot.bar : null
        minimum: 0.05
        maximum: 0.95
        step: 0.01
        value: root.splitPosition
        onMoved: function(val) {
          root.splitPosition = val;
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Action Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "POUŽÍT JAKO FINÁLNÍ" : "APPLY AS FINAL"
        bordered: true
        selected: true
        onClicked: {
          if (panelRoot) {
            panelRoot.referencePath = panelRoot.generatedPath;
            panelRoot.currentView = "studio";
          }
        }
      }

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "ZAHODIT VARIACI" : "DISCARD VARIATION"
        bordered: true
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "NASTAVIT JAKO TAPETU" : "SET AS WALLPAPER"
        bordered: true
        enabled: panelRoot && panelRoot.generatedPath !== ""
        onClicked: {
          if (panelRoot) panelRoot.setAsWallpaper(panelRoot.generatedPath);
        }
      }

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
