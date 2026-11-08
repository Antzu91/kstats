import QtQuick
import QtTest
import org.kde.ksysguard.sensors as Sensors
import "../contents/ui" as Local

// Loads the real popup against a root whose sensors, daemons and commands are
// unavailable (no ksystemstats or session bus in CI). Any script error fails.
TestCase {
    id: testCase
    name: "PopupSmoke"
    when: windowShown
    visible: true
    width: 520
    height: 900

    function substitute(text, args) {
        var result = String(text);
        for (var i = 0; i < args.length; ++i) {
            result = result.replace("%" + (i + 1), String(args[i]));
        }
        return result;
    }
    function i18n(text) { return substitute(text, Array.prototype.slice.call(arguments, 1)); }
    function i18nc(context, text) { return substitute(text, Array.prototype.slice.call(arguments, 2)); }
    function i18np(singular, plural, count) {
        return substitute(count === 1 ? singular : plural, Array.prototype.slice.call(arguments, 2));
    }
    function i18ncp(context, singular, plural, count) {
        return substitute(count === 1 ? singular : plural, Array.prototype.slice.call(arguments, 3));
    }

    Component {
        id: rootFactory
        Item {
            id: fakeRoot

            property int sensorUpdateRate: 1000
            property int selectedTab: 0
            property bool expanded: true
            property var gpuDevices: []
            readonly property bool detailsVisible: expanded
            readonly property bool cpuDetailsVisible: detailsVisible && selectedTab === 0
            readonly property bool memoryDetailsVisible: detailsVisible && selectedTab === 1
            readonly property bool gpuDetailsVisible: detailsVisible && selectedTab === 2
            readonly property bool networkDetailsVisible: detailsVisible && selectedTab === 3
            readonly property bool diskDetailsVisible: detailsVisible && selectedTab === 4
            readonly property int historyWindowMinutes: 1
            readonly property int historyWindowDuration: 60000
            readonly property real historyNow: store.now
            property alias histories: store
            property alias cpuUsageMonitor: cpuUsage
            property alias memoryUsageMonitor: memoryUsage
            property alias diskUsageMonitor: diskUsage
            property alias networkDownloadMonitor: networkDownload
            property alias networkUploadMonitor: networkUpload
            property alias cpuDetailHistory: cpuDetails
            property alias cpuCountSensor: cpuCount
            property alias cpuCoreCountSensor: cpuCoreCount
            readonly property var gpuUsageMonitor: gpuPool.selectedUsage
            readonly property var cpuUsageSamples: []
            readonly property var memoryUsageSamples: []
            readonly property var diskUsageSamples: []
            readonly property var gpuUsageSamples: []
            readonly property var networkUploadSamples: []
            readonly property var networkDownloadSamples: []

            function sensorText(sensor) {
                return sensor && sensor.status === Sensors.Sensor.Ready ? sensor.formattedValue : "N/A";
            }
            function historyCoverageText(samples) { return samples.length + " samples"; }
            function gpuMonitors(key) { return gpuPool.monitorFor(key); }
            function gpuName(device) { return device.name; }
            function selectTab(index) { selectedTab = index; }
            function toggleTab(index) { selectedTab = index; }
            function setHistoryWindowMinutes(minutes) {}
            function openSystemMonitor() {}

            Local.HistoryStore { id: store }
            Local.SensorMonitor { id: cpuUsage; metricId: "cpu"; valueMode: "percent"; sensorId: "cpu/all/usage" }
            Local.SensorMonitor { id: memoryUsage; metricId: "memory"; valueMode: "percent"; sensorId: "memory/physical/usedPercent" }
            Local.SensorMonitor { id: diskUsage; metricId: "disk"; valueMode: "percent"; sensorId: "disk/all/usedPercent" }
            Local.SensorMonitor { id: networkDownload; metricId: "networkDownload"; valueMode: "bytesPerSecond"; sensorId: "network/all/download" }
            Local.SensorMonitor { id: networkUpload; metricId: "networkUpload"; valueMode: "bytesPerSecond"; sensorId: "network/all/upload" }
            Sensors.Sensor { id: cpuCount; sensorId: "cpu/all/cpuCount" }
            Sensors.Sensor { id: cpuCoreCount; sensorId: "cpu/all/coreCount" }
            Local.CpuHistory {
                id: cpuDetails
                active: fakeRoot.cpuDetailsVisible
                provider: function(callback) {
                    Qt.callLater(function() {
                        callback({ exitCode: 1, stdout: "", stderr: "unavailable" });
                    });
                }
            }
            Local.GpuMonitorPool {
                id: gpuPool
                historyStore: store
                devices: fakeRoot.gpuDevices
                selectedDeviceId: "gpu0"
                popupDemand: fakeRoot.gpuDetailsVisible
            }
            // Bound by id, as main.qml does, so pages never see a null root.
            Local.FullRepresentation {
                rootItem: fakeRoot
                width: testCase.width
                height: testCase.height
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Unable to assign|Binding loop/);
    }

    function makePopup(rootProperties) {
        var root = createTemporaryObject(rootFactory, testCase, rootProperties || {});
        verify(root !== null);
        return { root: root };
    }

    function visitEveryPage(fixture) {
        // Tab indices follow main.qml: CPU, RAM, GPU, NET, DISK.
        for (var tab = 0; tab <= 4; ++tab) {
            fixture.root.selectedTab = tab;
            // Let asynchronous commands and sensor connection attempts finish.
            wait(400);
        }
        fixture.root.expanded = false;
        wait(50);
        fixture.root.expanded = true;
        wait(50);
    }

    function test_everyPageLoadsWithoutSensorsOrDevices() {
        visitEveryPage(makePopup());
    }

    function test_gpuPageToleratesUnavailableDeviceSensors() {
        var fixture = makePopup({ gpuDevices: [{
            key: "gpu0", name: "Test GPU",
            usageSensorId: "gpu/gpu0/usage",
            memorySensorId: "gpu/gpu0/usedVram",
            temperatureSensorId: ""
        }] });
        fixture.root.selectedTab = 2;
        wait(400);
        verify(fixture.root.gpuMonitors("gpu0") !== null);
        compare(fixture.root.gpuMonitors("gpu0").usage.available, false);
        visitEveryPage(fixture);
    }
}
