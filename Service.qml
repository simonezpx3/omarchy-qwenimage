import QtQuick
import Quickshell
import Quickshell.Io
import "internal" as Internal

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

    readonly property string effectiveVersion: localVersion !== "" ? localVersion : (bridgeVersion !== "" ? bridgeVersion : "1.2.8")
  }

  function setBridgeVersion(v) {
    d.bridgeVersion = d.cleanVer(v);
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

  // --- Modular Bridges ---
  Internal.SettingsSync { id: settingsSync; service: root }
  Internal.TelemetryBridge { id: telemetryBridge; service: root }
  Internal.GenerationBridge { id: generationBridge; service: root }
  Internal.MediaActions { id: mediaActions; service: root }
  Internal.DiscoveryBridge { id: discoveryBridge; service: root }

  // Telemetry Facade
  function watch() { telemetryBridge.watch(); }
  function unwatch() { telemetryBridge.unwatch(); }
  function checkBridge() { telemetryBridge.checkBridge(); }
  function refresh() { telemetryBridge.refresh(); }
  function refreshTelemetry() { telemetryBridge.refreshTelemetry(); }
  function updateTelemetry(data) { telemetryBridge.updateTelemetry(data); }

  // Settings Facade
  function saveSetting(key, val) { settingsSync.saveSetting(key, val); }
  function toggleLanguage() { settingsSync.toggleLanguage(); }
  function toggleNsfw() { settingsSync.toggleNsfw(); }
  function cycleAnimeMode() { settingsSync.cycleAnimeMode(); }
  function toggleAnimeLoRA() { settingsSync.cycleAnimeMode(); }
  function toggleTurbo() { settingsSync.toggleTurbo(); }
  function cycleHereticMode() { settingsSync.cycleHereticMode(); }
  function toggleUncensored() { settingsSync.cycleHereticMode(); }
  function cycleAnatomyMode() { settingsSync.cycleAnatomyMode(); }
  function toggleAnatomyLoRA() { settingsSync.cycleAnatomyMode(); }
  function toggleAutoExpand() { settingsSync.toggleAutoExpand(); }
  function setResolutionMode(mode) { settingsSync.setResolutionMode(mode); }

  // Media & System Facade
  function setAsWallpaper(path) { mediaActions.setAsWallpaper(path); }
  function copyImageToClipboard(path) { mediaActions.copyImageToClipboard(path); }
  function copyTextToClipboard(text) { mediaActions.copyTextToClipboard(text); }
  function openImageViewer(path) { mediaActions.openImageViewer(path); }
  function openFullscreenViewer(path) { mediaActions.openFullscreenViewer(path); }
  function openPicturesFolder() { mediaActions.openPicturesFolder(); }
  function paste() { mediaActions.pasteFromClipboard(); }
  function pasteFromClipboard() { mediaActions.pasteFromClipboard(); }
  function snip() { mediaActions.triggerScreenSnip(); }
  function snipScreenArea() { mediaActions.triggerScreenSnip(); }
  function triggerScreenSnip() { mediaActions.triggerScreenSnip(); }
  function pasteTextInto(targetItem) { mediaActions.pasteTextInto(targetItem); }
  function validateReference(filePath) { mediaActions.validateReference(filePath); }
  function pickReferenceImage() { mediaActions.pickReferenceImage(); }

  // Generation & AI Facade
  function cancelGeneration() { generationBridge.cancelGeneration(); }
  function resetForm() { generationBridge.resetForm(); }
  function sanitizePromptText(text) { return generationBridge.sanitizePromptText(text); }
  function recallPrompt(delta) { generationBridge.recallPrompt(delta); }
  function startGeneration(overridePrompt, overrideNegative) { generationBridge.startGeneration(overridePrompt, overrideNegative); }
  function aiUpscale(modelChoice) { generationBridge.aiUpscale(modelChoice); }
  function aiEnhance() { generationBridge.aiEnhance(); }
  function scaleImage(factor) { generationBridge.scaleImage(factor); }
  function interrogateWd14() { generationBridge.interrogateWd14(); }
  function extractVisionPrompt() { generationBridge.extractVisionPrompt(); }
  function setReferenceImage(path) { generationBridge.setReferenceImage(path); }
  function clear() { generationBridge.clearReference(); }
  function clearReference() { generationBridge.clearReference(); }
  function clearReferenceBuffer() { generationBridge.clearReference(); }
  function optimizePrompt(rawText) { generationBridge.optimizePrompt(rawText); }

  // Discovery & History Facade
  function fetchPrompts(source, query) { discoveryBridge.fetchPrompts(source, query); }
  function fetchCivitaiPrompts(query) { discoveryBridge.fetchCivitaiPrompts(query); }
  function fetchHistory() { discoveryBridge.fetchHistory(); }
  function restoreFromHistory(path, prompt, seed, ratio, negative) {
    discoveryBridge.restoreFromHistory(path, prompt, seed, ratio, negative);
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
      settingsSync.loadSettings();
      checkBridge();
      refreshTelemetry();
      fetchHistory();
    }
  }

  onActivePollingChanged: {
    if (root.activePolling) {
      settingsSync.loadSettings();
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
