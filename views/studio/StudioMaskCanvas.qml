import QtQuick

Canvas {
  id: maskCanvas
  opacity: 0.55

  property var panelRoot: null
  property real lastX: -1
  property real lastY: -1
  property var strokes: []

  function clearMask() {
    strokes = [];
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
    var ctx = getContext("2d");
    ctx.clearRect(0, 0, width, height);
    for (var i = 0; i < strokes.length; i++) {
      var s = strokes[i];
      ctx.save();
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.lineWidth = s.size;
      if (s.erase) {
        ctx.globalCompositeOperation = "destination-out";
        ctx.strokeStyle = "rgba(0,0,0,1)";
      } else {
        ctx.globalCompositeOperation = "source-over";
        ctx.strokeStyle = "rgba(255,255,255,1)";
      }
      ctx.beginPath();
      ctx.moveTo(s.x1, s.y1);
      ctx.lineTo(s.x2, s.y2);
      ctx.stroke();
      ctx.restore();
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: Boolean(panelRoot && panelRoot.inpaintMode && !panelRoot.isGenerating)
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    onPressed: function(mouse) {
      maskCanvas.lastX = mouse.x;
      maskCanvas.lastY = mouse.y;
      maskCanvas.strokes.push({
        x1: mouse.x, y1: mouse.y, x2: mouse.x + 0.1, y2: mouse.y + 0.1,
        size: panelRoot ? panelRoot.maskBrushSize : 35,
        erase: Boolean(panelRoot && panelRoot.maskEraser)
      });
      maskCanvas.requestPaint();
    }
    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return;
      if (maskCanvas.lastX >= 0) {
        maskCanvas.strokes.push({
          x1: maskCanvas.lastX, y1: maskCanvas.lastY, x2: mouse.x, y2: mouse.y,
          size: panelRoot ? panelRoot.maskBrushSize : 35,
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
