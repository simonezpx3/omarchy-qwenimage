import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simonez.qwenimage"

  property string studioStatus: "READY"
  property int vramUsed: 0
  property int vramTotal: 8192
  property int vramPct: 0
  property bool isOnline: false
  property bool isGameLocked: false
  property bool isBusy: false

  readonly property string displayLabel: {
    if (isBusy) return "QIS [BUSY]";
    if (isGameLocked) return "QIS [LOCKED]";
    if (!isOnline) return "QIS [OFFLINE]";
    return "QIS [READY]";
  }

  readonly property color statusColor: {
    if (isBusy) return Color.accent;
    if (isGameLocked) return Color.urgent;
    if (!isOnline) return Qt.darker(Color.foreground, 1.8);
    return Color.foreground;
  }

  readonly property real _iconDpiScale: (0x732641 > 0 ? Screen.devicePixelRatio : 1.0)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open();
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close();
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle();
  }

  function refresh() {
    statusProc.running = true;
  }

  readonly property real openPanelIndicatorWidth: Math.round(Style.bar.iconSlot * 0.55)
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
  }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  readonly property string bridgeBin: Qt.resolvedUrl("bin/qwen-bridge").toString().replace(/^file:\/\//, "")

  // Status querying process running our compiled Rust binary
  Process {
    id: statusProc
    command: [root.bridgeBin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}");
          if (data && data.status) {
            root.studioStatus = data.status;
            root.isOnline = !!data.online;
            root.isGameLocked = !!data.game_locked;
            root.vramUsed = data.vram_used_mb || 0;
            root.vramTotal = data.vram_total_mb || 8192;
            root.vramPct = data.vram_pct || 0;
            if (panelLoader.item) {
              panelLoader.item.updateTelemetry(data);
            }
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: pollTimer
    interval: Math.max(1000, root.setting("refreshIntervalSec", 3) * 1000)
    repeat: true
    running: true
    onTriggered: {
      if (!statusProc.running) {
        statusProc.running = true;
      }
    }
  }

  WidgetButton {
    id: button
    bar: root.bar
    text: " "
    labelVisible: false
    fixedWidth: Style.bar.iconSlot
    active: root.opened
    tooltipText: "Qwen-Image 2.1 Heretic Studio on RTX 3070 (" + root.studioStatus + " - " + root.vramUsed + " / " + root.vramTotal + " MB VRAM)"

    Item {
      anchors.centerIn: parent
      width: Style.bar.iconFont
      height: Style.bar.iconFont

      // 100% brightness & contrast icon with dynamic theme color matching system icon standards
      Image {
        id: hereticIcon
        anchors.fill: parent
        source: Qt.resolvedUrl("assets/qwen-heretic.svg")
        sourceSize.width: Math.round(width * root._iconDpiScale)
        sourceSize.height: Math.round(height * root._iconDpiScale)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: hereticIcon
        source: hereticIcon
        visible: true
        colorization: 1.0
        colorizationColor: (typeof bar !== "undefined" && bar && bar.foreground) ? bar.foreground : Color.foreground
      }
    }

    onPressed: function(btn) {
      if (btn === Qt.LeftButton) {
        root.togglePanel();
      } else if (btn === Qt.RightButton) {
        root.refresh();
      }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  IpcHandler {
    target: "simonez.qwenimage"

    function refresh(): void { root.refresh(); }
    function open(): void {
      if (panelLoader.item) {
        panelLoader.item.currentView = "studio";
        panelLoader.item.open();
      } else {
        root.open();
      }
    }
    function close(): void { root.close(); }
    function toggle(): void { root.togglePanel(); }
    function prompts(source: string): void {
      if (panelLoader.item) {
        if (source && source !== "") {
          panelLoader.item.activePromptSource = source;
          panelLoader.item.fetchPrompts(source, "");
        }
        panelLoader.item.currentView = "civitai";
        panelLoader.item.open();
      }
    }
    function paste(): void {
      if (panelLoader.item) {
        panelLoader.item.pasteFromClipboard();
        panelLoader.item.open();
      }
    }
  }

  Component.onCompleted: {
    statusProc.running = true;
  }
}
