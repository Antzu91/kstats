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
            // A manual sensor that does not exist, and a disabled one.
            property string cpuTemperatureSetting: "lmsensors/missing-isa-0000/temp1"
            property string cpuFanSetting: "off"
            property int selectedTab: 0
            readonly property var moduleOrder: ["network", "disk", "cpu", "gpu", "memory"]
            property alias modules: catalog
            property bool expanded: true
            property bool popupPinned: false
            property bool pinAvailable: true
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
            property alias diskReadMonitor: diskRead
            property alias diskScope: diskScopeModel
            property alias diskWriteMonitor: diskWrite
            property alias networkDownloadMonitor: networkDownload
            property alias networkUploadMonitor: networkUpload
            property alias networkModel: networkScope
            property alias publicIp: publicIpLookup
            property bool publicIpLookupEnabled: false
            function setPublicIpLookupEnabled(enabled) { publicIpLookupEnabled = enabled; }
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
            readonly property var diskReadSamples: []
            readonly property var diskWriteSamples: []

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
            Local.ModuleCatalog { id: catalog }
            Local.SensorMonitor { id: cpuUsage; metricId: "cpu"; valueMode: "percent"; sensorId: "cpu/all/usage" }
            Local.SensorMonitor { id: memoryUsage; metricId: "memory"; valueMode: "percent"; sensorId: "memory/physical/usedPercent" }
            Local.SensorMonitor { id: diskUsage; metricId: "disk"; valueMode: "percent"; sensorId: "disk/all/usedPercent" }
            // A chosen volume whose name sensor never answers falls back to its ID.
            Local.DiskScope { id: diskScopeModel; source: "volume:1792e22e-bc5e"; active: true }
            Local.SensorMonitor { id: diskRead; metricId: "diskRead"; valueMode: "bytesPerSecond"; sensorId: diskScopeModel.sensorIds.read }
            Local.SensorMonitor { id: diskWrite; metricId: "diskWrite"; valueMode: "bytesPerSecond"; sensorId: diskScopeModel.sensorIds.write }
            // Automatic needs a route lookup; CI may lack routes or the ip command.
            Local.NetworkModel {
                id: networkScope
                source: "auto"
                active: true
                detailsDemand: fakeRoot.networkDetailsVisible
            }
            // Enabled in one test; the request fails offline in CI or is aborted on close.
            Local.PublicIpLookup {
                id: publicIpLookup
                lookupEnabled: fakeRoot.publicIpLookupEnabled
                demand: fakeRoot.networkDetailsVisible
                routeKey: networkScope.routeInterface
                requestFactory: function() { return { readyState: 0, status: 0, responseText: "", onreadystatechange: null,
                    open: function() {}, send: function() {}, abort: function() {} }; }
            }
            Local.SensorMonitor { id: networkDownload; metricId: "networkDownload"; valueMode: "bytesPerSecond"; sensorId: networkScope.downloadSensorId; emptyIsUnavailable: true }
            Local.SensorMonitor { id: networkUpload; metricId: "networkUpload"; valueMode: "bytesPerSecond"; sensorId: networkScope.uploadSensorId; emptyIsUnavailable: true }
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
            property real popupHeight: testCase.height
            property alias popup: popup
            // Bound by id, as main.qml does, so pages never see a null root.
            Local.FullRepresentation {
                id: popup
                rootItem: fakeRoot
                width: testCase.width
                height: fakeRoot.popupHeight
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

    function test_networkPageWithPublicIpLookupEnabled() {
        var fixture = makePopup({ publicIpLookupEnabled: true });
        fixture.root.selectedTab = 3;
        wait(200);
        compare(fixture.root.publicIp.status, "loading");
        fixture.root.publicIp.timeout = 10;
        fixture.root.publicIp.refresh();
        tryCompare(fixture.root.publicIp, "status", "failed", 1000);
        visitEveryPage(fixture);
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

    function test_pagesScrollWhenThePopupIsShort() {
        // Far below the preferred height, as with large fonts or a small screen.
        var fixture = makePopup({ popupHeight: 360 });
        visitEveryPage(fixture);
        ["cpuScroll", "ramScroll", "networkScroll", "diskScroll"].forEach(function(name) {
            var scroll = findChild(fixture.root.popup, name);
            verify(scroll !== null, name);
            verify(scroll.contentHeight > scroll.availableHeight, name + " should scroll");
        });
    }

    function test_pagesFillTallPopupsWithoutScrolling() {
        var fixture = makePopup({ popupHeight: 2000 });
        visitEveryPage(fixture);
        ["cpuScroll", "ramScroll", "networkScroll", "diskScroll"].forEach(function(name) {
            var scroll = findChild(fixture.root.popup, name);
            // Nothing to scroll, and the page stretches to the full height.
            verify(scroll.contentHeight <= scroll.availableHeight, name);
            compare(scroll.contentChildren[0].height, scroll.availableHeight, name);
        });
    }

    function test_keyboardCyclesTabsInConfiguredOrder() {
        // Fixture order: network, disk, cpu, gpu, memory.
        var fixture = makePopup();
        fixture.root.selectedTab = 0;
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(fixture.root.selectedTab, 2);
        keyClick(Qt.Key_PageDown, Qt.ControlModifier);
        compare(fixture.root.selectedTab, 1);
        keyClick(Qt.Key_PageDown, Qt.ControlModifier);
        compare(fixture.root.selectedTab, 3);
        keyClick(Qt.Key_PageUp, Qt.ControlModifier);
        compare(fixture.root.selectedTab, 1);
    }

    function test_tabsActivateWithKeysAndStayHighlighted() {
        var fixture = makePopup();
        fixture.root.selectedTab = 0;
        fixture.root.popup.focusCurrentTab();
        var current = fixture.root.popup.Window.activeFocusItem;
        verify(current !== null && current.checked);
        // Re-activating the current tab keeps it highlighted.
        keyClick(Qt.Key_Return);
        compare(fixture.root.selectedTab, 0);
        verify(current.checked);
        keyClick(Qt.Key_Right);
        compare(fixture.root.selectedTab, 2);
        verify(fixture.root.popup.Window.activeFocusItem.checked);
        keyClick(Qt.Key_Left);
        compare(fixture.root.selectedTab, 0);
    }

    function test_pinTogglesWithoutTouchingTheRest() {
        var fixture = makePopup();
        var pin = null;
        var stack = [fixture.root.popup];
        while (stack.length > 0 && pin === null) {
            var item = stack.pop();
            if (item.icon && item.icon.name === "window-pin") {
                pin = item;
            }
            for (var i = 0; item.children && i < item.children.length; ++i) {
                stack.push(item.children[i]);
            }
        }
        verify(pin !== null);
        verify(pin.visible);
        mouseClick(pin);
        compare(fixture.root.popupPinned, true);
        verify(pin.checked);
        fixture.root.popupPinned = false;
        verify(!pin.checked);
        mouseClick(pin);
        compare(fixture.root.popupPinned, true);
        fixture.root.pinAvailable = false;
        verify(!pin.visible);
    }
}
