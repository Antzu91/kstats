import QtQuick
import QtTest
import "../contents/ui" as Local
import "../contents/ui/DiskHealth.js" as DiskHealth

TestCase {
    id: testCase
    name: "DiskHealthCollector"
    when: windowShown
    property var requests: []
    property var pending: []

    readonly property string drivePath: "/org/freedesktop/UDisks2/drives/Test_NVMe_SERIAL"

    Component {
        id: fakeCommand
        QtObject {
            function exec(command, callback) {
                testCase.requests.push(command);
                testCase.pending.push(callback);
            }
        }
    }
    Component {
        id: collectorFactory
        Local.DiskHealthCollector {
            commandComponent: fakeCommand
        }
    }

    function prop(type, data) { return { type: type, data: data }; }
    function objectsJson(withSmart) {
        var objects = {};
        var drive = { "org.freedesktop.UDisks2.Drive": { Model: prop("s", "Test NVMe") } };
        if (withSmart) {
            drive["org.freedesktop.UDisks2.NVMe.Controller"] = { SmartUpdated: prop("t", 1), SmartCriticalWarning: prop("as", []),
                SmartPowerOnHours: prop("t", 10), SmartTemperature: prop("q", 310) };
        }
        objects[drivePath] = drive;
        objects["/org/freedesktop/UDisks2/block_devices/nvme0n1"] = { "org.freedesktop.UDisks2.Block": {
            Device: prop("ay", [47, 100, 101, 118, 47, 110, 118, 109, 101, 48, 110, 49, 0]), Drive: prop("o", drivePath) } };
        return JSON.stringify({ type: "a{oa{sa{sv}}}", data: [objects] });
    }
    function attributesOutput() {
        return DiskHealth.marker + drivePath + "\n"
            + JSON.stringify({ type: "a{sv}", data: [{ percent_used: prop("y", 7) }] }) + "\n";
    }

    function init() {
        requests = [];
        pending = [];
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }
    function make(properties) {
        var collector = createTemporaryObject(collectorFactory, testCase, properties || {});
        verify(collector !== null);
        return collector;
    }
    function deliver(stdout, exitCode) {
        verify(pending.length > 0);
        pending.shift()({ stdout: stdout || "", stderr: "", exitCode: exitCode || 0 });
    }

    function test_inactiveMakesNoRequests() {
        var collector = make();
        wait(20);
        compare(requests.length, 0);
        compare(collector.readStatus, "idle");
    }

    function test_readsBaseAndExtendedHealth() {
        var collector = make({ active: true });
        compare(requests.length, 1);
        compare(requests[0], DiskHealth.managedObjectsCommand);
        deliver(objectsJson(true));
        compare(requests.length, 2);
        verify(requests[1].indexOf("NVMe.Controller SmartGetAttributes") > 0);
        deliver(attributesOutput());
        compare(collector.readStatus, "ready");
        var health = collector.healthFor("nvme0n1");
        verify(health !== null);
        compare(health.model, "Test NVMe");
        compare(health.summary.status, "good");
        compare(health.summary.wearPercent, 7);
        compare(collector.healthFor("sda"), null);
        compare(collector.inFlight, false);
    }

    function test_drivesWithoutSmartSkipAttributeCall() {
        var collector = make({ active: true });
        deliver(objectsJson(false));
        compare(requests.length, 1);
        compare(collector.readStatus, "ready");
        compare(collector.healthFor("nvme0n1").summary.problems, ["unsupported"]);
    }

    function test_unavailableServiceIsReported_data() {
        return [
            { tag: "no system bus", stdout: "Failed to connect to bus", exitCode: 1 },
            { tag: "busctl missing", stdout: "", exitCode: 127 },
            { tag: "garbage", stdout: "{", exitCode: 0 }
        ];
    }
    function test_unavailableServiceIsReported(data) {
        var collector = make({ active: true });
        deliver(data.stdout, data.exitCode);
        compare(collector.readStatus, "unavailable");
        compare(collector.byDevice, {});
        compare(collector.inFlight, false);
        compare(requests.length, 1);
    }

    function test_failedAttributeCallKeepsBaseHealth() {
        var collector = make({ active: true });
        deliver(objectsJson(true));
        deliver("Call failed: Access denied", 1);
        compare(collector.readStatus, "ready");
        compare(collector.healthFor("nvme0n1").summary.status, "good");
        compare(collector.healthFor("nvme0n1").summary.wearPercent, null);
    }

    function test_lateResultAfterHidingIsIgnoredAndKeepsPrevious() {
        var collector = make({ active: true });
        deliver(objectsJson(true));
        deliver(attributesOutput());
        collector.refresh();
        compare(requests.length, 3);
        collector.active = false;
        deliver("Failed to connect to bus", 1);
        // Hidden: no retry, and the previous result stays for the next opening.
        compare(requests.length, 3);
        compare(collector.readStatus, "ready");
        verify(collector.healthFor("nvme0n1") !== null);
        collector.active = true;
        tryVerify(function() { return testCase.requests.length === 4; });
    }

    function test_refreshIsSingleFlight() {
        var collector = make({ active: true });
        collector.refresh();
        collector.refresh();
        compare(requests.length, 1);
    }
}
