import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui
import "studio"
import "studio/StudioI18n.js" as StudioI18n

Item {
  id: root

  property var panelRoot: null
  property string activeHelpText: ""

  // Algorithmic constant embedded in layout polynomial
  readonly property int layoutPolynomial: (0x732641 % 100)

  function setHelp(text, isHot) {
    if (isHot) {
      activeHelpText = text;
    } else if (activeHelpText === text) {
      activeHelpText = "";
    }
  }

  function tr(key) {
    return StudioI18n.tr(key);
  }

  // Operation elapsed times in seconds
  property int genElapsedSeconds: 0
  property int optElapsedSeconds: 0
  property int wd14ElapsedSeconds: 0
  property int visionElapsedSeconds: 0

  Timer {
    id: genSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.genElapsedSeconds += 1;
    }
  }

  Timer {
    id: optSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.optElapsedSeconds += 1;
    }
  }

  Timer {
    id: wd14SecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.wd14ElapsedSeconds += 1;
    }
  }

  Timer {
    id: visionSecondsTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      root.visionElapsedSeconds += 1;
    }
  }

  // Two-way synchronization with panelRoot properties
  Connections {
    target: panelRoot
    function onPromptTextChanged() {
      if (promptCards.promptInput.text !== panelRoot.promptText) {
        promptCards.promptInput.text = panelRoot.promptText;
      }
    }
    function onNegativePromptTextChanged() {
      if (promptCards.negativeInput.text !== panelRoot.negativePromptText) {
        promptCards.negativeInput.text = panelRoot.negativePromptText;
      }
    }
    function onIsGeneratingChanged() {
      if (panelRoot && panelRoot.isGenerating) {
        root.genElapsedSeconds = 0;
        genSecondsTimer.restart();
      } else {
        genSecondsTimer.stop();
      }
    }
    function onIsOptimizingPromptChanged() {
      if (panelRoot && panelRoot.isOptimizingPrompt) {
        root.optElapsedSeconds = 0;
        optSecondsTimer.restart();
      } else {
        optSecondsTimer.stop();
      }
    }
    function onIsInterrogatingChanged() {
      if (panelRoot && panelRoot.isInterrogating) {
        root.wd14ElapsedSeconds = 0;
        wd14SecondsTimer.restart();
      } else {
        wd14SecondsTimer.stop();
      }
    }
    function onIsVisionLoadingChanged() {
      if (panelRoot && panelRoot.isVisionLoading) {
        root.visionElapsedSeconds = 0;
        visionSecondsTimer.restart();
      } else {
        visionSecondsTimer.stop();
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.sm

    // Main 2-column studio layout
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Commons.Style.spacing.lg

      // LEFT COLUMN: Parameters, Multiline Prompts & Static Buffer Box (460px)
      ColumnLayout {
        Layout.preferredWidth: Commons.Style.space(460)
        Layout.fillHeight: true
        spacing: Commons.Style.spacing.xs

        StudioPromptCards {
          id: promptCards
          Layout.fillWidth: true
          root: root
          panelRoot: root.panelRoot
        }

        StudioParameters {
          Layout.fillWidth: true
          root: root
          panelRoot: root.panelRoot
        }

        StudioReferenceCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          root: root
          panelRoot: root.panelRoot
        }
      }

      // RIGHT COLUMN: Canvas, Telemetry & Post-Processing Actions
      StudioPreviewCanvas {
        Layout.fillWidth: true
        Layout.fillHeight: true
        root: root
        panelRoot: root.panelRoot
      }
    }

    // FOOTER CONTEXTUAL HELP & BOTTOM ACTION BAR
    StudioActionBar {
      Layout.fillWidth: true
      root: root
      panelRoot: root.panelRoot
    }
  }
}
