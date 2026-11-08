import QtQuick

import org.kde.ksysguard.sensors as Sensors
import "." as Local

// Per-module panel tooltip text built from readings the widget already owns.
// Memory byte totals are the only extra sensors; they subscribe while hovered.
Item {
    id: tips

    required property var rootItem
    property bool memoryDemand: false
    // Replaceable in fixtures, as in SensorMonitor.
    property Component sensorComponent: Component { Sensors.Sensor {} }
    readonly property string defaultMemorySensorId: "memory/physical/usedPercent"

    visible: false

    function lines(values) {
        return values.filter(function(line) {
            return typeof line === "string" && line.length > 0;
        }).join("\n");
    }

    function monitorText(monitor) {
        return monitor ? monitor.text : i18nc("@info:status", "N/A");
    }

    function monitorEnabled(monitor) {
        return monitor !== null && monitor !== undefined && monitor.status !== "disabled";
    }

    function percentText(value) {
        return i18nc("@info:tooltip percent value", "%1%", value.toFixed(1));
    }

    readonly property string cpuTitle: i18nc("@info:tooltip", "CPU")
    readonly property string cpuText: {
        var details = rootItem.cpuDetailHistory;
        var hasBreakdown = details && details.userPercent !== null && details.systemPercent !== null;
        return lines([
            i18nc("@info:tooltip", "Usage: %1", monitorText(rootItem.cpuUsageMonitor)),
            hasBreakdown
                ? i18nc("@info:tooltip CPU time split", "User %1 · System %2",
                    percentText(details.userPercent), percentText(details.systemPercent))
                : ""
        ]);
    }

    readonly property string memoryTitle: i18nc("@info:tooltip", "Memory")
    readonly property string memoryText: {
        var monitor = rootItem.memoryUsageMonitor;
        // Byte totals share the default sensor's definition; never pair them with a custom one.
        var showBytes = monitor && monitor.sensorId === defaultMemorySensorId
            && memoryUsed.available && memoryTotal.available;
        return lines([
            i18nc("@info:tooltip", "Used: %1", monitorText(monitor)),
            showBytes ? i18nc("@info:tooltip used memory of total memory", "%1 of %2", memoryUsed.text, memoryTotal.text) : ""
        ]);
    }

    readonly property var gpuMonitors: rootItem.gpuMonitors(rootItem.gpuDeviceId)
    readonly property string gpuTitle: rootItem.selectedGpu
        ? rootItem.gpuName(rootItem.selectedGpu) : i18nc("@info:tooltip", "GPU")
    readonly property string gpuText: lines([
        i18nc("@info:tooltip", "Usage: %1", monitorText(rootItem.gpuUsageMonitor)),
        gpuMonitors && gpuMonitors.memory.sensorId.length > 0
            ? i18nc("@info:tooltip", "Memory: %1", gpuMonitors.memory.text) : "",
        gpuMonitors && gpuMonitors.temperature.sensorId.length > 0
            ? i18nc("@info:tooltip", "Temperature: %1", gpuMonitors.temperature.text) : ""
    ])

    readonly property string diskTitle: i18nc("@info:tooltip", "Disk")
    readonly property string diskText: lines([
        i18nc("@info:tooltip", "Used: %1", monitorText(rootItem.diskUsageMonitor)),
        monitorEnabled(rootItem.diskReadMonitor) || monitorEnabled(rootItem.diskWriteMonitor)
            ? i18nc("@info:tooltip disk activity", "Read %1 · Write %2",
                monitorText(rootItem.diskReadMonitor), monitorText(rootItem.diskWriteMonitor))
            : ""
    ])

    readonly property string networkTitle: i18nc("@info:tooltip", "Network")
    readonly property string networkText: lines([
        rootItem.networkModel ? rootItem.networkModel.scopeText : "",
        i18nc("@info:tooltip", "Download: %1", monitorText(rootItem.networkDownloadMonitor)),
        i18nc("@info:tooltip", "Upload: %1", monitorText(rootItem.networkUploadMonitor))
    ])

    Local.SensorMonitor {
        id: memoryUsed
        metricId: "memoryUsedBytes"
        sensorId: "memory/physical/used"
        active: tips.memoryDemand
        updateRateLimit: tips.rootItem.sensorUpdateRate
        sensorComponent: tips.sensorComponent
    }

    Local.SensorMonitor {
        id: memoryTotal
        metricId: "memoryTotalBytes"
        sensorId: "memory/physical/total"
        active: tips.memoryDemand
        updateRateLimit: tips.rootItem.sensorUpdateRate
        sensorComponent: tips.sensorComponent
    }
}
