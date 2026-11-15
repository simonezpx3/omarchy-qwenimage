import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons as Commons
import qs.Ui

RowLayout {
  id: headerRoot
  property var panelRoot: null

  readonly property color positiveColor: panelRoot ? panelRoot.positiveColor : Qt.hsva(0.38, 0.65, 0.85, 1.0)
  readonly property string versionQwen: panelRoot ? panelRoot.versionQwen : ""
  readonly property string versionComfy: panelRoot ? panelRoot.versionComfy : ""
  readonly property string versionOllama: panelRoot ? panelRoot.versionOllama : ""
  readonly property bool svcQwen: panelRoot ? panelRoot.svcQwen : false
  readonly property bool svcComfy: panelRoot ? panelRoot.svcComfy : false
  readonly property bool svcOllama: panelRoot ? panelRoot.svcOllama : false
  readonly property bool svcWd14: panelRoot ? panelRoot.svcWd14 : false
  readonly property int vramUsed: panelRoot ? panelRoot.vramUsed : 0
  readonly property int vramTotal: panelRoot ? panelRoot.vramTotal : 8192
  readonly property int vramPct: panelRoot ? panelRoot.vramPct : 0

  readonly property string currentView: {
    if (panelRoot && panelRoot.svc && panelRoot.svc.currentView) return panelRoot.svc.currentView;
    if (panelRoot && panelRoot.currentView) return panelRoot.currentView;
    return "studio";
  }

  function setView(viewKey) {
    if (panelRoot) {
      if (panelRoot.svc) {
        panelRoot.svc.currentView = viewKey;
      } else if ("currentView" in panelRoot) {
        panelRoot.currentView = viewKey;
      }
    }
  }

  spacing: Commons.Style.spacing.sm

  RowLayout {
    spacing: Commons.Style.spacing.xs

    Item {
      width: Commons.Style.space(18)
      height: Commons.Style.space(18)
      Layout.alignment: Qt.AlignVCenter

      Image {
        id: qisLogo
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/qwen-heretic.svg")
        sourceSize.width: 36
        sourceSize.height: 36
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: qisLogo
        source: qisLogo
        visible: true
        colorization: 1.0
        colorizationColor: "#ffffff"
      }
    }

    Text {
      textFormat: Text.PlainText
      text: "QIS"
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.body
      font.bold: true
      color: Commons.Color.foreground
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      textFormat: Text.PlainText
      visible: Boolean(panelRoot && panelRoot.pluginVersion !== "")
      text: panelRoot ? panelRoot.pluginVersion : ""
      font.family: Commons.Style.font.family
      font.features: { "tnum": 1 }
      font.pixelSize: Commons.Style.font.caption
      color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
      Layout.alignment: Qt.AlignVCenter
    }
  }

  Rectangle {
    width: 1
    implicitHeight: Commons.Style.space(16)
    color: Commons.Util.alpha(Commons.Color.menu.border, 0.25)
    Layout.alignment: Qt.AlignVCenter
  }

  // Segmented Navigation Tabs inside a quiet unified pill
  Rectangle {
    height: Commons.Style.space(24)
    implicitWidth: tabsRow.implicitWidth + Commons.Style.space(4)
    radius: Commons.Style.cornerRadius
    color: Commons.Util.alpha(Commons.Color.foreground, 0.04)
    border.color: Commons.Util.alpha(Commons.Color.menu.border, 0.35)
    border.width: 1

    RowLayout {
      id: tabsRow
      anchors.centerIn: parent
      spacing: Commons.Style.space(2)

      Repeater {
        model: [
          { key: "studio", label: "STUDIO" },
          { key: "civitai", label: "INSPIRATION" },
          { key: "history", label: "HISTORY" }
        ]

        delegate: Rectangle {
          readonly property bool isSelected: headerRoot.currentView === modelData.key
          property bool isHovered: false

          height: Commons.Style.space(18)
          implicitWidth: tabText.implicitWidth + Commons.Style.spacing.sm * 1.5
          radius: Math.max(2, Commons.Style.cornerRadius - 2)
          color: isSelected
            ? Commons.Util.alpha(Commons.Color.accent, 0.18)
            : (isHovered ? Commons.Util.alpha(Commons.Color.foreground, 0.07) : "transparent")

          Text {
            id: tabText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.label
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            font.bold: isSelected
            color: isSelected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.68)
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.isHovered = true
            onExited: parent.isHovered = false
            onClicked: headerRoot.setView(modelData.key)
          }
        }
      }
    }
  }

  Item { Layout.fillWidth: true }

  // Unified Service & Model Health Strip
  Rectangle {
    height: Commons.Style.space(22)
    implicitWidth: healthStripRow.implicitWidth + Commons.Style.spacing.sm * 1.5
    radius: Commons.Style.cornerRadius
    color: Commons.Util.alpha(Commons.Color.foreground, 0.04)
    border.color: Commons.Util.alpha(Commons.Color.menu.border, 0.35)
    border.width: 1

    RowLayout {
      id: healthStripRow
      anchors.centerIn: parent
      spacing: Commons.Style.spacing.sm

      Repeater {
        model: [
          {
            name: headerRoot.svcQwen
              ? (headerRoot.versionQwen || "Qwen-Image 2.1")
              : "NO DIT",
            ok: headerRoot.svcQwen
          },
          { name: "COMFY", ok: headerRoot.svcComfy },
          { name: "OLLAMA", ok: headerRoot.svcOllama },
          { name: "WD14", ok: headerRoot.svcWd14 }
        ]

        delegate: RowLayout {
          required property var modelData
          spacing: 4

          Text {
            textFormat: Text.PlainText
            text: "●"
            font.pixelSize: Commons.Style.font.caption
            color: modelData.ok ? headerRoot.positiveColor : Commons.Color.urgent
          }

          Text {
            textFormat: Text.PlainText
            text: modelData.name
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            font.bold: !modelData.ok
            color: modelData.ok ? Commons.Util.alpha(Commons.Color.foreground, 0.72) : Commons.Color.urgent
          }
        }
      }
      // Internal divider + compact VRAM gauge inside the unified capsule
      Rectangle {
        width: 1
        implicitHeight: Commons.Style.space(12)
        color: Commons.Util.alpha(Commons.Color.menu.border, 0.25)
        Layout.alignment: Qt.AlignVCenter
      }

      RowLayout {
        spacing: Commons.Style.space(6)
        Layout.alignment: Qt.AlignVCenter

        readonly property color vramColor: headerRoot.vramPct >= 90
          ? Commons.Color.urgent
          : (headerRoot.vramPct >= 75 ? "#f59e0b" : headerRoot.positiveColor)

        Rectangle {
          width: Commons.Style.space(32)
          height: Commons.Style.space(4)
          radius: height / 2
          color: Commons.Util.alpha(Commons.Color.foreground, 0.14)
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            width: Math.max(2, parent.width * Math.min(1.0, Math.max(0.0, headerRoot.vramPct / 100.0)))
            height: parent.height
            radius: parent.radius
            color: parent.parent.vramColor
          }
        }

        Text {
          textFormat: Text.PlainText
          text: (headerRoot.vramUsed / 1024).toFixed(1) + "/" + Math.round(headerRoot.vramTotal / 1024) + "G"
          font.family: Commons.Style.font.family
          font.features: { "tnum": 1 }
          font.pixelSize: Commons.Style.font.caption
          color: headerRoot.vramPct >= 90 ? Commons.Color.urgent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
          Layout.alignment: Qt.AlignVCenter
        }
      }
    }
  }
}
