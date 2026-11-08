import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "." as Local

Item {
    id: page

    required property var rootItem
    // Replace providers in fixtures without connecting to the session bus.
    property Component commandComponent: Component { Local.RunCommand {} }
    property Component applicationsComponent: Component {
        Local.TopApplicationList {
            active: page.rootItem.diskDetailsVisible
            metric: "disk"
            // Four rows leave room for the capacity summary within the popup height.
            limit: 4
            rowHeight: Kirigami.Units.gridUnit * 1.88
            refreshInterval: Math.max(3000, page.rootItem.sensorUpdateRate * 3)
        }
    }
    // Replace in fixtures to hold or fail SMART reads separately from layout reads.
    property Component healthCommandComponent: Component { Local.RunCommand {} }
    property var disks: []
    property var mounts: []
    property var previousDiskStats: ({})
    property real previousDiskStatsTime: 0
    property string errorText: ""
    property int maxDisks: 3
    property int maxMounts: 3
    property int currentView: 0
    readonly property bool active: rootItem.diskDetailsVisible
    property bool completed: false
    property bool refreshInFlight: false
    property int refreshGeneration: 0
    // Discovery (lsblk, df) runs on activation and then at most this often;
    // activity (/proc/diskstats) is sampled on every refresh.
    property int layoutRefreshInterval: 30000
    property var clock: function() { return Date.now(); }
    property var layoutSnapshot: null
    property real layoutTime: 0
    readonly property real sectionSpacing: Kirigami.Units.smallSpacing * 1.15
    readonly property real switchHeight: Kirigami.Units.gridUnit * 2.1
    readonly property var scope: rootItem.diskScope
    readonly property var usageMonitor: rootItem.diskUsageMonitor
    readonly property var readMonitor: rootItem.diskReadMonitor
    readonly property var writeMonitor: rootItem.diskWriteMonitor
    readonly property bool activityConfigured: readMonitor.status !== "disabled" || writeMonitor.status !== "disabled"
    // Byte totals come from sensors that share the capacity sensor's definition.
    readonly property bool bytesAvailable: usedBytesSensor.status === Sensors.Sensor.Ready
        && totalBytesSensor.status === Sensors.Sensor.Ready
        && usedBytesSensor.formattedValue.length > 0 && Number(totalBytesSensor.value) > 0
    readonly property real diskRowHeight: Kirigami.Units.gridUnit * 3.95

    clip: true
    implicitHeight: pageContent.implicitHeight
    Layout.fillWidth: true
    Layout.fillHeight: true

    function formatBytes(bytes) {
        var value = Math.max(0, Number(bytes) || 0);
        var tib = value / 1099511627776;
        if (tib >= 1) {
            return i18nc("@label storage in terabytes", "%1 TB", tib.toFixed(tib >= 10 ? 1 : 2));
        }

        var gib = value / 1073741824;
        if (gib >= 1) {
            return i18nc("@label storage in gigabytes", "%1 GB", gib.toFixed(gib >= 10 ? 1 : 2));
        }

        return i18nc("@label storage in megabytes", "%1 MB", Math.round(value / 1048576));
    }

    function formatRate(bytesPerSecond) {
        var value = Math.max(0, Number(bytesPerSecond) || 0);
        if (value >= 1048576) {
            return i18nc("@label disk megabytes per second", "%1 MB/s", (value / 1048576).toFixed(value >= 10485760 ? 1 : 2));
        }
        if (value >= 1024) {
            return i18nc("@label disk kilobytes per second", "%1 KB/s", (value / 1024).toFixed(value >= 10240 ? 0 : 1));
        }
        return i18nc("@label disk bytes per second", "%1 B/s", Math.round(value));
    }

    function healthSummary(deviceName) {
        var health = diskHealth.healthFor(deviceName);
        return health ? health.summary : null;
    }

    function healthColor(status) {
        return status === "failing" ? Kirigami.Theme.negativeTextColor
            : status === "warning" ? Kirigami.Theme.neutralTextColor
            : status === "good" ? Kirigami.Theme.positiveTextColor
            : Kirigami.Theme.disabledTextColor;
    }

    function healthStatusText(status) {
        switch (status) {
        case "good":
            return i18nc("@info:status drive health", "Healthy");
        case "warning":
            return i18nc("@info:status drive health", "Warning");
        case "failing":
            return i18nc("@info:status drive health", "Failing");
        default:
            return i18nc("@info:status drive health", "No data");
        }
    }

    function healthProblemText(code) {
        switch (code) {
        case "missing":
            return i18nc("@info drive health", "Not reported by UDisks");
        case "unsupported":
            return i18nc("@info drive health", "SMART not supported");
        case "disabled":
            return i18nc("@info drive health", "SMART is disabled");
        case "pending":
            return i18nc("@info drive health", "Waiting for the first SMART reading");
        case "nvme-spare":
            return i18nc("@info drive health", "Spare capacity is low");
        case "nvme-temperature":
            return i18nc("@info drive health", "Temperature above its threshold");
        case "nvme-degraded":
            return i18nc("@info drive health", "Reliability is degraded");
        case "nvme-readonly":
            return i18nc("@info drive health", "Drive switched to read-only");
        case "nvme-volatile_mem":
            return i18nc("@info drive health", "Backup memory failed");
        case "nvme-pmr_readonly":
            return i18nc("@info drive health", "Persistent memory is read-only");
        case "worn-out":
            return i18nc("@info drive health", "Rated endurance used up");
        case "media-errors":
            return i18nc("@info drive health", "Media errors reported");
        case "failing":
            return i18nc("@info drive health", "SMART predicts failure");
        case "attributes-failing":
            return i18nc("@info drive health", "Attributes below threshold");
        case "bad-sectors":
            return i18nc("@info drive health", "Bad sectors reported");
        default:
            return code;
        }
    }

    function healthProblemsText(summary) {
        if (!summary) {
            return diskHealth.readStatus === "unavailable"
                ? i18nc("@info drive health", "SMART data unavailable")
                : i18nc("@info drive health", "Reading SMART data…");
        }
        return summary.problems.map(page.healthProblemText).join(", ");
    }

    function formatHours(hours) {
        return i18nc("@label drive power-on time in hours", "%1 h", Number(hours).toLocaleString(Qt.locale(), "f", 0));
    }

    function isIgnoredDisk(name) {
        return name.indexOf("zram") === 0
            || name.indexOf("loop") === 0
            || name.indexOf("sr") === 0
            || name.indexOf("ram") === 0;
    }

    function isHiddenMount(mountPoint) {
        return mountPoint.length === 0
            || mountPoint === "[SWAP]"
            || mountPoint.indexOf("/proc") === 0
            || mountPoint.indexOf("/sys") === 0
            || mountPoint.indexOf("/dev") === 0
            || mountPoint.indexOf("/run") === 0
            || mountPoint.indexOf("/var/lib/docker") === 0;
    }

    function rememberDevice(map, name, diskName) {
        if (!name || name.length === 0) {
            return;
        }
        map[name] = diskName;
        map["/dev/" + name] = diskName;
    }

    function appendMount(disk, mountPoint) {
        if (!disk || page.isHiddenMount(mountPoint)) {
            return;
        }
        if (disk.mounts.indexOf(mountPoint) < 0) {
            disk.mounts.push(mountPoint);
        }
    }

    function parseBlockDevices(output) {
        var parsed = JSON.parse(output);
        var rows = [];
        var diskByName = {};
        var deviceToDisk = {};
        var mountToDisk = {};
        var mountRows = [];

        function walk(block, activeDiskName) {
            if (!block) {
                return;
            }

            var name = block.name || "";
            var kname = block.kname || name;
            var type = block.type || "";
            var diskName = activeDiskName;

            if (type === "disk" && !page.isIgnoredDisk(name)) {
                diskName = kname;
                var disk = {
                    name: kname,
                    title: name,
                    model: block.model || "",
                    size: Number(block.size) || 0,
                    used: 0,
                    percent: 0,
                    readRate: 0,
                    writeRate: 0,
                    mounts: []
                };
                rows.push(disk);
                diskByName[diskName] = disk;
                page.rememberDevice(deviceToDisk, name, diskName);
                page.rememberDevice(deviceToDisk, kname, diskName);
            } else if (diskName && diskName in diskByName) {
                page.rememberDevice(deviceToDisk, name, diskName);
                page.rememberDevice(deviceToDisk, kname, diskName);
            }

            if (diskName && diskName in diskByName) {
                var mountpoints = block.mountpoints || [];
                for (var i = 0; i < mountpoints.length; i++) {
                    var mountPoint = mountpoints[i] || "";
                    if (!page.isHiddenMount(mountPoint)) {
                        mountToDisk[mountPoint] = diskName;
                        page.appendMount(diskByName[diskName], mountPoint);
                    }
                }
            }

            var children = block.children || [];
            for (var childIndex = 0; childIndex < children.length; childIndex++) {
                walk(children[childIndex], diskName);
            }
        }

        var blockdevices = parsed.blockdevices || [];
        for (var i = 0; i < blockdevices.length; i++) {
            walk(blockdevices[i], "");
        }

        return {
            rows: rows,
            diskByName: diskByName,
            deviceToDisk: deviceToDisk,
            mountToDisk: mountToDisk,
            mountRows: mountRows
        };
    }

    function applyFilesystemUsage(layout, output) {
        var seenSources = {};
        var lines = output.trim().length > 0 ? output.trim().split(/\n/) : [];

        for (var i = 1; i < lines.length; i++) {
            var match = lines[i].match(/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.+?)\s*$/);
            if (!match) {
                continue;
            }

            var source = match[1];
            var total = Number(match[2]);
            var used = Number(match[3]);
            var available = Number(match[4]);
            var percent = Number(match[5]);
            var mountPoint = match[6];
            var diskName = layout.mountToDisk[mountPoint] || layout.deviceToDisk[source];

            if (!diskName || !(diskName in layout.diskByName) || page.isHiddenMount(mountPoint)) {
                continue;
            }

            var disk = layout.diskByName[diskName];
            page.appendMount(disk, mountPoint);

            layout.mountRows.push({
                source: source,
                mountPoint: mountPoint,
                diskName: diskName,
                diskTitle: disk.title,
                total: isFinite(total) ? total : 0,
                used: isFinite(used) ? used : 0,
                available: isFinite(available) ? available : 0,
                percent: isFinite(percent) ? Math.max(0, Math.min(100, percent)) : 0
            });

            if (source in seenSources) {
                continue;
            }
            seenSources[source] = true;

            if (isFinite(used)) {
                layout.diskByName[diskName].used += used;
            }
        }
    }

    function parseDiskStats(output) {
        var stats = {};
        var lines = output.split(/\n/);

        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].trim().split(/\s+/);
            if (fields.length < 10) {
                continue;
            }

            var name = fields[2];
            var readSectors = Number(fields[5]);
            var writtenSectors = Number(fields[9]);
            if (!isFinite(readSectors) || !isFinite(writtenSectors)) {
                continue;
            }

            stats[name] = {
                readBytes: readSectors * 512,
                writeBytes: writtenSectors * 512
            };
        }

        return stats;
    }

    function finishRefresh(layout, statsOutput) {
        var now = Date.now();
        var stats = page.parseDiskStats(statsOutput);
        var nextPrevious = {};
        var elapsed = page.previousDiskStatsTime > 0 ? Math.max(0.001, (now - page.previousDiskStatsTime) / 1000) : 0;

        for (var i = 0; i < layout.rows.length; i++) {
            var disk = layout.rows[i];
            var diskStats = stats[disk.name];

            if (disk.size > 0) {
                disk.percent = Math.max(0, Math.min(100, disk.used / disk.size * 100));
            }

            if (diskStats) {
                var previous = page.previousDiskStats[disk.name];
                if (previous && elapsed > 0) {
                    disk.readRate = Math.max(0, (diskStats.readBytes - previous.readBytes) / elapsed);
                    disk.writeRate = Math.max(0, (diskStats.writeBytes - previous.writeBytes) / elapsed);
                }
                nextPrevious[disk.name] = diskStats;
            }
        }

        layout.rows.sort(function(left, right) {
            return right.size - left.size;
        });

        layout.mountRows.sort(function(left, right) {
            if (left.mountPoint === "/") {
                return -1;
            }
            if (right.mountPoint === "/") {
                return 1;
            }
            return left.mountPoint.localeCompare(right.mountPoint);
        });

        page.previousDiskStats = nextPrevious;
        page.previousDiskStatsTime = now;
        page.errorText = "";
        page.disks = layout.rows.slice(0, page.maxDisks);
        page.mounts = layout.mountRows.slice(0, page.maxMounts);
    }

    function demandChanged() {
        if (!completed) {
            return;
        }
        refreshGeneration++;
        layoutSnapshot = null;
        previousDiskStats = ({});
        previousDiskStatsTime = 0;
        if (active) {
            refresh();
        }
    }

    function acceptResult(generation) {
        if (active && generation === refreshGeneration) {
            return true;
        }
        refreshInFlight = false;
        if (active) {
            // Let RunCommand disconnect its old source before requesting it again.
            Qt.callLater(page.refresh);
        }
        return false;
    }

    // Only rows and mount rows are needed after filesystem usage is applied.
    function copyLayout(layout) {
        return {
            rows: JSON.parse(JSON.stringify(layout.rows)),
            mountRows: JSON.parse(JSON.stringify(layout.mountRows))
        };
    }

    function layoutIsFresh(now) {
        return layoutSnapshot !== null && now >= layoutTime && now - layoutTime < layoutRefreshInterval;
    }

    function readStats(generation, layout) {
        statsCommand.provider.exec("cat /proc/diskstats", function(statsResult) {
            if (!page || !page.acceptResult(generation)) {
                return;
            }
            page.finishRefresh(layout, statsResult.exitCode === 0 ? statsResult.stdout : "");
            page.refreshInFlight = false;
        });
    }

    function refresh() {
        if (!completed || !active || refreshInFlight) {
            return;
        }
        refreshInFlight = true;
        var generation = refreshGeneration;
        if (layoutIsFresh(clock())) {
            readStats(generation, copyLayout(layoutSnapshot));
            return;
        }
        layoutCommand.provider.exec("lsblk -b -J -o NAME,KNAME,TYPE,SIZE,MODEL,PKNAME,MOUNTPOINTS", function(layoutResult) {
            if (!page || !page.acceptResult(generation)) {
                return;
            }
            if (layoutResult.exitCode !== 0) {
                page.refreshInFlight = false;
                page.errorText = layoutResult.stderr.length > 0 ? layoutResult.stderr : i18nc("@info:status", "Unable to read disk devices");
                page.disks = [];
                page.mounts = [];
                return;
            }

            var layout;
            try {
                layout = page.parseBlockDevices(layoutResult.stdout);
            } catch (error) {
                page.refreshInFlight = false;
                page.errorText = i18nc("@info:status", "Unable to parse disk devices");
                page.disks = [];
                page.mounts = [];
                return;
            }

            usageCommand.provider.exec("df -P -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs", function(usageResult) {
                if (!page || !page.acceptResult(generation)) {
                    return;
                }
                if (usageResult.exitCode === 0) {
                    page.applyFilesystemUsage(layout, usageResult.stdout);
                    // Reuse only complete discovery; a failed df retries next time.
                    page.layoutSnapshot = page.copyLayout(layout);
                    page.layoutTime = page.clock();
                }
                page.readStats(generation, layout);
            });
        });
    }

    onActiveChanged: demandChanged()
    Component.onCompleted: {
        completed = true;
        demandChanged();
    }

    Sensors.Sensor {
        id: usedBytesSensor
        sensorId: page.scope.sensorIds.used
        enabled: page.active && sensorId.length > 0
        updateRateLimit: Math.max(5000, page.rootItem.sensorUpdateRate)
    }

    Sensors.Sensor {
        id: totalBytesSensor
        sensorId: page.scope.sensorIds.total
        enabled: page.active && sensorId.length > 0
        updateRateLimit: 60000
    }

    Local.DiskHealthCollector {
        id: diskHealth
        active: page.active
        commandComponent: page.healthCommandComponent
    }

    Timer {
        interval: Math.max(2500, page.rootItem.sensorUpdateRate * 2)
        repeat: true
        running: page.active && page.completed
        triggeredOnStart: false
        onTriggered: page.refresh()
    }

    Loader {
        id: layoutCommand
        readonly property var provider: item
        sourceComponent: page.commandComponent
    }

    Loader {
        id: usageCommand
        readonly property var provider: item
        sourceComponent: page.commandComponent
    }

    Loader {
        id: statsCommand
        readonly property var provider: item
        sourceComponent: page.commandComponent
    }

    component HealthValue: RowLayout {
        property string label: ""
        property string value: ""

        spacing: Kirigami.Units.smallSpacing / 2

        Controls.Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        Controls.Label {
            text: value
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    component ActivityValue: RowLayout {
        property string label: ""
        property string value: ""
        property color markerColor: Kirigami.Theme.focusColor

        spacing: Kirigami.Units.smallSpacing / 2

        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 2
            color: markerColor
        }

        Controls.Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        Controls.Label {
            text: value
            font.weight: Font.DemiBold
        }
    }

    Column {
        id: pageContent

        anchors.fill: parent
        spacing: page.sectionSpacing

        // The same capacity reading as the panel, with its scope, then the
        // activity history collected in the background while the module is shown.
        Local.Card {
            width: parent.width
            height: summaryContent.implicitHeight + Kirigami.Units.smallSpacing * 2

            ColumnLayout {
                id: summaryContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: page.usageMonitor.available
                            ? i18nc("@label disk capacity used", "%1 used", page.usageMonitor.text)
                            : page.usageMonitor.text
                        font.weight: Font.DemiBold
                    }

                    Controls.Label {
                        visible: page.bytesAvailable
                        text: i18nc("@label used disk space of total", "%1 of %2", usedBytesSensor.formattedValue, totalBytesSensor.formattedValue)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    Controls.Label {
                        text: page.scope.scopeText
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    visible: page.activityConfigured
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ActivityValue {
                        label: i18nc("@label disk read rate", "Read")
                        value: page.readMonitor.text
                        markerColor: Kirigami.Theme.focusColor
                    }

                    ActivityValue {
                        label: i18nc("@label disk write rate", "Write")
                        value: page.writeMonitor.text
                        markerColor: Kirigami.Theme.negativeTextColor
                    }

                    Controls.Label {
                        text: page.rootItem.historyCoverageText(page.rootItem.diskWriteSamples)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Reads are drawn above the baseline and writes below it.
                Local.NetworkHistoryChart {
                    visible: page.activityConfigured
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.4
                    uploadSamples: page.rootItem.diskReadSamples
                    downloadSamples: page.rootItem.diskWriteSamples
                    windowDuration: page.rootItem.historyWindowDuration
                    now: page.rootItem.historyNow
                    uploadColor: Kirigami.Theme.focusColor
                    downloadColor: Kirigami.Theme.negativeTextColor
                }
            }
        }

        Rectangle {
            width: parent.width
            height: page.switchHeight
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.055)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing / 2
                spacing: Kirigami.Units.smallSpacing / 2

                Local.TabPill {
                    checked: page.currentView === 0
                    iconName: "drive-harddisk"
                    accentColor: Kirigami.Theme.focusColor
                    text: i18nc("@title:tab", "Disks")
                    onClicked: page.currentView = 0
                }

                Local.TabPill {
                    checked: page.currentView === 1
                    iconName: "folder"
                    accentColor: Kirigami.Theme.focusColor
                    text: i18nc("@title:tab", "Mounts")
                    onClicked: page.currentView = 1
                }

                Local.TabPill {
                    checked: page.currentView === 2
                    iconName: "security-high"
                    accentColor: Kirigami.Theme.focusColor
                    text: i18nc("@title:tab drive SMART health", "Health")
                    onClicked: page.currentView = 2
                }
            }
        }

        Repeater {
            model: page.currentView === 0 ? page.disks : []

            delegate: Local.Card {
                required property var modelData

                width: parent.width
                height: page.diskRowHeight
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing / 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing / 2

                                Controls.Label {
                                    text: modelData.title
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                // Only drives that need attention get a marker; it opens Health.
                                Rectangle {
                                    id: healthMarker
                                    readonly property var summary: page.healthSummary(modelData.name)
                                    visible: summary !== null && (summary.status === "warning" || summary.status === "failing")
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: page.healthColor(summary ? summary.status : "unknown")

                                    HoverHandler {
                                        id: healthMarkerHover
                                    }
                                    TapHandler {
                                        onTapped: page.currentView = 2
                                    }
                                    Controls.ToolTip.visible: healthMarkerHover.hovered
                                    Controls.ToolTip.text: healthMarker.summary
                                        ? i18nc("@info:tooltip drive health status and problems", "%1: %2",
                                            page.healthStatusText(healthMarker.summary.status), page.healthProblemsText(healthMarker.summary))
                                        : ""
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            Controls.Label {
                                text: modelData.model.length > 0 ? modelData.model : modelData.name
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing / 2

                            Controls.Label {
                                text: i18nc("@label disk read indicator", "R")
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 2
                                color: Kirigami.Theme.focusColor
                            }

                            Controls.Label {
                                text: page.formatRate(modelData.readRate)
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 4.3
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing / 2

                            Controls.Label {
                                text: i18nc("@label disk write indicator", "W")
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 2
                                color: Kirigami.Theme.negativeTextColor
                            }

                            Controls.Label {
                                text: page.formatRate(modelData.writeRate)
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 4.3
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: height / 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * modelData.percent / 100
                            radius: parent.radius
                            color: Kirigami.Theme.focusColor
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Label {
                            text: i18nc("@label disk used from total", "Used %1 from %2",
                                page.formatBytes(modelData.used),
                                page.formatBytes(modelData.size))
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Controls.Label {
                            text: i18nc("@label disk percent", "%1%", Math.round(modelData.percent))
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        Repeater {
            model: page.currentView === 1 ? page.mounts : []

            delegate: Local.Card {
                required property var modelData

                width: parent.width
                height: page.diskRowHeight
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing / 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            Controls.Label {
                                text: modelData.mountPoint
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Controls.Label {
                                text: i18nc("@label mount source and disk", "%1 on %2", modelData.source, modelData.diskTitle)
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Controls.Label {
                            text: i18nc("@label free filesystem space", "%1 free", page.formatBytes(modelData.available))
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: height / 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * modelData.percent / 100
                            radius: parent.radius
                            color: Kirigami.Theme.focusColor
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Label {
                            text: i18nc("@label disk used from total", "Used %1 from %2",
                                page.formatBytes(modelData.used),
                                page.formatBytes(modelData.total))
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Controls.Label {
                            text: i18nc("@label disk percent", "%1%", Math.round(modelData.percent))
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        Repeater {
            model: page.currentView === 2 ? page.disks : []

            delegate: Local.Card {
                id: healthCard

                required property var modelData
                readonly property var health: diskHealth.healthFor(modelData.name)
                readonly property var summary: health ? health.summary : null
                readonly property string status: summary ? summary.status : "unknown"

                width: parent.width
                height: page.diskRowHeight
                clip: true
                border.color: healthCard.status === "failing" || healthCard.status === "warning"
                    ? Qt.rgba(page.healthColor(healthCard.status).r, page.healthColor(healthCard.status).g, page.healthColor(healthCard.status).b, 0.45)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing / 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            Controls.Label {
                                text: healthCard.modelData.title
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Problems replace the model line so they are never hidden.
                            Controls.Label {
                                readonly property bool showProblems: healthCard.summary === null || healthCard.summary.problems.length > 0
                                text: showProblems ? page.healthProblemsText(healthCard.summary)
                                    : (healthCard.modelData.model.length > 0 ? healthCard.modelData.model : healthCard.modelData.name)
                                color: showProblems && (healthCard.status === "failing" || healthCard.status === "warning")
                                    ? page.healthColor(healthCard.status) : Kirigami.Theme.disabledTextColor
                                font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing / 2

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: page.healthColor(healthCard.status)
                            }

                            Controls.Label {
                                text: page.healthStatusText(healthCard.status)
                                color: healthCard.status === "unknown" ? Kirigami.Theme.disabledTextColor : page.healthColor(healthCard.status)
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        HealthValue {
                            visible: healthCard.summary !== null && healthCard.summary.temperatureC !== null
                            label: i18nc("@label drive temperature", "Temp")
                            value: visible ? i18nc("@label temperature in Celsius", "%1 °C", Math.round(healthCard.summary.temperatureC)) : ""
                        }

                        HealthValue {
                            visible: healthCard.summary !== null && healthCard.summary.powerOnHours !== null
                            label: i18nc("@label drive power-on time", "On")
                            value: visible ? page.formatHours(healthCard.summary.powerOnHours) : ""
                        }

                        HealthValue {
                            visible: healthCard.summary !== null && healthCard.summary.wearPercent !== null
                            label: i18nc("@label drive wear, share of rated endurance used", "Wear")
                            value: visible ? i18nc("@label percent value", "%1%", healthCard.summary.wearPercent) : ""
                        }

                        HealthValue {
                            visible: healthCard.summary !== null && healthCard.summary.dataWritten !== null
                            label: i18nc("@label total data written to the drive", "Written")
                            value: visible ? page.formatBytes(healthCard.summary.dataWritten) : ""
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        Controls.Label {
            visible: page.currentView === 2 && diskHealth.readStatus === "unavailable"
            width: parent.width
            text: i18nc("@info", "SMART data needs the UDisks service and busctl.")
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            wrapMode: Text.WordWrap
        }

        Controls.Label {
            visible: page.currentView === 1 ? page.mounts.length === 0 : page.disks.length === 0
            width: parent.width
            text: page.errorText.length > 0 ? page.errorText : i18nc("@info:status", "No disk data yet")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }

        Item {
            width: parent.width
            height: Kirigami.Units.smallSpacing
        }

        Loader {
            width: parent.width
            sourceComponent: page.applicationsComponent
        }
    }
}
