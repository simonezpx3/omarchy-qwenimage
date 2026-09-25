import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null
  property real splitPosition: 0.5

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.md

    PanelSectionHeader {
      text: panelRoot && panelRoot.currentLang === "cs" ? "INTERAKTIVNÍ ROZDĚLENÉ SROVNÁNÍ A/B" : "INTERACTIVE A/B SPLIT COMPARISON"
    }

    // Split Viewport Frame
    Rectangle {
      id: viewport
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.background
      border.color: Color.menu.border
      border.width: 1
      radius: Style.cornerRadius
      clip: true

      // Bottom Layer: Generated Image (After)
      Image {
        id: imgAfter
        anchors.fill: parent
        anchors.margins: Style.spacing.xs
        fillMode: Image.PreserveAspectFit
        source: panelRoot && panelRoot.generatedPath !== "" ? "file://" + panelRoot.generatedPath : ""
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
          source: panelRoot && panelRoot.referencePath !== "" ? "file://" + panelRoot.referencePath : ""
          cache: false
        }
      }

      // Divider Line
      Rectangle {
        id: divider
        x: viewport.width * root.splitPosition - (width / 2)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Color.accent

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(24)
          height: Style.space(24)
          radius: width / 2
          color: Color.background
          border.color: Color.accent
          border.width: 2

          Text {
            anchors.centerIn: parent
            text: "AB"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.accent
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
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.spacing.md
        text: panelRoot && panelRoot.currentLang === "cs" ? "PŘEDTÍM (ORIGINÁL)" : "BEFORE (ORIGINAL)"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.foreground
      }

      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.md
        text: panelRoot && panelRoot.currentLang === "cs" ? "POTOM (VARIACE)" : "AFTER (VARIATION)"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.accent
      }
    }

    // Split Slider Control Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      Text {
        text: (panelRoot && panelRoot.currentLang === "cs" ? "POMĚR ROZDĚLENÍ: " : "SPLIT RATIO: ") + Math.round(root.splitPosition * 100) + "%"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.foreground
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
      spacing: Style.spacing.sm

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
