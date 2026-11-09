import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

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
    spacing: Commons.Style.spacing.md

    PanelSectionHeader {
      text: "GENERATION HISTORY & SAVED ARCHIVE (~/Pictures/Qwen-Image/)"
    }

    // List of saved images
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Commons.Color.background
      border.color: Commons.Color.menu.border
      border.width: 1
      radius: Commons.Style.cornerRadius
      clip: true

      ListView {
        id: historyList
        anchors.fill: parent
        anchors.margins: Commons.Style.spacing.xs
        spacing: Commons.Style.spacing.sm
        model: panelRoot ? panelRoot.historyModel : []
        clip: true

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        delegate: Rectangle {
          id: cardDelegate
          x: Math.round((historyList.width - width) / 2)
          width: historyList.width - Commons.Style.spacing.sm * 2
          implicitHeight: Math.max(Commons.Style.space(130), rowContent.implicitHeight + Commons.Style.spacing.sm * 2)
          height: implicitHeight
          color: cardArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.06) : Commons.Color.menu.background
          border.color: cardArea.containsMouse ? Commons.Color.accent : Commons.Color.menu.border
          border.width: 1
          radius: Commons.Style.cornerRadius

          MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 0
            onClicked: {
              if (panelRoot) {
                panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio, modelData.negative_prompt);
                panelRoot.currentView = "studio";
              }
            }
            onDoubleClicked: {
              if (panelRoot) panelRoot.openFullscreenViewer(modelData.path);
            }
          }

          RowLayout {
            id: rowContent
            z: 1
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.sm
            spacing: Commons.Style.spacing.md

            // 1. Thumbnail Preview Box
            Rectangle {
              id: previewBox
              Layout.preferredWidth: Commons.Style.space(120)
              Layout.fillHeight: true
              Layout.minimumHeight: Commons.Style.space(110)
              color: Commons.Color.background
              radius: Commons.Style.cornerRadius
              clip: true
              border.color: Commons.Color.menu.border
              border.width: 1

              Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: modelData.path ? ("file://" + encodeURI(modelData.path)) : ""
                sourceSize.width: Commons.Style.space(120) * 2
                sourceSize.height: Commons.Style.space(125) * 2
                smooth: true
                cache: true
                asynchronous: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (panelRoot) panelRoot.openFullscreenViewer(modelData.path)
              }
            }

            // 2. Metadata, Prompt description & Action Buttons Header (Inspiration layout)
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Commons.Style.spacing.xs

              // Top row: Badge + Filename/Metadata + Action Buttons
              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xs

                Rectangle {
                  height: Commons.Style.space(18)
                  implicitWidth: tagText.implicitWidth + Commons.Style.spacing.xs * 2
                  color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15)
                  border.color: Commons.Color.accent
                  border.width: 1
                  radius: Commons.Style.cornerRadius

                  Text {
                    id: tagText
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: "SAVED"
                    font.family: Commons.Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Commons.Color.accent
                  }
                }

                Text {
                  text: (modelData.filename ? (modelData.filename + " | ") : "")
                        + (modelData.size_mb ? (modelData.size_mb + " MB | ") : "")
                        + (modelData.seed && modelData.seed > 0 ? ("SEED: " + modelData.seed + " | ") : "")
                        + (modelData.steps ? (modelData.steps + " STEPS") : "")
                  textFormat: Text.PlainText
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
                  font.bold: true
                  color: Commons.Color.accent
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Button {
                  text: "RESTORE"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  selected: true
                  foreground: "#4ade80"
                  accent: "#4ade80"
                  Layout.preferredHeight: Commons.Style.space(20)
                  verticalPadding: Commons.Style.space(1)
                  horizontalPadding: Commons.Style.space(6)
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio, modelData.negative_prompt);
                      panelRoot.currentView = "studio";
                    }
                  }
                }

                Button {
                  text: "BUFFER"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  foreground: Commons.Color.muted
                  accent: Commons.Color.accent
                  Layout.preferredHeight: Commons.Style.space(20)
                  verticalPadding: Commons.Style.space(1)
                  horizontalPadding: Commons.Style.space(6)
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.setReferenceImage(modelData.path);
                      panelRoot.currentView = "studio";
                    }
                  }
                }

                Button {
                  text: "WALLPAPER"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  foreground: Commons.Color.muted
                  accent: Commons.Color.accent
                  Layout.preferredHeight: Commons.Style.space(20)
                  verticalPadding: Commons.Style.space(1)
                  horizontalPadding: Commons.Style.space(6)
                  onClicked: if (panelRoot) panelRoot.setAsWallpaper(modelData.path)
                }

                Button {
                  text: "VIEW"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  foreground: Commons.Color.muted
                  accent: Commons.Color.accent
                  Layout.preferredHeight: Commons.Style.space(20)
                  verticalPadding: Commons.Style.space(1)
                  horizontalPadding: Commons.Style.space(6)
                  onClicked: if (panelRoot) panelRoot.openFullscreenViewer(modelData.path)
                }
              }

              // Main Prompt Text
              Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
                visible: !!modelData.negative_prompt && modelData.negative_prompt.trim() !== ""
              }
            }
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

    // Bottom Navigation Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.sm

      Button {
        text: "OPEN FOLDER"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onClicked: {
          if (panelRoot) panelRoot.openPicturesFolder();
        }
      }

      Button {
        text: "REFRESH"
        fontSize: Commons.Style.font.caption
        bordered: true
        Layout.preferredHeight: Commons.Style.space(20)
        verticalPadding: Commons.Style.space(1)
        onClicked: root.refreshHistory()
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

  Component.onCompleted: {
    if (panelRoot && (!panelRoot.historyModel || panelRoot.historyModel.length === 0)) {
      refreshHistory();
    }
  }
}
