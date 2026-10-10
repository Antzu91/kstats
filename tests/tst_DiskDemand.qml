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
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property bool popupOpen: false
            property bool diskTab: false
            property int sensorUpdateRate: 10000
            readonly property bool diskDetailsVisible: popupOpen && diskTab
            property alias page: page
            Local.DiskPage {
                id: page
                width: 500
                height: 700
                rootItem: fixture
                visible: fixture.diskTab
                commandComponent: fakeCommand
                applicationsComponent: fakeApplications
            }
        }
    }
    function init() { requests = []; pending = []; }
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
        fixture.page.refresh();
        compare(requests.length, 4);
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
}
