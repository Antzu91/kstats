import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Controls.AbstractButton {
    id: tab

    property string iconName
    property color accentColor: Kirigami.Theme.highlightColor

    hoverEnabled: true
    // Selection is driven by the owner; a checkable pill would un-highlight
    // itself when the current tab is clicked again.
    checkable: false
    focusPolicy: Qt.StrongFocus
    implicitHeight: Kirigami.Units.gridUnit * 2
    Layout.fillWidth: true
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked

    Keys.onReturnPressed: tab.clicked()
    Keys.onEnterPressed: tab.clicked()

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: tab.checked
            ? Qt.rgba(tab.accentColor.r, tab.accentColor.g, tab.accentColor.b, 0.16)
            : tab.hovered
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                : "transparent"
        border.width: tab.visualFocus ? 2 : tab.checked ? 1 : 0
        border.color: tab.visualFocus ? Kirigami.Theme.focusColor
            : Qt.rgba(tab.accentColor.r, tab.accentColor.g, tab.accentColor.b, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing / 2

        Item {
            Layout.fillWidth: true
        }

        Kirigami.Icon {
            source: tab.iconName
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            color: tab.checked ? tab.accentColor : Kirigami.Theme.disabledTextColor
        }

        Controls.Label {
            text: tab.text
            color: tab.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: tab.checked ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
