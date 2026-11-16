import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var service: null

  function loadSettings() {
    if (service && service.bridgeBin) {
      loadLangProc.command = [service.bridgeBin, "settings"];
      loadLangProc.running = true;
    }
  }

  function saveSetting(key, val) {
    if (!service || !service.bridgeBin) return;
    if (saveSettingsProc.running) {
      saveSettingsProc.running = false;
    }
    saveSettingsProc.command = [service.bridgeBin, "settings", "set", String(key), String(val)];
    Qt.callLater(function() {
      if (!saveSettingsProc.running) {
        saveSettingsProc.running = true;
      }
    });
  }

  function toggleLanguage() {
    if (!service) return;
    service.currentLang = "en";
    saveSetting("language", "en");
  }

  function toggleNsfw() {
    if (!service) return;
    service.isNsfwEnabled = !service.isNsfwEnabled;
    saveSetting("nsfw", service.isNsfwEnabled ? "true" : "false");
    service.fetchPrompts(service.activePromptSource, "");
  }

  function cycleAnimeMode() {
    if (!service) return;
    if (service.animeMode === "off") service.animeMode = "light";
    else if (service.animeMode === "light" || service.animeMode === "soft") service.animeMode = "medium";
    else if (service.animeMode === "medium") service.animeMode = "heavy";
    else service.animeMode = "off";
    saveSetting("anime_mode", service.animeMode);
  }

  function toggleTurbo() {
    if (!service) return;
    service.isTurboEnabled = !service.isTurboEnabled;
    if (!service.isTurboEnabled) {
      if (service.steps < 22) {
        service.steps = 25;
      }
      service.cfg = 3.2;
    } else {
      if (service.steps > 9) {
        service.steps = 6;
      }
      service.cfg = 1.0;
    }
    service.autoTuneSummary = "";
    saveSetting("turbo", service.isTurboEnabled ? "true" : "false");
  }

  function cycleHereticMode() {
    if (!service) return;
    if (service.hereticMode === "off") service.hereticMode = "light";
    else if (service.hereticMode === "light" || service.hereticMode === "soft") service.hereticMode = "medium";
    else if (service.hereticMode === "medium") service.hereticMode = "heavy";
    else service.hereticMode = "off";
    saveSetting("heretic_mode", service.hereticMode);
  }

  function cycleAnatomyMode() {
    if (!service) return;
    if (service.anatomyMode === "off") service.anatomyMode = "light";
    else if (service.anatomyMode === "light" || service.anatomyMode === "soft") service.anatomyMode = "medium";
    else if (service.anatomyMode === "medium") service.anatomyMode = "heavy";
    else service.anatomyMode = "off";
    saveSetting("anatomy_mode", service.anatomyMode);
  }

  function cycleAnatomyGuardMode() {
    if (!service) return;
    if (service.anatomyGuardMode === "auto") service.anatomyGuardMode = "on";
    else if (service.anatomyGuardMode === "on") service.anatomyGuardMode = "off";
    else service.anatomyGuardMode = "auto";
    saveSetting("anatomy_guard", service.anatomyGuardMode);
  }

  function cycleAutoTuneMode() {
    if (!service) return;
    if (service.autoTuneMode === "off") service.autoTuneMode = "balanced";
    else if (service.autoTuneMode === "balanced") service.autoTuneMode = "quality";
    else service.autoTuneMode = "off";
    saveSetting("auto_tune", service.autoTuneMode);
    if (service.autoTuneMode === "off") {
      service.autoTuneSummary = "";
    } else {
      applyAutoTune();
    }
  }

  function applyAutoTune() {
    if (!service || !service.bridgeBin || service.autoTuneMode === "off") return;
    var p = (service.promptText || "").trim();
    if (p === "" || service.isGenerating) return;
    var args = [service.bridgeBin, "analyze-prompt", p, "--profile", service.autoTuneMode];
    if (service.referencePath && service.referencePath !== "") {
      args.push("--has-ref");
      args.push("--denoise");
      args.push(String(service.denoise));
    }
    if (analyzeProc.running) {
      analyzeProc.running = false;
    }
    analyzeProc.command = args;
    analyzeProc.running = true;
  }

  Timer {
    id: autoTuneDebounceTimer
    interval: 350
    repeat: false
    onTriggered: root.applyAutoTune()
  }

  Connections {
    target: service
    function onPromptTextChanged() {
      if (service && service.autoTuneMode !== "off" && !service.isGenerating) {
        autoTuneDebounceTimer.restart();
      }
    }
    function onReferencePathChanged() {
      if (service && service.autoTuneMode !== "off" && !service.isGenerating) {
        autoTuneDebounceTimer.restart();
      }
    }
    function onDenoiseChanged() {
      if (service && service.autoTuneMode !== "off" && service.referencePath !== "" && !service.isGenerating) {
        autoTuneDebounceTimer.restart();
      }
    }
  }

  BoundedProcess {
    id: analyzeProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || service.autoTuneMode === "off" || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok") {
          if (typeof res.turbo === "boolean") service.isTurboEnabled = res.turbo;
          if (typeof res.steps === "number") service.steps = res.steps;
          if (typeof res.cfg === "number") service.cfg = res.cfg;
          service.autoTuneSummary = (res.turbo ? (res.steps >= 9 ? "HYBRID " : "TURBO ") : "") + res.steps + "s · CFG " + Number(res.cfg).toFixed(1);
        }
      } catch (e) {}
    }
  }

  function toggleAutoExpand() {
    if (!service) return;
    service.isAutoExpandEnabled = !service.isAutoExpandEnabled;
    saveSetting("auto_expand", service.isAutoExpandEnabled ? "true" : "false");
  }

  function setResolutionMode(mode) {
    if (!service || !mode) return;
    service.resMode = mode;
    saveSetting("res_mode", service.resMode);
  }

  Process {
    id: saveSettingsProc
  }

  BoundedProcess {
    id: loadLangProc
    maxOutBytes: 65536
    command: service && service.bridgeBin ? [service.bridgeBin, "settings"] : []
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        service.currentLang = "en";
        if (typeof res.nsfw === "boolean") {
          service.isNsfwEnabled = res.nsfw;
        }
        if (res.anime_mode) {
          service.animeMode = (res.anime_mode === "soft" ? "light" : (res.anime_mode === "full" ? "heavy" : res.anime_mode));
        } else if (typeof res.anime === "boolean") {
          service.animeMode = res.anime ? "heavy" : "off";
        }
        if (typeof res.turbo === "boolean") {
          service.isTurboEnabled = res.turbo;
        }
        if (res.heretic_mode) {
          service.hereticMode = (res.heretic_mode === "soft" ? "light" : (res.heretic_mode === "full" ? "heavy" : res.heretic_mode));
        } else if (res.uncensored_mode) {
          service.hereticMode = (res.uncensored_mode === "soft" ? "light" : (res.uncensored_mode === "full" ? "heavy" : res.uncensored_mode));
        } else if (typeof res.uncensored === "boolean") {
          service.hereticMode = res.uncensored ? "heavy" : "off";
        }
        if (res.anatomy_mode) {
          service.anatomyMode = (res.anatomy_mode === "soft" ? "light" : (res.anatomy_mode === "full" ? "heavy" : res.anatomy_mode));
        } else if (typeof res.anatomy === "boolean") {
          service.anatomyMode = res.anatomy ? "heavy" : "off";
        } else if (typeof res.anatomy_lora === "boolean") {
          service.anatomyMode = res.anatomy_lora ? "heavy" : "off";
        }
        if (res.anatomy_guard === "on" || res.anatomy_guard === "off" || res.anatomy_guard === "auto") {
          service.anatomyGuardMode = res.anatomy_guard;
        }
        if (res.auto_tune === "off" || res.auto_tune === "balanced" || res.auto_tune === "quality") {
          service.autoTuneMode = res.auto_tune;
          if (service.autoTuneMode !== "off" && (service.promptText || "").trim() !== "") {
            root.applyAutoTune();
          }
        }
        if (typeof res.auto_expand === "boolean") {
          service.isAutoExpandEnabled = res.auto_expand;
        }
        if (res.res_mode) {
          service.resMode = res.res_mode;
        }
      } catch (e) {}
    }
  }
}
