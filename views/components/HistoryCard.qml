import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons as Commons
import qs.Ui

Rectangle {
  id: cardDelegate
  property var panelRoot: null
  property var itemData: ({})

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
      if (panelRoot && itemData) {
        panelRoot.restoreFromHistory(itemData.path, itemData.prompt, itemData.seed, itemData.ratio, itemData.negative_prompt, itemData.steps, itemData.loras);
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
        source: itemData && itemData.path ? ("file://" + encodeURI(itemData.path)) : ""
        sourceSize.width: Commons.Style.space(88) * 2
        sourceSize.height: Commons.Style.space(88) * 2
        smooth: true
        cache: true
        asynchronous: true
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Commons.Style.spacing.xxs

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
            text: (itemData && itemData.ratio ? String(itemData.ratio) : "LOCAL").toUpperCase()
            font.family: Commons.Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: Commons.Color.accent
          }
        }

        NsfwBadge {
          level: itemData && itemData.nsfw ? String(itemData.nsfw) : "None"
        }

        Text {
          text: (itemData && itemData.filename ? (itemData.filename + " · ") : "")
                + (itemData && itemData.size_mb ? (itemData.size_mb + " MB · ") : "")
                + (itemData && itemData.seed && itemData.seed > 0 ? ("Seed " + itemData.seed + " · ") : "")
                + (itemData && itemData.steps ? (itemData.steps + " steps") : "")
          textFormat: Text.PlainText
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          color: Commons.Util.alpha(Commons.Color.foreground, 0.55)
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Text {
        Layout.fillWidth: true
        text: (itemData && itemData.prompt) || "No prompt description"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        color: Commons.Color.foreground
      }

      Text {
        Layout.fillWidth: true
        text: "NEG: " + ((itemData && itemData.negative_prompt) || "")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 1
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Math.max(10, Commons.Style.font.caption * 0.9)
        color: Commons.Util.alpha(Commons.Color.foreground, 0.45)
        visible: Boolean(itemData && itemData.negative_prompt && itemData.negative_prompt.trim() !== "")
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Commons.Style.spacing.xs

        Item { Layout.fillWidth: true }

        CardActionButton {
          text: "RESTORE"
          variant: "primary"
          onClicked: {
            if (panelRoot && itemData) {
              panelRoot.restoreFromHistory(itemData.path, itemData.prompt, itemData.seed, itemData.ratio, itemData.negative_prompt, itemData.steps, itemData.loras);
              panelRoot.currentView = "studio";
            }
          }
        }

        CardActionButton {
          text: "COPY"
          variant: "secondary"
          onClicked: {
            if (panelRoot && itemData) panelRoot.copyTextToClipboard(itemData.prompt || "");
          }
        }

        CardActionButton {
          text: "BUFFER"
          variant: "secondary"
          onClicked: {
            if (panelRoot && itemData) {
              panelRoot.setReferenceImage(itemData.path);
              panelRoot.currentView = "studio";
            }
          }
        }

        CardActionButton {
          text: "VIEW"
          variant: "secondary"
          onClicked: if (panelRoot && itemData) panelRoot.openFullscreenViewer(itemData.path)
        }

        CardActionButton {
          text: "WALLPAPER"
          variant: "secondary"
          onClicked: if (panelRoot && itemData) panelRoot.setAsWallpaper(itemData.path)
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
              if (panelRoot && itemData) panelRoot.deleteHistoryItem(itemData.path);
            }
          }
        }
      }
    }
  }

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
