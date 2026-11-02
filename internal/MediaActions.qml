import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var service: null
  property var activePasteTarget: null

  function setAsWallpaper(path) {
    if (!service || !path || !service.bridgeBin) return;
    wallProc.command = [service.bridgeBin, "wallpaper", path];
    wallProc.running = true;
  }

  function copyImageToClipboard(path) {
    if (!service || !path || !service.bridgeBin) return;
    clipCopyProc.command = [service.bridgeBin, "copy-image", path];
    clipCopyProc.running = true;
  }

  function copyTextToClipboard(text) {
    if (!service || !service.bridgeBin) return;
    clipCopyProc.command = [service.bridgeBin, "copy-text", text];
    clipCopyProc.running = true;
  }

  function openImageViewer(path) {
    if (!path) return;
    openFullscreenViewer(path);
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
    if (!service) return;
    openExternalProc.command = ["xdg-open", service.picturesDir];
    openExternalProc.running = true;
  }

  function pasteFromClipboard() {
    if (!service || !service.bridgeBin) return;
    pasteProc.command = [service.bridgeBin, "paste-clipboard"];
    pasteProc.running = true;
  }

  function triggerScreenSnip() {
    if (!service || !service.bridgeBin) return;
    snipProc.command = [service.bridgeBin, "snip"];
    snipProc.running = true;
  }

  function pasteTextInto(targetItem) {
    if (!service || !service.bridgeBin || pasteTextProc.running) return;
    root.activePasteTarget = targetItem;
    pasteTextProc.command = [service.bridgeBin, "paste-text"];
    pasteTextProc.running = true;
  }

  function validateReference(filePath) {
    if (!service || !filePath || !service.bridgeBin || validateRefProc.running) return;
    validateRefProc.command = [service.bridgeBin, "validate-ref", filePath];
    validateRefProc.running = true;
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

  Process {
    id: wallProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok") {
            service.generationTelemetry = "WALLPAPER SET";
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
      if (!service) return;
      if (exitCode === 0 && pickRefImageProc.collectedPath !== "") {
        service.setReferenceImage(pickRefImageProc.collectedPath);
      }
      pickRefImageProc.collectedPath = "";
    }
  }

  Process {
    id: pasteProc
    command: service && service.bridgeBin ? [service.bridgeBin, "paste-clipboard"] : []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            service.setReferenceImage(res.path);
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: pasteTextProc
    command: service && service.bridgeBin ? [service.bridgeBin, "paste-text"] : []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.text && root.activePasteTarget) {
            var cleanText = typeof service.sanitizePromptText === "function" ? service.sanitizePromptText(res.text) : res.text;
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
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            service.setReferenceImage(res.path);
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: snipProc
    command: service && service.bridgeBin ? [service.bridgeBin, "snip"] : []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!service) return;
        var str = (text || "").trim();
        if (str.length === 0 || str.length > 65536) return;
        try {
          var res = JSON.parse(str);
          if (res.status === "ok" && res.path) {
            service.setReferenceImage(res.path);
          }
        } catch (e) {}
      }
    }
  }
}
