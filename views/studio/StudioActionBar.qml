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
      bordered: false
      selected: panelRoot && panelRoot.isTurboEnabled
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_turbo_lora"), hot)
      onClicked: if (panelRoot) panelRoot.toggleTurbo()
    }

    // Anime Style LoRA Switcher (4-State: OFF -> LIGHT -> MEDIUM -> HEAVY)
    Button {
      text: {
        var mode = panelRoot ? panelRoot.animeMode : "off";
        if (mode === "heavy" || mode === "full") return "ANIME: HEAVY";
        if (mode === "medium") return "ANIME: MEDIUM";
        if (mode === "light" || mode === "soft") return "ANIME: LIGHT";
        return "ANIME: OFF";
      }
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.animeMode !== "off"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_anime_lora"), hot)
      onClicked: if (panelRoot) panelRoot.cycleAnimeMode()
    }

    // Uncensored Latent LoRA Switcher (4-State: OFF -> LIGHT -> MEDIUM -> HEAVY)
    Button {
      text: {
        var mode = panelRoot ? panelRoot.hereticMode : "off";
        if (mode === "heavy" || mode === "full") return "HERETIC: HEAVY";
        if (mode === "medium") return "HERETIC: MEDIUM";
        if (mode === "light" || mode === "soft") return "HERETIC: LIGHT";
        return "HERETIC: OFF";
      }
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: panelRoot && panelRoot.hereticMode !== "off"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_uncensored_lora"), hot)
      onClicked: if (panelRoot) panelRoot.cycleHereticMode()
    }

    // Genitalia Anatomy Fidelity LoRA Switcher (4-State: OFF -> LIGHT -> MEDIUM -> HEAVY)
    Button {
      readonly property string anatomyLevel: panelRoot ? panelRoot.anatomyMode : "off"
      readonly property bool anatomyActive: anatomyLevel !== "off"
      readonly property bool anatomyDeferred: anatomyActive && panelRoot && panelRoot.isAnatomyGateDeferred && !panelRoot.isNudityInPrompt
      readonly property bool anatomyIdle: anatomyActive && !anatomyDeferred && panelRoot && !panelRoot.isNudityInPrompt
      readonly property string anatomyHelpKey: anatomyIdle ? "help_anatomy_lora_idle" : (anatomyDeferred ? "help_anatomy_lora_deferred" : "help_anatomy_lora")
      text: {
        var base = "GENITALIA: OFF";
        if (anatomyLevel === "heavy" || anatomyLevel === "full") base = "GENITALIA: HEAVY";
        else if (anatomyLevel === "medium") base = "GENITALIA: MEDIUM";
        else if (anatomyLevel === "light" || anatomyLevel === "soft") base = "GENITALIA: LIGHT";
        return anatomyIdle ? (base + " (IDLE)") : base;
      }
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: anatomyActive && !anatomyIdle
      opacity: anatomyIdle ? 0.52 : 1.0
      foreground: selected
        ? Commons.Color.accent
        : (anatomyIdle
            ? Commons.Util.alpha(Commons.Color.foreground, 0.55)
            : Commons.Util.alpha(Commons.Color.foreground, 0.72))
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) {
        if (hot) {
          root.setHelp(root.tr(anatomyHelpKey), true);
        } else {
          root.setHelp(root.tr("help_anatomy_lora_idle"), false);
          root.setHelp(root.tr("help_anatomy_lora_deferred"), false);
          root.setHelp(root.tr("help_anatomy_lora"), false);
        }
      }
      onAnatomyHelpKeyChanged: if (hot && root) root.setHelp(root.tr(anatomyHelpKey), true)
      onClicked: if (panelRoot) panelRoot.cycleAnatomyMode()
    }

    // Human Anatomy Safeguard Switcher (3-State: AUTO -> ON -> OFF)
    Button {
      readonly property string guardMode: panelRoot && panelRoot.anatomyGuardMode ? panelRoot.anatomyGuardMode : "auto"
      text: "ANATOMY GUARD: " + guardMode.toUpperCase()
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: guardMode !== "off"
      foreground: guardMode === "off"
        ? Commons.Util.alpha(Commons.Color.urgent, 0.85)
        : (guardMode === "on" ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.82))
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_anatomy_guard"), hot)
      onClicked: if (panelRoot) panelRoot.cycleAnatomyGuardMode()
    }

    Item { Layout.fillWidth: true }

    // Reset button (quiet flat style, height 20)
    Button {
      text: root ? root.tr("reset") : "RESET"
      fontSize: Commons.Style.font.caption
      bordered: false
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) root.setHelp(root.tr("help_reset"), hot)
      onClicked: if (panelRoot) {
        panelRoot.resetForm();
        if (root) root.genElapsedSeconds = 0;
      }
    }

    // Auto-Tune Sampling Switcher (3-State: OFF -> BALANCED -> QUALITY)
    Button {
      readonly property string tuneMode: panelRoot && panelRoot.autoTuneMode ? panelRoot.autoTuneMode : "off"
      text: "AUTO TUNE: " + tuneMode.toUpperCase()
      fontSize: Commons.Style.font.caption
      bordered: false
      selected: tuneMode !== "off"
      foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      accent: Commons.Color.accent
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
      onHotChanged: if (root) {
        var extra = (panelRoot && panelRoot.autoTuneMode !== "off" && panelRoot.autoTuneSummary !== "")
          ? " [" + panelRoot.autoTuneSummary + "]"
          : "";
        root.setHelp(root.tr("help_auto_tune") + extra, hot);
      }
      onClicked: if (panelRoot) panelRoot.cycleAutoTuneMode()
    }

    // Primary CTA: GENERATE (height 20 matching tabs)
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
      fontSize: Commons.Style.font.caption
      bordered: true
      active: true
      selected: !isBusy
      foreground: isBusy ? Commons.Color.urgent : Commons.Color.accent
      Layout.preferredWidth: Commons.Style.space(136)
      Layout.preferredHeight: Commons.Style.space(20)
      verticalPadding: Commons.Style.space(1)
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
