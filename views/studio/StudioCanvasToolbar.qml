import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: toolbarRoot
  Layout.fillWidth: true
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null

  // Image Scaling Row
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      readonly property bool isBusy: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_esrgan")
      text: isBusy ? ("ESRGAN " + (root ? root.genElapsedSeconds : 0) + "s") : "4X ESRGAN"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      active: isBusy
      selected: isBusy
      foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
      enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
      onHotChanged: if (root) root.setHelp(root.tr("help_scale_esrgan"), hot)
      onClicked: if (panelRoot) panelRoot.aiUpscale("esrgan")
    }

    Button {
      readonly property bool isBusy: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_ultra")
      text: isBusy ? ("ULTRA " + (root ? root.genElapsedSeconds : 0) + "s") : "4X ULTRA"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      active: isBusy
      selected: isBusy
      foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
      enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
      onHotChanged: if (root) root.setHelp(root.tr("help_scale_ultra"), hot)
      onClicked: if (panelRoot) panelRoot.aiUpscale("ultra")
    }

    Button {
      readonly property bool isBusy: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale_anime")
      text: isBusy ? ("ANIME " + (root ? root.genElapsedSeconds : 0) + "s") : "4X ANIME"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      active: isBusy
      selected: isBusy
      foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
      enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
      onHotChanged: if (root) root.setHelp(root.tr("help_scale_anime"), hot)
      onClicked: if (panelRoot) panelRoot.aiUpscale("anime")
    }

    Button {
      readonly property bool isBusy: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === 0.5)
      text: isBusy ? ("0.5X " + (root ? root.genElapsedSeconds : 0) + "s") : "0.5X"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      active: isBusy
      selected: isBusy
      foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
      enabled: panelRoot && ((panelRoot.referencePath !== "") || (panelRoot.generatedPath !== "")) && !panelRoot.isGenerating
      onHotChanged: if (root) root.setHelp(root.tr("help_scale_half"), hot)
      onClicked: if (panelRoot) panelRoot.scaleImage(0.5)
    }

    Button {
      readonly property bool isBusy: Boolean(panelRoot && panelRoot.isGenerating && panelRoot.generatingMode === "scale" && panelRoot.currentScaleFactor === -1.0)
      text: isBusy ? ("FIT 1K " + (root ? root.genElapsedSeconds : 0) + "s") : "FIT 1K"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      active: isBusy
      selected: isBusy
      foreground: isBusy ? Commons.Color.accent : Commons.Color.foreground
      enabled: Boolean(((panelRoot && panelRoot.referencePath !== "") || (panelRoot && panelRoot.generatedPath !== "")) && !panelRoot.isGenerating)
      onHotChanged: if (root) root.setHelp(root.tr("help_scale_fit1k"), hot)
      onClicked: if (panelRoot) panelRoot.scaleImage(-1.0)
    }
  }

  // Actions Row
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      text: root ? root.tr("set_wallpaper") : "SET AS WALLPAPER"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      enabled: panelRoot && panelRoot.generatedPath !== ""
      onHotChanged: if (root) root.setHelp(root.tr("help_set_wallpaper"), hot)
      onClicked: if (panelRoot) panelRoot.setAsWallpaper(panelRoot.generatedPath)
    }

    Button {
      text: root ? root.tr("compare_ab") : "COMPARE A/B"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      enabled: panelRoot && panelRoot.referencePath !== "" && panelRoot.generatedPath !== ""
      onHotChanged: if (root) root.setHelp(root.tr("help_compare_ab"), hot)
      onClicked: if (panelRoot) panelRoot.currentView = "compare"
    }

    Button {
      text: root ? root.tr("copy_clipboard") : "COPY CLIPBOARD"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      enabled: panelRoot && panelRoot.generatedPath !== ""
      onHotChanged: if (root) root.setHelp(root.tr("help_copy_clipboard"), hot)
      onClicked: if (panelRoot) panelRoot.copyImageToClipboard(panelRoot.generatedPath)
    }

    Button {
      text: root ? root.tr("open_viewer") : "OPEN IN VIEWER"
      fontSize: Commons.Style.font.caption
      bordered: true
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      enabled: panelRoot && panelRoot.generatedPath !== ""
      onHotChanged: if (root) root.setHelp(root.tr("help_open_viewer"), hot)
      onClicked: if (panelRoot) panelRoot.openImageViewer(panelRoot.generatedPath)
    }
  }
}
