import QtQuick

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.formatter as Formatter

// Owns acquisition/lifecycle state. Views may use sensor for metadata, but
// should use value/percent/status for current readings.
Item {
    id: monitor

    property string metricId: ""
    property string sensorId: ""
    property string sourceKey: sensorId
    property string scopeLabel: ""
    property bool active: true
    property int updateRateLimit: 1000
    property string valueMode: "raw"
    property string unavailableText: i18nc("@info:status", "N/A")
    property string disabledText: i18nc("@info:status", "Off")

    // Injectable source and clock permit Qt Quick fixtures without a daemon.
    property var clock: function() { return Date.now(); }
    property Component sensorComponent: Component { Sensors.Sensor {} }
    readonly property var sensor: sensorLoader.item
    readonly property bool collecting: active && enabled && sensorId.length > 0
    readonly property int staleAfter: Math.max(5000, updateRateLimit * 3,
        sensor ? sensor.updateInterval * 3 : 0)
    readonly property int maximumRetryDelay: 30000
    readonly property int generation: state.generation
    readonly property var lastConfirmedAt: state.lastConfirmedAt
    readonly property var lastKnownValue: state.lastKnownValue
    readonly property string status: !collecting ? "disabled"
        : state.timedOut ? (lastKnownValue !== null ? "stale" : "unavailable")
        : sensor && (sensor.status === Sensors.Sensor.Error || sensor.status === Sensors.Sensor.Removed) ? "unavailable"
        : state.invalidReading ? "unavailable"
        : sensor && sensor.enabled && sensor.status === Sensors.Sensor.Ready && state.received ? "available"
        : "loading"
    readonly property bool available: status === "available"
    readonly property var value: available ? state.reading : null
    readonly property var percent: available ? percentValue(state.rawReading, sensor.maximum) : null
    readonly property var unit: valueMode === "bytesPerSecond" ? "B/s" : sensor ? sensor.unit : null
    readonly property string text: available
        ? (sensor.formattedValue || String(value))
        : status === "disabled" ? disabledText : unavailableText

    QtObject {
        id: state
        property bool initialized: false
        property bool sourceInitialized: false
        property int generation: 0
        property int observedStatus: Sensors.Sensor.Unknown
        property bool received: false
        property bool invalidReading: false
        property bool timedOut: false
        property var reading: null
        property var rawReading: null
        property var lastKnownValue: null
        property var lastConfirmedAt: null
        property real startedAt: 0
        property real retryAt: 0
        property int retryDelay: 5000
    }

    function numericValue(raw) {
        if (typeof raw !== "number" && typeof raw !== "string") {
            return null;
        }
        if (typeof raw === "string" && raw.trim().length === 0) {
            return null;
        }
        var number = Number(raw);
        return isFinite(number) ? number : null;
    }

    function percentValue(raw, maximum) {
        var number = numericValue(raw);
        if (number === null || number < 0) {
            return null;
        }
        return Math.max(0, Math.min(100, maximum > 0 ? number / maximum * 100 : number));
    }

    function normalizedValue(raw) {
        var number = numericValue(raw);
        if (number === null || valueMode !== "bytesPerSecond") {
            return valueMode === "percent" && number !== null && number < 0 ? null : number;
        }
        if (number < 0 || !sensor) {
            return null;
        }
        // Scale by metadata, never by parsing a localized formattedValue.
        var byteUnits = [Formatter.Units.UnitByteRate, Formatter.Units.UnitKiloByteRate,
            Formatter.Units.UnitMegaByteRate, Formatter.Units.UnitGigaByteRate,
            Formatter.Units.UnitTeraByteRate, Formatter.Units.UnitPetaByteRate];
        var bitUnits = [Formatter.Units.UnitBitRate, Formatter.Units.UnitKiloBitRate,
            Formatter.Units.UnitMegaBitRate, Formatter.Units.UnitGigaBitRate,
            Formatter.Units.UnitTeraBitRate, Formatter.Units.UnitPetaBitRate];
        var index = byteUnits.indexOf(sensor.unit);
        if (index >= 0) {
            return number * Math.pow(1024, index);
        }
        index = bitUnits.indexOf(sensor.unit);
        return index >= 0 ? number * Math.pow(1024, index) / 8 : null;
    }

    function resetSource() {
        if (!state.initialized) {
            return;
        }
        state.generation++;
        state.lastKnownValue = null;
        state.lastConfirmedAt = null;
        state.timedOut = false;
        state.retryDelay = staleAfter;
        state.startedAt = clock();
        state.retryAt = state.startedAt + staleAfter;
        reload();
    }

    function reload() {
        state.sourceInitialized = false;
        state.received = false;
        state.invalidReading = false;
        state.reading = null;
        state.rawReading = null;
        state.observedStatus = Sensors.Sensor.Unknown;
        sensorLoader.active = false;
        sensorLoader.active = collecting;
    }

    function receiveReading() {
        if (!collecting || !state.sourceInitialized || !sensor || !sensor.enabled) {
            return;
        }
        // libksysguard 6.7.5 emits valueChanged for EVERY accepted acquisition,
        // including equal values. It ALSO forwards statusChanged to valueChanged
        // before the QML status handler. Exclude that synthetic notification:
        // Ready alone is metadata, not evidence that the default zero was read.
        if (sensor.status !== state.observedStatus || sensor.status !== Sensors.Sensor.Ready) {
            return;
        }
        var raw = numericValue(sensor.value);
        var number = normalizedValue(raw);
        state.invalidReading = number === null || !isFinite(number);
        state.received = !state.invalidReading;
        state.reading = state.received ? number : null;
        state.rawReading = state.received ? raw : null;
        if (state.received) {
            state.lastKnownValue = number;
            state.lastConfirmedAt = clock();
            state.timedOut = false;
            state.retryDelay = staleAfter;
            state.retryAt = state.lastConfirmedAt + staleAfter;
        }
    }

    function checkHealth(timestamp) {
        if (!collecting) {
            return;
        }
        if (lastConfirmedAt !== null && timestamp < lastConfirmedAt) {
            // A backwards wall-clock step cannot keep a cached reading healthy.
            resetSource();
            return;
        }
        if (timestamp >= state.retryAt) {
            state.timedOut = true;
            state.retryAt = timestamp + state.retryDelay;
            state.retryDelay = Math.min(maximumRetryDelay, state.retryDelay * 2);
            reload();
        }
    }

    function snapshot(timestamp) {
        var sampledAt = timestamp === undefined ? clock() : timestamp;
        checkHealth(sampledAt);
        return { metricId: metricId, sourceKey: sourceKey, scopeLabel: scopeLabel,
            unit: unit, value: value, status: status, sampledAt: sampledAt,
            lastConfirmedAt: lastConfirmedAt };
    }

    onStaleAfterChanged: {
        if (state.initialized && !state.timedOut) {
            state.retryDelay = staleAfter;
            state.retryAt = (lastConfirmedAt !== null ? lastConfirmedAt : state.startedAt) + staleAfter;
        }
    }
    onValueModeChanged: resetSource()
    onSensorIdChanged: resetSource()
    onSourceKeyChanged: resetSource()
    onCollectingChanged: resetSource()
    onSensorComponentChanged: resetSource()
    Component.onCompleted: {
        state.initialized = true;
        resetSource();
    }

    Loader {
        id: sensorLoader
        active: false
        sourceComponent: monitor.sensorComponent
        onLoaded: {
            item.sensorId = Qt.binding(function() { return monitor.sensorId; });
            item.updateRateLimit = Qt.binding(function() { return monitor.updateRateLimit; });
            state.observedStatus = monitor.sensor.status;
            state.sourceInitialized = true;
        }
    }

    Connections {
        target: monitor.sensor
        function onValueChanged() { monitor.receiveReading(); }
        function onStatusChanged() {
            state.observedStatus = monitor.sensor.status;
            state.received = false;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: monitor.collecting
        onTriggered: monitor.checkHealth(monitor.clock())
    }
}
