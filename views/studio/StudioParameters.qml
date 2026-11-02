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

  // 3. Aspect Ratio Selection (Declarative Repeater from 21:9 to 9:16 + AUTO REF)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.xs

    Button {
      text: root ? root.tr("ratio_auto_ref") : "AUTO (REF)"
      fontSize: Commons.Style.font.caption
      bordered: true
      visible: panelRoot && panelRoot.referencePath !== ""
      selected: panelRoot && panelRoot.aspectRatio === "auto"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(root.tr("help_ratio_auto_ref"), hot)
      onClicked: if (panelRoot) panelRoot.aspectRatio = "auto"
    }

    Repeater {
      model: ["21:9", "16:9", "16:10", "4:3", "1:1", "3:4", "9:16"]

      delegate: Button {
        readonly property bool isRefMatch: panelRoot && panelRoot.referencePath !== "" && panelRoot.referenceMatchedRatio === modelData
        text: modelData + (isRefMatch ? " · REF" : "")
        fontSize: Commons.Style.font.caption
        bordered: true
        selected: panelRoot && panelRoot.aspectRatio === modelData
        Layout.fillWidth: true
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
      bordered: true
      selected: panelRoot && panelRoot.resMode === "draft"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(root.tr("help_res_draft"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("draft")
    }
    Button {
      text: root ? root.tr("std") : "STD (1024)"
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.resMode === "standard"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(root.tr("help_res_std"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("standard")
    }
    Button {
      text: root ? root.tr("high") : "HIGH (1536)"
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.resMode === "high"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(root.tr("help_res_high"), hot)
      onClicked: if (panelRoot) panelRoot.setResolutionMode("high")
    }
    Button {
      readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2048
      text: root ? root.tr("ultra") : "ULTRA (2048)"
      fontSize: Commons.Style.font.caption
      bordered: true
      enabled: isAllowed
      opacity: isAllowed ? 1.0 : 0.4
      selected: panelRoot && panelRoot.resMode === "ultra"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(isAllowed ? root.tr("help_res_ultra") : root.tr("help_res_ultra_locked"), hot)
      onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("ultra")
    }
    Button {
      readonly property bool isAllowed: panelRoot && panelRoot.maxSupportedDim >= 2560
      text: root ? root.tr("max") : "MAX (2560)"
      fontSize: Commons.Style.font.caption
      bordered: true
      enabled: isAllowed
      opacity: isAllowed ? 1.0 : 0.4
      selected: panelRoot && panelRoot.resMode === "max"
      Layout.fillWidth: true
      onHotChanged: if (root) root.setHelp(isAllowed ? root.tr("help_res_max") : root.tr("help_res_max_locked"), hot)
      onClicked: if (isAllowed && panelRoot) panelRoot.setResolutionMode("max")
    }
  }

  // 6. Seed Control & Steps (with Steps Slider Hover Help)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.sm

    Button {
      text: panelRoot && panelRoot.seedLocked ? String(panelRoot.seedVal) : (root ? root.tr("seed_auto") : "AUTO")
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.seedLocked
      Layout.preferredWidth: Commons.Style.space(110)
      onHotChanged: {
        if (hot && panelRoot && root) {
          if (panelRoot.seedLocked) {
            root.setHelp("SEED: " + panelRoot.seedVal + " (" + root.tr("help_seed_locked") + ")", true);
          } else {
            root.setHelp(root.tr("help_seed_auto"), true);
          }
        } else if (!hot && root) {
          root.setHelp("", false);
        }
      }
      onClicked: {
        if (panelRoot) {
          panelRoot.seedLocked = !panelRoot.seedLocked;
          if (!panelRoot.seedLocked) {
            panelRoot.seedVal = -1;
          } else if (panelRoot.seedVal <= 0) {
            panelRoot.seedVal = Math.floor(Math.random() * 1000000000);
          }
        }
      }
    }

    Text {
      id: stepsLabel
      textFormat: Text.PlainText
      text: (root ? root.tr("steps") : "STEPS: ") + (panelRoot ? panelRoot.steps : 25)
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      color: Commons.Color.foreground
      Layout.preferredWidth: Commons.Style.space(68)

      HoverHandler {
        onHoveredChanged: if (root) root.setHelp(root.tr("help_steps"), hovered)
      }
    }

    Item {
      id: stepsSliderContainer
      Layout.fillWidth: true
      Layout.minimumWidth: Commons.Style.space(80)
      implicitHeight: stepsSlider.implicitHeight
      clip: true

      PanelSlider {
        id: stepsSlider
        anchors.fill: parent
        bar: panelRoot ? panelRoot.bar : null
        minimum: 10
        maximum: 50
        integer: true
        step: 1
        value: panelRoot ? panelRoot.steps : 25
        onMoved: function(val) {
          if (panelRoot) panelRoot.steps = Math.round(val);
        }

        HoverHandler {
          onHoveredChanged: if (root) root.setHelp(root.tr("help_steps"), hovered)
        }
      }
    }

    // Quick Step Presets (15 Fast, 25 Standard, 35 Detail)
    RowLayout {
      spacing: Commons.Style.spacing.xs
      Layout.alignment: Qt.AlignVCenter
      Repeater {
        model: [15, 25, 35]
        delegate: Button {
          text: String(modelData)
          fontSize: Commons.Style.font.caption
          bordered: true
          selected: panelRoot && panelRoot.steps === modelData
          active: panelRoot && panelRoot.steps === modelData
          Layout.preferredWidth: Commons.Style.space(28)
          horizontalPadding: Commons.Style.space(3)
          verticalPadding: Commons.Style.space(2)
          onClicked: if (panelRoot) panelRoot.steps = modelData
          onHotChanged: if (root) root.setHelp(root.tr("help_steps_" + modelData), hot)
        }
      }
    }
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
