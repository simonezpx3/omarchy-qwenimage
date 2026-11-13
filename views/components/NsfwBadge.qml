import QtQuick
import qs.Commons as Commons

Rectangle {
  id: root

  property string level: "None"

  readonly property string normalizedLevel: String(level || "none").trim().toLowerCase()
  readonly property bool isNsfw: normalizedLevel !== "none"
    && normalizedLevel !== "false"
    && normalizedLevel !== "0"
    && normalizedLevel !== "1"
    && normalizedLevel !== ""

  visible: isNsfw
  height: Commons.Style.space(16)
  implicitWidth: badgeText.implicitWidth + Commons.Style.spacing.xs * 2
  color: Commons.Util.alpha(Commons.Color.urgent, 0.12)
  border.width: 0
  radius: Commons.Style.cornerRadius

  Text {
    id: badgeText
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: "NSFW"
    font.family: Commons.Style.font.family
    font.pixelSize: 10
    font.bold: true
    color: Commons.Color.urgent
  }
}
