import QtQuick

// A lightweight bridge from one monitor to a shared store. The owner supplies
// ticks; demand/source transitions record gaps synchronously between ticks.
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
    property string previousMetricId: ""
    property string previousSourceKey: ""

    function transition() {
        if (!initialized || !store) {
            return;
        }
        var timestamp = store.clock();
        if (wasActive && previousMetricId.length > 0) {
            store.append(previousMetricId, previousSourceKey, null, "disabled", timestamp);
        }
        wasActive = active;
        previousMetricId = metricId;
        previousSourceKey = sourceKey;
        // A resumed source starts with a gap even if a cached reading is present.
        if (active && metricId.length > 0) {
            store.append(metricId, sourceKey, null, "loading", timestamp);
        }
    }

    function sample(timestamp) {
        if (!active) {
            return;
        }
        var snapshot = monitor.snapshot(timestamp);
        store.append(metricId, sourceKey, usePercent ? monitor.percent : snapshot.value,
            snapshot.status, timestamp);
    }

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
