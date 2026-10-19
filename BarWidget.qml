import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simonez.qwenimage"

  readonly property var shellService: (bar && bar.shell && typeof bar.shell.serviceFor === "function")
    ? bar.shell.serviceFor("simonez.qwenimage")
    : null

  Loader {
    id: localServiceLoader
    active: root.shellService === null && root.opened
    sourceComponent: Component {
      Service {
        activePolling: false
      }
    }
  }

  readonly property var svc: root.shellService ? root.shellService : (localServiceLoader.item || null)

  property string studioStatus: svc ? svc.studioStatus : "READY"
  property int vramUsed: svc ? svc.vramUsed : 0
  property int vramTotal: svc ? svc.vramTotal : 8192
  property int vramPct: svc ? svc.vramPct : 0
  property bool isOnline: svc ? svc.isOnline : false
  property bool isGameLocked: svc ? svc.isGameLocked : false
  property bool isBusy: svc ? svc.isBusy : false

  readonly property string displayLabel: {
    if (isBusy) return "QIS // BUSY";
    if (isGameLocked) return "QIS // LOCKED";
    if (!isOnline) return "QIS // OFFLINE";
    return "QIS // READY";
  }

  readonly property color statusColor: {
    if (isBusy) return Commons.Color.accent;
    if (isGameLocked) return Commons.Color.urgent;
    if (!isOnline) return Commons.Util.alpha(Commons.Color.foreground, 0.45);
    return Commons.Color.foreground;
  }

  readonly property real _iconDpiScale: Screen.devicePixelRatio

  property alias anchorButton: button
  property bool opened: false
  property bool watchingService: false

  function syncService() {
    if (!root.svc) return;
    if ("settings" in root.svc) root.svc.settings = root.settings;
    if ("bar" in root.svc) root.svc.bar = root.bar;
  }

  function open() {
    root.syncService();
    root.opened = true;
    if (panelLoader.item) {
      panelLoader.item.open();
    }
  }

  function close() {
    if (panelLoader.item) {
      panelLoader.item.close();
    }
    root.opened = false;
  }

  function toggle() {
    if (root.opened) {
      root.close();
    } else {
      root.open();
    }
  }

  function togglePanel() {
    root.toggle();
  }

  function refresh() {
    if (root.svc) {
      root.svc.refresh();
    }
  }

  readonly property real openPanelIndicatorWidth: Math.round(Commons.Style.bar.iconSlot * 0.55)
  readonly property real openPanelIndicatorHeight: Math.max(Commons.Style.space(10), Math.round(Commons.Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) {
      panelLoader.item.closeForPopoutSwitch();
    }
    root.opened = false;
  }

  function injectPanel() {
    root.syncService();
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
    if ("injectedService" in target) target.injectedService = root.svc;
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onSvcChanged: injectPanel()

  onOpenedChanged: {
    if (root.opened) {
      if (!root.watchingService && root.svc) {
        root.watchingService = true;
        root.svc.watch();
      }
      if (root.svc) {
        root.svc.refresh();
      }
    } else {
      if (root.watchingService && root.svc) {
        root.watchingService = false;
        root.svc.unwatch();
      }
    }
  }

  Component.onDestruction: {
    if (root.watchingService && root.svc) {
      root.watchingService = false;
      root.svc.unwatch();
    }
  }

  WidgetButton {
    id: button
    bar: root.bar
    text: " "
    labelVisible: false
    fixedWidth: Commons.Style.bar.iconSlot
    active: root.opened
    tooltipText: "Qwen-Image Studio (" + root.studioStatus + " · " + root.vramUsed + " / " + root.vramTotal + " MB VRAM)"

    Item {
      anchors.centerIn: parent
      width: Commons.Style.bar.iconFont
      height: Commons.Style.bar.iconFont

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
        colorizationColor: (typeof bar !== "undefined" && bar && bar.foreground) ? bar.foreground : Commons.Color.foreground
      }
    }

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        root.refresh();
      } else {
        root.togglePanel();
      }
    }
  }

  Loader {
    id: panelLoader
    active: root.opened
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      if (root.opened && panelLoader.item) {
        panelLoader.item.open();
      }
      Qt.callLater(function() {
        root.injectPanel();
        if (root.opened && panelLoader.item && !panelLoader.item.opened) {
          panelLoader.item.open();
        }
      });
    }
  }

  function isTargetScreen(): bool {
    if (!root.bar || !root.bar.screen) return true;
    try {
      if (typeof Hyprland !== "undefined" && Hyprland && Hyprland.focusedMonitor) {
        const m = Hyprland.monitorFor(root.bar.screen);
        if (m && Hyprland.focusedMonitor && m.name !== Hyprland.focusedMonitor.name) {
          return false;
        }
      }
    } catch (e) {}
    return true;
  }

  Connections {
    target: root.svc
    ignoreUnknownSignals: true

    function onOpenRequested(view) {
      if (!root.isTargetScreen()) return;
      root.open();
    }

    function onCloseRequested() {
      root.close();
    }

    function onToggleRequested() {
      if (!root.isTargetScreen()) return;
      root.togglePanel();
    }
  }

  Component.onCompleted: {
    root.syncService();
    if (root.svc) {
      root.svc.refresh();
    }
  }
}
