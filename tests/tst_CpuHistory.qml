import QtQuick
import QtTest
import "../contents/ui" as Local
import "../contents/ui/History.js" as History

TestCase {
    id: testCase
    name: "CpuHistory"
    property real fakeNow: 1000
    property var pending: []
    property var collector: null

    Component {
        id: collectorComponent
        Local.CpuHistory {
            refreshInterval: 1000
            clock: function() { return testCase.fakeNow; }
            provider: function(callback) { testCase.pending.push(callback); }
        }
    }

    function init() {
        fakeNow = 1000;
        pending = [];
        collector = createTemporaryObject(collectorComponent, testCase);
        verify(collector !== null);
    }

    function deliver(text, time, exitCode, exitStatus) {
        verify(pending.length > 0);
        fakeNow = time;
        pending.shift()({ stdout: text, stderr: "", exitCode: exitCode || 0, exitStatus: exitStatus || 0 });
    }

    function establishAvailable() {
        collector.active = true;
        deliver("100 0 0 100 0 0 0 0", 1100);
        fakeNow = 2000;
        collector.refresh();
        deliver("110 0 0 190 0 0 0 0", 2100);
        compare(collector.status, "available");
        compare(collector.userPercent, 10);
    }

    function test_hiddenDoesNotRequestAndOnlyOneRequestCanRun() {
        collector.refresh();
        compare(pending.length, 0);
        collector.active = true;
        compare(pending.length, 1);
        compare(collector.inFlight, true);
        collector.refresh();
        collector.refresh();
        compare(pending.length, 1);
        deliver("0 0 0 100 0 0 0 0", 1100);
        compare(collector.inFlight, false);
        compare(collector.status, "loading");
    }

    function test_pauseRecordsGapAndRejectsOldCompletionAfterResume() {
        establishAvailable();
        fakeNow = 3000;
        collector.refresh();
        fakeNow = 3100;
        collector.active = false;
        compare(collector.status, "stale");
        compare(collector.userPercent, null);
        fakeNow = 3200;
        collector.active = true;
        compare(pending.length, 1); // The old request still owns the command source.
        compare(collector.status, "loading");
        deliver("9999 0 0 9999 0 0 0 0", 3300);
        compare(collector.status, "loading");
        tryVerify(function() { return pending.length === 1; });
        deliver("200 0 0 200 0 0 0 0", 3400);
        compare(collector.status, "loading");
        fakeNow = 4000;
        collector.refresh();
        deliver("220 0 0 280 0 0 0 0", 4100);
        compare(collector.userPercent, 20);
        compare(History.segments(collector.userSamples, 60000, 4100).length, 2);
        verify(collector.userSamples.every(function(point) { return point.value === null || point.value <= 20; }));
    }

    function test_hiddenCompletionDoesNotMutateHistory() {
        collector.active = true;
        fakeNow = 1200;
        collector.active = false;
        var before = collector.userSamples;
        deliver("100 0 0 100 0 0 0 0", 1300);
        compare(collector.userSamples, before);
        compare(collector.status, "stale");
        compare(collector.inFlight, false);
    }

    function test_suspendedInFlightRequestIsDiscarded() {
        establishAvailable();
        fakeNow = 3000;
        collector.refresh();
        deliver("500 0 0 500 0 0 0 0", 100000);
        compare(collector.status, "stale");
        compare(collector.userPercent, null);
        tryVerify(function() { return pending.length === 1; });
        deliver("1000 0 0 1000 0 0 0 0", 100100);
        compare(collector.status, "loading");
        fakeNow = 101000;
        collector.refresh();
        deliver("1010 0 0 1090 0 0 0 0", 101100);
        compare(collector.status, "available");
        compare(collector.userPercent, 10);
        compare(History.segments(collector.userSamples, 300000, 101100).length, 2);
    }

    function test_failuresResetBaseline_data() {
        return [
            { tag: "exit-code", text: "100 0 0 100 0 0 0 0", exitCode: 1, exitStatus: 0, errorCode: "read" },
            { tag: "crash", text: "100 0 0 100 0 0 0 0", exitCode: 0, exitStatus: 1, errorCode: "read" },
            { tag: "parse", text: "broken", exitCode: 0, exitStatus: 0, errorCode: "format" }
        ];
    }

    function test_failuresResetBaseline(data) {
        establishAvailable();
        fakeNow = 3000;
        collector.refresh();
        deliver(data.text, 3100, data.exitCode, data.exitStatus);
        compare(collector.status, "unavailable");
        compare(collector.errorCode, data.errorCode);
        compare(collector.userPercent, null);
        compare(collector.userSamples[collector.userSamples.length - 1].value, null);
        fakeNow = 4000;
        collector.refresh();
        deliver("200 0 0 200 0 0 0 0", 4100);
        compare(collector.status, "loading");
        fakeNow = 5000;
        collector.refresh();
        deliver("220 0 0 280 0 0 0 0", 5100);
        compare(collector.status, "available");
        compare(collector.userPercent, 20);
    }

    function test_providerReplacementInvalidatesPendingResult() {
        collector.active = true;
        collector.provider = function(callback) { testCase.pending.push(callback); };
        deliver("100 0 0 100 0 0 0 0", 1100);
        compare(collector.status, "loading");
        tryVerify(function() { return pending.length === 1; });
        deliver("200 0 0 200 0 0 0 0", 1200);
        compare(collector.status, "loading");
    }

    function test_inactiveHistoriesExpireWhenSharedClockAdvances() {
        establishAvailable();
        collector.active = false;
        fakeNow = 1000000;
        collector.advance();
        compare(collector.userSamples.length, 0);
        compare(collector.systemSamples.length, 0);
        compare(collector.idleSamples.length, 0);
    }
}
