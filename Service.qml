import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})
  property var bar: null
  property bool activePolling: true
  property int watchers: 0

  readonly property string bridgeBin: Qt.resolvedUrl("bin/qwen-bridge").toString().replace(/^file:\/\//, "")
  readonly property string userHome: Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "user")
  readonly property string picturesDir: userHome + "/Pictures/Qwen-Image"

  QtObject {
    id: d
    property string localVersion: ""
    property string bridgeVersion: ""

    function cleanVer(v) {
      return v ? String(v).replace(/^v/i, "").trim() : "";
    }

    readonly property string effectiveVersion: localVersion !== "" ? localVersion : (bridgeVersion !== "" ? bridgeVersion : "1.2.3")
  }

  readonly property string pluginVersion: "v" + d.effectiveVersion
  readonly property int viewCalibrationSeed: (0x732641 % 50)

  // View & Navigation State
  property string currentView: "studio"
  onCurrentViewChanged: {
    if (currentView === "civitai") {
      root.fetchPrompts(root.activePromptSource || "civitai", "");
    } else if (currentView === "history") {
      root.fetchHistory();
    }
  }

  // Persistent Studio Session State
  property string promptText: ""
  property string negativePromptText: "blurry, low quality, deformed, extra fingers, text, watermark"
  property string aspectRatio: "1:1"
  property string resMode: "standard"
  property string hardwareTier: "B"
  property int maxSupportedDim: 1536
  property var supportedResModes: ["draft", "standard", "high"]
  property int steps: 25
  property real cfg: 4.0
  property bool seedLocked: false
  property var seedVal: -1
  property string referencePath: ""
  property string referenceMatchedRatio: ""
  property int referenceRevision: 0
  property real denoise: 0.65
  property string generatedPath: ""
  property string baseGeneratedPath: ""
  property string previousGeneratedPath: ""
  property bool isGenerating: false
  property bool isCancelling: false
  property string generatingMode: "generate"
  property real currentScaleFactor: 0.0
  property bool isInterrogating: false
  property string generationTelemetry: "1024x1024 | 25 STEPS | RTX 3070 (0 TOKENS)"

  // Live TAEQI / Diffusion Preview State
  property string livePreviewPath: ""
  property int livePreviewStep: 0
  property int livePreviewMaxSteps: 25
  property int livePreviewTick: 0

  // System & GPU Telemetry State
  property string studioStatus: "READY"
  property int vramUsed: 0
  property int vramTotal: 8192
  property int vramPct: 0
  property bool isOnline: false
  property bool isGameLocked: false
  property bool isBusy: isGenerating

  // Service Health Badges
  property bool svcComfy: false
  property bool svcGpu: true
  property bool svcOllama: false
  property bool svcWd14: false
  property bool svcCivitai: true

  // Dynamic Stack & Model Versions
  property string versionQwen: "Qwen-Image 2.1 Heretic"
  property string versionComfy: ""
  property string versionOllama: ""
  property string versionGpuDriver: ""
  property string versionQuickshell: ""
  property string versionHyprland: ""

  // Discovery & History Models
  property var civitaiModel: []
  property bool isCivitaiLoading: false
  property string activePromptSource: "civitai"
  property bool isVisionLoading: false
  property var historyModel: []
  property bool isHistoryLoading: false
  property bool isBridgeAvailable: true
  property var promptHistory: []
  property int promptHistoryIndex: -1
  property bool isOptimizingPrompt: false

  // User Preferences
  property string currentLang: "cs"
  property bool isNsfwEnabled: false
  property bool isAnimeLoRAEnabled: false
  property bool isTurboEnabled: true
  property bool isUncensoredEnabled: false
  property bool isAutoExpandEnabled: false

  readonly property bool isHumanSubjectInPrompt: {
    var p = promptText.toLowerCase();
    var kw = [
      "woman", "women", "man", "men", "girl", "girls", "boy", "boys",
      "person", "people", "human", "body", "nude", "naked", "erotic",
      "portrait", "skin", "breasts", "legs", "face", "buttocks", "ass",
      "waist", "hips", "thighs", "female", "male", "model", "hand", "hands",
      "finger", "fingers", "child", "children", "character", "warrior", "elf",
      "slim", "petite", "slender",
      "dívka", "dívky", "žena", "ženy", "muž", "muži", "tělo", "nahá", "nahý",
      "nahé", "akt", "ruce", "ruka", "prsty", "prst", "obličej", "tvář", "postava"
    ];
    var words = p.match(/[\p{L}\p{N}_]+/gu) || [];
    for (var i = 0; i < words.length; ++i) {
      if (kw.indexOf(words[i]) !== -1) return true;
    }
    return false;
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined;
    return value === undefined || value === null ? fallback : value;
  }

  function watch() {
    watchers += 1;
    refreshTelemetry();
  }

  function unwatch() {
    watchers = Math.max(0, watchers - 1);
  }

  function toggleLanguage() {
    currentLang = (currentLang === "cs" ? "en" : "cs");
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "language", root.currentLang];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function toggleNsfw() {
    isNsfwEnabled = !isNsfwEnabled;
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "nsfw", root.isNsfwEnabled ? "true" : "false"];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
    root.fetchPrompts(root.activePromptSource, "");
  }

  function toggleAnimeLoRA() {
    isAnimeLoRAEnabled = !isAnimeLoRAEnabled;
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "anime_lora", root.isAnimeLoRAEnabled ? "true" : "false"];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function toggleTurbo() {
    isTurboEnabled = !isTurboEnabled;
    if (!isTurboEnabled && steps < 25) {
      steps = 28;
      cfg = 4.0;
    } else if (isTurboEnabled && steps > 8) {
      steps = 6;
      cfg = 1.0;
    }
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "turbo", root.isTurboEnabled ? "true" : "false"];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function toggleUncensored() {
    isUncensoredEnabled = !isUncensoredEnabled;
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "uncensored", root.isUncensoredEnabled ? "true" : "false"];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function toggleAutoExpand() {
    isAutoExpandEnabled = !isAutoExpandEnabled;
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "auto_expand", root.isAutoExpandEnabled ? "true" : "false"];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function setResolutionMode(mode) {
    if (!mode) return;
    root.resMode = mode;
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", "res_mode", root.resMode];
    saveSettingsProc.running = false;
    saveSettingsProc.running = true;
  }

  function updateTelemetry(data) {
    if (!data) return;
    root.studioStatus = data.status || "READY";
    root.isOnline = !!data.online;
    root.isGameLocked = !!data.game_locked;
    root.vramUsed = data.vram_used_mb || 0;
    root.vramTotal = data.vram_total_mb || 8192;
    root.vramPct = data.vram_pct || 0;
    root.hardwareTier = data.hardware_tier || root.hardwareTier;
    root.maxSupportedDim = data.max_res_dim || root.maxSupportedDim;
    if (data.supported_res_modes && Array.isArray(data.supported_res_modes)) {
      root.supportedResModes = data.supported_res_modes;
    }
    if (data.services) {
      root.svcComfy = !!data.services.comfyui;
      root.svcGpu = !!data.services.gpu;
      root.svcOllama = !!data.services.ollama;
      root.svcWd14 = !!data.services.wd14;
      root.svcCivitai = !!data.services.civitai;
    }
    if (data.versions) {
      if (data.versions.plugin) {
        d.bridgeVersion = d.cleanVer(data.versions.plugin);
      }
      root.versionQwen = data.versions.qwen_model || root.versionQwen;
      root.versionComfy = data.versions.comfyui || "";
      root.versionOllama = data.versions.ollama || "";
      root.versionGpuDriver = data.versions.driver ? (data.gpu_name + " (" + data.versions.driver + ")") : (data.gpu_name || "");
      root.versionQuickshell = data.versions.quickshell || "";
      root.versionHyprland = data.versions.hyprland || "";
    }
  }

  function checkBridge() {
    if (!checkBridgeProc.running) {
      checkBridgeProc.running = true;
    }
  }

  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true;
    }
  }

  function refreshTelemetry() {
    root.checkBridge();
    root.refresh();
  }

  function paste() {
    root.pasteFromClipboard();
  }

  function snip() {
    root.triggerScreenSnip();
  }

  function snipScreenArea() {
    root.triggerScreenSnip();
  }

  function clear() {
    root.clearReference();
  }

  function clearReferenceBuffer() {
    root.clearReference();
  }

  property var activePasteTarget: null
  function pasteTextInto(targetItem) {
    if (pasteTextProc.running) return;
    root.activePasteTarget = targetItem;
    pasteTextProc.running = true;
  }

  function validateReference(filePath) {
    if (!filePath || validateRefProc.running) return;
    validateRefProc.command = [root.bridgeBin, "validate-ref", filePath];
    validateRefProc.running = true;
  }

  function cancelGeneration() {
    if ((!root.isGenerating && !genProc.running) || root.isCancelling) return;
    root.isCancelling = true;

    if (genProc.running) {
      genProc.running = false;
    }
    interruptProc.running = false;
    interruptProc.running = true;
    root.isGenerating = false;
    root.currentScaleFactor = 0.0;
    root.livePreviewPath = "";
    root.generationTelemetry = root.currentLang === "cs"
      ? "GENEROVÁNÍ PŘERUŠENO"
      : "GENERATION INTERRUPTED";
  }

  function resetForm() {
    if (root.isGenerating || genProc.running) {
      root.cancelGeneration();
    }
    root.promptText = "";
    root.negativePromptText = "blurry, low quality, deformed, extra fingers, text, watermark";
    root.aspectRatio = "1:1";
    root.resMode = "standard";
    root.steps = 25;
    root.seedLocked = false;
    root.seedVal = -1;
    root.referencePath = "";
    root.referenceMatchedRatio = "";
    root.referenceRevision = 0;
    root.denoise = 0.65;
    root.generatedPath = "";
    root.baseGeneratedPath = "";
    root.previousGeneratedPath = "";
    root.livePreviewPath = "";
    root.livePreviewStep = 0;
    root.generationTelemetry = "1024x1024 | 25 STEPS | RTX 3070 (0 TOKENS)";
  }

  function recallPrompt(delta) {
    if (promptHistory.length === 0) return;
    var newIdx = promptHistoryIndex + delta;
    if (newIdx < 0) newIdx = 0;
    if (newIdx >= promptHistory.length) newIdx = promptHistory.length - 1;
    promptHistoryIndex = newIdx;
    root.promptText = promptHistory[promptHistoryIndex];
  }

  function startGeneration() {
    if (!root.isBridgeAvailable) {
      root.generationTelemetry = root.currentLang === "cs"
        ? "CHYBA: bin/qwen-bridge chybí! Spusť install.sh"
        : "ERROR: bin/qwen-bridge is missing! Run install.sh";
      return;
    }
    if (isGenerating || isGameLocked) return;
    var trimmed = promptText.trim();
    if (trimmed === "") return;

    if (promptHistory.indexOf(trimmed) === -1) {
      promptHistory.push(trimmed);
      promptHistoryIndex = promptHistory.length - 1;
    }

    isGenerating = true;
    generatingMode = "generate";
    currentScaleFactor = 0.0;
    livePreviewPath = "";
    livePreviewStep = 0;
    livePreviewMaxSteps = steps;
    livePreviewTick = 0;

    var actualSeed = seedLocked ? Number(seedVal) : -1;
    var args = [
      root.bridgeBin,
      "generate",
      trimmed,
      aspectRatio,
      String(steps),
      String(cfg),
      String(actualSeed),
      negativePromptText
    ];

    if (referencePath !== "") {
      args.push(referencePath);
      var clampedDenoise = Math.min(0.95, Math.max(0.05, denoise));
      args.push(String(clampedDenoise));
    }

    if (root.isAnimeLoRAEnabled) {
      args.push("--anime");
    }

    if (root.isTurboEnabled) {
      args.push("--turbo");
    }

    if (root.isUncensoredEnabled) {
      args.push("--uncensored");
    }

    if (root.isAutoExpandEnabled) {
      args.push("--expand");
    }

    if (root.resMode && root.resMode !== "") {
      args.push("--res");
      args.push(root.resMode);
    }

    genProc.command = args;
    genProc.running = true;
  }

  function aiUpscale(modelChoice) {
    if (!root.isBridgeAvailable) return;
    var target = root.baseGeneratedPath !== "" ? root.baseGeneratedPath : (root.generatedPath !== "" ? root.generatedPath : root.referencePath);
    if (target === "" || isGenerating) return;

    isGenerating = true;
    generatingMode = "scale_" + modelChoice;
    currentScaleFactor = 4.0;

    var args = [
      root.bridgeBin,
      "upscale",
      target,
      modelChoice
    ];

    if (root.isAnimeLoRAEnabled) {
      args.push("--anime");
    }

    scaleProc.command = args;
    scaleProc.running = true;
  }

  function aiEnhance() {
    aiUpscale("ultra");
  }

  function scaleImage(factor) {
    if (!root.isBridgeAvailable) return;
    var target = root.baseGeneratedPath !== "" ? root.baseGeneratedPath : (root.generatedPath !== "" ? root.generatedPath : root.referencePath);
    if (target === "" || isGenerating) return;
    isGenerating = true;
    generatingMode = "scale";
    currentScaleFactor = factor;
    scaleProc.command = [
      root.bridgeBin,
      "scale",
      target,
      String(factor)
    ];
    scaleProc.running = true;
  }

  function setAsWallpaper(path) {
    if (!path) return;
    wallProc.command = [root.bridgeBin, "wallpaper", path];
    wallProc.running = true;
  }

  function copyImageToClipboard(path) {
    if (!path) return;
    clipCopyProc.command = [root.bridgeBin, "copy-image", path];
    clipCopyProc.running = true;
  }

  function copyTextToClipboard(text) {
    clipCopyProc.command = [root.bridgeBin, "copy-text", text];
    clipCopyProc.running = true;
  }

  function openImageViewer(path) {
    if (!path) return;
    root.openFullscreenViewer(path);
  }

  function openFullscreenViewer(path) {
    if (!path) return;
    var cleanPath = path;
    if (cleanPath.startsWith("file://")) {
      cleanPath = cleanPath.substring(7);
    }
    openFullscreenProc.running = false;
    openFullscreenProc.command = ["imv", "-i", "imv-fullscreen", "-f", "-c", "bind <Escape> quit", "--", cleanPath];
    openFullscreenProc.running = true;
  }

  function openPicturesFolder() {
    openExternalProc.command = ["xdg-open", root.picturesDir];
    openExternalProc.running = true;
  }

  function pasteFromClipboard() {
    pasteProc.running = true;
  }

  function triggerScreenSnip() {
    snipProc.running = true;
  }

  function interrogateWd14() {
    if (!root.isBridgeAvailable || referencePath === "" || isInterrogating) return;
    root.isInterrogating = true;
    tagProc.command = [root.bridgeBin, "interrogate", referencePath];
    tagProc.running = true;
  }

  function extractVisionPrompt() {
    if (!root.isBridgeAvailable || referencePath === "" || isVisionLoading) return;
    root.isVisionLoading = true;
    visionProc.command = [root.bridgeBin, "vision", referencePath];
    visionProc.running = true;
  }

  function setReferenceImage(path) {
    if (!path) return;
    referencePath = path;
    referenceRevision++;
    metaProc.command = [root.bridgeBin, "read-meta", path];
    metaProc.running = true;
  }

  function clearReference() {
    if (root.referencePath === "" && root.referenceMatchedRatio === "") return;
    root.referencePath = "";
    root.referenceMatchedRatio = "";
    root.referenceRevision++;
  }

  function restoreFromHistory(path, prompt, seed, ratio, negative) {
    if (prompt) promptText = prompt;
    if (negative !== undefined && negative !== null && negative !== "") {
      negativePromptText = negative;
    }
    if (seed && seed > 0) {
      seedVal = seed;
      seedLocked = true;
    }
    if (ratio) aspectRatio = ratio;
    generatedPath = path;
    baseGeneratedPath = path;
  }

  function pickReferenceImage() {
    pickRefImageProc.running = false;
    var picDir = Quickshell.env("XDG_PICTURES_DIR") || ((Quickshell.env("HOME") || "") + "/Pictures");
    if (picDir !== "" && !picDir.endsWith("/")) {
      picDir += "/";
    }
    pickRefImageProc.command = [
      "zenity",
      "--file-selection",
      "--filename=" + picDir,
      "--file-filter=" + (root.currentLang === "cs" ? "Obrázky" : "Images") + " (*.png *.jpg *.jpeg *.webp *.avif) | *.png *.jpg *.jpeg *.webp *.avif *.PNG *.JPG *.JPEG *.WEBP *.AVIF",
      "--title=" + (root.currentLang === "cs" ? "Vybrat referenční obrázek" : "Select reference image")
    ];
    pickRefImageProc.running = true;
  }

  function fetchPrompts(source, query) {
    if (!root.isBridgeAvailable) {
      root.isCivitaiLoading = false;
      return;
    }
    root.isCivitaiLoading = true;
    root.activePromptSource = source || "civitai";
    var cmd = [
      root.bridgeBin,
      "prompts",
      root.activePromptSource,
      query || "",
      "--limit",
      "100"
    ];
    if (root.isNsfwEnabled) {
      cmd.push("--nsfw");
    }
    civitaiProc.running = false;
    civitaiProc.command = cmd;
    civitaiProc.running = true;
  }

  function fetchCivitaiPrompts(query) {
    root.fetchPrompts(root.activePromptSource || "civitai", query);
  }

  function fetchHistory() {
    if (!root.isBridgeAvailable) {
      root.isHistoryLoading = false;
      return;
    }
    if (histProc.running) {
      return;
    }
    root.isHistoryLoading = true;
    histProc.command = [root.bridgeBin, "history", "30"];
    histProc.running = true;
  }

  function optimizePrompt(rawText) {
    if (!rawText || rawText.trim() === "" || root.isOptimizingPrompt) return;
    root.isOptimizingPrompt = true;
    optProc.command = [root.bridgeBin, "optimize-prompt", rawText.trim()];
    optProc.running = true;
  }

  function handleGenLine(line) {
    var trimmed = (line || "").trim();
    if (!trimmed || trimmed === "" || trimmed.length > 65536) return;
    try {
      var res = JSON.parse(trimmed);
      if (res.event === "preview") {
        root.livePreviewPath = res.path || "";
        root.livePreviewStep = res.step || 0;
        root.livePreviewMaxSteps = res.max_steps || root.steps;
        root.livePreviewTick += 1;
      } else if (res.status === "ok" && res.path) {
        root.isGenerating = false;
        root.currentScaleFactor = 0.0;
        root.livePreviewPath = "";
        root.previousGeneratedPath = root.generatedPath;
        root.generatedPath = res.path;
        root.baseGeneratedPath = res.path;
        var elapsedSec = (typeof res.elapsed === "number") ? res.elapsed.toFixed(1) : String(res.elapsed || "0");
        root.generationTelemetry = (res.ratio || "1:1") + " | " + (res.steps || root.steps) + " STEPS | " + elapsedSec + "s | SEED: " + (res.seed >= 0 ? res.seed : "RANDOM");
        root.fetchHistory();
      } else if (res.status === "error") {
        root.isGenerating = false;
        root.currentScaleFactor = 0.0;
        root.livePreviewPath = "";
        root.generationTelemetry = (root.currentLang === "cs" ? "CHYBA: " : "ERROR: ") + (res.message || (root.currentLang === "cs" ? "Generování selhalo" : "Generation failed"));
      }
    } catch (e) {}
  }

  // Status Polling & Watchdog
  Process {
    id: statusProc
    command: [root.bridgeBin, "status"]
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
    interval: root.watchers > 0 ? 2000 : Math.max(1000, root.setting("refreshIntervalSec", 3) * 1000)
    repeat: true
    running: root.activePolling
    onTriggered: {
      if (!statusProc.running) {
        statusProc.running = true;
      }
    }
  }

  Process {
    id: checkBridgeProc
    command: ["test", "-x", root.bridgeBin]
    onExited: function(exitCode) {
      root.isBridgeAvailable = (exitCode === 0);
    }
  }

  Process {
    id: interruptProc
    command: [root.bridgeBin, "interrupt"]
    onExited: function() {
      root.isCancelling = false;
    }
  }

  Process {
    id: genProc
    stdout: SplitParser {
      onRead: function(line) {
        root.handleGenLine(line);
      }
    }
    onExited: function(exitCode) {
      root.isCancelling = false;
      if (root.isGenerating) {
        root.isGenerating = false;
        root.currentScaleFactor = 0.0;
        root.livePreviewPath = "";
        if (exitCode !== 0) {
          root.generationTelemetry = root.currentLang === "cs"
            ? "CHYBA: Proces byl ukončen (" + exitCode + ")"
            : "ERROR: Process exited (" + exitCode + ")";
        }
      }
    }
  }

  Process {
    id: scaleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isGenerating = false;
        root.currentScaleFactor = 0.0;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            root.previousGeneratedPath = root.generatedPath;
            root.generatedPath = res.path;
            var info = (res.factor ? (res.factor + " ") : (res.tier ? ("AI " + res.tier + " ") : "")) + (res.width || "2048") + "x" + (res.height || "2048");
            if (res.model) {
              info += " // " + res.model.replace(".safetensors", "");
            } else {
              info += " // SIMD LANCZOS";
            }
            root.generationTelemetry = info;
            root.fetchHistory();
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: wallProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok") {
            root.generationTelemetry = "WALLPAPER SET";
          }
        } catch (e) {}
      }
    }
  }

  Process { id: clipCopyProc }
  Process { id: openExternalProc }

  Process {
    id: openFullscreenProc
    onExited: function(exitCode) {
      if (exitCode !== 0 && openFullscreenProc.command.length >= 1) {
        var target = openFullscreenProc.command[openFullscreenProc.command.length - 1];
        if (target && target !== "" && target !== "--") {
          openExternalProc.running = false;
          openExternalProc.command = ["xdg-open", "--", target];
          openExternalProc.running = true;
        }
      }
    }
  }

  Process {
    id: pickRefImageProc
    property string collectedPath: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var s = (text || "").trim();
        if (s.length > 4096) s = s.substring(0, 4096);
        pickRefImageProc.collectedPath = s;
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && pickRefImageProc.collectedPath !== "") {
        root.setReferenceImage(pickRefImageProc.collectedPath);
      }
      pickRefImageProc.collectedPath = "";
    }
  }

  Process {
    id: pasteProc
    command: [root.bridgeBin, "paste-clipboard"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            root.setReferenceImage(res.path);
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: pasteTextProc
    command: [root.bridgeBin, "paste-text"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.text && root.activePasteTarget) {
            if (typeof root.activePasteTarget.insert === "function") {
              var pos = root.activePasteTarget.cursorPosition !== undefined ? root.activePasteTarget.cursorPosition : root.activePasteTarget.length;
              root.activePasteTarget.insert(pos, res.text);
            } else if (root.activePasteTarget.text !== undefined) {
              root.activePasteTarget.text = (root.activePasteTarget.text || "") + res.text;
            }
          }
        } catch (e) {}
        root.activePasteTarget = null;
      }
    }
  }

  Process {
    id: validateRefProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            root.setReferenceImage(res.path);
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: snipProc
    command: [root.bridgeBin, "snip"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            root.setReferenceImage(res.path);
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
        root.isInterrogating = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.raw) {
            if (root.promptText.trim() === "") {
              root.promptText = res.raw;
            } else {
              root.promptText = root.promptText + ", " + res.raw;
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
        root.isVisionLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.prompt) {
            root.promptText = res.prompt;
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
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok") {
            if (res.prompt) root.promptText = res.prompt;
            if (res.negative_prompt) root.negativePromptText = res.negative_prompt;
            if (res.seed && res.seed > 0) {
              root.seedVal = res.seed;
              root.seedLocked = true;
            }
            if (res.ratio) {
              root.aspectRatio = res.ratio;
              root.referenceMatchedRatio = res.ratio;
            }
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: civitaiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isCivitaiLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 524288) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.items) {
            root.civitaiModel = res.items;
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
        root.isHistoryLoading = false;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 524288) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.items) {
            root.historyModel = res.items;
          }
        } catch (e) {}
      }
    }
  }

  Process { id: saveSettingsProc }

  Process {
    id: loadLangProc
    command: [root.bridgeBin, "settings"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.lang === "cs" || res.lang === "en") {
            root.currentLang = res.lang;
          }
          if (typeof res.nsfw === "boolean") {
            root.isNsfwEnabled = res.nsfw;
          }
          if (typeof res.anime === "boolean") {
            root.isAnimeLoRAEnabled = res.anime;
          }
          if (typeof res.turbo === "boolean") {
            root.isTurboEnabled = res.turbo;
          }
          if (typeof res.uncensored === "boolean") {
            root.isUncensoredEnabled = res.uncensored;
          }
          if (typeof res.auto_expand === "boolean") {
            root.isAutoExpandEnabled = res.auto_expand;
          }
          if (res.res_mode) {
            root.resMode = res.res_mode;
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
        root.isOptimizingPrompt = false;
        var raw = (text || "").trim();
        if (raw === "" || raw.length > 65536) return;
        try {
          var res = JSON.parse(raw);
          if (res.rewritten_prompt && res.rewritten_prompt.trim() !== "") {
            root.promptText = res.rewritten_prompt.trim();
          } else if (res.optimized_prompt && res.optimized_prompt.trim() !== "") {
            root.promptText = res.optimized_prompt.trim();
          }
          if (res.negative_prompt && res.negative_prompt.trim() !== "") {
            root.negativePromptText = res.negative_prompt.trim();
          }
          if (res.wh_ratio && res.wh_ratio.trim() !== "") {
            var ratio = res.wh_ratio.trim();
            var validRatios = ["16:10", "16:9", "1:1", "9:16", "21:9", "4:3", "3:4", "3:2", "2:3"];
            if (validRatios.indexOf(ratio) !== -1) {
              root.aspectRatio = ratio;
            }
          }
        } catch (e) {
          root.promptText = raw;
        }
      }
    }
  }

  function loadLocalManifestAsync() {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", Qt.resolvedUrl("manifest.json"), true);
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200 || xhr.status === 0) {
          try {
            var parsed = JSON.parse(xhr.responseText);
            if (parsed && parsed.version) {
              d.localVersion = d.cleanVer(parsed.version);
            }
          } catch (e) {}
        }
      }
    };
    xhr.send();
  }

  Component.onCompleted: {
    loadLocalManifestAsync();
    if (root.activePolling) {
      loadLangProc.running = true;
      checkBridge();
      refreshTelemetry();
      fetchHistory();
    }
  }

  onActivePollingChanged: {
    if (root.activePolling) {
      loadLangProc.running = true;
      checkBridge();
      refreshTelemetry();
      fetchHistory();
    }
  }
}
