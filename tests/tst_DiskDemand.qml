import QtQuick
import QtTest
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "DiskDemand"
    when: windowShown
    visible: true
    property var requests: []
    property var pending: []
    function i18nc(context, text) { return text; }

    Component {
        id: fakeCommand
        QtObject {
            function exec(command, callback) {
                testCase.requests.push(command);
                testCase.pending.push(callback);
            }
        }
    }
    Component { id: fakeApplications; Item { implicitHeight: 1 } }
    // SMART reads are covered by tst_DiskHealthCollector; here they report one
    // failing drive so the Health view and attention marker are exercised.
    property var healthRequests: []
    Component {
        id: fakeHealthCommand
        QtObject {
            function exec(command, callback) {
                testCase.healthRequests.push(command);
                if (command.indexOf("GetManagedObjects") < 0) {
                    return;
                }
                var path = "/org/freedesktop/UDisks2/drives/Test_SSD";
                var objects = {};
                objects[path] = {
                    "org.freedesktop.UDisks2.Drive": { Model: { type: "s", data: "Test SSD" } },
                    "org.freedesktop.UDisks2.Drive.Ata": {
                        SmartSupported: { type: "b", data: true }, SmartEnabled: { type: "b", data: false } }
                };
                objects["/org/freedesktop/UDisks2/block_devices/sda"] = { "org.freedesktop.UDisks2.Block": {
                    Device: { type: "ay", data: [47, 100, 101, 118, 47, 115, 100, 97, 0] }, Drive: { type: "o", data: path } } };
                Qt.callLater(function() {
                    callback({ stdout: JSON.stringify({ type: "a{oa{sa{sv}}}", data: [objects] }), stderr: "", exitCode: 0 });
                });
            }
        }
    }
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property bool popupOpen: false
            property bool diskTab: false
            property int sensorUpdateRate: 10000
            readonly property bool diskDetailsVisible: popupOpen && diskTab
            property QtObject diskScope: QtObject {
                property string scopeText: "All disks"
                property var sensorIds: ({ usage: "", read: "", write: "", used: "", total: "" })
            }
            property QtObject diskUsageMonitor: QtObject {
                property string status: "unavailable"
                property bool available: false
                property string text: "N/A"
            }
            // Aggregate activity sensors cleared in settings: activity stays hidden.
            property QtObject diskReadMonitor: QtObject {
                property string sensorId: ""
                property string status: "disabled"
                property string text: "Off"
            }
            property QtObject diskWriteMonitor: QtObject {
                property string sensorId: ""
                property string status: "disabled"
                property string text: "Off"
            }
            readonly property var diskReadSamples: []
            readonly property var diskWriteSamples: []
            readonly property int historyWindowDuration: 60000
            readonly property real historyNow: 0
            function historyCoverageText(samples) { return ""; }
            property alias page: page
            Local.DiskPage {
                id: page
                width: 500
                height: 700
                rootItem: fixture
                visible: fixture.diskTab
                commandComponent: fakeCommand
                healthCommandComponent: fakeHealthCommand
                applicationsComponent: fakeApplications
            }
        }
    }
    function init() {
        requests = [];
        pending = [];
        healthRequests = [];
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }
    function make(properties) {
        var fixture = createTemporaryObject(fixtureFactory, testCase, properties || {});
        verify(fixture !== null);
        return fixture;
    }
    function deliver(stdout, exitCode) {
        compare(pending.length, 1);
        var callback = pending.shift();
        callback({ stdout: stdout || "", stderr: "", exitCode: exitCode || 0 });
    }
    function finish() {
        deliver('{"blockdevices":[{"name":"sda","type":"disk","size":100000,"mountpoints":["/"]}]}');
        deliver("Filesystem 1B-blocks Used Available Use% Mounted on\n/dev/sda 100000 10000 90000 10% /\n");
        deliver("8 0 sda 1 0 20 0 1 0 40 0\n");
    }

    function test_openDiskTabStartsImmediately() {
        var fixture = make();
        compare(requests.length, 0);
        fixture.popupOpen = true;
        fixture.diskTab = true;
        compare(requests.length, 1);
        finish();
        compare(fixture.page.disks.length, 1);
    }

    function test_reopenPopupWithoutVisibilityChangeStartsImmediately() {
        var fixture = make({ diskTab: true });
        compare(fixture.page.visible, true);
        compare(requests.length, 0);
        fixture.popupOpen = true;
        compare(requests.length, 1);
        finish();
        fixture.popupOpen = false;
        fixture.popupOpen = true;
        compare(requests.length, 4);
        finish();
    }

    function test_initialActiveDemandStartsExactlyOnceAndDoesNotOverlap() {
        var fixture = make({ diskTab: true, popupOpen: true });
        compare(requests.length, 1);
        fixture.page.refresh();
        fixture.page.refresh();
        compare(requests.length, 1);
        finish();
        compare(fixture.page.refreshInFlight, false);
        // Discovery is fresh, so the next refresh only samples activity.
        fixture.page.refresh();
        compare(requests.length, 4);
        compare(requests[3], "cat /proc/diskstats");
        deliver("8 0 sda 3 0 60 0 2 0 80 0\n");
        compare(fixture.page.refreshInFlight, false);
        compare(fixture.page.disks.length, 1);
        compare(fixture.page.disks[0].percent, 10);
    }

    function test_discoveryRefreshesAfterInterval() {
        var time = 100000;
        var fixture = make({ diskTab: true, popupOpen: true });
        fixture.page.clock = function() { return time; };
        finish();
        time += 29000;
        fixture.page.refresh();
        compare(requests[requests.length - 1], "cat /proc/diskstats");
        deliver("8 0 sda 1 0 20 0 1 0 40 0\n");
        time += 2000;
        fixture.page.refresh();
        verify(requests[requests.length - 1].indexOf("lsblk") === 0);
        finish();
        // A clock moving backwards never trusts the cached layout.
        time -= 60000;
        fixture.page.refresh();
        verify(requests[requests.length - 1].indexOf("lsblk") === 0);
        finish();
    }

    function test_failedFilesystemUsageIsNotCached() {
        var fixture = make({ diskTab: true, popupOpen: true });
        deliver('{"blockdevices":[{"name":"sda","type":"disk","size":100000,"mountpoints":["/"]}]}');
        deliver("", 1);
        deliver("8 0 sda 1 0 20 0 1 0 40 0\n");
        compare(fixture.page.layoutSnapshot, null);
        fixture.page.refresh();
        verify(requests[requests.length - 1].indexOf("lsblk") === 0);
        finish();
    }

    function test_hiddenCompletionDoesNotPublishOrContinueRequests_data() {
        return [{ tag: "layout", stage: 0 }, { tag: "usage", stage: 1 }, { tag: "stats", stage: 2 }];
    }
    function test_hiddenCompletionDoesNotPublishOrContinueRequests(data) {
        var fixture = make({ diskTab: true, popupOpen: true });
        if (data.stage > 0) { deliver('{"blockdevices":[]}'); }
        if (data.stage > 1) { deliver(""); }
        fixture.popupOpen = false;
        var count = requests.length;
        deliver("ignored old result");
        compare(requests.length, count);
        compare(fixture.page.refreshInFlight, false);
        compare(fixture.page.disks.length, 0);
        compare(fixture.page.errorText, "");
        fixture.page.refresh();
        compare(requests.length, count);
    }

    function test_reopenDuringPendingRequestRejectsOldResultThenRefreshes() {
        var fixture = make({ diskTab: true, popupOpen: true });
        fixture.page.previousDiskStats = { sda: { readBytes: 100, writeBytes: 100 } };
        fixture.page.previousDiskStatsTime = 1000;
        fixture.popupOpen = false;
        fixture.popupOpen = true;
        compare(requests.length, 1); // Keep the one-request guard until completion.
        compare(fixture.page.previousDiskStatsTime, 0);
        compare(Object.keys(fixture.page.previousDiskStats).length, 0);
        deliver("ignored old result");
        tryVerify(function() { return testCase.requests.length === 2; });
        finish();
        compare(fixture.page.disks.length, 1);
        compare(fixture.page.disks[0].readRate, 0);
        compare(fixture.page.errorText, "");
    }

    function test_failedRequestReleasesGuard_data() {
        return [{ tag: "read", stdout: "", exitCode: 1 }, { tag: "parse", stdout: "invalid json", exitCode: 0 }];
    }
    function test_failedRequestReleasesGuard(data) {
        var fixture = make({ diskTab: true, popupOpen: true });
        deliver(data.stdout, data.exitCode);
        verify(fixture.page.errorText.length > 0);
        compare(fixture.page.refreshInFlight, false);
        fixture.page.refresh();
        compare(requests.length, 2);
        finish();
        compare(fixture.page.errorText, "");
    }

    function test_healthViewShowsDrivesWithoutSmartSafely() {
        var fixture = make({ diskTab: true, popupOpen: true });
        finish();
        tryVerify(function() { return fixture.page.healthSummary("sda") !== null; });
        compare(fixture.page.healthSummary("sda").status, "unknown");
        compare(fixture.page.healthSummary("sda").problems, ["disabled"]);
        fixture.page.currentView = 2;
        wait(20);
        fixture.page.currentView = 1;
        wait(20);
        fixture.page.currentView = 0;
        // Health reads only while the page is visible.
        var count = healthRequests.length;
        fixture.popupOpen = false;
        wait(20);
        compare(healthRequests.length, count);
    }
}
