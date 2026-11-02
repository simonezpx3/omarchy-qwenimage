import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var service: null

  function sanitizePromptText(text) {
    if (!text) return "";
    var s = String(text);
    // 1. Remove U+FFF9..U+FFFB (Interlinear Annotation Anchors) & U+FFFD (Replacement Character)
    s = s.replace(/[\uFFF9-\uFFFB\uFFFD]/g, "");
    // 2. Remove Zero-width, BOM, Word Joiners & Soft Hyphen
    s = s.replace(/[\uFEFF\u200B-\u200D\u2060\u00AD]/g, "");
    // 3. Remove Bidi overrides and isolates
    s = s.replace(/[\u202A-\u202E\u2066-\u2069\u200E\u200F]/g, "");
    // 4. Remove Private Use Area (Nerd Font / PUA glyphs)
    s = s.replace(/[\uE000-\uF8FF]/g, "");
    // 5. Remove C0/C1 control characters except newline and tab
    s = s.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, "");
    // 6. Normalize multiple spaces and repeated commas
    s = s.replace(/[ \t]+/g, " ");
    s = s.replace(/,\s*,+/g, ", ");
    return s.trim();
  }

  function recallPrompt(delta) {
    if (!service || service.promptHistory.length === 0) return;
    var newIdx = service.promptHistoryIndex + delta;
    if (newIdx < 0) newIdx = 0;
    if (newIdx >= service.promptHistory.length) newIdx = service.promptHistory.length - 1;
    service.promptHistoryIndex = newIdx;
    service.promptText = service.promptHistory[service.promptHistoryIndex];
  }

  function startGeneration() {
    if (!service) return;
    if (!service.isBridgeAvailable) {
      service.generationTelemetry = "ERROR: bin/qwen-bridge is missing! Run install.sh";
      return;
    }
    if (service.isGenerating || service.isGameLocked) return;
    service.promptText = sanitizePromptText(service.promptText);
    service.negativePromptText = sanitizePromptText(service.negativePromptText);
    var trimmed = service.promptText;
    if (trimmed === "") return;

    if (service.promptHistory.indexOf(trimmed) === -1) {
      service.promptHistory.push(trimmed);
      service.promptHistoryIndex = service.promptHistory.length - 1;
    }

    service.isGenerating = true;
    service.generatingMode = "generate";
    service.currentScaleFactor = 0.0;
    service.livePreviewPath = "";
    service.livePreviewStep = 0;
    service.livePreviewMaxSteps = service.steps;
    service.livePreviewTick = 0;

    var actualSeed = service.seedLocked ? Number(service.seedVal) : -1;
    var args = [
      service.bridgeBin,
      "generate",
      trimmed,
      service.aspectRatio,
      String(service.steps),
      String(service.cfg),
      String(actualSeed),
      service.negativePromptText
    ];

    if (service.referencePath !== "") {
      args.push(service.referencePath);
      var clampedDenoise = Math.min(0.95, Math.max(0.05, service.denoise));
      args.push(String(clampedDenoise));
    }

    if (service.animeMode === "soft" || service.animeMode === "full") {
      args.push("--anime");
      args.push(service.animeMode);
    }

    if (service.isTurboEnabled) {
      args.push("--turbo");
    }

    if (service.hereticMode === "soft" || service.hereticMode === "full") {
      args.push("--heretic");
      args.push(service.hereticMode);
    }

    if (service.anatomyMode === "soft" || service.anatomyMode === "full") {
      args.push("--anatomy");
      args.push(service.anatomyMode);
    }

    if (service.isAutoExpandEnabled) {
      args.push("--expand");
    }

    if (service.resMode && service.resMode !== "") {
      args.push("--res");
      args.push(service.resMode);
    }

    genProc.command = args;
    genProc.running = true;
  }

  function cancelGeneration() {
    if (!service) return;
    if ((!service.isGenerating && !genProc.running) || service.isCancelling) return;
    service.isCancelling = true;

    if (genProc.running) {
      genProc.running = false;
    }
    interruptProc.command = [service.bridgeBin, "interrupt"];
    interruptProc.running = false;
    interruptProc.running = true;
    service.isGenerating = false;
    service.currentScaleFactor = 0.0;
    service.livePreviewPath = "";
    service.generationTelemetry = "GENERATION INTERRUPTED";
  }

  function aiUpscale(modelChoice) {
    if (!service || !service.isBridgeAvailable) return;
    var target = service.baseGeneratedPath !== "" ? service.baseGeneratedPath : (service.generatedPath !== "" ? service.generatedPath : service.referencePath);
    if (target === "" || service.isGenerating) return;

    service.isGenerating = true;
    service.generatingMode = "scale_" + modelChoice;
    service.currentScaleFactor = (modelChoice === "sana") ? 2.0 : 4.0;

    var args = [
      service.bridgeBin,
      "upscale",
      target,
      modelChoice
    ];

    if (service.isAnimeLoRAEnabled) {
      args.push("--anime");
    }

    scaleProc.command = args;
    scaleProc.running = true;
  }

  function aiEnhance() {
    aiUpscale("ultra");
  }

  function scaleImage(factor) {
    if (!service || !service.isBridgeAvailable) return;
    var target = service.baseGeneratedPath !== "" ? service.baseGeneratedPath : (service.generatedPath !== "" ? service.generatedPath : service.referencePath);
    if (target === "" || service.isGenerating) return;
    service.isGenerating = true;
    service.generatingMode = "scale";
    service.currentScaleFactor = factor;
    scaleProc.command = [
      service.bridgeBin,
      "scale",
      target,
      String(factor)
    ];
    scaleProc.running = true;
  }

  function optimizePrompt(rawText) {
    if (!service || !rawText || rawText.trim() === "" || service.isOptimizingPrompt) return;
    service.isOptimizingPrompt = true;
    optProc.command = [service.bridgeBin, "optimize-prompt", rawText.trim()];
    optProc.running = true;
  }

  function interrogateWd14() {
    if (!service || !service.isBridgeAvailable || service.referencePath === "" || service.isInterrogating) return;
    service.isInterrogating = true;
    tagProc.command = [service.bridgeBin, "interrogate", service.referencePath];
    tagProc.running = true;
  }

  function extractVisionPrompt() {
    if (!service || !service.isBridgeAvailable || service.referencePath === "" || service.isVisionLoading) return;
    service.isVisionLoading = true;
    visionProc.command = [service.bridgeBin, "vision", service.referencePath];
    visionProc.running = true;
  }

  function setReferenceImage(path) {
    if (!service || !path) return;
    service.referencePath = path;
    service.referenceRevision++;
    metaProc.command = [service.bridgeBin, "read-meta", path];
    metaProc.running = true;
  }

  function clearReference() {
    if (!service) return;
    if (service.referencePath === "" && service.referenceMatchedRatio === "") return;
    service.referencePath = "";
    service.referenceMatchedRatio = "";
    service.referenceRevision++;
  }

  function resetForm() {
    if (!service) return;
    if (service.isGenerating || genProc.running) {
      cancelGeneration();
    }
    service.promptText = "";
    service.negativePromptText = "blurry, low quality, deformed, extra fingers, text, watermark";
    service.aspectRatio = "1:1";
    service.resMode = "standard";
    service.steps = 25;
    service.seedLocked = false;
    service.seedVal = -1;
    service.referencePath = "";
    service.referenceMatchedRatio = "";
    service.referenceRevision = 0;
    service.denoise = 0.65;
    service.generatedPath = "";
    service.baseGeneratedPath = "";
    service.previousGeneratedPath = "";
    service.livePreviewPath = "";
    service.livePreviewStep = 0;
    service.generationTelemetry = "1024x1024 | 25 STEPS | LOCAL GPU (0 TOKENS)";
  }

  function handleGenLine(line) {
    if (!service) return;
    var trimmed = (line || "").trim();
    if (!trimmed || trimmed === "" || trimmed.length > 65536) return;
    try {
      var res = JSON.parse(trimmed);
      if (res.event === "preview") {
        service.livePreviewPath = res.path || "";
        service.livePreviewStep = res.step || 0;
        service.livePreviewMaxSteps = res.max_steps || service.steps;
        service.livePreviewTick += 1;
      } else if (res.status === "ok" && res.path) {
        service.isGenerating = false;
        service.currentScaleFactor = 0.0;
        service.livePreviewPath = "";
        service.previousGeneratedPath = service.generatedPath;
        service.generatedPath = res.path;
        service.baseGeneratedPath = res.path;
        var elapsedSec = (typeof res.elapsed === "number") ? res.elapsed.toFixed(1) : String(res.elapsed || "0");
        service.generationTelemetry = (res.ratio || "1:1") + " | " + (res.steps || service.steps) + " STEPS | " + elapsedSec + "s | SEED: " + (res.seed >= 0 ? res.seed : "RANDOM");
        service.fetchHistory();
      } else if (res.status === "error") {
        service.isGenerating = false;
        service.currentScaleFactor = 0.0;
        service.livePreviewPath = "";
        service.generationTelemetry = "ERROR: " + (res.message || "Generation failed");
      }
    } catch (e) {}
  }

  Process {
    id: genProc
    stdout: SplitParser {
      onRead: function(line) {
        root.handleGenLine(line);
      }
    }
    onExited: function(exitCode) {
      if (!service) return;
      service.isCancelling = false;
      if (service.isGenerating) {
        service.isGenerating = false;
        service.currentScaleFactor = 0.0;
        service.livePreviewPath = "";
        if (exitCode !== 0) {
          service.generationTelemetry = "ERROR: Process exited (" + exitCode + ")";
        }
      }
    }
  }

  Process {
    id: interruptProc
    command: service && service.bridgeBin ? [service.bridgeBin, "interrupt"] : []
    onExited: function() {
      if (service) {
        service.isCancelling = false;
      }
    }
  }

  Process {
    id: scaleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isGenerating = false;
        service.currentScaleFactor = 0.0;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            service.previousGeneratedPath = service.generatedPath;
            service.generatedPath = res.path;
            var info = (res.factor ? (res.factor + " ") : (res.tier ? ("AI " + res.tier + " ") : "")) + (res.width || "2048") + "x" + (res.height || "2048");
            if (res.model) {
              info += " // " + res.model.replace(".safetensors", "");
            } else {
              info += " // SIMD LANCZOS";
            }
            service.generationTelemetry = info;
            service.fetchHistory();
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: tagProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isInterrogating = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.raw) {
            if (service.promptText.trim() === "") {
              service.promptText = res.raw;
            } else {
              service.promptText = service.promptText + ", " + res.raw;
            }
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: visionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isVisionLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.prompt) {
            service.promptText = res.prompt;
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: metaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok") {
            if (res.prompt) service.promptText = res.prompt;
            if (res.negative_prompt) service.negativePromptText = res.negative_prompt;
            if (res.seed && res.seed > 0) {
              service.seedVal = res.seed;
              service.seedLocked = true;
            }
            if (res.ratio) {
              service.aspectRatio = res.ratio;
              service.referenceMatchedRatio = res.ratio;
            }
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: optProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        service.isOptimizingPrompt = false;
        var raw = (text || "").trim();
        if (raw === "" || raw.length > 65536) return;
        try {
          var res = JSON.parse(raw);
          if (res.rewritten_prompt && res.rewritten_prompt.trim() !== "") {
            service.promptText = res.rewritten_prompt.trim();
          } else if (res.optimized_prompt && res.optimized_prompt.trim() !== "") {
            service.promptText = res.optimized_prompt.trim();
          }
          if (res.negative_prompt && res.negative_prompt.trim() !== "") {
            service.negativePromptText = res.negative_prompt.trim();
          }
          if (res.wh_ratio && res.wh_ratio.trim() !== "") {
            var ratio = res.wh_ratio.trim();
            var validRatios = ["16:10", "16:9", "1:1", "9:16", "21:9", "4:3", "3:4", "3:2", "2:3"];
            if (validRatios.indexOf(ratio) !== -1) {
              service.aspectRatio = ratio;
            }
          }
        } catch (e) {
          service.promptText = raw;
        }
      }
    }
  }
}
