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
      text: panelRoot && panelRoot.currentLang === "cs" ? "HISTORIE GENEROVÁNÍ & ARCHIV (~/Pictures/Qwen-Image/)" : "GENERATION HISTORY & SAVED ARCHIVE (~/Pictures/Qwen-Image/)"
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

        delegate: Rectangle {
          width: historyList.width - Commons.Style.spacing.sm
          height: Commons.Style.space(125)
          color: Commons.Color.menu.background
          border.color: Commons.Color.menu.border
          border.width: 1
          radius: Commons.Style.cornerRadius

          RowLayout {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.xs
            spacing: Commons.Style.spacing.sm

            // Thumbnail (+50% enlarged from 80px to 120px)
            Rectangle {
              Layout.preferredWidth: Commons.Style.space(120)
              Layout.fillHeight: true
              color: Commons.Color.background
              radius: Commons.Style.cornerRadius
              clip: true

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
            }

            // Meta Info
            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: Commons.Style.spacing.xxs

              Text {
                text: modelData.filename || ""
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: Commons.Color.accent
                elide: Text.ElideMiddle
                Layout.preferredWidth: 0
                Layout.fillWidth: true
              }

              Text {
                text: modelData.prompt || "No prompt"
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Color.foreground
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                Layout.preferredWidth: 0
                Layout.fillWidth: true
              }

              Text {
                visible: !!modelData.negative_prompt && modelData.negative_prompt.trim() !== ""
                text: "// NEG: " + (modelData.negative_prompt || "")
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: Math.max(10, Commons.Style.font.caption * 0.9)
                color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.preferredWidth: 0
                Layout.fillWidth: true
              }

              Text {
                text: (modelData.size_mb ? (modelData.size_mb + " MB") : "")
                      + (modelData.seed && modelData.seed > 0 ? (" // SEED " + modelData.seed) : "")
                      + (modelData.steps ? (" // " + modelData.steps + " STEPS") : "")
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
                Layout.fillWidth: true
              }
            }

            // Action Buttons for this item
            ColumnLayout {
              Layout.preferredWidth: Commons.Style.space(240)
              Layout.alignment: Qt.AlignVCenter
              spacing: Commons.Style.spacing.xxs

              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xxs

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "OBNOVIT PARAMETRY" : "RESTORE PARAMS"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  selected: true
                  Layout.preferredWidth: 0
                  Layout.fillWidth: true
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio, modelData.negative_prompt);
                      panelRoot.currentView = "studio";
                    }
                  }
                }

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "DO BUFFERU" : "COPY TO BUFFER"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  Layout.preferredWidth: 0
                  Layout.fillWidth: true
                  onClicked: {
                    if (panelRoot) {
                      panelRoot.setReferenceImage(modelData.path);
                      panelRoot.currentView = "studio";
                    }
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.spacing.xxs

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "TAPETA" : "WALLPAPER"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  Layout.preferredWidth: 0
                  Layout.fillWidth: true
                  onClicked: if (panelRoot) panelRoot.setAsWallpaper(modelData.path)
                }

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "ZOBRAZIT" : "VIEW"
                  fontSize: Commons.Style.font.caption
                  bordered: true
                  Layout.preferredWidth: 0
                  Layout.fillWidth: true
                  onClicked: if (panelRoot) panelRoot.openFullscreenViewer(modelData.path)
                }
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
            text: panelRoot && panelRoot.currentLang === "cs"
              ? "Prohledávám galerii ~/Pictures/Qwen-Image/..."
              : "Scanning ~/Pictures/Qwen-Image/ gallery..."
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            font.bold: true
            color: Commons.Color.accent
          }

          Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: panelRoot && panelRoot.currentLang === "cs"
              ? "Načítám metadata, prompty a náhledy..."
              : "Loading metadata, prompts and previews..."
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
          text: panelRoot && panelRoot.currentLang === "cs" ? "Žádné vygenerované obrázky v ~/Pictures/Qwen-Image/" : "No generated images found in ~/Pictures/Qwen-Image/"
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
        text: panelRoot && panelRoot.currentLang === "cs" ? "OTEVŘÍT SLOŽKU" : "OPEN PICTURES FOLDER"
        bordered: true
        onClicked: {
          if (panelRoot) panelRoot.openPicturesFolder();
        }
      }

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "OBNOVIT" : "REFRESH"
        bordered: true
        onClicked: root.refreshHistory()
      }

      Item { Layout.fillWidth: true }

      Button {
        text: panelRoot && panelRoot.currentLang === "cs" ? "ZPĚT DO STUDIA (ESC)" : "BACK TO STUDIO (ESC)"
        bordered: true
        active: true
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
