import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: paramsRoot
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null
  property bool advancedExpanded: false

  // 3. Aspect Ratio Selection (Declarative Repeater from 21:9 to 9:16 + AUTO REF)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      text: root ? root.tr("ratio_auto_ref") : "AUTO (REF)"
      fontSize: Commons.Style.font.caption
      bordered: false
      visible: panelRoot && panelRoot.referencePath !== ""
      selected: panelRoot && panelRoot.aspectRatio === "auto"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_ratio_auto_ref"), hot)
      onClicked: if (panelRoot) panelRoot.aspectRatio = "auto"
    }

    Repeater {
      model: ["21:9", "16:9", "16:10", "4:3", "1:1", "3:4", "9:16"]

      delegate: Button {
        readonly property bool isRefMatch: panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === modelData
        text: modelData + (isRefMatch ? " · REF" : "")
        fontSize: Commons.Style.font.caption
        bordered: false
        selected: panelRoot && panelRoot.aspectRatio === modelData
        foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
        accent: Commons.Color.accent
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onHotChanged: if (root) root.setHelp(root.tr("help_ratio_" + modelData.replace(":", "_")), hot)
        onClicked: if (panelRoot) panelRoot.aspectRatio = modelData
      }
    }
  }

  // 5. Resolution Mode (Hardware Tier Adaptive: 8GB -> High 1536, 12GB+ -> Ultra 2048, 20GB+ -> Max 2560)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      text: root ? root.tr("draft") : "DRAFT (512)"
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.resMode === "draft"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_res_draft"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("draft")
    }
    Button {
      text: root ? root.tr("std") : "STD (1024)"
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.resMode === "standard"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_res_std"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("standard")
    }
    Button {
      text: root ? root.tr("high") : "HIGH (1536)"
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.resMode === "high"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_res_high"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("high")
    }
    Button {
      readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2048
      text: root ? root.tr("ultra") : "ULTRA (2048)"
      fontSize: Commons.Style.font.caption
      bordered: false
      enabled: isAllowed
      opacity: isAllowed ? 1.0 : 0.4
      selected: panelRoot && panelRoot.resMode === "ultra"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(isAllowed ? root.tr("help_res_ultra") : root.tr("help_res_ultra_locked"), hot)
      onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("ultra")
    }
    Button {
      readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2560
      text: root ? root.tr("max") : "MAX (2560)"
      fontSize: Commons.Style.font.caption
      bordered: false
      enabled: isAllowed
      opacity: isAllowed ? 1.0 : 0.4
      selected: panelRoot && panelRoot.resMode === "max"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(isAllowed ? root.tr("help_res_max") : root.tr("help_res_max_locked"), hot)
      onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("max")
    }
  }

  // 6. Advanced Drawer Toggle (AC4)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      id: advToggleBtn
      text: (paramsRoot.advancedExpanded ? "ADVANCED ▾" : "ADVANCED ▸") + " // CFG " + (panelRoot ? panelRoot.cfg.toFixed(1) : "4.0") + " · " + (panelRoot && panelRoot.seedLocked ? "SEED " + panelRoot.seedVal : "AUTO SEED")
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: paramsRoot.advancedExpanded
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.fillWidth: true
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_advanced_params"), hot)
      onClicked: paramsRoot.advancedExpanded = !paramsRoot.advancedExpanded
    }
  }

  // 7. Advanced Drawer Content (AC4 - CFG, Seed, Steps)
  StudioAdvancedDrawer {
    visible: paramsRoot.advancedExpanded
    root: paramsRoot.root
    panelRoot: paramsRoot.panelRoot
  }

  // Status & Anatomical Warning Line
  Text {
    textFormat: Text.PlainText
    visible: panelRoot && !panelRoot.isTurboEnabled && panelRoot.steps < 25
    text: root ? root.tr("warn_low_steps") : ""
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.caption
    color: Commons.Color.urgent
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
  Text {
    textFormat: Text.PlainText
    visible: panelRoot && panelRoot.isHumanSubjectInPrompt && panelRoot.resMode === "draft"
    text: root ? root.tr("warn_human_draft") : ""
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.caption
    color: Commons.Color.urgent
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
}
