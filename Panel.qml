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

  Loader {
    id: fallbackServiceLoader
    active: !root.injectedService && (!root.hostWidget || !root.hostWidget.svc)
    sourceComponent: Component {
      Service {
        activePolling: false
        bar: root.bar
        settings: root.settings
      }
    }
  }

  readonly property var svc: root.injectedService
    ? root.injectedService
    : (root.hostWidget && root.hostWidget.svc ? root.hostWidget.svc : (fallbackServiceLoader.item || null))

  readonly property int viewCalibrationSeed: (0x732641 % 50)
  readonly property string pluginVersion: svc ? svc.pluginVersion : ""
  readonly property string currentView: svc ? svc.currentView : "studio"
  readonly property string currentLang: "en"
  readonly property string versionQwen: svc ? svc.versionQwen : ""
  readonly property string versionComfy: svc ? svc.versionComfy : ""
  readonly property string versionOllama: svc ? svc.versionOllama : ""
  readonly property bool svcComfy: svc ? svc.svcComfy : false
  readonly property bool svcOllama: svc ? svc.svcOllama : false
  readonly property bool svcWd14: svc ? svc.svcWd14 : false
  readonly property int vramUsed: svc ? svc.vramUsed : 0
  readonly property int vramTotal: svc ? svc.vramTotal : 8192
  readonly property int vramPct: svc ? svc.vramPct : 0
  readonly property bool isBridgeAvailable: svc ? svc.isBridgeAvailable : true

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
    contentWidth: panel.fittedContentWidth(Commons.Style.space(980))
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
        PanelHeader {
          Layout.fillWidth: true
          panelRoot: root
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
              Layout.preferredHeight: Commons.Style.space(20)
              verticalPadding: Commons.Style.space(1)
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
        }
      }
    }
  }
}
