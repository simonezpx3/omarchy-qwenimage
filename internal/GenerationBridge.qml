import QtQuick
import Quickshell
import Quickshell.Io
import "PromptUtils.js" as PromptUtils

Item {
  id: root

  property var service: null

  function sanitizePromptText(text) {
    return PromptUtils.sanitizePromptText(text);
  }

  function recallPrompt(delta) {
    if (!service || service.promptHistory.length === 0) return;
    var newIdx = service.promptHistoryIndex + delta;
    if (newIdx < 0) newIdx = 0;
    if (newIdx >= service.promptHistory.length) newIdx = service.promptHistory.length - 1;
    service.promptHistoryIndex = newIdx;
    service.promptText = service.promptHistory[service.promptHistoryIndex];
  }

  function startGeneration(overridePrompt, overrideNegative) {
    if (!service) return;
    if (!service.isBridgeAvailable) {
      service.generationTelemetry = "ERROR: bin/qwen-bridge is missing! Run install.sh";
      return;
    }
    if (service.isGenerating || service.isGameLocked) return;

    if (typeof overridePrompt === "string" && overridePrompt.trim() !== "") {
      service.promptText = overridePrompt;
    }
    if (typeof overrideNegative === "string") {
      service.negativePromptText = overrideNegative;
    }

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

    genProc.command = PromptUtils.buildGenerationArgs(service, trimmed);
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
    service.currentScaleFactor = 4.0;

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
    service.cfg = service.isTurboEnabled ? 1.0 : 2.5;
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
    PromptUtils.applyGenerationEvent(service, line);
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

  BoundedProcess {
    id: scaleProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      service.isGenerating = false;
      service.currentScaleFactor = 0.0;
      if (wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
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

  BoundedProcess {
    id: tagProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      service.isInterrogating = false;
      if (wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
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

  BoundedProcess {
    id: visionProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      service.isVisionLoading = false;
      if (wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok" && res.prompt) {
          service.promptText = res.prompt;
        }
      } catch (e) {}
    }
  }

  BoundedProcess {
    id: metaProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
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

  BoundedProcess {
    id: optProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      service.isOptimizingPrompt = false;
      if (!wasOverflowed) {
        PromptUtils.applyOptResult(service, stdoutText);
      }
    }
  }
}
