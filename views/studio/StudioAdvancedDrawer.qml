import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: drawerRoot
  Layout.fillWidth: true
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null

  // Row A: CFG Scale Slider
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.sm

    Text {
      id: cfgLabel
      textFormat: Text.PlainText
      text: "CFG: " + (panelRoot ? panelRoot.cfg.toFixed(1) : "4.0")
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      color: Commons.Color.foreground
      Layout.preferredWidth: Commons.Style.space(68)

      HoverHandler {
        onHoveredChanged: if (root) root.setHelp(root.tr("help_cfg"), hovered)
      }
    }

    Item {
      id: cfgSliderContainer
      Layout.fillWidth: true
      Layout.minimumWidth: Commons.Style.space(80)
      implicitHeight: cfgSlider.implicitHeight
      clip: true

      PanelSlider {
        id: cfgSlider
        anchors.fill: parent
        bar: panelRoot ? panelRoot.bar : null
        minimum: 1.0
        maximum: 9.0
        step: 0.5
        value: panelRoot ? panelRoot.cfg : 4.0
        onMoved: function(val) {
          if (panelRoot) panelRoot.cfg = Math.round(val * 10) / 10;
        }

        HoverHandler {
          onHoveredChanged: if (root) root.setHelp(root.tr("help_cfg"), hovered)
        }
      }
    }

    // Quick CFG Presets (Turbo: 1.0 | Subtle: 2.5 | Standard: 4.0 | Bold: 6.0)
    RowLayout {
      spacing: Commons.Style.spacing.xs
      Layout.alignment: Qt.AlignVCenter
      Repeater {
        model: [1.0, 2.5, 4.0, 6.0]
        delegate: Button {
          text: String(modelData)
          fontSize: Commons.Style.font.caption
          bordered: false
          selected: panelRoot && Math.abs(panelRoot.cfg - modelData) < 0.1
          active: panelRoot && Math.abs(panelRoot.cfg - modelData) < 0.1
          foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
          accent: Commons.Color.accent
          Layout.preferredWidth: Commons.Style.space(28)
          Layout.preferredHeight: Commons.Style.space(20)
          horizontalPadding: Commons.Style.space(3)
          verticalPadding: Commons.Style.space(1)
          onClicked: if (panelRoot) panelRoot.cfg = modelData
          onHotChanged: if (root) root.setHelp("CFG: " + modelData, hot)
        }
      }
    }
  }

  // Row B: Seed Control & Steps (with Steps Slider Hover Help)
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.sm

    Button {
      text: panelRoot && panelRoot.seedLocked ? String(panelRoot.seedVal) : (root ? root.tr("seed_auto") : "AUTO")
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.seedLocked
      Layout.preferredWidth: Commons.Style.space(110)
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
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

    // Seed Stepper: [-1], [+1], [RND]
    Button {
      text: "-1"
      fontSize: Commons.Style.font.caption
      bordered: false
      Layout.preferredWidth: Commons.Style.space(28)
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      horizontalPadding: Commons.Style.space(2)
      onHotChanged: if (root) root.setHelp(root.tr("help_seed_dec"), hot)
      onClicked: {
        if (!panelRoot) return;
        var cur = Number(panelRoot.seedVal);
        if (!panelRoot.seedLocked || isNaN(cur) || cur <= 1) {
          panelRoot.seedVal = Math.max(1, Math.floor(Math.random() * 1000000000));
        } else {
          panelRoot.seedVal = cur - 1;
        }
        panelRoot.seedLocked = true;
      }
    }

    Button {
      text: "+1"
      fontSize: Commons.Style.font.caption
      bordered: false
      Layout.preferredWidth: Commons.Style.space(28)
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      horizontalPadding: Commons.Style.space(2)
      onHotChanged: if (root) root.setHelp(root.tr("help_seed_inc"), hot)
      onClicked: {
        if (!panelRoot) return;
        var cur = Number(panelRoot.seedVal);
        if (!panelRoot.seedLocked || isNaN(cur) || cur <= 0) {
          panelRoot.seedVal = Math.floor(Math.random() * 1000000000) + 1;
        } else {
          panelRoot.seedVal = cur + 1;
        }
        panelRoot.seedLocked = true;
      }
    }

    Button {
      text: "RND"
      fontSize: Commons.Style.font.caption
      bordered: false
      Layout.preferredWidth: Commons.Style.space(36)
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      horizontalPadding: Commons.Style.space(4)
      onHotChanged: if (root) root.setHelp(root.tr("help_seed_rnd"), hot)
      onClicked: {
        if (!panelRoot) return;
        panelRoot.seedVal = Math.floor(Math.random() * 1000000000) + 1;
        panelRoot.seedLocked = true;
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
        minimum: panelRoot && panelRoot.isTurboEnabled ? 4 : 20
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

    // Quick Step Presets (Turbo: 4, 6, 8 | Standard: 20, 25, 35)
    RowLayout {
      spacing: Commons.Style.spacing.xs
      Layout.alignment: Qt.AlignVCenter
      Repeater {
        model: panelRoot && panelRoot.isTurboEnabled ? [4, 6, 8] : [20, 25, 35]
        delegate: Button {
          text: String(modelData)
          fontSize: Commons.Style.font.caption
          bordered: false
          selected: panelRoot && panelRoot.steps === modelData
          active: panelRoot && panelRoot.steps === modelData
          foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
          accent: Commons.Color.accent
          Layout.preferredWidth: Commons.Style.space(28)
          Layout.preferredHeight: Commons.Style.space(20)
          horizontalPadding: Commons.Style.space(3)
          verticalPadding: Commons.Style.space(1)
          onClicked: if (panelRoot) panelRoot.steps = modelData
          onHotChanged: if (root) root.setHelp(root.tr("help_steps_" + modelData), hot)
        }
      }
    }
  }
}
