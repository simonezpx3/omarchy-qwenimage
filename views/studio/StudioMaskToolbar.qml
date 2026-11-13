import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

RowLayout {
  id: maskToolbarRoot
  Layout.fillWidth: true
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null
  property var maskCanvas: null

  Button {
    text: "BRUSH"
    fontSize: Commons.Style.font.caption
    bordered: false
    selected: Boolean(panelRoot && !panelRoot.maskEraser)
    foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
    accent: Commons.Color.accent
    Layout.preferredHeight: Commons.Style.space(18)
    verticalPadding: Commons.Style.space(1)
    horizontalPadding: Commons.Style.space(6)
    onHotChanged: if (root) root.setHelp(root.tr("help_mask_brush"), hot)
    onClicked: if (panelRoot) panelRoot.maskEraser = false
  }

  Button {
    text: "ERASE"
    fontSize: Commons.Style.font.caption
    bordered: false
    selected: Boolean(panelRoot && panelRoot.maskEraser)
    foreground: selected ? Commons.Color.urgent : Commons.Color.muted
    Layout.preferredHeight: Commons.Style.space(18)
    verticalPadding: Commons.Style.space(1)
    horizontalPadding: Commons.Style.space(6)
    onHotChanged: if (root) root.setHelp(root.tr("help_mask_erase"), hot)
    onClicked: if (panelRoot) panelRoot.maskEraser = true
  }

  Repeater {
    model: [15, 35, 70]
    Button {
      required property int modelData
      text: modelData + "px"
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: Boolean(panelRoot && panelRoot.maskBrushSize === modelData)
      foreground: selected ? Commons.Color.accent : Commons.Color.muted
      Layout.preferredHeight: Commons.Style.space(18)
      verticalPadding: Commons.Style.space(1)
      horizontalPadding: Commons.Style.space(5)
      onHotChanged: if (root) root.setHelp(root.tr("help_mask_size") + " (" + modelData + "px)", hot)
      onClicked: if (panelRoot) panelRoot.maskBrushSize = modelData
    }
  }

  Item { Layout.fillWidth: true }

  Button {
    text: "CLEAR"
    fontSize: Commons.Style.font.caption
    bordered: false
    foreground: Commons.Color.urgent
    Layout.preferredHeight: Commons.Style.space(18)
    verticalPadding: Commons.Style.space(1)
    horizontalPadding: Commons.Style.space(6)
    onHotChanged: if (root) root.setHelp(root.tr("help_mask_clear"), hot)
    onClicked: if (maskCanvas) maskCanvas.clearMask()
  }
}
