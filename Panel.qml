import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "views"

Panel {
  id: root
  moduleName: "simonez.qwenimage"
  ipcTarget: "simonez.qwenimage"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string bridgeBin: Qt.resolvedUrl("bin/qwen-bridge").toString().replace(/^file:\/\//, "")
  readonly property string userHome: Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "user")
  readonly property string picturesDir: userHome + "/Pictures/Qwen-Image"
  readonly property string promptOptBin: userHome + "/.local/bin/prompt-opt"

  property string currentView: "studio" // "studio", "compare", "civitai", "history"
  onCurrentViewChanged: {
    if (currentView === "civitai") {
      root.fetchPrompts(root.activePromptSource || "civitai", "");
    } else if (currentView === "history") {
      root.fetchHistory();
    }
  }
  property string promptText: ""
  property string negativePromptText: "blurry, low quality, deformed, extra fingers, text, watermark"
  property string aspectRatio: "1:1"
  property string resMode: "standard" // "draft", "standard", "high"
  property int steps: 25
  property real cfg: 4.0
  property bool seedLocked: false
  property var seedVal: -1
  property string referencePath: ""
  property string referenceMatchedRatio: ""
  property int referenceRevision: 0
  property real denoise: 0.65
  property string generatedPath: ""
  property string previousGeneratedPath: ""
  property bool isGenerating: false
  property string generatingMode: "generate" // "generate", "scale", "enhance"
  property real currentScaleFactor: 0.0
  property bool isInterrogating: false
  property string generationTelemetry: "1024x1024 | 25 STEPS | RTX 3070 (0 TOKENS)"

  // Telemetry from Host
  property string studioStatus: "READY"
  property int vramUsed: 0
  property int vramTotal: 8192
  property int vramPct: 0
  property bool isOnline: false
  property bool isGameLocked: false

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

  // Models
  property var civitaiModel: []
  property bool isCivitaiLoading: false
  property string activePromptSource: "civitai"
  property bool isVisionLoading: false
  property var historyModel: []
  property var promptHistory: []
  property int promptHistoryIndex: -1
  property bool isOptimizingPrompt: false

  // Update state & timers
  property bool isUpdating: false
  property string updateMode: "plugin" // "plugin" or "all"
  property int updateElapsedSeconds: 0
  property string updateStatusText: ""
  property bool showStackConfirm: false
  property string qisScriptBin: userHome + "/Projects/omarchy-qwenimage/scripts/qis-stack.sh"

  // Language state (cs = Čeština, en = English)
  property string currentLang: "cs"

  function toggleLanguage() {
    currentLang = (currentLang === "cs" ? "en" : "cs");
    saveLangProc.command = ["python3", "-c", "import json, os, sys; p = os.path.expanduser('~/.config/omarchy/plugins/simonez.qwenimage/settings.json'); d = json.load(open(p)) if os.path.exists(p) else {}; d['language'] = sys.argv[1]; open(p, 'w').write(json.dumps(d))", root.currentLang];
    saveLangProc.running = true;
  }

  // Algorithmic author signature embedded in view switcher seed
  readonly property int viewCalibrationSeed: (0x732641 % 50)

  function updateTelemetry(data) {
    if (!data) return;
    root.studioStatus = data.status || "READY";
    root.isOnline = !!data.online;
    root.isGameLocked = !!data.game_locked;
    root.vramUsed = data.vram_used_mb || 0;
    root.vramTotal = data.vram_total_mb || 8192;
    root.vramPct = data.vram_pct || 0;
    if (data.services) {
      root.svcComfy = !!data.services.comfyui;
      root.svcGpu = !!data.services.gpu;
      root.svcOllama = !!data.services.ollama;
      root.svcWd14 = !!data.services.wd14;
      root.svcCivitai = !!data.services.civitai;
    }
    if (data.versions) {
      root.versionQwen = data.versions.qwen_model || root.versionQwen;
      root.versionComfy = data.versions.comfyui || "";
      root.versionOllama = data.versions.ollama || "";
      root.versionGpuDriver = data.versions.driver ? (data.gpu_name + " (" + data.versions.driver + ")") : (data.gpu_name || "");
      root.versionQuickshell = data.versions.quickshell || "";
      root.versionHyprland = data.versions.hyprland || "";
    }
  }

  function refreshTelemetry() {
    panelStatusProc.running = true;
    if (hostWidget && hostWidget.refresh) hostWidget.refresh();
  }

  function open() {
    root.controller.show();
    root.refreshTelemetry();
  }

  function close() {
    root.controller.hide();
  }

  function toggle() {
    root.opened ? root.close() : root.open();
  }

  function paste() {
    root.pasteFromClipboard();
  }

  function snip() {
    root.triggerScreenSnip();
  }

  function resetForm() {
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
    if (isGenerating || isGameLocked) return;
    var trimmed = promptText.trim();
    if (trimmed === "") return;

    // Add to prompt history
    if (promptHistory.indexOf(trimmed) === -1) {
      promptHistory.push(trimmed);
      promptHistoryIndex = promptHistory.length - 1;
    }

    isGenerating = true;
    generatingMode = "generate";
    currentScaleFactor = 0.0;
    if (hostWidget) hostWidget.isBusy = true;

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
      args.push(String(denoise));
    }

    genProc.command = args;
    genProc.running = true;
  }

  function aiEnhance() {
    var target = generatedPath !== "" ? generatedPath : referencePath;
    if (target === "" || isGenerating || isGameLocked) return;

    var pText = promptText.trim();
    if (pText === "") {
      pText = "masterpiece, best quality, ultra detailed, sharp focus, 8k";
    }

    isGenerating = true;
    generatingMode = "enhance";
    currentScaleFactor = 2.0;
    if (hostWidget) hostWidget.isBusy = true;

    var actualSeed = seedLocked ? Number(seedVal) : -1;
    var args = [
      root.bridgeBin,
      "generate",
      pText,
      "ai2x",
      String(steps),
      String(cfg),
      String(actualSeed),
      negativePromptText,
      target,
      "0.35"
    ];

    genProc.command = args;
    genProc.running = true;
  }

  function scaleImage(factor) {
    var target = generatedPath !== "" ? generatedPath : referencePath;
    if (target === "" || isGenerating) return;
    isGenerating = true;
    generatingMode = "scale";
    currentScaleFactor = factor;
    if (hostWidget) hostWidget.isBusy = true;
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
    var proc = wallProc;
    proc.command = [root.bridgeBin, "wallpaper", path];
    proc.running = true;
  }

  function copyImageToClipboard(path) {
    if (!path) return;
    var p = clipCopyProc;
    p.command = ["bash", "-c", "wl-copy -t image/png < '" + path + "'"];
    p.running = true;
  }

  function copyTextToClipboard(text) {
    var p = clipCopyProc;
    p.command = ["bash", "-c", "echo -n " + JSON.stringify(text) + " | wl-copy"];
    p.running = true;
  }

  function openImageViewer(path) {
    if (!path) return;
    var p = clipCopyProc;
    p.command = ["xdg-open", path];
    p.running = true;
  }

  function openPicturesFolder() {
    var p = clipCopyProc;
    p.command = ["xdg-open", root.picturesDir];
    p.running = true;
  }

  function pasteFromClipboard() {
    pasteProc.running = true;
  }

  function triggerScreenSnip() {
    snipProc.running = true;
  }

  function interrogateWd14() {
    if (referencePath === "" || isInterrogating) return;
    root.isInterrogating = true;
    tagProc.command = [root.bridgeBin, "interrogate", referencePath];
    tagProc.running = true;
  }

  function extractVisionPrompt() {
    if (referencePath === "" || isVisionLoading) return;
    root.isVisionLoading = true;
    visionProc.command = [root.bridgeBin, "vision", referencePath];
    visionProc.running = true;
  }

  function setReferenceImage(path) {
    if (!path) return;
    referencePath = path;
    referenceRevision++;
    // Inspect for metadata
    metaProc.command = [root.bridgeBin, "read-meta", path];
    metaProc.running = true;
  }

  function restoreFromHistory(path, prompt, seed, ratio) {
    if (prompt) promptText = prompt;
    if (seed && seed > 0) {
      seedVal = seed;
      seedLocked = true;
    }
    if (ratio) aspectRatio = ratio;
    generatedPath = path;
  }

  function fetchPrompts(source, query) {
    root.isCivitaiLoading = true;
    root.activePromptSource = source || "civitai";
    civitaiProc.command = [
      root.bridgeBin,
      "prompts",
      root.activePromptSource,
      query || "",
      "--limit",
      "25"
    ];
    civitaiProc.running = true;
  }

  function fetchCivitaiPrompts(query) {
    root.fetchPrompts(root.activePromptSource || "civitai", query);
  }

  function fetchHistory() {
    histProc.command = [root.bridgeBin, "history", "30"];
    histProc.running = true;
  }

  // Backend Processes
  Process {
    id: genProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isGenerating = false;
        root.currentScaleFactor = 0.0;
        if (hostWidget) hostWidget.isBusy = false;
        try {
          var res = JSON.parse(text || "{}");
          if (res.status === "ok" && res.path) {
            root.previousGeneratedPath = root.generatedPath;
            root.generatedPath = res.path;
            var elapsedSec = (typeof res.elapsed === "number") ? res.elapsed.toFixed(1) : String(res.elapsed || "0");
            root.generationTelemetry = (res.ratio || "1:1") + " | " + (res.steps || 25) + " STEPS | " + elapsedSec + "s | SEED: " + (res.seed >= 0 ? res.seed : "RANDOM");
            root.fetchHistory();
          } else if (res.status === "error") {
            root.generationTelemetry = "CHYBA: " + (res.message || "Generování selhalo");
          }
        } catch (e) {
          root.generationTelemetry = "CHYBA ZPRACOVÁNÍ VÝSTUPU";
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
        if (hostWidget) hostWidget.isBusy = false;
        try {
          var res = JSON.parse(text || "{}");
          if (res.status === "ok" && res.path) {
            root.previousGeneratedPath = root.generatedPath;
            root.generatedPath = res.path;
            root.generationTelemetry = (res.width || "2048") + "x" + (res.height || "2048") + " (SIMD LANCZOS)";
            root.fetchHistory();
          }
        } catch (e) {}
      }
    }
  }

  Process { id: wallProc }
  Process { id: clipCopyProc }

  Process {
    id: panelStatusProc
    command: [root.bridgeBin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}");
          if (data && data.status) {
            root.updateTelemetry(data);
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: pasteProc
    command: [root.bridgeBin, "paste-clipboard"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
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
        try {
          var res = JSON.parse(text || "{}");
          if (res.status === "ok" && res.items) {
            root.historyModel = res.items;
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: saveLangProc
  }

  Process {
    id: loadLangProc
    command: ["python3", "-c", "import json, os; p = os.path.expanduser('~/.config/omarchy/plugins/simonez.qwenimage/settings.json'); print(json.load(open(p)).get('language', 'cs') if os.path.exists(p) else 'cs')"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var l = (text || "").trim();
        if (l === "cs" || l === "en") {
          root.currentLang = l;
        }
      }
    }
  }

  function optimizePrompt(rawText) {
    if (!rawText || rawText.trim() === "" || root.isOptimizingPrompt) return;
    root.isOptimizingPrompt = true;
    optProc.command = [root.promptOptBin, rawText.trim(), "-m", "diffusion", "-s"];
    optProc.running = true;
  }

  Process {
    id: optProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isOptimizingPrompt = false;
        var opt = (text || "").trim();
        if (opt !== "") {
          root.promptText = opt;
        }
      }
    }
  }

  Timer {
    id: updateTimer
    interval: 1000
    repeat: true
    running: root.isUpdating
    onTriggered: {
      root.updateElapsedSeconds += 1;
    }
  }

  Timer {
    id: updateDoneTimer
    interval: 3000
    repeat: false
    running: false
    onTriggered: {
      root.updateStatusText = "";
    }
  }

  function triggerUpdate(mode) {
    if (isUpdating) return;
    updateMode = mode || "plugin";
    updateElapsedSeconds = 0;
    updateStatusText = "";
    showStackConfirm = false;
    isUpdating = true;
    updateProc.command = ["bash", root.qisScriptBin, "update", updateMode];
    updateProc.running = true;
  }

  Process {
    id: updateProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isUpdating = false;
        var totalTime = root.updateElapsedSeconds;
        root.updateStatusText = "󰄬 AKTUALIZOVÁNO (" + totalTime + "s)";
        updateDoneTimer.restart();
        root.refreshTelemetry();
        root.fetchHistory();
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: panel.fittedContentWidth(Style.space(960))
    contentHeight: panel.fittedContentHeight(Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: {
        if (root.currentView !== "studio") {
          root.currentView = "studio";
        } else {
          root.close();
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.md
        spacing: Style.spacing.sm

        // HEADER BAR WITH SYSTEM HEALTH & SERVICE BADGES
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.sm

          RowLayout {
            spacing: Style.spacing.xs

            Item {
              width: Style.space(18)
              height: Style.space(18)
              Layout.alignment: Qt.AlignVCenter

              Image {
                id: qisLogo
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/qwen-heretic.svg")
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
                layer.enabled: true
              }

              MultiEffect {
                anchors.fill: qisLogo
                source: qisLogo
                visible: true
                colorization: 1.0
                colorizationColor: Color.accent
              }
            }

            Text {
              text: "QIS"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.accent
            }
          }

          // Active Qwen Model Version Badge
          Rectangle {
            height: Style.space(20)
            implicitWidth: qwenModelRow.implicitWidth + Style.spacing.xs * 2
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
            border.width: 1
            radius: Style.cornerRadius

            RowLayout {
              id: qwenModelRow
              anchors.centerIn: parent
              spacing: 4
              Text {
                text: "󱫠"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.accent
              }
              Text {
                text: root.versionQwen
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Service Health Badges row
          RowLayout {
            spacing: Style.spacing.xs

            // 1. COMFYUI
            Rectangle {
              height: Style.space(20)
              implicitWidth: comfyRow.implicitWidth + Style.spacing.xs * 2
              color: root.svcComfy ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcComfy ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: comfyRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcComfy ? "#4ade80" : "#f87171"
                }
                Text {
                  text: (root.versionComfy && root.versionComfy !== "Offline" && root.versionComfy !== "Online") ? ("COMFYUI v" + root.versionComfy) : "COMFYUI"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcComfy ? "#4ade80" : "#f87171"
                }
              }
            }

            // 2. OLLAMA (CZ➔EN)
            Rectangle {
              height: Style.space(20)
              implicitWidth: ollamaRow.implicitWidth + Style.spacing.xs * 2
              color: root.svcOllama ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcOllama ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: ollamaRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcOllama ? "#4ade80" : "#f87171"
                }
                Text {
                  text: (root.versionOllama && root.versionOllama !== "Offline" && root.versionOllama !== "Online") ? ("OLLAMA v" + root.versionOllama) : "OLLAMA"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcOllama ? "#4ade80" : "#f87171"
                }
              }
            }

            // 3. WD14 ONNX
            Rectangle {
              height: Style.space(20)
              implicitWidth: wd14Row.implicitWidth + Style.spacing.xs * 2
              color: root.svcWd14 ? Qt.rgba(0.2, 0.8, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
              border.color: root.svcWd14 ? Qt.rgba(0.2, 0.8, 0.2, 0.6) : Qt.rgba(0.9, 0.2, 0.2, 0.6)
              border.width: 1
              radius: Style.cornerRadius

              RowLayout {
                id: wd14Row
                anchors.centerIn: parent
                spacing: 4
                Text {
                  text: "●"
                  font.pixelSize: Style.font.caption
                  color: root.svcWd14 ? "#4ade80" : "#f87171"
                }
                Text {
                  text: "WD14 ONNX"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.svcWd14 ? "#4ade80" : "#f87171"
                }
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Confirm Box for Full Stack Update (Režim 2: Kompletní stack)
          RowLayout {
            visible: root.showStackConfirm && !root.isUpdating
            spacing: Style.spacing.xs

            Text {
              text: root.currentLang === "cs" ? "Aktualizovat stack (ComfyUI & nody)?" : "Update stack (ComfyUI & nodes)?"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
            }

            Button {
              text: root.currentLang === "cs" ? "PROVÉST" : "CONFIRM"
              fontSize: Style.font.caption
              bordered: true
              foreground: Color.accent
              onClicked: root.triggerUpdate("all")
            }

            Button {
              text: root.currentLang === "cs" ? "ZRUŠIT" : "CANCEL"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.showStackConfirm = false
            }
          }

          Text {
            text: "VRAM: " + (root.vramUsed / 1024).toFixed(1) + " / " + (root.vramTotal / 1024).toFixed(1) + " GB (" + root.vramPct + "%)"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
          }

          Button {
            id: updateBtn
            text: {
              if (root.isUpdating) {
                return "󰑮 AKTUALIZUJI " + (root.updateMode === "all" ? "STACK" : "PLUGIN") + "... (" + root.updateElapsedSeconds + "s)";
              }
              if (root.updateStatusText !== "") {
                return root.updateStatusText;
              }
              return "󰑐 UPDATE";
            }
            fontSize: Style.font.caption
            bordered: true
            active: root.isUpdating
            foreground: root.updateStatusText !== "" ? "#4ade80" : (root.isUpdating ? Color.accent : Color.foreground)
            enabled: !root.isUpdating
            onClicked: {
              root.triggerUpdate("plugin");
            }

            TapHandler {
              acceptedButtons: Qt.RightButton
              onTapped: {
                if (!root.isUpdating) {
                  root.showStackConfirm = !root.showStackConfirm;
                }
              }
            }

            HoverHandler {
              onHoveredChanged: {
                if (viewLoader.item && typeof viewLoader.item.setHelp === "function") {
                  viewLoader.item.setHelp(
                    root.currentLang === "cs"
                      ? "UPDATE: Levý klik = Rychlý update pluginu | Pravý klik = Kompletní stack (ComfyUI & nody)"
                      : "UPDATE: Left click = Quick plugin update | Right click = Full stack update (ComfyUI & nodes)",
                    hovered
                  );
                }
              }
            }
          }

          Button {
            text: "REFRESH"
            fontSize: Style.font.caption
            bordered: true
            onClicked: {
              root.refreshTelemetry();
              root.fetchHistory();
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // MAIN VIEW CONTAINER
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Loader {
            id: viewLoader
            anchors.fill: parent
            sourceComponent: {
              if (root.currentView === "compare") return compareComponent;
              if (root.currentView === "civitai") return civitaiComponent;
              if (root.currentView === "history") return historyComponent;
              return studioComponent;
            }
          }

          Component {
            id: studioComponent
            StudioView { panelRoot: root }
          }

          Component {
            id: compareComponent
            CompareView { panelRoot: root }
          }

          Component {
            id: civitaiComponent
            CivitaiView { panelRoot: root }
          }

          Component {
            id: historyComponent
            HistoryView { panelRoot: root }
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // FOOTER BAR WITH BRAND SIGNATURE AND ESCAPE HINT (IDENTICAL TO VKEYBOARD)
        Item {
          Layout.fillWidth: true
          implicitHeight: Style.space(16)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              text: "v1.0.0"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            }
            Text {
              text: "·"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            }
            Text {
              text: "s&A"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "[Esc: " + (root.currentLang === "cz" ? "Zavřít" : "Close") + "]"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
          }
        }
      }
    }
  }

  Component.onCompleted: {
    loadLangProc.running = true;
    refreshTelemetry();
    fetchHistory();
  }
}
