import QtQuick
import QtTest
import "../contents/ui" as Local
import "../contents/ui/History.js" as History

TestCase {
    id: testCase
    name: "History"

    property real fakeNow: 1000000
    property var observed: store.samplesFor("cpu", "source")

    Local.HistoryStore {
        id: store
        clock: function() { return testCase.fakeNow; }
    }

    function init() {
        store.clear();
        store.sampleInterval = 1000;
        store.retentionDuration = 900000;
        store.maxSamples = 1802;
        store.maxSeries = 64;
        fakeNow = 1000000;
    }

    function point(time, value, status, source) {
        return { timestamp: time, value: value, status: status || "available", sourceKey: source || "source" };
    }

    function test_constantZeroUsesInjectedClockAndReactiveBinding() {
        store.append("cpu", "source", 0, "available");
        fakeNow += 1000;
        store.append("cpu", "source", 0, "available");
        compare(observed.length, 2);
        compare(observed[0], point(1000000, 0));
        compare(observed[1], point(1001000, 0));
        compare(store.now, fakeNow);
        compare(History.segments(observed, 60000, fakeNow).length, 1);
        compare(History.xPosition(observed[0].timestamp, 60000, fakeNow), 59 / 60);
        compare(History.xPosition(observed[1].timestamp, 60000, fakeNow), 1);
    }

    function test_invalidValues_data() {
        return [
            { tag: "null", value: null }, { tag: "undefined", value: undefined },
            { tag: "negative", value: -1 }, { tag: "nan", value: NaN },
            { tag: "infinity", value: Infinity }, { tag: "string", value: "20" },
            { tag: "boolean", value: false }, { tag: "empty", value: "" }
        ];
    }

    function test_invalidValues(data) {
        store.append("cpu", "source", 25, "available", 1000);
        store.append("cpu", "source", data.value, "available", 2000);
        store.append("cpu", "source", 30, "available", 3000);
        var samples = store.samplesFor("cpu", "source");
        compare(samples[1].value, null);
        compare(samples[1].status, "unavailable");
        compare(History.segments(samples, 60000, 3000).length, 2);
    }

    function test_nonAvailableStates_data() {
        return ["loading", "unavailable", "stale", "disabled", "unknown"].map(function(status) {
            return { tag: status, status: status };
        });
    }

    function test_nonAvailableStates(data) {
        store.append("cpu", "source", 77, data.status, 1000);
        var actual = store.samplesFor("cpu", "source")[0];
        compare(actual.value, null);
        compare(actual.status, data.status === "unknown" ? "unavailable" : data.status);
        compare(History.segments([actual], 60000, 1000).length, 0);
    }

    function test_intervalChangePreservesCoordinates() {
        store.sampleInterval = 500;
        store.append("cpu", "source", 50, "available", 10000);
        store.append("cpu", "source", 50, "available", 10500);
        store.sampleInterval = 5000;
        store.append("cpu", "source", 50, "available", 15500);
        store.sampleInterval = 500;
        store.append("cpu", "source", 50, "available", 16000);
        compare(observed.length, 4);
        compare(History.segments(observed, 60000, 16000).length, 1);
        compare(History.xPosition(10000, 60000, 16000), 0.9);
        compare(History.xPosition(10500, 60000, 16000), 1 - 5500 / 60000);
    }

    function test_forwardDiscontinuityCreatesGapWithoutBackfill() {
        store.append("cpu", "source", 10, "available", 10000);
        store.append("cpu", "source", 10, "available", 11000);
        store.append("cpu", "source", 10, "available", 100000);
        compare(observed.length, 4);
        compare(observed[2].status, "stale");
        compare(observed[2].value, null);
        verify(observed[2].timestamp > 11000 && observed[2].timestamp < 100000);
        compare(History.segments(observed, 300000, 100000).length, 2);
    }

    function test_backwardClockRestartsSeries() {
        store.append("cpu", "source", 10, "available", 10000);
        store.append("cpu", "source", 20, "available", 11000);
        store.append("cpu", "source", 30, "available", 5000);
        compare(observed.length, 1);
        compare(observed[0], point(5000, 30));
    }

    function test_sameTimestampReplacesAndInvalidTimestampDoesNothing() {
        store.append("cpu", "source", 10, "available", 10000);
        store.append("cpu", "source", 20, "available", 10000);
        compare(observed.length, 1);
        compare(observed[0].value, 20);
        var before = store._state;
        var invalid = [NaN, Infinity, -1, null, "12000"];
        for (var i = 0; i < invalid.length; i++) {
            store.append("cpu", "source", 30, "available", invalid[i]);
            compare(store._state, before);
        }
    }

    function test_backwardClockWhilePausedAlsoRestartsInactiveSeries() {
        store.append("cpu", "source", 10, "available", 10000);
        store.append("network", "eth0", 20, "available", 11000);
        store.advance(5000);
        compare(store.seriesCount, 0);
        compare(store.now, 5000);
        store.append("cpu", "source", 30, "available", 6000);
        compare(observed, [point(6000, 30)]);
    }

    function test_explicitPausePreservedOnQuickResume() {
        store.append("cpu", "source", 10, "available", 10000);
        store.append("cpu", "source", null, "stale", 10100);
        store.append("cpu", "source", 10, "available", 10200);
        compare(History.segments(observed, 60000, 10200).length, 2);
    }

    function test_capsCannotBeIncreasedBeyondRetentionPolicy() {
        var options = History.optionsOrDefault({ retentionDuration: 9999999, maxSamples: 999999, maxSeries: 9999 });
        compare(options.retention, 900000);
        compare(options.maxSamples, 1802);
        compare(options.maxSeries, 64);
        store.retentionDuration = 1000;
        store.maxSamples = 3;
        for (var i = 0; i < 5; i++) {
            store.append("cpu", "source", 10, "available", 1000 + i * 500);
        }
        compare(observed.length, 3);
        store.advance(4001);
        compare(store.seriesCount, 0);
    }

    function test_sourceIdentityAndReturnGap() {
        store.append("network", "eth0", 10, "available", 1000);
        store.append("network", "eth0", 10, "available", 2000);
        store.append("network", "wlan0", 20, "available", 2500);
        store.append("network", "eth0", 15, "available", 3000);
        store.append("network", "eth0", 15, "available", 4000);
        store.append("cpu", "eth0", 70, "available", 4000);
        var ethernet = store.samplesFor("network", "eth0");
        compare(ethernet.length, 5);
        compare(ethernet[2].value, null);
        compare(History.segments(ethernet, 60000, 4000).length, 2);
        compare(store.samplesFor("network", "wlan0").length, 1);
        compare(store.samplesFor("cpu", "eth0")[0].value, 70);
        compare(store.samplesFor("missing", "eth0").length, 0);
    }

    function test_keysCannotCollide() {
        store.append("a/b", "c", 1, "available", 1000);
        store.append("a", "b/c", 2, "available", 1000);
        store.append("__proto__", "constructor", 3, "available", 1000);
        compare(store.seriesCount, 3);
        compare(store.samplesFor("a/b", "c")[0].value, 1);
        compare(store.samplesFor("a", "b/c")[0].value, 2);
        compare(store.samplesFor("__proto__", "constructor")[0].value, 3);
    }

    function test_retentionBoundAndBoundaryPredecessor() {
        var state = History.createState();
        var options = { sampleInterval: 500 };
        for (var i = 0; i < 4000; i++) {
            state = History.append(state, "cpu", "source", 20, "available", i * 500, options);
        }
        var samples = History.samplesFor(state, "cpu", "source");
        compare(samples.length, 1802);
        compare(samples[0].timestamp, 3999 * 500 - 900000 - 500);
        compare(samples[samples.length - 1].timestamp, 3999 * 500);
        compare(History.segments(samples, 900000, 3999 * 500)[0][0].timestamp, 3999 * 500 - 900000);
        // Faster accidental appends also obey the hard memory ceiling.
        for (var j = 1; j <= 200; j++) {
            state = History.append(state, "cpu", "source", 20, "available", 3999 * 500 + j, options);
        }
        compare(History.samplesFor(state, "cpu", "source").length, 1802);
    }

    function test_inactiveExpiryAndDeviceChurn() {
        store.maxSeries = 3;
        for (var i = 0; i < 5; i++) {
            store.append("network", "device" + i, i, "available", 1000 + i * 1000);
        }
        compare(store.seriesCount, 3);
        compare(store.samplesFor("network", "device0").length, 0);
        compare(store.samplesFor("network", "device2").length, 1);
        // Sampling an older series refreshes its eviction order.
        store.append("network", "device2", 10, "available", 6000);
        store.append("network", "device5", 10, "available", 7000);
        compare(store.samplesFor("network", "device3").length, 0);
        fakeNow = 907001;
        store.advance();
        compare(store.seriesCount, 0);
        compare(store.now, fakeNow);
    }

    function test_immutableStateAndProviderInjection() {
        var oldState = History.createState();
        var provider = function(time) { return { value: time % 2, status: "available", sourceKey: "fake" }; };
        var reading = provider(1000);
        var next = History.append(oldState, "cpu", reading.sourceKey, reading.value, reading.status, 1000);
        compare(oldState.series.length, 0);
        var originalSamples = next.series[0].samples;
        var later = History.append(next, "cpu", "fake", 1, "available", 2000);
        compare(originalSamples.length, 1);
        compare(later.series[0].samples.length, 2);
    }

    function test_renderWindows_data() {
        return [60000, 300000, 900000].map(function(duration) {
            return { tag: String(duration), duration: duration };
        });
    }

    function test_renderWindows(data) {
        var samples = [point(0, 10), point(450000, 20), point(900000, 30)];
        var result = History.segments(samples, data.duration, 900000);
        compare(result.length, 1);
        compare(result[0][0].timestamp, 900000 - data.duration);
        compare(History.xPosition(result[0][0].timestamp, data.duration, 900000), 0);
        compare(History.xPosition(result[0][result[0].length - 1].timestamp, data.duration, 900000), 1);
        compare(samples.length, 3); // Changing the window never discards stored history.
    }

    function test_segmentsClipOnlyContinuousAvailableReadings() {
        var samples = [point(1000, 10), point(3000, 30), point(4000, null, "stale"),
            point(5000, 50), point(7000, 70)];
        var result = History.segments(samples, 4000, 6000);
        compare(result.length, 2);
        compare(result[0], [point(2000, 20), point(3000, 30)]);
        compare(result[1], [point(5000, 50), point(6000, 60)]);
        compare(History.segments([point(1000, 10), point(4000, null, "unavailable")], 1000, 4000).length, 0);
        compare(History.segments([point(1000, 10), point(2000, 20, "available", "other")], 60000, 2000).length, 2);
        compare(History.segments([point(2000, 10), point(1000, 20)], 60000, 2000).length, 2);
        compare(History.segments([point(1000, 10), point(2000, -1), point(3000, 20)], 60000, 3000).length, 2);
        compare(History.segments([0, 1, 2], 60000, 3000).length, 0);
    }

    function test_nearestObservationIncludesMissingState() {
        var samples = [point(1000, 10), point(2000, null, "stale"), point(3000, 30)];
        compare(History.nearestSample(samples, 1400, 60000, 3000), samples[0]);
        compare(History.nearestSample(samples, 2100, 60000, 3000), samples[1]);
        compare(History.nearestSample(samples, 2900, 60000, 3000), samples[2]);
        compare(History.nearestSample(samples, 4000, 60000, 3000), null);
        compare(History.nearestSample(samples, 1000, 1000, 3000), null);
        compare(History.nearestSample([], 1000, 60000, 3000), null);
    }
}
