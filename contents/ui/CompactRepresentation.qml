import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "PanelPresentation.js" as PanelPresentation
import "." as Local

Item {
    id: compact

    required property var rootItem
    readonly property real horizontalPadding: Math.max(1, Kirigami.Units.smallSpacing / 2)
    readonly property real moduleSpacing: Math.max(1, Kirigami.Units.smallSpacing / 2)
    readonly property real innerSpacing: Math.max(1, Kirigami.Units.smallSpacing / 4)
    readonly property real minimumBarWidth: Kirigami.Units.gridUnit * 4
    readonly property real configuredBarLength: Number(Plasmoid.configuration.compactBarLength)
    readonly property bool hasConfiguredBarLength: configuredBarLength > 0
    readonly property real adaptiveBarLength: row.implicitWidth
    readonly property real fixedWidth: Math.max(minimumBarWidth, hasConfiguredBarLength ? configuredBarLength : adaptiveBarLength)
    readonly property real contentWidth: Math.max(0, hasConfiguredBarLength ? fixedWidth - horizontalPadding * 2 : fixedWidth)

    readonly property bool monochrome: Plasmoid.configuration.monochrome === true
    readonly property int labelFontSize: Number(Plasmoid.configuration.barLabelFontSize) || 0
    readonly property int valueFontSize: Number(Plasmoid.configuration.barValueFontSize) || 0
    readonly property var cpuParts: PanelPresentation.parts(PanelPresentation.presentation("cpu", Plasmoid.configuration.cpuPresentation))
    readonly property var memoryParts: PanelPresentation.parts(PanelPresentation.presentation("memory", Plasmoid.configuration.memoryPresentation))
    readonly property var gpuParts: PanelPresentation.parts(PanelPresentation.presentation("gpu", Plasmoid.configuration.gpuPresentation))
    readonly property var diskParts: PanelPresentation.parts(PanelPresentation.presentation("disk", Plasmoid.configuration.diskPresentation))
    readonly property var networkParts: PanelPresentation.networkParts(PanelPresentation.presentation("network", Plasmoid.configuration.networkPresentation))

    // Monochrome changes decoration only; values and N/A stay as text.
    function moduleColor(id) {
        return compact.monochrome ? Kirigami.Theme.textColor : Kirigami.Theme[compact.rootItem.modules.module(id).colorRole];
    }

    // Column of a module in the configured order; hidden modules leave no gap.
    function moduleColumn(id) {
        return Math.max(0, compact.rootItem.moduleOrder.indexOf(id));
    }

    function networkRateNumber(text) {
        const value = String(text).trim();
        const match = value.match(/^(.*\S)\s+(\S+\/s)$/);
        return match ? match[1] : value;
    }

    function networkRateUnit(text) {
        const value = String(text).trim();
        const match = value.match(/^(.*\S)\s+(\S+\/s)$/);
        return match ? match[2] : "";
    }

    Layout.minimumWidth: fixedWidth
    Layout.minimumHeight: Kirigami.Units.gridUnit
    Layout.preferredWidth: fixedWidth
    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
    Layout.maximumWidth: fixedWidth

    implicitWidth: fixedWidth
    implicitHeight: Layout.preferredHeight
    clip: true

    component ClickTarget: Item {
        id: target

        property int tabIndex: 0
        property color accentColor: Kirigami.Theme.highlightColor
        property string toolTipTitle: ""
        property string toolTipText: ""
        readonly property bool hovered: targetMouse.containsMouse
        default property alias content: contentRow.data
        readonly property real horizontalPadding: compact.horizontalPadding
        readonly property real fixedWidth: contentRow.implicitWidth + horizontalPadding * 2
        readonly property bool active: compact.rootItem.selectedTab === tabIndex && compact.rootItem.expanded

        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: fixedWidth
        Layout.preferredWidth: fixedWidth
        Layout.maximumWidth: fixedWidth
        Layout.preferredHeight: compact.height
        implicitWidth: fixedWidth
        implicitHeight: Layout.preferredHeight

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: target.active
                ? Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.16)
                : targetMouse.containsMouse
                    ? Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.10)
                    : "transparent"
            border.width: target.active ? 1 : 0
            border.color: Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.32)
        }

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: compact.innerSpacing
        }

        // The tooltip area must be an ancestor of the MouseArea to receive hover.
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: target.toolTipTitle
            subText: target.toolTipText
            location: Plasmoid.location
            active: !compact.rootItem.expanded

            MouseArea {
                id: targetMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: compact.rootItem.toggleTab(target.tabIndex)
            }
        }
    }

    Local.PanelToolTips {
        id: toolTips

        rootItem: compact.rootItem
        memoryDemand: memoryTarget.hovered
    }

    // With every module hidden the widget must still open; show its icon.
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        visible: !compact.rootItem.panelModulesVisible
        source: "utilities-system-monitor"
        active: fallbackMouse.containsMouse

        MouseArea {
            id: fallbackMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: compact.rootItem.expanded = !compact.rootItem.expanded
        }
    }

    // A one-row grid so each module sits in its configured column.
    GridLayout {
        id: row

        readonly property real fitScale: Math.min(1, compact.contentWidth / Math.max(1, implicitWidth))

        x: (compact.width - row.implicitWidth * fitScale) / 2
        y: (compact.height - row.implicitHeight * fitScale) / 2
        height: parent.height
        scale: fitScale
        transformOrigin: Item.TopLeft
        rows: 1
        rowSpacing: 0
        columnSpacing: compact.moduleSpacing

        ClickTarget {
            visible: Plasmoid.configuration.showCpu
            Layout.row: 0
            Layout.column: compact.moduleColumn("cpu")
            toolTipTitle: toolTips.cpuTitle
            toolTipText: toolTips.cpuText
            accentColor: compact.moduleColor("cpu")
            tabIndex: 0

            Local.BarStat {
                label: i18nc("@label", "CPU")
                value: rootItem.cpuUsageMonitor.text
                percent: rootItem.cpuUsageMonitor.percent ?? 0
                dataAvailable: rootItem.cpuUsageMonitor.available
                samples: rootItem.cpuUsageSamples
                windowDuration: rootItem.historyWindowDuration
                now: rootItem.historyNow
                accentColor: compact.moduleColor("cpu")
                showLabel: Plasmoid.configuration.cpuShowLabel !== false
                meterMode: compact.cpuParts.meter
                showValue: compact.cpuParts.value
                labelFontSize: compact.labelFontSize
                valueFontSize: compact.valueFontSize
            }
        }

        ClickTarget {
            id: memoryTarget

            visible: Plasmoid.configuration.showMemory
            Layout.row: 0
            Layout.column: compact.moduleColumn("memory")
            toolTipTitle: toolTips.memoryTitle
            toolTipText: toolTips.memoryText
            accentColor: compact.moduleColor("memory")
            tabIndex: 1

            Local.BarStat {
                label: i18nc("@label", "MEM")
                value: rootItem.memoryUsageMonitor.text
                percent: rootItem.memoryUsageMonitor.percent ?? 0
                dataAvailable: rootItem.memoryUsageMonitor.available
                samples: rootItem.memoryUsageSamples
                windowDuration: rootItem.historyWindowDuration
                now: rootItem.historyNow
                accentColor: compact.moduleColor("memory")
                showLabel: Plasmoid.configuration.memoryShowLabel !== false
                meterMode: compact.memoryParts.meter
                showValue: compact.memoryParts.value
                labelFontSize: compact.labelFontSize
                valueFontSize: compact.valueFontSize
            }
        }

        ClickTarget {
            visible: Plasmoid.configuration.showGpu
            Layout.row: 0
            Layout.column: compact.moduleColumn("gpu")
            toolTipTitle: toolTips.gpuTitle
            toolTipText: toolTips.gpuText
            accentColor: compact.moduleColor("gpu")
            tabIndex: 2

            Local.BarStat {
                label: i18nc("@label", "GPU")
                value: rootItem.gpuUsageMonitor.available
                    ? i18nc("@label GPU utilization percentage", "%1%", Math.round(rootItem.gpuUsageMonitor.percent))
                    : rootItem.gpuUsageMonitor.text
                valueWidthSample: i18nc("@label GPU utilization percentage", "%1%", 100)
                percent: rootItem.gpuUsageMonitor.percent ?? 0
                dataAvailable: rootItem.gpuUsageMonitor.available
                samples: rootItem.gpuUsageSamples
                windowDuration: rootItem.historyWindowDuration
                now: rootItem.historyNow
                accentColor: compact.moduleColor("gpu")
                showLabel: Plasmoid.configuration.gpuShowLabel !== false
                meterMode: compact.gpuParts.meter
                showValue: compact.gpuParts.value
                labelFontSize: compact.labelFontSize
                valueFontSize: compact.valueFontSize
            }
        }

        ClickTarget {
            visible: Plasmoid.configuration.showDisk
            Layout.row: 0
            Layout.column: compact.moduleColumn("disk")
            toolTipTitle: toolTips.diskTitle
            toolTipText: toolTips.diskText
            accentColor: compact.moduleColor("disk")
            tabIndex: 4

            Local.BarStat {
                label: i18nc("@label", "DSK")
                value: rootItem.diskUsageMonitor.text
                percent: rootItem.diskUsageMonitor.percent ?? 0
                dataAvailable: rootItem.diskUsageMonitor.available
                samples: rootItem.diskUsageSamples
                windowDuration: rootItem.historyWindowDuration
                now: rootItem.historyNow
                accentColor: compact.moduleColor("disk")
                showLabel: Plasmoid.configuration.diskShowLabel !== false
                meterMode: compact.diskParts.meter
                showValue: compact.diskParts.value
                labelFontSize: compact.labelFontSize
                valueFontSize: compact.valueFontSize
            }
        }

        ClickTarget {
            visible: Plasmoid.configuration.showNetwork
            Layout.row: 0
            Layout.column: compact.moduleColumn("network")
            toolTipTitle: toolTips.networkTitle
            toolTipText: toolTips.networkText
            accentColor: compact.moduleColor("network")
            tabIndex: 3

            Controls.Label {
                id: networkLabel

                visible: Plasmoid.configuration.networkShowLabel !== false
                text: i18nc("@label", "NET")
                color: compact.moduleColor("network")
                elide: Text.ElideRight
                font.pixelSize: compact.labelFontSize > 0 ? compact.labelFontSize : Kirigami.Theme.smallFont.pixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 1.25)
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 1.25)
                Layout.maximumWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 1.25)
            }

            // Upload above the baseline, download below, in the configured window.
            Rectangle {
                visible: compact.networkParts.graph
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: Math.ceil(Kirigami.Units.gridUnit * 2.2)
                Layout.preferredWidth: Math.ceil(Kirigami.Units.gridUnit * 2.2)
                Layout.maximumWidth: Math.ceil(Kirigami.Units.gridUnit * 2.2)
                // Same height rule as the BarStat meters beside it.
                Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 0.9, networkLabel.implicitHeight - Kirigami.Units.smallSpacing)
                radius: 2
                color: Qt.rgba(0, 0, 0, 0.86)
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.32)

                Local.NetworkHistoryChart {
                    anchors.fill: parent
                    anchors.margins: 2
                    showScale: false
                    uploadSamples: compact.rootItem.networkUploadSamples
                    downloadSamples: compact.rootItem.networkDownloadSamples
                    windowDuration: compact.rootItem.historyWindowDuration
                    now: compact.rootItem.historyNow
                    uploadColor: compact.monochrome ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                    downloadColor: compact.monochrome ? Kirigami.Theme.textColor : Kirigami.Theme.focusColor
                }
            }

            ColumnLayout {
                id: networkRates

                visible: compact.networkParts.numbers

                readonly property real rateFontSize: Math.max(7, Kirigami.Theme.smallFont.pixelSize - 2)
                readonly property real arrowWidth: Math.ceil(networkArrowMetrics.width)
                readonly property real valueGap: Math.max(2, compact.innerSpacing)
                readonly property real unitGap: Math.max(2, compact.innerSpacing)
                readonly property real valuePadding: Math.max(2, Kirigami.Units.smallSpacing / 2)
                readonly property real valueWidth: Math.ceil(networkValueMetrics.width) + valuePadding
                readonly property real unitWidth: Math.ceil(networkUnitMetrics.width)
                readonly property real valueSlotWidth: valueWidth + valueGap
                readonly property real unitSlotWidth: unitWidth + unitGap
                readonly property real fixedWidth: arrowWidth + valueSlotWidth + unitSlotWidth
                readonly property real rowHeight: rateFontSize + 1

                spacing: 1
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: fixedWidth
                Layout.preferredWidth: fixedWidth
                Layout.maximumWidth: fixedWidth
                Layout.preferredHeight: rowHeight * 2 + spacing

                TextMetrics {
                    id: networkArrowMetrics

                    font.pixelSize: networkRates.rateFontSize
                    font.weight: Font.DemiBold
                    text: i18nc("@label upload", "↑")
                }

                TextMetrics {
                    id: networkValueMetrics

                    font.pixelSize: networkRates.rateFontSize
                    text: "999.9"
                }

                TextMetrics {
                    id: networkUnitMetrics

                    font.pixelSize: networkRates.rateFontSize
                    text: "MiB/s"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: networkRates.rowHeight
                    spacing: 0

                    Controls.Label {
                        text: i18nc("@label upload", "↑")
                        color: compact.moduleColor("network")
                        font.pixelSize: networkRates.rateFontSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        Layout.minimumWidth: networkRates.arrowWidth
                        Layout.preferredWidth: networkRates.arrowWidth
                        Layout.maximumWidth: networkRates.arrowWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }

                    Controls.Label {
                        text: compact.networkRateNumber(rootItem.networkUploadMonitor.text)
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        font.pixelSize: networkRates.rateFontSize
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: networkRates.valueGap
                        Layout.minimumWidth: networkRates.valueSlotWidth
                        Layout.preferredWidth: networkRates.valueSlotWidth
                        Layout.maximumWidth: networkRates.valueSlotWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }

                    Controls.Label {
                        text: compact.networkRateUnit(rootItem.networkUploadMonitor.text)
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        font.pixelSize: networkRates.rateFontSize
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: networkRates.unitGap
                        Layout.minimumWidth: networkRates.unitSlotWidth
                        Layout.preferredWidth: networkRates.unitSlotWidth
                        Layout.maximumWidth: networkRates.unitSlotWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: networkRates.rowHeight
                    spacing: 0

                    Controls.Label {
                        text: i18nc("@label download", "↓")
                        color: compact.moduleColor("network")
                        font.pixelSize: networkRates.rateFontSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        Layout.minimumWidth: networkRates.arrowWidth
                        Layout.preferredWidth: networkRates.arrowWidth
                        Layout.maximumWidth: networkRates.arrowWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }

                    Controls.Label {
                        text: compact.networkRateNumber(rootItem.networkDownloadMonitor.text)
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        font.pixelSize: networkRates.rateFontSize
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: networkRates.valueGap
                        Layout.minimumWidth: networkRates.valueSlotWidth
                        Layout.preferredWidth: networkRates.valueSlotWidth
                        Layout.maximumWidth: networkRates.valueSlotWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }

                    Controls.Label {
                        text: compact.networkRateUnit(rootItem.networkDownloadMonitor.text)
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        font.pixelSize: networkRates.rateFontSize
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: networkRates.unitGap
                        Layout.minimumWidth: networkRates.unitSlotWidth
                        Layout.preferredWidth: networkRates.unitSlotWidth
                        Layout.maximumWidth: networkRates.unitSlotWidth
                        Layout.preferredHeight: networkRates.rowHeight
                    }
                }
            }
        }
    }
}
