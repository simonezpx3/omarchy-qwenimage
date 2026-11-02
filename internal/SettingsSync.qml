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
    if (service.animeMode === "off") service.animeMode = "soft";
    else if (service.animeMode === "soft") service.animeMode = "full";
    else service.animeMode = "off";
    saveSetting("anime_mode", service.animeMode);
  }

  function toggleTurbo() {
    if (!service) return;
    service.isTurboEnabled = !service.isTurboEnabled;
    if (!service.isTurboEnabled && service.steps < 25) {
      service.steps = 28;
      service.cfg = 4.0;
    } else if (service.isTurboEnabled && service.steps > 8) {
      service.steps = 6;
      service.cfg = 1.0;
    }
    saveSetting("turbo", service.isTurboEnabled ? "true" : "false");
  }

  function cycleHereticMode() {
    if (!service) return;
    if (service.hereticMode === "off") service.hereticMode = "soft";
    else if (service.hereticMode === "soft") service.hereticMode = "full";
    else service.hereticMode = "off";
    saveSetting("heretic_mode", service.hereticMode);
  }

  function cycleAnatomyMode() {
    if (!service) return;
    if (service.anatomyMode === "off") service.anatomyMode = "soft";
    else if (service.anatomyMode === "soft") service.anatomyMode = "full";
    else service.anatomyMode = "off";
    saveSetting("anatomy_mode", service.anatomyMode);
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

  Process {
    id: loadLangProc
    command: service && service.bridgeBin ? [service.bridgeBin, "settings"] : []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          service.currentLang = "en";
          if (typeof res.nsfw === "boolean") {
            service.isNsfwEnabled = res.nsfw;
          }
          if (res.anime_mode) {
            service.animeMode = res.anime_mode;
          } else if (typeof res.anime === "boolean") {
            service.animeMode = res.anime ? "full" : "off";
          }
          if (typeof res.turbo === "boolean") {
            service.isTurboEnabled = res.turbo;
          }
          if (res.heretic_mode) {
            service.hereticMode = res.heretic_mode;
          } else if (res.uncensored_mode) {
            service.hereticMode = res.uncensored_mode;
          } else if (typeof res.uncensored === "boolean") {
            service.hereticMode = res.uncensored ? "full" : "off";
          }
          if (res.anatomy_mode) {
            service.anatomyMode = res.anatomy_mode;
          } else if (typeof res.anatomy === "boolean") {
            service.anatomyMode = res.anatomy ? "full" : "off";
          } else if (typeof res.anatomy_lora === "boolean") {
            service.anatomyMode = res.anatomy_lora ? "full" : "off";
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
}
