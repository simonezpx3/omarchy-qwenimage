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

  function deleteHistoryItem(path) {
    if (!service || !path || !service.bridgeBin) return;
    deleteProc.running = false;
    deleteProc.command = [service.bridgeBin, "delete", path];
    deleteProc.running = true;
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

  BoundedProcess {
    id: wallProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok") {
          service.generationTelemetry = "WALLPAPER SET";
        }
      } catch (e) {}
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

  BoundedProcess {
    id: pickRefImageProc
    maxOutBytes: 4096
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      if (!wasOverflowed && exitCode === 0 && stdoutText.length > 0) {
        service.setReferenceImage(stdoutText);
      }
    }
  }

  BoundedProcess {
    id: pasteProc
    maxOutBytes: 65536
    command: service && service.bridgeBin ? [service.bridgeBin, "paste-clipboard"] : []
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok" && res.path) {
          service.setReferenceImage(res.path);
        }
      } catch (e) {}
    }
  }

  BoundedProcess {
    id: pasteTextProc
    maxOutBytes: 65536
    command: service && service.bridgeBin ? [service.bridgeBin, "paste-text"] : []
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service) return;
      if (!wasOverflowed && stdoutText.length > 0) {
        try {
          var res = JSON.parse(stdoutText);
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
      }
      root.activePasteTarget = null;
    }
  }

  BoundedProcess {
    id: validateRefProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok" && res.path) {
          service.setReferenceImage(res.path);
        }
      } catch (e) {}
    }
  }

  BoundedProcess {
    id: deleteProc
    maxOutBytes: 65536
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok" && typeof service.fetchHistory === "function") {
          service.fetchHistory();
        }
      } catch (e) {}
    }
  }

  BoundedProcess {
    id: snipProc
    maxOutBytes: 65536
    command: service && service.bridgeBin ? [service.bridgeBin, "snip"] : []
    onFinished: function(stdoutText, exitCode, wasOverflowed) {
      if (!service || wasOverflowed || stdoutText.length === 0) return;
      try {
        var res = JSON.parse(stdoutText);
        if (res.status === "ok" && res.path) {
          service.setReferenceImage(res.path);
        }
      } catch (e) {}
    }
  }
}
