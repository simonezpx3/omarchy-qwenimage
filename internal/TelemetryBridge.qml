import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var service: null

  function watch() {
    if (!service) return;
    service.watchers += 1;
    refreshTelemetry();
  }

  function unwatch() {
    if (!service) return;
    service.watchers = Math.max(0, service.watchers - 1);
  }

  function checkBridge() {
    if (!service || !service.bridgeBin) return;
    checkBridgeProc.command = ["test", "-x", service.bridgeBin];
    if (!checkBridgeProc.running) {
      checkBridgeProc.running = true;
    }
  }

  function refresh() {
    if (!service || !service.bridgeBin) return;
    statusProc.command = [service.bridgeBin, "status"];
    if (!statusProc.running) {
      statusProc.running = true;
    }
  }

  function refreshTelemetry() {
    checkBridge();
    refresh();
  }

  function updateTelemetry(data) {
    if (!service || !data) return;
    service.studioStatus = data.status || "READY";
    service.isOnline = !!data.online;
    service.isGameLocked = !!data.game_locked;
    service.vramUsed = data.vram_used_mb || 0;
    service.vramTotal = data.vram_total_mb || 8192;
    service.vramPct = data.vram_pct || 0;
    service.hardwareTier = data.hardware_tier || service.hardwareTier;
    service.maxSupportedDim = data.max_res_dim || service.maxSupportedDim;
    if (data.supported_res_modes && Array.isArray(data.supported_res_modes)) {
      service.supportedResModes = data.supported_res_modes;
    }
    if (data.services) {
      service.svcComfy = !!data.services.comfyui;
      service.svcGpu = !!data.services.gpu;
      service.svcOllama = !!data.services.ollama;
      service.svcWd14 = !!data.services.wd14;
      service.svcCivitai = !!data.services.civitai;
    }
    if (data.versions) {
      if (data.versions.plugin && typeof service.setBridgeVersion === "function") {
        service.setBridgeVersion(data.versions.plugin);
      }
      service.versionQwen = data.versions.qwen_model || service.versionQwen;
      service.versionComfy = data.versions.comfyui || "";
      service.versionOllama = data.versions.ollama || "";
      service.versionGpuDriver = data.versions.driver ? (data.gpu_name + " (" + data.versions.driver + ")") : (data.gpu_name || "");
      service.versionQuickshell = data.versions.quickshell || "";
      service.versionHyprland = data.versions.hyprland || "";
    }
  }

  Process {
    id: statusProc
    command: service && service.bridgeBin ? [service.bridgeBin, "status"] : []
    onRunningChanged: {
      if (statusProc.running) {
        statusWatchdog.restart();
      } else {
        statusWatchdog.stop();
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        statusWatchdog.stop();
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var data = JSON.parse(str);
          if (data && data.status) {
            root.updateTelemetry(data);
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: statusWatchdog
    interval: 8000
    repeat: false
    running: false
    onTriggered: {
      if (statusProc.running) {
        statusProc.running = false;
      }
    }
  }

  Timer {
    id: pollTimer
    interval: service && service.watchers > 0 ? 2000 : Math.max(1000, (service && typeof service.setting === "function" ? service.setting("refreshIntervalSec", 3) : 3) * 1000)
    repeat: true
    running: service ? service.activePolling : true
    onTriggered: {
      if (!statusProc.running) {
        statusProc.running = true;
      }
    }
  }

  Process {
    id: checkBridgeProc
    command: service && service.bridgeBin ? ["test", "-x", service.bridgeBin] : []
    onExited: function(exitCode) {
      if (service) {
        service.isBridgeAvailable = (exitCode === 0);
      }
    }
  }
}
