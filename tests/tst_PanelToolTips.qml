import QtQuick
import QtTest
import org.kde.ksysguard.sensors as Sensors
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "PanelToolTips"
    when: windowShown

    function substitute(text, args) {
        var result = String(text);
        for (var i = 0; i < args.length; ++i) {
            result = result.replace("%" + (i + 1), String(args[i]));
        }
        return result;
    }
    function i18n(text) { return substitute(text, Array.prototype.slice.call(arguments, 1)); }
    function i18nc(context, text) { return substitute(text, Array.prototype.slice.call(arguments, 2)); }

    // Mirrors the SensorMonitor surface the tooltips read.
    Component {
        id: fakeMonitor
        QtObject {
            property string sensorId: "fake"
            property string status: "available"
            property string text: "N/A"
        }
    }
    // Becomes ready shortly after a monitor loads it, like a daemon reply.
    Component {
        id: readySensor
        Item {
            property string sensorId: ""
            property int updateRateLimit: 1000
            property int updateInterval: 500
            property bool enabled: true
            property int status: Sensors.Sensor.Loading
            property var value: 0
            property int unit: 0
            property real maximum: 0
            property string formattedValue: sensorId === "memory/physical/used" ? "19.6 GiB" : "60.5 GiB"
            onStatusChanged: valueChanged()
            Timer {
                interval: 10
                running: true
                onTriggered: {
                    parent.status = Sensors.Sensor.Ready;
                    parent.value = 1;
                    parent.valueChanged();
                }
            }
        }
    }
    Component {
        id: fixtureFactory
        Item {
            id: fakeRoot
            property int sensorUpdateRate: 1000
            property string gpuDeviceId: "gpu0"
            property var selectedGpu: null
            property var gpuMonitorSet: null
            property bool memoryDemand: false
            property Component tipSensors: Component { Sensors.Sensor {} }
            property QtObject cpuUsageMonitor: fakeMonitor.createObject(fakeRoot)
            property QtObject memoryUsageMonitor: fakeMonitor.createObject(fakeRoot, { sensorId: "memory/physical/usedPercent" })
            property QtObject gpuUsageMonitor: fakeMonitor.createObject(fakeRoot)
            property QtObject diskUsageMonitor: fakeMonitor.createObject(fakeRoot)
            property QtObject diskReadMonitor: fakeMonitor.createObject(fakeRoot, { sensorId: "", status: "disabled", text: "Off" })
            property QtObject diskWriteMonitor: fakeMonitor.createObject(fakeRoot, { sensorId: "", status: "disabled", text: "Off" })
            property QtObject networkDownloadMonitor: fakeMonitor.createObject(fakeRoot)
            property QtObject networkUploadMonitor: fakeMonitor.createObject(fakeRoot)
            property QtObject diskScope: QtObject {
                property string scopeText: "All disks"
            }
            property QtObject networkModel: QtObject {
                property string scopeText: "All interfaces"
            }
            property QtObject cpuDetailHistory: QtObject {
                property var userPercent: null
                property var systemPercent: null
            }
            property alias tips: tips
            function gpuMonitors(key) { return key === gpuDeviceId ? gpuMonitorSet : null; }
            function gpuName(device) { return "GPU 1: " + device.name; }

            Local.PanelToolTips {
                id: tips
                rootItem: fakeRoot
                memoryDemand: fakeRoot.memoryDemand
                sensorComponent: fakeRoot.tipSensors
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }

    function make(properties) {
        var fixture = createTemporaryObject(fixtureFactory, testCase, properties || {});
        verify(fixture !== null);
        return fixture;
    }

    function test_unavailableReadingsStaySafe() {
        // No sensor daemon: the hover-only byte sensors never become ready.
        var f = make({ memoryDemand: true });
        compare(f.tips.cpuTitle, "CPU");
        compare(f.tips.cpuText, "Usage: N/A");
        compare(f.tips.memoryText, "Used: N/A");
        compare(f.tips.gpuTitle, "GPU");
        compare(f.tips.gpuText, "Usage: N/A");
        compare(f.tips.diskText, "All disks\nUsed: N/A");
        compare(f.tips.networkText, "All interfaces\nDownload: N/A\nUpload: N/A");
        wait(50);
        compare(f.tips.memoryText, "Used: N/A");
    }

    function test_cpuShowsTimeSplitWhenCollected() {
        var f = make();
        f.cpuUsageMonitor.text = "23.4%";
        f.cpuDetailHistory.userPercent = 12.34;
        compare(f.tips.cpuText, "Usage: 23.4%");
        f.cpuDetailHistory.systemPercent = 4.06;
        compare(f.tips.cpuText, "Usage: 23.4%\nUser 12.3% · System 4.1%");
    }

    function test_memoryBytesOnlyWhileHoveredAndForDefaultSensor() {
        var f = make({ tipSensors: readySensor });
        f.memoryUsageMonitor.text = "30.8%";
        wait(50);
        compare(f.tips.memoryText, "Used: 30.8%");
        f.memoryDemand = true;
        tryCompare(f.tips, "memoryText", "Used: 30.8%\n19.6 GiB of 60.5 GiB");
        f.memoryUsageMonitor.sensorId = "memory/swap/usedPercent";
        compare(f.tips.memoryText, "Used: 30.8%");
        f.memoryUsageMonitor.sensorId = "memory/physical/usedPercent";
        f.memoryDemand = false;
        compare(f.tips.memoryText, "Used: 30.8%");
    }

    function test_gpuListsOnlyConfiguredMetrics() {
        var f = make();
        f.gpuUsageMonitor.text = "31%";
        f.selectedGpu = { key: "gpu0", name: "Radeon" };
        compare(f.tips.gpuTitle, "GPU 1: Radeon");
        compare(f.tips.gpuText, "Usage: 31%");
        f.gpuMonitorSet = {
            memory: fakeMonitor.createObject(f, { sensorId: "gpu/gpu0/usedVram", text: "17%" }),
            temperature: fakeMonitor.createObject(f, { sensorId: "", status: "disabled", text: "N/A" })
        };
        compare(f.tips.gpuText, "Usage: 31%\nMemory: 17%");
    }

    function test_networkNamesItsScope() {
        var f = make();
        f.networkModel.scopeText = "Automatic: Ethernet (eno1)";
        f.networkDownloadMonitor.text = "1.2 MiB/s";
        f.networkUploadMonitor.text = "40 KiB/s";
        compare(f.tips.networkText, "Automatic: Ethernet (eno1)\nDownload: 1.2 MiB/s\nUpload: 40 KiB/s");
    }

    function test_diskActivityAppearsWhenConfigured() {
        var f = make();
        f.diskUsageMonitor.text = "56%";
        compare(f.tips.diskText, "All disks\nUsed: 56%");
        f.diskReadMonitor.status = "unavailable";
        f.diskReadMonitor.text = "N/A";
        f.diskWriteMonitor.status = "available";
        f.diskWriteMonitor.text = "272 KiB/s";
        compare(f.tips.diskText, "All disks\nUsed: 56%\nRead N/A · Write 272 KiB/s");
    }
}
