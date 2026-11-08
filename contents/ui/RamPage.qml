import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "." as Local

Item {
    id: page

    required property var rootItem
    readonly property bool active: rootItem.memoryDetailsVisible
    property int generation: 0
    property bool inFlight: false
    property var memoryInfo: unavailableMemoryInfo()
    // The gauge shows the panel's configured reading. /proc/meminfo only supplies
    // byte details; its used value (MemTotal - MemAvailable) matches the default
    // memory/physical/usedPercent definition, so name any custom gauge source.
    readonly property string defaultSensorId: "memory/physical/usedPercent"
    readonly property string gaugeSensorId: rootItem.memoryUsageMonitor.sensorId
    readonly property bool customGaugeSensor: gaugeSensorId.length > 0 && gaugeSensorId !== defaultSensorId

    clip: true
    implicitHeight: pageContent.implicitHeight
    Layout.fillWidth: true
    Layout.fillHeight: true

    function value(values, key) {
        return key in values ? values[key] : 0;
    }

    function unavailableMemoryInfo() {
        var missing = i18nc("@info:status", "N/A");
        return {
            valid: false,
            totalText: missing,
            usedText: missing,
            availableText: missing,
            appText: missing,
            cacheText: missing,
            kernelText: missing,
            compressedText: missing,
            swapText: missing
        };
    }

    function formatKiB(kib) {
        var bytes = Math.max(0, Number(kib) || 0) * 1024;
        var gib = bytes / 1073741824;
        if (gib >= 1) {
            return i18nc("@label memory in gigabytes", "%1 GB", gib.toFixed(gib >= 10 ? 1 : 2));
        }

        return i18nc("@label memory in megabytes", "%1 MB", Math.round(bytes / 1048576));
    }

    function refreshMemory() {
        if (!active || inFlight) {
            return;
        }
        var requestGeneration = generation;
        inFlight = true;
        meminfoCommand.exec("cat /proc/meminfo", function(result) {
            page.inFlight = false;
            if (!page.active || requestGeneration !== page.generation) {
                if (page.active) {
                    Qt.callLater(page.refreshMemory);
                }
                return;
            }
            if (result.exitCode !== 0) {
                page.memoryInfo = page.unavailableMemoryInfo();
                return;
            }

            var values = {};
            var lines = result.stdout.split(/\n/);
            for (var i = 0; i < lines.length; i++) {
                var match = lines[i].match(/^([^:]+):\s+(\d+)/);
                if (match) {
                    values[match[1]] = Number(match[2]);
                }
            }

            var total = page.value(values, "MemTotal");
            var available = page.value(values, "MemAvailable");
            if (available <= 0) {
                available = page.value(values, "MemFree") + page.value(values, "Buffers") + page.value(values, "Cached");
            }

            var used = Math.max(0, total - available);
            var app = page.value(values, "AnonPages") + page.value(values, "Shmem");
            if (app <= 0) {
                app = page.value(values, "Active(anon)") + page.value(values, "Inactive(anon)");
            }

            var pageCache = Math.max(0,
                page.value(values, "Cached")
                    + page.value(values, "Buffers")
                    + page.value(values, "SReclaimable")
                    - page.value(values, "Shmem"));
            var unreclaimableSlab = page.value(values, "SUnreclaim");
            if (unreclaimableSlab <= 0) {
                unreclaimableSlab = Math.max(0, page.value(values, "Slab") - page.value(values, "SReclaimable"));
            }

            var kernel = unreclaimableSlab
                + page.value(values, "KernelStack")
                + page.value(values, "PageTables")
                + page.value(values, "SecPageTables")
                + page.value(values, "VmallocUsed")
                + page.value(values, "Percpu")
                + page.value(values, "Unevictable");
            var compressed = page.value(values, "Zswap");
            var swapTotal = page.value(values, "SwapTotal");
            var swapFree = page.value(values, "SwapFree");
            var swapUsed = Math.max(0, swapTotal - swapFree);
            if (total <= 0) {
                page.memoryInfo = page.unavailableMemoryInfo();
                return;
            }

            page.memoryInfo = {
                valid: true,
                totalText: page.formatKiB(total),
                usedText: page.formatKiB(used),
                availableText: page.formatKiB(available),
                appText: page.formatKiB(app),
                cacheText: page.formatKiB(pageCache),
                kernelText: page.formatKiB(kernel),
                compressedText: page.formatKiB(compressed),
                swapText: swapTotal > 0
                    ? i18nc("@label swap used over total", "%1 / %2", page.formatKiB(swapUsed), page.formatKiB(swapTotal))
                    : i18nc("@info:status", "Off")
            };
        });
    }

    component MemoryDetailRow: RowLayout {
        property string label: ""
        property string value: ""
        property color markerColor: Kirigami.Theme.focusColor
        property bool showMarker: true

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 2
            opacity: showMarker ? 1 : 0
            color: markerColor
        }

        Controls.Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Controls.Label {
            text: value
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    onActiveChanged: {
        generation++;
        if (active) {
            refreshMemory();
        }
    }
    Component.onCompleted: if (active) { refreshMemory(); }

    Timer {
        interval: Math.max(1000, page.rootItem.sensorUpdateRate)
        repeat: true
        running: page.active
        triggeredOnStart: false
        onTriggered: page.refreshMemory()
    }

    Local.RunCommand {
        id: meminfoCommand
    }

    ColumnLayout {
        id: pageContent

        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 4.4, ramSummaryContent.implicitHeight + Kirigami.Units.smallSpacing * 2)
            clip: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            RowLayout {
                id: ramSummaryContent

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing

                Local.RingGauge {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
                    value: page.rootItem.memoryUsageMonitor.percent ?? 0
                    dataAvailable: page.rootItem.memoryUsageMonitor.available
                    label: i18nc("@label", "RAM")
                    accentColor: Kirigami.Theme.focusColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    Controls.Label {
                        text: page.memoryInfo.valid
                            ? i18nc("@label used memory of total memory", "%1 of %2 used", page.memoryInfo.usedText, page.memoryInfo.totalText)
                            : i18nc("@label", "Memory")
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    MemoryDetailRow {
                        label: i18nc("@label", "Available")
                        value: page.memoryInfo.availableText
                        markerColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
                    }

                    MemoryDetailRow {
                        label: i18nc("@label", "Swap")
                        value: page.memoryInfo.swapText
                        markerColor: Kirigami.Theme.neutralTextColor
                    }

                    Controls.Label {
                        visible: page.customGaugeSensor
                        text: i18nc("@label sensor shown by the memory gauge", "Gauge: %1", page.gaugeSensorId)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4.7
            clip: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Controls.Label {
                    text: i18nc("@label history and coverage", "Usage History · %1", page.rootItem.historyCoverageText(page.rootItem.memoryUsageSamples))
                    color: Kirigami.Theme.disabledTextColor
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Local.Sparkline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    samples: page.rootItem.memoryUsageSamples
                    windowDuration: page.rootItem.historyWindowDuration
                    now: page.rootItem.historyNow
                    lineColor: Kirigami.Theme.focusColor
                    showFill: true
                    showScale: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: memoryDetailsContent.implicitHeight + Kirigami.Units.smallSpacing * 2
            clip: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                id: memoryDetailsContent

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                Controls.Label {
                    text: i18nc("@label", "Details")
                    color: Kirigami.Theme.disabledTextColor
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing / 2

                    MemoryDetailRow {
                        label: i18nc("@label", "App")
                        value: page.memoryInfo.appText
                        markerColor: Kirigami.Theme.positiveTextColor
                    }

                    MemoryDetailRow {
                        label: i18nc("@label", "Page Cache")
                        value: page.memoryInfo.cacheText
                        markerColor: Kirigami.Theme.visitedLinkColor
                    }

                    MemoryDetailRow {
                        label: i18nc("@label", "Kernel")
                        value: page.memoryInfo.kernelText
                        markerColor: Kirigami.Theme.neutralTextColor
                    }

                    MemoryDetailRow {
                        label: i18nc("@label", "Compressed")
                        value: page.memoryInfo.compressedText
                        markerColor: Kirigami.Theme.negativeTextColor
                    }
                }
            }
        }

        Local.TopApplicationList {
            active: page.active
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            metric: "memory"
            limit: 5
            refreshInterval: Math.max(1500, page.rootItem.sensorUpdateRate * 2)
        }
    }
}
