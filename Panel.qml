import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
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
  readonly property color positiveColor: Qt.hsva(0.38, 0.65, 0.85, 1.0)

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
  readonly property string currentLang: "en"
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

  property string activePromptSource: svc ? svc.activePromptSource : "civitai"
  onActivePromptSourceChanged: {
    if (svc && svc.activePromptSource !== activePromptSource) {
      svc.activePromptSource = activePromptSource;
    }
  }

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
    contentWidth: panel.fittedContentWidth(Commons.Style.space(960))
    contentHeight: panel.fittedContentHeight(Commons.Style.space(720))

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
        anchors.margins: Commons.Style.spacing.md
        spacing: Commons.Style.spacing.sm

        // HEADER BAR WITH SYSTEM HEALTH & SERVICE BADGES
        RowLayout {
          Layout.fillWidth: true
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
                text: root.versionQwen
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
              color: root.svcComfy ? Commons.Util.alpha(root.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
              border.color: root.svcComfy ? Commons.Util.alpha(root.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
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
                  color: root.svcComfy ? root.positiveColor : Commons.Color.urgent
                }
                Text {
                  textFormat: Text.PlainText
                  text: (root.versionComfy && root.versionComfy !== "Offline" && root.versionComfy !== "Online") ? ("COMFYUI v" + root.versionComfy) : "COMFYUI"
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: root.svcComfy ? root.positiveColor : Commons.Color.urgent
                }
              }
            }

            // 2. OLLAMA
            Rectangle {
              height: Commons.Style.space(20)
              implicitWidth: ollamaRow.implicitWidth + Commons.Style.spacing.xs * 2
              color: root.svcOllama ? Commons.Util.alpha(root.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
              border.color: root.svcOllama ? Commons.Util.alpha(root.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
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
                  color: root.svcOllama ? root.positiveColor : Commons.Color.urgent
                }
                Text {
                  textFormat: Text.PlainText
                  text: (root.versionOllama && root.versionOllama !== "Offline" && root.versionOllama !== "Online") ? ("OLLAMA v" + root.versionOllama) : "OLLAMA"
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: root.svcOllama ? root.positiveColor : Commons.Color.urgent
                }
              }
            }

            // 3. WD14 ONNX
            Rectangle {
              height: Commons.Style.space(20)
              implicitWidth: wd14Row.implicitWidth + Commons.Style.spacing.xs * 2
              color: root.svcWd14 ? Commons.Util.alpha(root.positiveColor, 0.15) : Commons.Util.alpha(Commons.Color.urgent, 0.15)
              border.color: root.svcWd14 ? Commons.Util.alpha(root.positiveColor, 0.6) : Commons.Util.alpha(Commons.Color.urgent, 0.6)
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
                  color: root.svcWd14 ? root.positiveColor : Commons.Color.urgent
                }
                Text {
                  textFormat: Text.PlainText
                  text: "WD14 ONNX"
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: root.svcWd14 ? root.positiveColor : Commons.Color.urgent
                }
              }
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            textFormat: Text.PlainText
            text: "VRAM: " + (root.vramUsed / 1024).toFixed(1) + " / " + (root.vramTotal / 1024).toFixed(1) + " GB (" + root.vramPct + "%)"
            font.family: Commons.Style.font.family
            font.features: { "tnum": 1 }
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Color.foreground
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // Binary Degradation / Missing Guard Warning (#screens Error/Fallback State)
        Rectangle {
          Layout.fillWidth: true
          visible: !root.isBridgeAvailable
          implicitHeight: Commons.Style.space(34)
          color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15)
          border.color: Commons.Color.urgent
          border.width: 1
          radius: Commons.Style.cornerRadius

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Commons.Style.spacing.sm
            anchors.rightMargin: Commons.Style.spacing.sm
            spacing: Commons.Style.spacing.xs

            Text {
              textFormat: Text.PlainText
              text: "ERR //"
              color: Commons.Color.urgent
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: "BRIDGE ERROR: bin/qwen-bridge is missing or not executable. Run install.sh or cargo build --release."
              color: Commons.Color.urgent
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }

            Button {
              text: "RECHECK"
              fontSize: Commons.Style.font.caption
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
          implicitHeight: Commons.Style.space(16)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: root.pluginVersion
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              color: Commons.Util.alpha(root.bar ? root.bar.foreground : Commons.Color.foreground, 0.55)
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "ESC // CLOSE"
            font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Util.alpha(root.bar ? root.bar.foreground : Commons.Color.foreground, 0.55)
          }
        }
      }
    }
  }
}
