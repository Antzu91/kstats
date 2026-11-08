import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// Title row of a collapsible popup section; click, Enter or Space toggles it.
Controls.AbstractButton {
    id: header

    property string title
    property string trailingText
    property bool expanded: true
    property bool centered: false
    property color titleColor: Kirigami.Theme.textColor

    signal toggleRequested()

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    padding: 0
    Layout.fillWidth: true
    Accessible.role: Accessible.Button
    Accessible.name: header.title
    Accessible.description: header.expanded
        ? i18nc("@info:accessibility section state", "Expanded")
        : i18nc("@info:accessibility section state", "Collapsed")

    onClicked: header.toggleRequested()
    Keys.onReturnPressed: header.toggleRequested()
    Keys.onEnterPressed: header.toggleRequested()

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: header.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05) : "transparent"
        border.width: header.visualFocus ? 2 : 0
        border.color: Kirigami.Theme.focusColor
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing / 2

        Item {
            visible: header.centered
            Layout.fillWidth: true
        }

        Kirigami.Icon {
            source: header.expanded ? "arrow-down" : "arrow-right"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            color: Kirigami.Theme.disabledTextColor
        }

        Controls.Label {
            text: header.title
            color: header.titleColor
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: !header.centered
        }

        Item {
            visible: header.centered
            Layout.fillWidth: true
        }

        Controls.Label {
            visible: header.trailingText.length > 0
            text: header.trailingText
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }
}
