import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "." as Local

PlasmoidItem {
    id: root

    property int sensorUpdateRate: Math.max(500, Plasmoid.configuration.updateRateLimit)

    readonly property var cpuUsageSensor: cpuUsage.sensor
    property alias cpuUsageMonitor: cpuUsage
    property alias cpuCountSensor: cpuCount
    property alias cpuCoreCountSensor: cpuCoreCount
    readonly property var memoryUsageSensor: memoryUsage.sensor
    property alias memoryUsageMonitor: memoryUsage
    readonly property var diskUsageSensor: diskUsage.sensor
    property alias diskUsageMonitor: diskUsage
    property alias diskReadSensor: diskRead
    property alias diskWriteSensor: diskWrite
    readonly property var networkDownloadSensor: networkDownload.sensor
    property alias networkDownloadMonitor: networkDownload
    readonly property var networkUploadSensor: networkUpload.sensor
    property alias networkUploadMonitor: networkUpload
    readonly property var gpuDevices: gpuDiscovery.devices
    readonly property string gpuDeviceId: root.configString(Plasmoid.configuration.gpuDeviceId)
    readonly property var selectedGpu: gpuDevices.find(function(device) {
        return device.key === root.gpuDeviceId;
    }) || null
    readonly property bool detailsVisible: expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool cpuDetailsVisible: detailsVisible && selectedTab === 0
    readonly property bool memoryDetailsVisible: detailsVisible && selectedTab === 1
    readonly property bool gpuDetailsVisible: detailsVisible && selectedTab === 2
    readonly property bool networkDetailsVisible: detailsVisible && selectedTab === 3
    readonly property bool diskDetailsVisible: detailsVisible && selectedTab === 4
    property alias gpuUsageMonitor: gpuUsage
    property int selectedTab: 0
    readonly property int historySampleLimit: 72
    readonly property int networkHistorySampleLimit: 48
    property var memoryUsageSamples: []
    property var networkUploadSamples: []
    property var networkDownloadSamples: []

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.title: i18n("KStats")
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    Layout.minimumWidth: Kirigami.Units.gridUnit * 4
    Layout.minimumHeight: Kirigami.Units.gridUnit

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: i18n("KStats")
    toolTipSubText: i18n("CPU %1 | Memory %2 | Disk %3 | Down %4 | Up %5",
        cpuUsage.text,
        memoryUsage.text,
        diskUsage.text,
        networkDownload.text,
        networkUpload.text)
        + (Plasmoid.configuration.showGpu
            ? i18nc("@info:tooltip GPU name and usage", " | %1: %2", selectedGpu ? gpuName(selectedGpu) : i18n("GPU"), gpuUsage.text)
            : "")

    function gpuName(device) {
        return gpuDiscovery.deviceName(device);
    }

    function sensorText(sensor) {
        if (!sensor || !sensor.enabled || sensor.sensorId.length === 0) {
            return i18nc("@info:status", "Off");
        }

        if (sensor.status !== Sensors.Sensor.Ready || cpuUsage.numericValue(sensor.value) === null) {
            return i18nc("@info:status", "N/A");
        }
        return sensor.formattedValue || String(sensor.value);
    }

    function configString(value) {
        if (value === undefined || value === null) {
            return "";
        }
        return String(value);
    }

    function sensorPercent(sensor) {
        if (!sensor || !sensor.enabled || sensor.status !== Sensors.Sensor.Ready) {
            return null;
        }
        return cpuUsage.percentValue(sensor.value, sensor.maximum);
    }

    function appendSample(samples, value, limit, clampPercent) {
        // The timestamp store replaces this temporary gap policy in the next slice.
        if (value === null || value === undefined || !isFinite(Number(value))) {
            return [];
        }
        var numeric = Number(value);
        numeric = clampPercent ? Math.max(0, Math.min(100, numeric)) : Math.max(0, numeric);

        var next = samples.slice(0);
        next.push(numeric);
        while (next.length > limit) {
            next.shift();
        }
        return next;
    }

    function sampleHistory() {
        root.memoryUsageSamples = root.appendSample(root.memoryUsageSamples,
            memoryUsage.percent,
            root.historySampleLimit,
            true);
        root.networkUploadSamples = root.appendSample(root.networkUploadSamples,
            networkUpload.value,
            root.networkHistorySampleLimit,
            false);
        root.networkDownloadSamples = root.appendSample(root.networkDownloadSamples,
            networkDownload.value,
            root.networkHistorySampleLimit,
            false);
    }

    function activeCount() {
        var count = 0;
        count += Plasmoid.configuration.showCpu ? 1 : 0;
        count += Plasmoid.configuration.showMemory ? 1 : 0;
        count += Plasmoid.configuration.showGpu ? 1 : 0;
        count += Plasmoid.configuration.showDisk ? 1 : 0;
        count += Plasmoid.configuration.showNetwork ? 1 : 0;
        return Math.max(1, count);
    }

    function selectTab(tabIndex) {
        var parsed = Number(tabIndex);
        if (!isFinite(parsed)) {
            parsed = 0;
        }
        root.selectedTab = Math.max(0, Math.min(4, Math.round(parsed)));
    }

    function openTab(tabIndex) {
        root.selectTab(tabIndex);
        root.expanded = true;
    }

    function toggleTab(tabIndex) {
        var previousTab = root.selectedTab;
        root.selectTab(tabIndex);

        if (root.expanded && root.selectedTab === previousTab) {
            root.expanded = false;
            return;
        }

        root.expanded = true;
    }

    function openSystemMonitor() {
        systemMonitorLauncher.exec("plasma-systemmonitor >/dev/null 2>&1 &", function(result) {
            if (result.exitCode !== 0) {
                Qt.openUrlExternally("applications:org.kde.plasma-systemmonitor.desktop");
            }
        });
    }

    compactRepresentation: Local.CompactRepresentation {
        rootItem: root
    }

    fullRepresentation: Local.FullRepresentation {
        rootItem: root
    }

    Local.RunCommand {
        id: systemMonitorLauncher
    }

    Local.GpuDiscovery {
        id: gpuDiscovery
        active: Plasmoid.configuration.showGpu || root.gpuDetailsVisible
    }

    Local.GpuSensor {
        id: gpuUsage
        metricId: "gpuUsage"
        valueMode: "percent"
        active: Plasmoid.configuration.showGpu || root.gpuDetailsVisible
        sensorId: root.selectedGpu ? root.selectedGpu.usageSensorId : ""
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: cpuUsage
        metricId: "cpu"
        valueMode: "percent"
        active: Plasmoid.configuration.showCpu || root.cpuDetailsVisible
        sensorId: root.configString(Plasmoid.configuration.cpuSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Sensors.Sensor {
        id: cpuCount
        sensorId: "cpu/all/cpuCount"
        updateRateLimit: root.sensorUpdateRate
    }

    Sensors.Sensor {
        id: cpuCoreCount
        sensorId: "cpu/all/coreCount"
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: memoryUsage
        metricId: "memory"
        valueMode: "percent"
        active: Plasmoid.configuration.showMemory || root.memoryDetailsVisible
        sensorId: root.configString(Plasmoid.configuration.memorySensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: diskUsage
        metricId: "disk"
        valueMode: "percent"
        active: Plasmoid.configuration.showDisk || root.diskDetailsVisible
        sensorId: root.configString(Plasmoid.configuration.diskSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Sensors.Sensor {
        id: diskRead
        enabled: root.configString(Plasmoid.configuration.diskReadSensorId).length > 0
        sensorId: root.configString(Plasmoid.configuration.diskReadSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Sensors.Sensor {
        id: diskWrite
        enabled: root.configString(Plasmoid.configuration.diskWriteSensorId).length > 0
        sensorId: root.configString(Plasmoid.configuration.diskWriteSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: networkDownload
        metricId: "networkDownload"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showNetwork || root.networkDetailsVisible
        sensorId: root.configString(Plasmoid.configuration.networkDownloadSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: networkUpload
        metricId: "networkUpload"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showNetwork || root.networkDetailsVisible
        sensorId: root.configString(Plasmoid.configuration.networkUploadSensorId)
        updateRateLimit: root.sensorUpdateRate
    }

    Timer {
        interval: Math.max(1000, root.sensorUpdateRate)
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleHistory()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Open System Monitor")
            icon.name: "utilities-system-monitor"
            onTriggered: root.openSystemMonitor()
        }
    ]
}
