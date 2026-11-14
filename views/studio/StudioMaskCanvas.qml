import QtQuick

Canvas {
  id: maskCanvas
  opacity: 0.55

  property var panelRoot: null
  property real lastX: -1
  property real lastY: -1
  property var strokes: []
  property int paintedCount: 0

  function clearMask() {
    strokes = [];
    paintedCount = 0;
    requestPaint();
  }

  onWidthChanged: {
    paintedCount = 0;
    requestPaint();
  }
  onHeightChanged: {
    paintedCount = 0;
    requestPaint();
  }

  Component.onCompleted: {
    if (panelRoot) panelRoot.activeMaskCanvas = maskCanvas;
  }
  Component.onDestruction: {
    if (panelRoot && panelRoot.activeMaskCanvas === maskCanvas) {
      panelRoot.activeMaskCanvas = null;
    }
  }

  onPaint: {
    if (width <= 0 || height <= 0) return;
    var ctx = getContext("2d");
    if (paintedCount > strokes.length) {
      paintedCount = 0;
    }
    if (paintedCount === 0) {
      ctx.clearRect(0, 0, width, height);
    }
    for (var i = paintedCount; i < strokes.length; i++) {
      var s = strokes[i];
      ctx.save();
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.lineWidth = s.nsize * width;
      if (s.erase) {
        ctx.globalCompositeOperation = "destination-out";
        ctx.strokeStyle = "rgba(0,0,0,1)";
      } else {
        ctx.globalCompositeOperation = "source-over";
        ctx.strokeStyle = "rgba(255,255,255,1)";
      }
      ctx.beginPath();
      ctx.moveTo(s.nx1 * width, s.ny1 * height);
      ctx.lineTo(s.nx2 * width, s.ny2 * height);
      ctx.stroke();
      ctx.restore();
    }
    paintedCount = strokes.length;
  }

  MouseArea {
    anchors.fill: parent
    enabled: Boolean(panelRoot && panelRoot.inpaintMode && !panelRoot.isGenerating)
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    onPressed: function(mouse) {
      if (maskCanvas.width <= 0 || maskCanvas.height <= 0) return;
      maskCanvas.lastX = mouse.x;
      maskCanvas.lastY = mouse.y;
      var brushSize = panelRoot ? panelRoot.maskBrushSize : 35;
      maskCanvas.strokes.push({
        nx1: mouse.x / maskCanvas.width,
        ny1: mouse.y / maskCanvas.height,
        nx2: (mouse.x + 0.1) / maskCanvas.width,
        ny2: (mouse.y + 0.1) / maskCanvas.height,
        nsize: brushSize / maskCanvas.width,
        erase: Boolean(panelRoot && panelRoot.maskEraser)
      });
      maskCanvas.requestPaint();
    }
    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return;
      if (maskCanvas.width <= 0 || maskCanvas.height <= 0) return;
      if (maskCanvas.lastX >= 0) {
        var brushSize = panelRoot ? panelRoot.maskBrushSize : 35;
        maskCanvas.strokes.push({
          nx1: maskCanvas.lastX / maskCanvas.width,
          ny1: maskCanvas.lastY / maskCanvas.height,
          nx2: mouse.x / maskCanvas.width,
          ny2: mouse.y / maskCanvas.height,
          nsize: brushSize / maskCanvas.width,
          erase: Boolean(panelRoot && panelRoot.maskEraser)
        });
        maskCanvas.requestPaint();
      }
      maskCanvas.lastX = mouse.x;
      maskCanvas.lastY = mouse.y;
    }
    onReleased: {
      maskCanvas.lastX = -1;
      maskCanvas.lastY = -1;
    }
  }
}
