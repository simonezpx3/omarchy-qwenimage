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

        delegate: Rectangle {
          id: cardDelegate
          width: historyList.width
          implicitHeight: Math.max(Commons.Style.space(104), rowContent.implicitHeight + Commons.Style.spacing.sm * 2)
          height: implicitHeight
          color: cardArea.containsMouse ? Commons.Util.alpha(Commons.Color.accent, 0.05) : "transparent"
          border.width: 0
          radius: Commons.Style.cornerRadius

          MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 0
            onClicked: {
              if (panelRoot) {
                panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio, modelData.negative_prompt, modelData.steps, modelData.loras);
                panelRoot.currentView = "studio";
              }
            }
          }

          RowLayout {
            id: rowContent
            z: 1
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.sm
            spacing: Commons.Style.spacing.sm

            // 1. Minimalist Thumbnail (88x88, borderless)
            Rectangle {
              id: previewBox
              Layout.preferredWidth: Commons.Style.space(88)
              Layout.preferredHeight: Commons.Style.space(88)
              Layout.alignment: Qt.AlignTop
              color: Commons.Util.alpha(Commons.Color.foreground, 0.04)
              radius: Commons.Style.cornerRadius
              clip: true
              border.width: 0

              Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: modelData.path ? ("file://" + encodeURI(modelData.path)) : ""
                sourceSize.width: Commons.Style.space(88) * 2
                sourceSize.height: Commons.Style.space(88) * 2
                smooth: true
                cache: true
                asynchronous: true
              }
            }

            // 2. Metadata, Prompt description & Action Row
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Commons.Style.spacing.xxs

              // Top row: Ratio/Local Tag + NSFW Badge + Filename/Metadata
              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xs

                Rectangle {
                  height: Commons.Style.space(16)
                  implicitWidth: typeTagText.implicitWidth + Commons.Style.spacing.xs * 2
                  color: Commons.Util.alpha(Commons.Color.accent, 0.12)
                  border.width: 0
                  radius: Commons.Style.cornerRadius

                  Text {
                    id: typeTagText
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: (modelData.ratio ? String(modelData.ratio) : "LOCAL").toUpperCase()
                    font.family: Commons.Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Commons.Color.accent
                  }
                }

                NsfwBadge {
                  level: modelData.nsfw ? String(modelData.nsfw) : "None"
                }

                Text {
                  text: (modelData.filename ? (modelData.filename + " · ") : "")
                        + (modelData.size_mb ? (modelData.size_mb + " MB · ") : "")
                        + (modelData.seed && modelData.seed > 0 ? ("Seed " + modelData.seed + " · ") : "")
                        + (modelData.steps ? (modelData.steps + " steps") : "")
                  textFormat: Text.PlainText
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              // Main Prompt Text
              Text {
                Layout.fillWidth: true
                text: modelData.prompt || "No prompt description"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Color.foreground
              }

              // Negative Prompt Text
              Text {
                Layout.fillWidth: true
                text: "NEG: " + (modelData.negative_prompt || "")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 1
                elide: Text.ElideRight
                font.family: Commons.Style.font.family
                font.pixelSize: Math.max(10, Commons.Style.font.caption * 0.9)
                color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                visible: !!modelData.negative_prompt && modelData.negative_prompt.trim() !== ""
              }

              // Bottom Action Row (unified with InspirationCard)
              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xs

                Item { Layout.fillWidth: true }

                CardActionButton {
                  text: "RESTORE"
                  variant: "primary"
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio, modelData.negative_prompt, modelData.steps, modelData.loras);
                      panelRoot.currentView = "studio";
                    }
                  }
                }

                CardActionButton {
                  text: "COPY"
                  variant: "secondary"
                  onClicked: {
                    if (panelRoot) panelRoot.copyTextToClipboard(modelData.prompt || "");
                  }
                }

                CardActionButton {
                  text: "BUFFER"
                  variant: "secondary"
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.setReferenceImage(modelData.path);
                      panelRoot.currentView = "studio";
                    }
                  }
                }

                CardActionButton {
                  text: "VIEW"
                  variant: "secondary"
                  onClicked: if (panelRoot) panelRoot.openFullscreenViewer(modelData.path)
                }

                CardActionButton {
                  text: "WALLPAPER"
                  variant: "secondary"
                  onClicked: if (panelRoot) panelRoot.setAsWallpaper(modelData.path)
                }

                CardActionButton {
                  id: deleteBtn
                  property bool confirmArmed: false
                  Timer {
                    id: confirmResetTimer
                    interval: 3000
                    repeat: false
                    onTriggered: deleteBtn.confirmArmed = false
                  }
                  text: confirmArmed ? "CONFIRM?" : "DELETE"
                  variant: "danger"
                  armed: confirmArmed
                  onClicked: {
                    if (!confirmArmed) {
                      confirmArmed = true;
                      confirmResetTimer.restart();
                    } else {
                      confirmArmed = false;
                      confirmResetTimer.stop();
                      if (panelRoot) panelRoot.deleteHistoryItem(modelData.path);
                    }
                  }
                }
              }
            }
          }

          // 1px minimalist bottom hairline
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Commons.Style.spacing.sm
            anchors.rightMargin: Commons.Style.spacing.sm
            height: 1
            color: Commons.Util.alpha(Commons.Color.menu.border, 0.22)
          }
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
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
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
