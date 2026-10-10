import QtQml
import "CpuCounters.js" as CpuCounters

QtObject {
    id: collector

    // provider(callback) returns {exitCode, exitStatus?, stdout, stderr?}. Tests
    // can hold/reorder callbacks without launching commands or reading hardware.
    property var provider: null
    property var clock: function() { return Date.now(); }
    property bool active: false
    property int refreshInterval: 1500
    readonly property bool inFlight: _inFlight
    readonly property var userSamples: _history.samplesFor("cpu.user", "/proc/stat:cpu")
    readonly property var systemSamples: _history.samplesFor("cpu.system", "/proc/stat:cpu")
    readonly property var idleSamples: _history.samplesFor("cpu.idle", "/proc/stat:cpu")
    property var userPercent: null
    property var systemPercent: null
    property var idlePercent: null
    property string status: "disabled"
    property string errorCode: ""

    property bool _inFlight: false
    property bool _completed: false
    property int _generation: 0
    property var _baseline: null
    property HistoryStore _history: HistoryStore { sampleInterval: collector.refreshInterval }
    property Timer _timer: Timer {
        interval: Math.max(500, collector.refreshInterval)
        repeat: true
        running: collector.active && collector._completed
        onTriggered: collector.refresh()
    }

    function record(reading, timestamp) {
        userPercent = reading.user;
        systemPercent = reading.system;
        idlePercent = reading.idle;
        status = reading.status;
        errorCode = reading.errorCode;
        _history.append("cpu.user", "/proc/stat:cpu", reading.user, reading.status, timestamp);
        _history.append("cpu.system", "/proc/stat:cpu", reading.system, reading.status, timestamp);
        _history.append("cpu.idle", "/proc/stat:cpu", reading.idle, reading.status, timestamp);
    }

    function demandChanged() {
        if (!_completed) {
            return;
        }
        _generation++;
        _baseline = null;
        record(CpuCounters.empty(active ? "loading" : "stale", null), clock());
        if (active) {
            refresh();
        }
    }

    function advance() {
        _history.advance(clock());
    }

    function refresh() {
        if (!active || !_completed || _inFlight) {
            return;
        }
        if (typeof provider !== "function") {
            _baseline = null;
            record(CpuCounters.empty("unavailable", null, "read"), clock());
            return;
        }
        var generation = _generation;
        var requestedAt = clock();
        var requestedInterval = refreshInterval;
        _inFlight = true;
        provider(function(result) {
            collector._inFlight = false;
            if (!collector.active || generation !== collector._generation) {
                if (collector.active) {
                    // RunCommand cleans up its source after invoking the callback.
                    Qt.callLater(collector.refresh);
                }
                return;
            }
            var timestamp = collector.clock();
            if (CpuCounters.discontinuity(requestedAt, timestamp, requestedInterval, collector.refreshInterval)) {
                // A pre-suspend command result is not a current counter snapshot.
                collector._baseline = null;
                collector.record(CpuCounters.empty("stale", null), timestamp);
                Qt.callLater(collector.refresh);
                return;
            }
            if (!result || result.exitCode !== 0 || (result.exitStatus !== undefined && result.exitStatus !== 0)) {
                collector._baseline = null;
                collector.record(CpuCounters.empty("unavailable", null, "read"), timestamp);
                return;
            }
            var reading = CpuCounters.observe(collector._baseline, result.stdout, timestamp, collector.refreshInterval);
            collector._baseline = reading.baseline;
            collector.record(reading, timestamp);
        });
    }

    onActiveChanged: demandChanged()
    onProviderChanged: demandChanged()
    Component.onCompleted: {
        _completed = true;
        if (active) {
            demandChanged();
        }
    }
}
