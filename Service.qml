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

  signal openRequested(string view)
  signal closeRequested()
  signal toggleRequested()

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

    readonly property string effectiveVersion: localVersion !== "" ? localVersion : (bridgeVersion !== "" ? bridgeVersion : "1.2.7")
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
  property string generationTelemetry: "1024x1024 | 25 STEPS | LOCAL GPU (0 TOKENS)"

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
  property string currentLang: "en"
  property bool isNsfwEnabled: false
  property string animeMode: "off"      // "off" | "soft" | "full"
  property bool isTurboEnabled: true
  property string hereticMode: "off"    // "off" | "soft" | "full"
  property string anatomyMode: "off"    // "off" | "soft" | "full"
  property bool isAutoExpandEnabled: false

  // Backward compatibility properties for bindings and external widgets
  readonly property bool isAnimeLoRAEnabled: animeMode !== "off"
  readonly property bool isUncensoredEnabled: hereticMode !== "off"
  readonly property bool isAnatomyLoRAEnabled: anatomyMode !== "off"

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
    var words = p.split(/[\s,.;:!?_"'`\(\)\[\]\{\}\/\\~-]+/).filter(Boolean);
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

  function saveSetting(key, val) {
    if (saveSettingsProc.running) {
      saveSettingsProc.running = false;
    }
    saveSettingsProc.command = [root.bridgeBin, "settings", "set", String(key), String(val)];
    Qt.callLater(function() {
      if (!saveSettingsProc.running) {
        saveSettingsProc.running = true;
      }
    });
  }

  function toggleLanguage() {
    currentLang = "en";
    saveSetting("language", "en");
  }

  function toggleNsfw() {
    isNsfwEnabled = !isNsfwEnabled;
    saveSetting("nsfw", root.isNsfwEnabled ? "true" : "false");
    root.fetchPrompts(root.activePromptSource, "");
  }

  function cycleAnimeMode() {
    if (animeMode === "off") animeMode = "soft";
    else if (animeMode === "soft") animeMode = "full";
    else animeMode = "off";
    saveSetting("anime_mode", animeMode);
  }

  function toggleAnimeLoRA() {
    cycleAnimeMode();
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
    saveSetting("turbo", root.isTurboEnabled ? "true" : "false");
  }

  function cycleHereticMode() {
    if (hereticMode === "off") hereticMode = "soft";
    else if (hereticMode === "soft") hereticMode = "full";
    else hereticMode = "off";
    saveSetting("heretic_mode", hereticMode);
  }

  function toggleUncensored() {
    cycleHereticMode();
  }

  function cycleAnatomyMode() {
    if (anatomyMode === "off") anatomyMode = "soft";
    else if (anatomyMode === "soft") anatomyMode = "full";
    else anatomyMode = "off";
    saveSetting("anatomy_mode", anatomyMode);
  }

  function toggleAnatomyLoRA() {
    cycleAnatomyMode();
  }

  function toggleAutoExpand() {
    isAutoExpandEnabled = !isAutoExpandEnabled;
    saveSetting("auto_expand", root.isAutoExpandEnabled ? "true" : "false");
  }

  function setResolutionMode(mode) {
    if (!mode) return;
    root.resMode = mode;
    saveSetting("res_mode", root.resMode);
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
    root.generationTelemetry = "GENERATION INTERRUPTED";
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
    root.generationTelemetry = "1024x1024 | 25 STEPS | LOCAL GPU (0 TOKENS)";
  }

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
    if (promptHistory.length === 0) return;
    var newIdx = promptHistoryIndex + delta;
    if (newIdx < 0) newIdx = 0;
    if (newIdx >= promptHistory.length) newIdx = promptHistory.length - 1;
    promptHistoryIndex = newIdx;
    root.promptText = promptHistory[promptHistoryIndex];
  }

  function startGeneration() {
    if (!root.isBridgeAvailable) {
      root.generationTelemetry = "ERROR: bin/qwen-bridge is missing! Run install.sh";
      return;
    }
    if (isGenerating || isGameLocked) return;
    root.promptText = root.sanitizePromptText(root.promptText);
    root.negativePromptText = root.sanitizePromptText(root.negativePromptText);
    var trimmed = root.promptText;
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

    if (root.animeMode === "soft" || root.animeMode === "full") {
      args.push("--anime");
      args.push(root.animeMode);
    }

    if (root.isTurboEnabled) {
      args.push("--turbo");
    }

    if (root.hereticMode === "soft" || root.hereticMode === "full") {
      args.push("--heretic");
      args.push(root.hereticMode);
    }

    if (root.anatomyMode === "soft" || root.anatomyMode === "full") {
      args.push("--anatomy");
      args.push(root.anatomyMode);
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
      "--file-filter=Images (*.png *.jpg *.jpeg *.webp *.avif) | *.png *.jpg *.jpeg *.webp *.avif *.PNG *.JPG *.JPEG *.WEBP *.AVIF",
      "--title=Select reference image"
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
        root.generationTelemetry = "ERROR: " + (res.message || "Generation failed");
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
          root.generationTelemetry = "ERROR: Process exited (" + exitCode + ")";
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
            var cleanText = root.sanitizePromptText(res.text);
            if (typeof root.activePasteTarget.insert === "function") {
              var pos = root.activePasteTarget.cursorPosition !== undefined ? root.activePasteTarget.cursorPosition : root.activePasteTarget.length;
              root.activePasteTarget.insert(pos, cleanText);
            } else if (root.activePasteTarget.text !== undefined) {
              root.activePasteTarget.text = (root.activePasteTarget.text || "") + cleanText;
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
          root.currentLang = "en";
          if (typeof res.nsfw === "boolean") {
            root.isNsfwEnabled = res.nsfw;
          }
          if (res.anime_mode) {
            root.animeMode = res.anime_mode;
          } else if (typeof res.anime === "boolean") {
            root.animeMode = res.anime ? "full" : "off";
          }
          if (typeof res.turbo === "boolean") {
            root.isTurboEnabled = res.turbo;
          }
          if (res.heretic_mode) {
            root.hereticMode = res.heretic_mode;
          } else if (res.uncensored_mode) {
            root.hereticMode = res.uncensored_mode;
          } else if (typeof res.uncensored === "boolean") {
            root.hereticMode = res.uncensored ? "full" : "off";
          }
          if (res.anatomy_mode) {
            root.anatomyMode = res.anatomy_mode;
          } else if (typeof res.anatomy === "boolean") {
            root.anatomyMode = res.anatomy ? "full" : "off";
          } else if (typeof res.anatomy_lora === "boolean") {
            root.anatomyMode = res.anatomy_lora ? "full" : "off";
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

  IpcHandler {
    target: "simonez.qwenimage"

    function refresh(): void {
      root.refresh();
    }
    function open(): void {
      root.currentView = "studio";
      root.openRequested("studio");
    }
    function close(): void {
      root.closeRequested();
    }
    function toggle(): void {
      root.toggleRequested();
    }
    function prompts(source: string): void {
      var s = String(source || "").trim().toLowerCase();
      if (s.length > 32) s = s.substring(0, 32);
      var validSources = ["civitai", "lexica", "prompthero", "openart", "huggingface", "midlibrary", "diffusiondb", "seaart", "shakker", "playground", "krea", "tensorart", "all"];
      if (validSources.indexOf(s) === -1) s = "civitai";
      root.activePromptSource = s;
      root.fetchPrompts(s, "");
      root.currentView = "civitai";
      root.openRequested("civitai");
    }
    function history(): void {
      root.currentView = "history";
      root.fetchHistory();
      root.openRequested("history");
    }
    function paste(): void {
      root.pasteFromClipboard();
      root.openRequested("studio");
    }
  }
}
