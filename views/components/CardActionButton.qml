import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Ui

Button {
  id: control

  property string variant: "secondary" // "primary" | "secondary" | "danger"
  property bool armed: false

  fontSize: Commons.Style.font.caption
  Layout.preferredHeight: Commons.Style.space(20)
  verticalPadding: Commons.Style.space(1)
  horizontalPadding: Commons.Style.space(6)

  bordered: variant === "danger" && armed
  selected: false

  foreground: {
    if (variant === "primary") return Commons.Color.accent;
    if (variant === "danger") return Commons.Color.urgent;
    return Commons.Util.alpha(Commons.Color.foreground, 0.58);
  }

  accent: variant === "danger" ? Commons.Color.urgent : Commons.Color.accent
}
