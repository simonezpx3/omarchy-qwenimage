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
  readonly property bool svcComfy: panelRoot ? panelRoot.svcComfy : false
  readonly property bool svcOllama: panelRoot ? panelRoot.svcOllama : false
  readonly property bool svcWd14: panelRoot ? panelRoot.svcWd14 : false
  readonly property int vramUsed: panelRoot ? panelRoot.vramUsed : 0
  readonly property int vramTotal: panelRoot ? panelRoot.vramTotal : 8192
  readonly property int vramPct: panelRoot ? panelRoot.vramPct : 0

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
        colorizationColor: Commons.Color.accent
      }
    }

    Text {
      textFormat: Text.PlainText
      text: "QIS"
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.body
      font.bold: true
      color: Commons.Color.accent
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // Active Qwen Model Version Badge
  Rectangle {
    height: Commons.Style.space(20)
    implicitWidth: qwenModelRow.implicitWidth + Commons.Style.spacing.xs * 2
    color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
    border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
    border.width: 1
    radius: Commons.Style.cornerRadius

    RowLayout {
      id: qwenModelRow
      anchors.centerIn: parent
      spacing: 4
      Text {
        textFormat: Text.PlainText
        text: "QWEN //"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Color.accent
      }
      Text {
        textFormat: Text.PlainText
        text: headerRoot.versionQwen
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: Commons.Color.accent
      }
    }
  }

  // Service Health Badges row
  RowLayout {
    spacing: Commons.Style.spacing.xs

    // 1. COMFYUI
    Rectangle {
      height: Commons.Style.space(20)
      implicitWidth: comfyRow.implicitWidth + Commons.Style.spacing.xs * 2
      color: headerRoot.svcComfy ? Commons.Util.alpha(headerRoot.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
      border.color: headerRoot.svcComfy ? Commons.Util.alpha(headerRoot.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
      border.width: 1
      radius: Commons.Style.cornerRadius

      RowLayout {
        id: comfyRow
        anchors.centerIn: parent
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: "●"
          font.pixelSize: Commons.Style.font.caption
          color: headerRoot.svcComfy ? headerRoot.positiveColor : Commons.Color.urgent
        }
        Text {
          textFormat: Text.PlainText
          text: (headerRoot.versionComfy && headerRoot.versionComfy !== "Offline" && headerRoot.versionComfy !== "Online") ? ("COMFYUI v" + headerRoot.versionComfy) : "COMFYUI"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: headerRoot.svcComfy ? headerRoot.positiveColor : Commons.Color.urgent
        }
      }
    }

    // 2. OLLAMA
    Rectangle {
      height: Commons.Style.space(20)
      implicitWidth: ollamaRow.implicitWidth + Commons.Style.spacing.xs * 2
      color: headerRoot.svcOllama ? Commons.Util.alpha(headerRoot.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
      border.color: headerRoot.svcOllama ? Commons.Util.alpha(headerRoot.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
      border.width: 1
      radius: Commons.Style.cornerRadius

      RowLayout {
        id: ollamaRow
        anchors.centerIn: parent
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: "●"
          font.pixelSize: Commons.Style.font.caption
          color: headerRoot.svcOllama ? headerRoot.positiveColor : Commons.Color.urgent
        }
        Text {
          textFormat: Text.PlainText
          text: (headerRoot.versionOllama && headerRoot.versionOllama !== "Offline" && headerRoot.versionOllama !== "Online") ? ("OLLAMA v" + headerRoot.versionOllama) : "OLLAMA"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: headerRoot.svcOllama ? headerRoot.positiveColor : Commons.Color.urgent
        }
      }
    }

    // 3. WD14 ONNX
    Rectangle {
      height: Commons.Style.space(20)
      implicitWidth: wd14Row.implicitWidth + Commons.Style.spacing.xs * 2
      color: headerRoot.svcWd14 ? Commons.Util.alpha(headerRoot.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
      border.color: headerRoot.svcWd14 ? Commons.Util.alpha(headerRoot.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
      border.width: 1
      radius: Commons.Style.cornerRadius

      RowLayout {
        id: wd14Row
        anchors.centerIn: parent
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: "●"
          font.pixelSize: Commons.Style.font.caption
          color: headerRoot.svcWd14 ? headerRoot.positiveColor : Commons.Color.urgent
        }
        Text {
          textFormat: Text.PlainText
          text: "WD14 ONNX"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.bold: true
          color: headerRoot.svcWd14 ? headerRoot.positiveColor : Commons.Color.urgent
        }
      }
    }
  }

  Item { Layout.fillWidth: true }

  Text {
    textFormat: Text.PlainText
    text: "VRAM: " + (headerRoot.vramUsed / 1024).toFixed(1) + " / " + (headerRoot.vramTotal / 1024).toFixed(1) + " GB (" + headerRoot.vramPct + "%)"
    font.family: Commons.Style.font.family
    font.features: { "tnum": 1 }
    font.pixelSize: Commons.Style.font.caption
    color: Commons.Color.foreground
  }
}
