import QtQuick

// A lightweight bridge from one monitor to a shared store. The owner supplies
// ticks; demand/source and availability loss record gaps between ticks.
Item {
    id: sampler

    required property var monitor
    required property var store
    property bool usePercent: true
    readonly property bool active: monitor && monitor.collecting
    readonly property string metricId: monitor ? monitor.metricId : ""
    readonly property string sourceKey: monitor ? monitor.sourceKey : ""
    readonly property var samples: store.samplesFor(metricId, sourceKey)

    property bool initialized: false
    property bool wasActive: false
    property bool wasAvailable: false
    property var previousMonitor: null
    property string previousMetricId: ""
    property string previousSourceKey: ""
    property bool sampling: false
    property real samplingTimestamp: 0
    property string samplingLossStatus: ""
    property var preserveGapAt: null

    function appendGap(metric, source, status, timestamp) {
        var points = store.samplesFor(metric, source);
        var last = points.length > 0 ? points[points.length - 1] : null;
        if (!last || last.timestamp !== timestamp || last.status === "available") {
            store.append(metric, source, null, status, timestamp);
        }
    }

    function transition() {
        if (!initialized || !store) {
            return;
        }
        if (wasActive === active && previousMonitor === monitor
                && previousMetricId === metricId && previousSourceKey === sourceKey) {
            return;
        }
        var timestamp = sampling ? samplingTimestamp : store.clock();
        // Keep a transition gap if a regular tick arrives in the same millisecond.
        preserveGapAt = previousMetricId.length > 0 ? timestamp : null;
        if (wasActive && previousMetricId.length > 0) {
            appendGap(previousMetricId, previousSourceKey, "disabled", timestamp);
        }
        wasActive = active;
        wasAvailable = active && monitor.status === "available";
        previousMonitor = monitor;
        previousMetricId = metricId;
        previousSourceKey = sourceKey;
        // A resumed source starts with a gap even if a cached reading is present.
        if (active && metricId.length > 0) {
            appendGap(metricId, sourceKey, "loading", timestamp);
        }
    }

    function availabilityChanged() {
        if (!initialized || !monitor || !store) {
            return;
        }
        transition();
        var available = active && monitor.status === "available";
        var lost = wasAvailable && !available;
        wasAvailable = available;
        if (!lost || !active) {
            return;
        }
        if (sampling) {
            // snapshot() may emit statusChanged synchronously. Do not read a
            // later clock or append recursively: the enclosing tick owns time.
            samplingLossStatus = monitor.status;
        } else {
            preserveGapAt = store.clock();
            appendGap(metricId, sourceKey, monitor.status, preserveGapAt);
        }
    }

    function sample(timestamp) {
        if (!active || sampling) {
            return;
        }
        var sampledMonitor = monitor;
        var sampledMetric = metricId;
        var sampledSource = sourceKey;
        if (preserveGapAt !== timestamp) {
            preserveGapAt = null;
        }
        sampling = true;
        samplingTimestamp = timestamp;
        samplingLossStatus = "";
        var snapshot;
        try {
            snapshot = monitor.snapshot(timestamp);
        } finally {
            sampling = false;
        }
        if (!active || monitor !== sampledMonitor || metricId !== sampledMetric || sourceKey !== sampledSource) {
            return;
        }
        if (samplingLossStatus.length > 0) {
            preserveGapAt = timestamp;
            appendGap(metricId, sourceKey, snapshot.status === "available" ? samplingLossStatus : snapshot.status, timestamp);
            return;
        }
        if (preserveGapAt === timestamp && snapshot.status === "available") {
            return;
        }
        store.append(metricId, sourceKey, usePercent ? monitor.percent : snapshot.value,
            snapshot.status, timestamp);
    }

    Connections {
        target: sampler.monitor
        ignoreUnknownSignals: true
        function onStatusChanged() { sampler.availabilityChanged(); }
    }

    onMonitorChanged: transition()
    onActiveChanged: transition()
    onMetricIdChanged: transition()
    onSourceKeyChanged: transition()
    Component.onCompleted: {
        initialized = true;
        transition();
    }
    Component.onDestruction: {
        if (initialized && wasActive && store && previousMetricId.length > 0) {
            store.append(previousMetricId, previousSourceKey, null, "disabled", store.clock());
        }
    }
}
