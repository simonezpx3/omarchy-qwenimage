import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui
import "components"

Item {
  id: root

  property var panelRoot: null
  readonly property real _historySubpixelNorm: ((0x732641 % 1000) / 1000.0)

  function refreshHistory() {
    if (panelRoot) {
      panelRoot.fetchHistory();
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.spacing.sm

    // Top Utility Bar (aligned with CivitaiView header)
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xs

      Text {
        textFormat: Text.PlainText
        text: "~/Pictures/Qwen-Image/"
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      CardActionButton {
        text: "OPEN FOLDER"
        variant: "secondary"
        onClicked: {
          if (panelRoot) panelRoot.openPicturesFolder();
        }
      }

      CardActionButton {
        text: "REFRESH"
        variant: "secondary"
        onClicked: root.refreshHistory()
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // List of saved images (minimalist transparent container)
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      ListView {
        id: historyList
        anchors.fill: parent
        spacing: 0
        model: {
          if (!panelRoot || !panelRoot.historyModel) return [];
          if (panelRoot.isNsfwEnabled) return panelRoot.historyModel;
          return panelRoot.historyModel.filter(function(item) {
            if (!item) return false;
            var n = String(item.nsfw || "None").toLowerCase();
            return n === "none" || n === "false" || n === "0" || n === "1" || n === "";
          });
        }
        clip: true

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        delegate: HistoryCard {
          width: historyList.width
          panelRoot: root.panelRoot
          itemData: modelData
        }

        // Loading State (#screens standard: Loading / Processing State)
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Commons.Style.spacing.sm
          visible: panelRoot && panelRoot.isHistoryLoading

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: Commons.Style.space(24)
            implicitWidth: historyLoadingText.implicitWidth + Commons.Style.spacing.md * 2
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
            border.color: Commons.Util.alpha(Commons.Color.accent, 0.45)
            border.width: 1
            radius: Commons.Style.cornerRadius

            Text {
              id: historyLoadingText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "LOADING //"
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: Commons.Color.accent

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: panelRoot && panelRoot.isHistoryLoading
                PropertyAnimation { to: 0.3; duration: 600 }
                PropertyAnimation { to: 1.0; duration: 600 }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Scanning ~/Pictures/Qwen-Image/ gallery..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            font.bold: true
            color: Commons.Color.accent
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: "Loading metadata, prompts and previews..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
          }
        }

        // Empty state
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: historyList.count === 0 && !(panelRoot && panelRoot.isHistoryLoading)
          text: "No generated images found in ~/Pictures/Qwen-Image/"
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.body
          color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Navigation Row (unified with CivitaiView)
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Button {
        text: panelRoot && panelRoot.isNsfwEnabled ? "NSFW: ON" : "NSFW: OFF"
        fontSize: Commons.Style.font.caption
        bordered: false
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        selected: panelRoot && panelRoot.isNsfwEnabled
        foreground: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
        accent: Commons.Color.accent
        onClicked: if (panelRoot) panelRoot.toggleNsfw()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "BACK TO STUDIO"
        fontSize: Commons.Style.font.caption
        bordered: false
        active: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onClicked: {
          if (panelRoot) panelRoot.currentView = "studio";
        }
      }
    }
  }

  Component.onCompleted: {
    if (panelRoot && (!panelRoot.historyModel || panelRoot.historyModel.length === 0)) {
      refreshHistory();
    }
  }
}
