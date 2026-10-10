import QtQml
import "History.js" as History

QtObject {
    id: store

    // The owning sampler calls append on every tick, including unchanged values
    // and missing states. Views only bind to samplesFor(), windowDuration and now.
    // Source/device identity belongs in sourceKey; metricId identifies the value.
    // Use one shared tick timestamp, in nondecreasing order. On clock rollback all
    // series restart, including inactive ones. Returned arrays are read-only to callers.
    property var clock: function() { return Date.now(); }
    property int sampleInterval: 1000
    property int retentionDuration: History.retentionDuration
    property int maxSamples: History.maximumSamples
    property int maxSeries: History.maximumSeries
    property var _state: History.createState()
    readonly property real now: _state.now
    readonly property int seriesCount: _state.series.length

    function options() {
        return { sampleInterval: sampleInterval, retentionDuration: retentionDuration,
            maxSamples: maxSamples, maxSeries: maxSeries };
    }

    function append(metricId, sourceKey, value, status, timestamp) {
        var time = timestamp === undefined ? clock() : timestamp;
        _state = History.append(_state, metricId, sourceKey, value, status, time, options());
    }

    function samplesFor(metricId, sourceKey) {
        return History.samplesFor(_state, metricId, sourceKey);
    }

    // Call even when all collection is paused to expire inactive device histories
    // and move the render window. There is deliberately no timer in this object.
    function advance(timestamp) {
        var time = timestamp === undefined ? clock() : timestamp;
        _state = History.prune(_state, time, options());
    }

    function clear() {
        _state = History.createState();
    }
}
