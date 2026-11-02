import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var service: null

  function fetchPrompts(source, query) {
    if (!service || !service.isBridgeAvailable || !service.bridgeBin) {
      if (service) service.isCivitaiLoading = false;
      return;
    }
    service.isCivitaiLoading = true;
    service.activePromptSource = source || "civitai";
    var cmd = [
      service.bridgeBin,
      "prompts",
      service.activePromptSource,
      query || "",
      "--limit",
      "100"
    ];
    if (service.isNsfwEnabled) {
      cmd.push("--nsfw");
    }
    civitaiProc.running = false;
    civitaiProc.command = cmd;
    civitaiProc.running = true;
  }

  function fetchCivitaiPrompts(query) {
    if (!service) return;
    fetchPrompts(service.activePromptSource || "civitai", query);
  }

  function fetchHistory() {
    if (!service || !service.isBridgeAvailable || !service.bridgeBin) {
      if (service) service.isHistoryLoading = false;
      return;
    }
    if (histProc.running) {
      return;
    }
    service.isHistoryLoading = true;
    histProc.command = [service.bridgeBin, "history", "30"];
    histProc.running = true;
  }

  function restoreFromHistory(path, prompt, seed, ratio, negative) {
    if (!service) return;
    if (prompt) service.promptText = prompt;
    if (negative !== undefined && negative !== null && negative !== "") {
      service.negativePromptText = negative;
    }
    if (seed && seed > 0) {
      service.seedVal = seed;
      service.seedLocked = true;
    }
    if (ratio) service.aspectRatio = ratio;
    service.generatedPath = path;
    service.baseGeneratedPath = path;
  }

  Process {
    id: civitaiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isCivitaiLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 524288) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.items) {
            service.civitaiModel = res.items;
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: histProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isHistoryLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 524288) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.items) {
            service.historyModel = res.items;
          }
        } catch (e) {}
      }
    }
  }
}
