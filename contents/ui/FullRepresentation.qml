import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "ModuleCatalog.js" as ModuleCatalog
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

    // Moves through tabs in the configured module order, wrapping around.
    function cycleTab(delta) {
        var order = full.rootItem.moduleOrder;
        var index = order.indexOf(ModuleCatalog.moduleForPage(full.currentTab));
        var next = order[((index < 0 ? 0 : index) + delta + order.length) % order.length];
        full.rootItem.selectTab(ModuleCatalog.pageIndex(next));
    }

    function focusCurrentTab() {
        for (var i = 0; i < tabRepeater.count; ++i) {
            var pill = tabRepeater.itemAt(i) as Local.TabPill;
            if (pill && pill.checked) {
                pill.forceActiveFocus(Qt.TabFocusReason);
                return;
            }
        }
    }

    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: full.cycleTab(1)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
        onActivated: full.cycleTab(-1)
    }

    component PageScroll: Controls.ScrollView {
        contentWidth: availableWidth
        clip: true
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: i18n("KStats")
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Controls.ComboBox {
                model: [i18nc("@item:inlistbox history duration", "1 min"),
                    i18nc("@item:inlistbox history duration", "5 min"),
                    i18nc("@item:inlistbox history duration", "15 min")]
                currentIndex: [1, 5, 15].indexOf(full.rootItem.historyWindowMinutes)
                onActivated: full.rootItem.setHistoryWindowMinutes([1, 5, 15][currentIndex])
                Accessible.name: i18nc("@label", "History window")
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

                // Follows the configured module order, including modules hidden
                // from the panel; each pill resolves its page from the module ID.
                Repeater {
                    id: tabRepeater
                    model: full.rootItem.moduleOrder

                    delegate: Local.TabPill {
                        required property string modelData
                        readonly property var info: full.rootItem.modules.module(modelData)
                        readonly property int pageIndex: ModuleCatalog.pageIndex(modelData)

                        checked: full.currentTab === pageIndex
                        iconName: info.icon
                        accentColor: Kirigami.Theme[info.colorRole]
                        text: info.tabLabel
                        onClicked: full.rootItem.selectTab(pageIndex)
                        Keys.onLeftPressed: {
                            full.cycleTab(-1);
                            full.focusCurrentTab();
                        }
                        Keys.onRightPressed: {
                            full.cycleTab(1);
                            full.focusCurrentTab();
                        }
                    }
                }
            }
        }

        StackLayout {
            currentIndex: full.currentTab
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Pages scroll when the popup is short or fonts are large; the
            // header and tabs above stay reachable. GPU scrolls internally.
            PageScroll {
                id: cpuScroll
                objectName: "cpuScroll"

                Local.CpuPage {
                    rootItem: full.rootItem
                    width: cpuScroll.availableWidth
                    height: Math.max(implicitHeight, cpuScroll.availableHeight)
                }
            }

            PageScroll {
                id: ramScroll
                objectName: "ramScroll"

                Local.RamPage {
                    rootItem: full.rootItem
                    width: ramScroll.availableWidth
                    height: Math.max(implicitHeight, ramScroll.availableHeight)
                }
            }

            Local.GpuPage {
                rootItem: full.rootItem
            }

            PageScroll {
                id: networkScroll
                objectName: "networkScroll"

                Local.NetworkPage {
                    rootItem: full.rootItem
                    width: networkScroll.availableWidth
                    height: Math.max(implicitHeight, networkScroll.availableHeight)
                }
            }

            PageScroll {
                id: diskScroll
                objectName: "diskScroll"

                Local.DiskPage {
                    rootItem: full.rootItem
                    width: diskScroll.availableWidth
                    height: Math.max(implicitHeight, diskScroll.availableHeight)
                }
            }
        }
    }
}
