import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui
import "inspiration"
import "inspiration/InspirationHelper.js" as Helper

Item {
  id: root

  property var panelRoot: null
  readonly property bool isLoading: panelRoot ? panelRoot.isCivitaiLoading : false
  readonly property string activeSource: panelRoot ? panelRoot.activePromptSource : "civitai"

  Component.onCompleted: {
    if (panelRoot && (!panelRoot.civitaiModel || panelRoot.civitaiModel.length === 0)) {
      root.searchPrompts("");
    }
  }

  function selectSource(source) {
    if (panelRoot) {
      panelRoot.activePromptSource = source;
      root.searchPrompts(searchField.text);
    }
  }

  function searchPrompts(query) {
    if (panelRoot) {
      panelRoot.fetchPrompts(root.activeSource, query);
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.sm

    // Source Selector Tabs
    Flow {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xs

      Repeater {
        model: [
          { key: "civitai", label: "CIVITAI" },
          { key: "midlibrary", label: "MIDLIBRARY" },
          { key: "diffusiondb", label: "DIFFUSIONDB" },
          { key: "seaart", label: "SEAART" },
          { key: "shakker", label: "SHAKKER" },
          { key: "playground", label: "PLAYGROUND" },
          { key: "lexica", label: "LEXICA" },
          { key: "prompthero", label: "PROMPT HERO" },
          { key: "openart", label: "OPENART" },
          { key: "liblib", label: "LIBLIB" },
          { key: "tensora", label: "TENSORA" },
          { key: "huggingface", label: "HUGGING FACE" }
        ]

        delegate: Button {
          text: modelData.label
          fontSize: Commons.Style.font.caption
          bordered: true
          Layout.preferredHeight: Commons.Style.space(20)
          verticalPadding: Commons.Style.space(1)
          selected: root.activeSource === modelData.key
          foreground: selected ? "#4ade80" : Commons.Color.muted
          accent: "#4ade80"
          onClicked: root.selectSource(modelData.key)
        }
      }
    }

    // Search and Action Bar
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      FocusScope {
        id: searchField
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Style.space(20)
        implicitHeight: Commons.Style.space(20)
        activeFocusOnTab: true

        property string text: ""
        property string placeholderText: Helper.sourcePlaceholder(root.activeSource)
        readonly property int maxLength: 512
        signal accepted(string query)

        function insert(pos, str) {
          if (!str) return;
          var t = searchField.text + str;
          if (t.length > maxLength) t = t.slice(0, maxLength);
          searchField.text = t;
        }

        onTextChanged: {
          var t = text.replace(/[\r\n\t]+/g, " ").replace(/[\x00-\x1f\x7f]/g, "");
          if (t.length > maxLength) t = t.slice(0, maxLength);
          if (t !== text) text = t;
        }

        BorderSurface {
          anchors.fill: parent
          radius: Commons.Style.cornerRadius
          borderSpec: Commons.Border.controlSpec(searchField.activeFocus ? "focus" : (mouseArea.containsMouse ? "hover-cursor" : "normal"), Commons.Color.foreground, Commons.Color.accent)
          color: Commons.Style.controlFill(searchField.activeFocus, mouseArea.containsMouse, Commons.Color.foreground, Commons.Color.accent)
        }

        Text {
          id: label
          textFormat: Text.PlainText
          anchors.fill: parent
          anchors.leftMargin: Commons.Style.spacing.controlPaddingX
          anchors.rightMargin: Commons.Style.spacing.controlPaddingX
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideLeft
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          color: searchField.text.length ? Commons.Color.foreground : Commons.Util.alpha(Commons.Color.foreground, 0.55)
          text: searchField.text.length ? searchField.text : searchField.placeholderText
        }

        Rectangle {
          width: 1
          height: label.font.pixelSize + 2
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: label.left
          anchors.leftMargin: searchField.text.length ? label.implicitWidth + 2 : 0
          color: Commons.Color.accent
          visible: searchField.activeFocus

          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: searchField.activeFocus
            PropertyAnimation { to: 0; duration: 500 }
            PropertyAnimation { to: 1; duration: 500 }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          hoverEnabled: true
          onClicked: searchField.forceActiveFocus()
        }

        Keys.onPressed: function(e) {
          var mod = e.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
          if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            e.accepted = true;
            searchField.accepted(searchField.text);
          } else if (e.key === Qt.Key_Backspace) {
            e.accepted = true;
            if (searchField.text.length > 0) {
              searchField.text = searchField.text.slice(0, -1);
            }
          } else if (mod && (e.key === Qt.Key_V)) {
            e.accepted = true;
            if (panelRoot && panelRoot.pasteTextInto) {
              panelRoot.pasteTextInto(searchField);
            }
          } else if (mod && (e.key === Qt.Key_U || e.key === Qt.Key_K)) {
            e.accepted = true;
            searchField.text = "";
          } else if (e.key === Qt.Key_Escape) {
            if (searchField.text.length > 0) {
              e.accepted = true;
              searchField.text = "";
            } else {
              e.accepted = false;
            }
          } else if (!mod && !(e.modifiers & Qt.AltModifier) && e.text.length > 0) {
            e.accepted = true;
            searchField.text += e.text;
          }
        }

        onAccepted: function(query) {
          root.searchPrompts(query || searchField.text);
        }
      }

      Shortcut {
        sequence: "Ctrl+K"
        context: Qt.WindowShortcut
        enabled: root.visible && root.enabled
        onActivated: searchField.forceActiveFocus()
      }

      Button {
        text: root.isLoading ? "FETCHING..." : "FETCH PROMPTS"
        fontSize: Commons.Style.font.caption
        bordered: true
        active: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        enabled: !root.isLoading
        onClicked: root.searchPrompts(searchField.text)
      }
    }

    // Results Scroll Area
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Qt.tint(Commons.Color.background, Commons.Util.alpha(Commons.Color.foreground, 0.04))
      radius: Commons.Style.cornerRadius
      clip: true

      ListView {
        id: promptList
        anchors.fill: parent
        anchors.margins: Commons.Style.spacing.xs
        spacing: Commons.Style.spacing.sm
        model: {
          if (!panelRoot || !panelRoot.civitaiModel) return [];
          if (panelRoot.isNsfwEnabled) return panelRoot.civitaiModel;
          return panelRoot.civitaiModel.filter(function(item) {
            if (!item) return false;
            var n = String(item.nsfw || "None").toLowerCase();
            return n === "none" || n === "1" || n === "";
          });
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        delegate: InspirationCard {
          x: Math.round((promptList.width - width) / 2)
          width: promptList.width - Commons.Style.spacing.sm * 2
          modelData: model.modelData
          panelRoot: root.panelRoot
          activeSource: root.activeSource
        }

        // Loading State
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Commons.Style.spacing.sm
          visible: root.isLoading

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: Commons.Style.space(24)
            implicitWidth: loadingText.implicitWidth + Commons.Style.spacing.md * 2
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
            border.width: 1
            radius: Commons.Style.cornerRadius

            Text {
              id: loadingText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "LOADING //"
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: Commons.Color.accent

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.isLoading
                PropertyAnimation { to: 0.3; duration: 600 }
                PropertyAnimation { to: 1.0; duration: 600 }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Fetching prompts from " + Helper.sourceDisplayName(root.activeSource) + "..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            font.bold: true
            color: Commons.Color.accent
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Querying database and retrieving community metadata..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
          }
        }

        // Empty state
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: promptList.count === 0 && !root.isLoading
          text: "Enter keywords and click FETCH PROMPTS to explore " + Helper.sourceDisplayName(root.activeSource)
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.body
          color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Navigation Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      // NSFW Switcher
      Button {
        text: panelRoot && panelRoot.isNsfwEnabled ? "NSFW: ON" : "NSFW: OFF"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        selected: panelRoot && panelRoot.isNsfwEnabled
        foreground: selected ? "#4ade80" : Commons.Color.muted
        accent: "#4ade80"
        onClicked: if (panelRoot) panelRoot.toggleNsfw()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "BACK TO STUDIO"
        fontSize: Commons.Style.font.caption
        bordered: true
        active: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }
    }
  }
}
