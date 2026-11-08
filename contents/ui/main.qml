import QtQuick
import QtQuick.Layouts
import "History.js" as History

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
    property alias cpuDetailHistory: cpuDetailCollector
    property alias cpuCountSensor: cpuCount
    property alias cpuCoreCountSensor: cpuCoreCount
    readonly property var memoryUsageSensor: memoryUsage.sensor
    property alias memoryUsageMonitor: memoryUsage
    readonly property var diskUsageSensor: diskUsage.sensor
    property alias diskUsageMonitor: diskUsage
    property alias diskReadMonitor: diskRead
    property alias diskScope: diskScopeModel
    property alias diskWriteMonitor: diskWrite
    readonly property var networkDownloadSensor: networkDownload.sensor
    property alias networkDownloadMonitor: networkDownload
    readonly property var networkUploadSensor: networkUpload.sensor
    property alias networkUploadMonitor: networkUpload
    property alias networkModel: networkScope
    property alias publicIp: publicIpLookup
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
    readonly property var gpuUsageMonitor: gpuPool.selectedUsage
    property int selectedTab: 0
    readonly property int historyWindowMinutes: [1, 5, 15].indexOf(Number(Plasmoid.configuration.historyWindowMinutes)) >= 0
        ? Number(Plasmoid.configuration.historyWindowMinutes) : 1
    readonly property int historyWindowDuration: historyWindowMinutes * 60000
    readonly property real historyNow: historyStore.now
    property alias histories: historyStore
    readonly property var cpuUsageSamples: cpuHistory.samples
    readonly property var memoryUsageSamples: memoryHistory.samples
    readonly property var diskUsageSamples: diskHistory.samples
    readonly property var gpuUsageSamples: historyStore.samplesFor(gpuUsageMonitor.metricId, gpuUsageMonitor.sourceKey)
    readonly property var networkUploadSamples: uploadHistory.samples
    readonly property var networkDownloadSamples: downloadHistory.samples
    readonly property var diskReadSamples: diskReadHistory.samples
    readonly property var diskWriteSamples: diskWriteHistory.samples

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.title: i18n("KStats")
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    Layout.minimumWidth: Kirigami.Units.gridUnit * 4
    Layout.minimumHeight: Kirigami.Units.gridUnit

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 8

    readonly property bool panelModulesVisible: Plasmoid.configuration.showCpu || Plasmoid.configuration.showMemory
        || Plasmoid.configuration.showGpu || Plasmoid.configuration.showDisk || Plasmoid.configuration.showNetwork

    // Each visible panel module owns its tooltip. An explicitly empty string
    // hides Plasma's applet-wide tooltip; keep it only when no module is shown.
    toolTipMainText: panelModulesVisible ? "" : i18n("KStats")
    toolTipSubText: panelModulesVisible ? "" : i18n("CPU %1 | Memory %2 | Disk %3 | Down %4 | Up %5",
        cpuUsage.text,
        memoryUsage.text,
        diskUsage.text,
        networkDownload.text,
        networkUpload.text)
        + (Plasmoid.configuration.showGpu
            ? i18nc("@info:tooltip GPU name and usage", " | %1: %2", selectedGpu ? gpuName(selectedGpu) : i18n("GPU"), root.gpuUsageMonitor.text)
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

    function setPublicIpLookupEnabled(enabled) {
        Plasmoid.configuration.publicIpLookup = enabled === true;
    }

    function setHistoryWindowMinutes(minutes) {
        if ([1, 5, 15].indexOf(minutes) >= 0) {
            Plasmoid.configuration.historyWindowMinutes = minutes;
        }
    }

    function historyCoverageText(samples) {
        var seconds = Math.floor(History.coverageDuration(samples, historyWindowDuration, historyNow) / 1000);
        return seconds >= 60
            ? i18nc("@label retained history duration", "%1 min retained", (seconds / 60).toFixed(1))
            : i18nc("@label retained history duration", "%1 s retained", seconds);
    }

    function gpuMonitors(deviceKey) {
        return gpuPool.monitorFor(deviceKey);
    }

    function sampleHistory() {
        var timestamp = Date.now();
        historyStore.advance(timestamp);
        cpuDetailCollector.advance();
        cpuHistory.sample(timestamp);
        memoryHistory.sample(timestamp);
        diskHistory.sample(timestamp);
        uploadHistory.sample(timestamp);
        downloadHistory.sample(timestamp);
        diskReadHistory.sample(timestamp);
        diskWriteHistory.sample(timestamp);
        gpuPool.sample(timestamp);
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

    Local.GpuMonitorPool {
        id: gpuPool
        historyStore: historyStore
        devices: root.gpuDevices
        selectedDeviceId: root.gpuDeviceId
        panelDemand: Plasmoid.configuration.showGpu
        popupDemand: root.gpuDetailsVisible
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

    // History belongs to the widget, so the first popup can show data already
    // collected and closing or changing pages cannot discard the counter baseline.
    Local.CpuHistory {
        id: cpuDetailCollector
        active: Plasmoid.configuration.showCpu || root.cpuDetailsVisible
        refreshInterval: Math.max(1000, root.sensorUpdateRate)
        provider: function(callback) {
            cpuDetailCommand.exec("awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' /proc/stat", callback);
        }
    }

    Local.RunCommand {
        id: cpuDetailCommand
    }

    Sensors.Sensor {
        id: cpuCount
        enabled: root.cpuDetailsVisible
        sensorId: "cpu/all/cpuCount"
        updateRateLimit: root.sensorUpdateRate
    }

    Sensors.Sensor {
        id: cpuCoreCount
        enabled: root.cpuDetailsVisible
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

    // Capacity and activity follow one scope, so a chosen volume's reads,
    // writes and usage always describe the same filesystem.
    Local.DiskScope {
        id: diskScopeModel
        source: root.configString(Plasmoid.configuration.diskSource)
        usageSensorIdSetting: root.configString(Plasmoid.configuration.diskSensorId)
        readSensorIdSetting: root.configString(Plasmoid.configuration.diskReadSensorId)
        writeSensorIdSetting: root.configString(Plasmoid.configuration.diskWriteSensorId)
        active: Plasmoid.configuration.showDisk || root.diskDetailsVisible
    }

    Local.SensorMonitor {
        id: diskUsage
        metricId: "disk"
        valueMode: "percent"
        active: Plasmoid.configuration.showDisk || root.diskDetailsVisible
        sensorId: diskScopeModel.sensorIds.usage
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: diskRead
        metricId: "diskRead"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showDisk || root.diskDetailsVisible
        sensorId: diskScopeModel.sensorIds.read
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: diskWrite
        metricId: "diskWrite"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showDisk || root.diskDetailsVisible
        sensorId: diskScopeModel.sensorIds.write
        updateRateLimit: root.sensorUpdateRate
    }

    // One scope for the panel, popup, tooltip and history. Changing it changes
    // the sensor IDs, so history starts a new series instead of joining lines.
    Local.NetworkModel {
        id: networkScope
        source: root.configString(Plasmoid.configuration.networkSource)
        customDownloadSensorId: root.configString(Plasmoid.configuration.networkDownloadSensorId)
        customUploadSensorId: root.configString(Plasmoid.configuration.networkUploadSensorId)
        active: Plasmoid.configuration.showNetwork || root.networkDetailsVisible
        detailsDemand: root.networkDetailsVisible
    }

    // Opt-in; requests only when the Network page opens or on refresh. The
    // result lives here so reopening the popup can show it while refreshing.
    Local.PublicIpLookup {
        id: publicIpLookup
        lookupEnabled: Plasmoid.configuration.publicIpLookup === true
        demand: root.networkDetailsVisible
        routeKey: networkScope.routeInterface
    }

    Local.SensorMonitor {
        id: networkDownload
        metricId: "networkDownload"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showNetwork || root.networkDetailsVisible
        sensorId: networkScope.downloadSensorId
        // An unresolved automatic route is missing data; a cleared custom ID is "Off".
        emptyIsUnavailable: networkScope.mode !== "custom"
        updateRateLimit: root.sensorUpdateRate
    }

    Local.SensorMonitor {
        id: networkUpload
        metricId: "networkUpload"
        valueMode: "bytesPerSecond"
        active: Plasmoid.configuration.showNetwork || root.networkDetailsVisible
        sensorId: networkScope.uploadSensorId
        emptyIsUnavailable: networkScope.mode !== "custom"
        updateRateLimit: root.sensorUpdateRate
    }

    Local.HistoryStore {
        id: historyStore
        sampleInterval: root.sensorUpdateRate
    }

    Local.HistorySampler { id: cpuHistory; monitor: cpuUsage; store: historyStore }
    Local.HistorySampler { id: memoryHistory; monitor: memoryUsage; store: historyStore }
    Local.HistorySampler { id: diskHistory; monitor: diskUsage; store: historyStore }
    Local.HistorySampler { id: uploadHistory; monitor: networkUpload; store: historyStore; usePercent: false }
    Local.HistorySampler { id: downloadHistory; monitor: networkDownload; store: historyStore; usePercent: false }
    Local.HistorySampler { id: diskReadHistory; monitor: diskRead; store: historyStore; usePercent: false }
    Local.HistorySampler { id: diskWriteHistory; monitor: diskWrite; store: historyStore; usePercent: false }

    Timer {
        interval: root.sensorUpdateRate
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
