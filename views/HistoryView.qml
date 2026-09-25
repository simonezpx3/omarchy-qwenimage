import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: root

  property var panelRoot: null

  function refreshHistory() {
    if (panelRoot) {
      panelRoot.fetchHistory();
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.md

    PanelSectionHeader {
      text: panelRoot && panelRoot.currentLang === "cs" ? "HISTORIE GENEROVÁNÍ & ARCHIV (~/Pictures/Qwen-Image/)" : "GENERATION HISTORY & SAVED ARCHIVE (~/Pictures/Qwen-Image/)"
    }

    // List of saved images
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.background
      border.color: Color.menu.border
      border.width: 1
      radius: Style.cornerRadius
      clip: true

      ListView {
        id: historyList
        anchors.fill: parent
        anchors.margins: Style.spacing.xs
        spacing: Style.spacing.sm
        model: panelRoot ? panelRoot.historyModel : []

        delegate: Rectangle {
          width: historyList.width - Style.spacing.sm
          height: Style.space(125)
          color: Color.menu.background
          border.color: Color.menu.border
          border.width: 1
          radius: Style.cornerRadius

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.xs
            spacing: Style.spacing.sm

            // Thumbnail (+50% enlarged from 80px to 120px)
            Rectangle {
              Layout.preferredWidth: Style.space(120)
              Layout.fillHeight: true
              color: Color.background
              radius: Style.cornerRadius
              clip: true

              Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: "file://" + modelData.path
                cache: true
                asynchronous: true
              }
            }

            // Meta Info
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.spacing.xxs

              Text {
                text: modelData.filename || ""
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.accent
                elide: Text.ElideMiddle
                Layout.fillWidth: true
              }

              Text {
                text: modelData.prompt || "No prompt"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }

              Text {
                text: (modelData.timestamp || "") + " | " + (modelData.size_mb || "0") + " MB"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.foreground, 1.8)
              }
            }

            // Action Buttons for this item
            ColumnLayout {
              Layout.preferredWidth: Style.space(160)
              spacing: Style.spacing.xxs

              Button {
                text: panelRoot && panelRoot.currentLang === "cs" ? "OBNOVIT PARAMETRY" : "RESTORE PARAMS"
                fontSize: Style.font.caption
                bordered: true
                selected: true
                Layout.fillWidth: true
                onClicked: {
                  if (panelRoot) {
                    panelRoot.restoreFromHistory(modelData.path, modelData.prompt, modelData.seed, modelData.ratio);
                    panelRoot.currentView = "studio";
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.xxs

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "TAPETA" : "WALLPAPER"
                  fontSize: Style.font.caption
                  bordered: true
                  Layout.fillWidth: true
                  onClicked: if (panelRoot) panelRoot.setAsWallpaper(modelData.path)
                }

                Button {
                  text: panelRoot && panelRoot.currentLang === "cs" ? "ZOBRAZIT" : "VIEW"
                  fontSize: Style.font.caption
                  bordered: true
                  Layout.fillWidth: true
                  onClicked: if (panelRoot) panelRoot.openImageViewer(modelData.path)
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: historyList.count === 0
          text: panelRoot && panelRoot.currentLang === "cs" ? "Žádné vygenerované obrázky v ~/Pictures/Qwen-Image/" : "No generated images found in ~/Pictures/Qwen-Image/"
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Qt.darker(Color.foreground, 1.8)
        }
      }
    }

    PanelSeparator { Layout.fillWidth: true }

    // Bottom Navigation Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

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
    refreshHistory();
  }
}
