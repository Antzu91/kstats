import QtQuick
import QtTest
import "../contents/ui/CpuCounters.js" as CpuCounters

TestCase {
    name: "CpuCounters"

    function test_validSevenAndTenFieldSnapshots() {
        compare(CpuCounters.parse("100 2 30 400 5 6 7\n"), [100, 2, 30, 400, 5, 6, 7, 0]);
        compare(CpuCounters.parse("100 2 30 400 5 6 7 8 9 10\n"), [100, 2, 30, 400, 5, 6, 7, 8]);
    }

    function test_invalidSnapshots_data() {
        return [
            { tag: "empty", text: "" }, { tag: "whitespace", text: " \n " },
            { tag: "short", text: "1 2 3" }, { tag: "null", text: null },
            { tag: "negative", text: "1 2 -1 4 5 6 7" },
            { tag: "nonfinite", text: "1 2 NaN 4 5 6 7" },
            { tag: "decimal", text: "1 2 3.1 4 5 6 7" },
            { tag: "hex", text: "1 2 0xff 4 5 6 7" },
            { tag: "unsafe", text: "9007199254740992 2 3 4 5 6 7" },
            { tag: "unsafe-total", text: "9007199254740991 2 3 4 5 6 7" },
            { tag: "extra", text: "1 2 3 4 5 6 7 8 9 10 11" },
            { tag: "bad-guest", text: "1 2 3 4 5 6 7 8 broken 10" }
        ];
    }

    function test_invalidSnapshots(data) {
        compare(CpuCounters.parse(data.text), null);
        var observed = CpuCounters.observe(null, data.text, 1000, 1000);
        compare(observed.status, "unavailable");
        compare(observed.baseline, null);
        compare(observed.user, null);
    }

    function test_deltasDoNotDoubleCountGuestTime() {
        var first = CpuCounters.observe(null, "100 0 50 500 0 0 0 0 80 0", 1000, 1000);
        compare(first.status, "loading");
        var second = CpuCounters.observe(first.baseline, "120 0 60 570 0 0 0 0 100 0", 2000, 1000);
        compare(second.status, "available");
        compare(second.user, 20);
        compare(second.system, 10);
        compare(second.idle, 70);
    }

    function test_constantZeroIsAvailableWhenIdleCountersAdvance() {
        var first = CpuCounters.observe(null, "0 0 0 100 0 0 0 0", 1000, 1000);
        var second = CpuCounters.observe(first.baseline, "0 0 0 200 0 0 0 0", 2000, 1000);
        compare(second.status, "available");
        compare(second.user, 0);
        compare(second.system, 0);
        compare(second.idle, 100);
    }

    function test_rollbackCannotHideWithinAggregatedCategory() {
        var first = CpuCounters.observe(null, "100 100 0 100 0 0 0 0", 1000, 1000);
        var second = CpuCounters.observe(first.baseline, "90 200 0 200 0 0 0 0", 2000, 1000);
        compare(second.status, "unavailable");
        compare(second.user, null);
        var third = CpuCounters.observe(second.baseline, "100 200 0 290 0 0 0 0", 3000, 1000);
        compare(third.status, "available");
        compare(third.user, 10);
    }

    function test_unchangedCountersAreNotInventedZeroUsage() {
        var first = CpuCounters.observe(null, "100 0 0 100 0 0 0 0", 1000, 1000);
        var second = CpuCounters.observe(first.baseline, "100 0 0 100 0 0 0 0", 2000, 1000);
        compare(second.status, "unavailable");
        compare(second.user, null);
    }

    function test_pauseAndBackwardTimeRestartBaseline() {
        var first = CpuCounters.observe(null, "100 0 0 100 0 0 0 0", 1000, 1000);
        var resumed = CpuCounters.observe(first.baseline, "500 0 0 500 0 0 0 0", 100000, 1000);
        compare(resumed.status, "loading");
        compare(resumed.user, null);
        var rollback = CpuCounters.observe(resumed.baseline, "600 0 0 600 0 0 0 0", 500, 1000);
        compare(rollback.status, "loading");
        compare(rollback.baseline.timestamp, 500);
    }

    function test_intervalChangesKeepValidBaseline() {
        var first = CpuCounters.observe(null, "100 0 0 100 0 0 0 0", 1000, 500);
        var second = CpuCounters.observe(first.baseline, "110 0 0 190 0 0 0 0", 6000, 5000);
        compare(second.status, "available");
        compare(second.user, 10);
        var third = CpuCounters.observe(second.baseline, "120 0 0 280 0 0 0 0", 6500, 500);
        compare(third.status, "available");
        compare(third.user, 10);
    }
}
