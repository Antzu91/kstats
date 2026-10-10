import QtQuick
import QtTest
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "CpuCoreBars"
    when: windowShown
    property real time: 100000
    property var pending: []

    function i18nc(context, text) { return text; }
    Component {
        id: factory
        Local.CpuCoreBars {
            clock: function() { return testCase.time; }
            provider: function(callback) { testCase.pending.push(callback); }
        }
    }
    function init() { time = 100000; pending = []; }
    function make() {
        var bars = createTemporaryObject(factory, testCase);
        verify(bars !== null);
        return bars;
    }
    function finish(idle) {
        var callback = pending.shift();
        verify(callback !== undefined);
        callback({ exitCode: 0, stdout: "cpu0 0 0 0 " + idle + " 0 0 0 0 0 0", stderr: "" });
    }
    function test_firstSnapshotAndConstantZero() {
        var bars = make();
        compare(pending.length, 0);
        bars.active = true;
        finish(100);
        compare(bars.cores[0].usage, null);
        time += 1000;
        bars.refresh();
        finish(200);
        compare(bars.cores[0].usage, 0);
        compare(bars.averagePercent(), 0);
    }
    function test_pauseDropsBaselineAndRejectsOldCompletion() {
        var bars = make();
        bars.active = true;
        bars.active = false;
        time += 100;
        bars.active = true;
        compare(pending.length, 1);
        finish(100);
        compare(bars.cores.length, 0);
        wait(0);
        compare(pending.length, 1);
        finish(200);
        compare(bars.cores[0].usage, null);
    }
    function test_resumeAndCounterRollbackRequireFreshBaseline() {
        var bars = make();
        bars.active = true;
        finish(100);
        time += 60000;
        bars.refresh();
        finish(200);
        compare(bars.cores[0].usage, null);
        time += 1000;
        bars.refresh();
        finish(50);
        compare(bars.cores[0].usage, null);
    }
    function test_singleInFlightAndSuspendCompletion() {
        var bars = make();
        bars.active = true;
        bars.refresh();
        compare(pending.length, 1);
        time += 60000;
        finish(100);
        compare(bars.cores.length, 0);
        wait(0);
        compare(pending.length, 1);
        finish(200);
        compare(bars.cores[0].usage, null);
    }
}
