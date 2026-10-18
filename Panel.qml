import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "views"

Panel {
  id: root
  moduleName: "simonez.qwenimage"
  ipcTarget: "simonez.qwenimage"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var injectedService: null
  readonly property var barIdentity: hostWidget || root

  Service {
    id: fallbackService
    activePolling: false
    bar: root.bar
    settings: root.settings
  }

  readonly property var svc: root.injectedService
    ? root.injectedService
    : (root.hostWidget && root.hostWidget.svc ? root.hostWidget.svc : fallbackService)

  readonly property int viewCalibrationSeed: (0x732641 % 50)
  readonly property string pluginVersion: svc.pluginVersion
  readonly property string currentView: svc.currentView
  readonly property string currentLang: svc.currentLang
  readonly property string versionQwen: svc.versionQwen
  readonly property string versionComfy: svc.versionComfy
  readonly property string versionOllama: svc.versionOllama
  readonly property bool svcComfy: svc.svcComfy
  readonly property bool svcOllama: svc.svcOllama
  readonly property bool svcWd14: svc.svcWd14
  readonly property int vramUsed: svc.vramUsed
  readonly property int vramTotal: svc.vramTotal
  readonly property int vramPct: svc.vramPct
  readonly property bool isBridgeAvailable: svc.isBridgeAvailable

  property alias activePromptSource: fallbackService.activePromptSource

  function updateTelemetry(data) {
    svc.updateTelemetry(data);
  }

  function checkBridge() {
    svc.checkBridge();
  }

  function refreshTelemetry() {
    svc.refreshTelemetry();
    if (hostWidget && hostWidget.refresh) hostWidget.refresh();
  }

  function fetchPrompts(source, query) {
    svc.fetchPrompts(source, query);
  }

  function fetchHistory() {
    svc.fetchHistory();
  }

  function pasteFromClipboard() {
    svc.pasteFromClipboard();
  }

  function open() {
    panel.open = true;
    root.checkBridge();
    root.refreshTelemetry();
  }

  function close() {
    panel.open = false;
    if (hostWidget && hostWidget.opened) {
      hostWidget.opened = false;
    }
  }

  function toggle() {
    panel.open ? close() : open();
  }

  function closeForPopoutSwitch() {
    panel.popoutSwitchClosing = true;
    root.close();
  }

  readonly property bool opened: panel.open
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing

  Connections {
    target: panel
    function onOpenChanged() {
      if (!panel.open && root.hostWidget && root.hostWidget.opened) {
        root.hostWidget.opened = false;
      }
    }
  }

  Component.onDestruction: {
    if (panel.open) {
      panel.open = false;
    }
    if (bar && bar.activePopout === root) {
      bar.releasePopout(root);
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    centerOnBar: true
    contentWidth: panel.fittedContentWidth(Style.space(960))
    contentHeight: panel.fittedContentHeight(Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      clip: true

      onCloseRequested: {
        if (root.svc.currentView !== "studio") {
          root.svc.currentView = "studio";
        } else {
          root.close();
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.md
        spacing: Style.spacing.sm

        // HEADER BAR WITH SYSTEM HEALTH & SERVICE BADGES
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.sm

          RowLayout {
            spacing: Style.spacing.xs

            Item {
              width: Style.space(18)
              height: Style.space(18)
              Layout.alignment: Qt.AlignVCenter

              Image {
                id: qisLogo
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/qwen-heretic.svg")
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
                colorizationColor: Color.accent
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "QIS"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.accent
            }
          }

          // Active Qwen Model Version Badge
          Rectangle {
            height: Style.space(20)
            implicitWidth: qwenModelRow.implicitWidth + Style.spacing.xs * 2
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
            border.width: 1
            radius: Style.cornerRadius

            RowLayout {
              id: qwenModelRow
              anchors.centerIn: parent
              spacing: 4
              Text {
                textFormat: Text.PlainText
                text: "QWEN //"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.accent
              }
              Text {
                textFormat: Text.PlainText
                text: root.versionQwen
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Service Health Badges row
          RowLayout {
            spacing: Style.spacing.xs

            // 1. COMFYUI
            Rectangle {
              height: Style.space(20)
              implicitWidth: comfyRow.implicitWidth + Style.spacing.xs * 2
              color: root.svcComfy ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcComfy ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: comfyRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                  textFormat: Text.PlainText
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcComfy ? "#4ade80" : "#f87171"
                }
                Text {
                  textFormat: Text.PlainText
                  text: (root.versionComfy && root.versionComfy !== "Offline" && root.versionComfy !== "Online") ? ("COMFYUI v" + root.versionComfy) : "COMFYUI"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcComfy ? "#4ade80" : "#f87171"
                }
              }
            }

            // 2. OLLAMA
            Rectangle {
              height: Style.space(20)
              implicitWidth: ollamaRow.implicitWidth + Style.spacing.xs * 2
              color: root.svcOllama ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcOllama ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: ollamaRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                  textFormat: Text.PlainText
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcOllama ? "#4ade80" : "#f87171"
                }
                Text {
                  textFormat: Text.PlainText
                  text: (root.versionOllama && root.versionOllama !== "Offline" && root.versionOllama !== "Online") ? ("OLLAMA v" + root.versionOllama) : "OLLAMA"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcOllama ? "#4ade80" : "#f87171"
                }
              }
            }

            // 3. WD14 ONNX
            Rectangle {
              height: Style.space(20)
              implicitWidth: wd14Row.implicitWidth + Style.spacing.xs * 2
              color: root.svcWd14 ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcWd14 ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: wd14Row
                anchors.centerIn: parent
                spacing: 4
                Text {
                  textFormat: Text.PlainText
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcWd14 ? "#4ade80" : "#f87171"
                }
                Text {
                  textFormat: Text.PlainText
                  text: "WD14 ONNX"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcWd14 ? "#4ade80" : "#f87171"
                }
              }
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            textFormat: Text.PlainText
            text: "VRAM: " + (root.vramUsed / 1024).toFixed(1) + " / " + (root.vramTotal / 1024).toFixed(1) + " GB (" + root.vramPct + "%)"
            font.family: Style.font.family
            font.features: { "tnum": 1 }
            font.pixelSize: Style.font.caption
            color: Color.foreground
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // Binary Degradation / Missing Guard Warning (#screens Error/Fallback State)
        Rectangle {
          Layout.fillWidth: true
          visible: !root.isBridgeAvailable
          implicitHeight: Style.space(34)
          color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
          border.color: Color.urgent
          border.width: 1
          radius: Style.cornerRadius

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.xs

            Text {
              textFormat: Text.PlainText
              text: "ERR //"
              color: Color.urgent
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: root.currentLang === "cs"
                ? "CHYBA MŮSTKU: bin/qwen-bridge chybí nebo není spustitelný. Spusť install.sh nebo cargo build --release."
                : "BRIDGE ERROR: bin/qwen-bridge is missing or not executable. Run install.sh or cargo build --release."
              color: Color.urgent
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }

            Button {
              text: root.currentLang === "cs" ? "ZKONTROLOVAT" : "RECHECK"
              fontSize: Style.font.caption
              bordered: true
              onClicked: {
                root.checkBridge();
                root.refreshTelemetry();
              }
            }
          }
        }

        // MAIN VIEW CONTAINER
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Loader {
            id: viewLoader
            anchors.fill: parent
            sourceComponent: {
              if (root.currentView === "compare") return compareComponent;
              if (root.currentView === "civitai") return civitaiComponent;
              if (root.currentView === "history") return historyComponent;
              return studioComponent;
            }
          }

          Component {
            id: studioComponent
            StudioView { panelRoot: root.svc }
          }

          Component {
            id: compareComponent
            CompareView { panelRoot: root.svc }
          }

          Component {
            id: civitaiComponent
            CivitaiView { panelRoot: root.svc }
          }

          Component {
            id: historyComponent
            HistoryView { panelRoot: root.svc }
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // FOOTER BAR WITH VERSION AND ESCAPE HINT
        Item {
          Layout.fillWidth: true
          implicitHeight: Style.space(16)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: root.pluginVersion
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "ESC // " + (root.currentLang === "cs" ? "ZAVŘÍT" : "CLOSE")
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
          }
        }
      }
    }
  }
}
