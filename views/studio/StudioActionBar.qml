import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: actionBarRoot
  Layout.fillWidth: true
  spacing: Commons.Style.spacing.xs

  property var root: null
  property var panelRoot: null

  // ===================================================================
  // FOOTER CONTEXTUAL HELP / STATUS BAR (Po najetí myši na tlačítka)
  // ===================================================================
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: Commons.Style.space(26)
    color: Commons.Util.alpha(Commons.Color.background, 0.85)
    border.color: (root && root.activeHelpText !== "")
      ? (root.activeHelpText.indexOf("VAROVÁNÍ") !== -1 || root.activeHelpText.indexOf("WARNING") !== -1
          ? Commons.Util.alpha(Commons.Color.urgent, 0.55)
          : Commons.Util.alpha(Commons.Color.accent, 0.45))
      : Commons.Color.menu.border
    border.width: 1
    radius: Commons.Style.cornerRadius

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Commons.Style.spacing.sm
      anchors.rightMargin: Commons.Style.spacing.sm
      spacing: Commons.Style.spacing.xs

      Text {
        textFormat: Text.PlainText
        text: "//"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: true
        color: (root && root.activeHelpText !== "")
          ? (root.activeHelpText.indexOf("VAROVÁNÍ") !== -1 || root.activeHelpText.indexOf("WARNING") !== -1
              ? Commons.Color.urgent
              : Commons.Color.accent)
          : Commons.Util.alpha(Commons.Color.foreground, 0.55)
      }

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: (root && root.activeHelpText !== "") ? root.activeHelpText : (root ? root.tr("default_tip") : "")
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.bold: Boolean(root && root.activeHelpText !== "")
        color: (root && root.activeHelpText !== "") ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.45)
        elide: Text.ElideRight
      }
    }
  }

  PanelSeparator { Layout.fillWidth: true }

  // ===================================================================
  // BOTTOM BAR: LoRA Toggles, Reset & Primary Synthesis Action (AC2)
  // ===================================================================
  RowLayout {
    Layout.fillWidth: true
    spacing: Commons.Style.spacing.sm

    // Turbo Viggle LoRA Switcher
    Button {
      text: panelRoot && panelRoot.isTurboEnabled ? "TURBO: ON" : "TURBO: OFF"
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.isTurboEnabled
      onHotChanged: if (root) root.setHelp(root.tr("help_turbo_lora"), hot)
      onClicked: if (panelRoot) panelRoot.toggleTurbo()
    }

    // Anime Style LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
    Button {
      text: {
        var mode = panelRoot ? panelRoot.animeMode : "off";
        return mode === "full" ? "ANIME: FULL" : (mode === "soft" ? "ANIME: SOFT" : "ANIME: OFF");
      }
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.animeMode !== "off"
      onHotChanged: if (root) root.setHelp(root.tr("help_anime_lora"), hot)
      onClicked: if (panelRoot) panelRoot.cycleAnimeMode()
    }

    // Uncensored Latent LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
    Button {
      text: {
        var mode = panelRoot ? panelRoot.hereticMode : "off";
        return mode === "full" ? "HERETIC: FULL" : (mode === "soft" ? "HERETIC: SOFT" : "HERETIC: OFF");
      }
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.hereticMode !== "off"
      onHotChanged: if (root) root.setHelp(root.tr("help_uncensored_lora"), hot)
      onClicked: if (panelRoot) panelRoot.cycleHereticMode()
    }

    // Anatomy Body LoRA Switcher (Tri-State: OFF -> SOFT -> FULL)
    Button {
      text: {
        var mode = panelRoot ? panelRoot.anatomyMode : "off";
        return mode === "full" ? "ANATOMY: FULL" : (mode === "soft" ? "ANATOMY: SOFT" : "ANATOMY: OFF");
      }
      fontSize: Commons.Style.font.caption
      bordered: true
      selected: panelRoot && panelRoot.anatomyMode !== "off"
      onHotChanged: if (root) root.setHelp(root.tr("help_anatomy_lora"), hot)
      onClicked: if (panelRoot) panelRoot.cycleAnatomyMode()
    }

    Item { Layout.fillWidth: true }

    // Isolated subtle Reset button (protected against accidental clicks)
    Button {
      text: root ? root.tr("reset") : "RESET"
      fontSize: Commons.Style.font.caption
      bordered: false
      foreground: Commons.Util.alpha(Commons.Color.foreground, 0.55)
      onHotChanged: if (root) root.setHelp(root.tr("help_reset"), hot)
      onClicked: if (panelRoot) {
        panelRoot.resetForm();
        if (root) root.genElapsedSeconds = 0;
      }
    }

    Rectangle {
      width: 1
      implicitHeight: Commons.Style.space(16)
      color: Commons.Util.alpha(Commons.Color.menu.border, 0.6)
      Layout.alignment: Qt.AlignVCenter
    }

    // Primary CTA: GENERATE
    Button {
      readonly property bool isBusy: Boolean(panelRoot && (panelRoot.isGenerating || panelRoot.isCancelling))
      text: {
        if (panelRoot && panelRoot.isCancelling) {
          return "CANCELLING...";
        }
        if (panelRoot && panelRoot.isGenerating) {
          return (root ? root.tr("cancel") : "CANCEL") + " // " + (root ? root.genElapsedSeconds : 0) + "s";
        }
        if (panelRoot && panelRoot.isGameLocked) return root ? root.tr("locked_game") : "LOCKED";
        return root ? root.tr("generate") : "GENERATE";
      }
      fontSize: Commons.Style.font.body
      font.bold: true
      bordered: true
      active: true
      selected: !isBusy
      foreground: isBusy ? Commons.Color.urgent : Commons.Color.accent
      Layout.preferredWidth: Commons.Style.space(136)
      Layout.preferredHeight: Commons.Style.space(28)
      enabled: panelRoot && (isBusy || !panelRoot.isGameLocked)
      onHotChanged: if (root) root.setHelp(isBusy ? root.tr("help_cancel") : root.tr("help_generate"), hot)
      onClicked: {
        if (!panelRoot) return;
        if (isBusy) {
          panelRoot.cancelGeneration();
          if (root) root.genElapsedSeconds = 0;
        } else {
          var pText = (root && root.promptCards && root.promptCards.promptInput) ? root.promptCards.promptInput.text : "";
          var nText = (root && root.promptCards && root.promptCards.negativeInput) ? root.promptCards.negativeInput.text : "";
          panelRoot.startGeneration(pText, nText);
        }
      }
    }
  }
}
