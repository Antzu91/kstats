import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "." as Local

Controls.Pane {
    id: full

    required property var rootItem
    readonly property int currentTab: rootItem.selectedTab

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 27
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 38

    padding: Kirigami.Units.largeSpacing

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Controls.Label {
                    text: i18n("KStats")
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Controls.Label {
                    text: i18nc("@label", "Live system stats")
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    Layout.fillWidth: true
                }
            }

            Controls.ToolButton {
                icon.name: "utilities-system-monitor"
                text: i18nc("@action", "Open System Monitor")
                display: Controls.AbstractButton.IconOnly
                onClicked: full.rootItem.openSystemMonitor()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.4
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.055)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing / 2
                spacing: Kirigami.Units.smallSpacing / 2

                Repeater {
                    model: full.rootItem.modules.ordered

                    Local.TabPill {
                        required property var modelData
                        checked: full.currentTab === modelData.tabId
                        iconName: modelData.icon
                        accentColor: modelData.color
                        text: modelData.label
                        onClicked: full.rootItem.selectTab(modelData.tabId)
                    }
                }
            }
        }

        StackLayout {
            currentIndex: full.currentTab
            Layout.fillWidth: true
            Layout.fillHeight: true

            Local.CpuPage {
                rootItem: full.rootItem
            }

            Local.RamPage {
                rootItem: full.rootItem
            }

            Local.GpuPage {
                rootItem: full.rootItem
            }

            Local.NetworkPage {
                rootItem: full.rootItem
            }

            Local.DiskPage {
                rootItem: full.rootItem
            }
        }
    }
}
