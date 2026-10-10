import QtQuick
import QtTest
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.formatter as Formatter
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "SensorMonitor"
    when: windowShown

    property real time: 100000

    // Matches KSysGuard: equal acquisitions notify, and status changes forward
    // a synthetic valueChanged before the statusChanged observer runs.
    Component {
        id: fakeSensor
        QtObject {
            property string sensorId: ""
            property bool enabled: true
            property int updateRateLimit: 1000
            property int updateInterval: 500
            property int status: Sensors.Sensor.Loading
            property var value: 0
            property real maximum: 100
            property int unit: Formatter.Units.UnitPercent
            property string formattedValue: "0%"
            onStatusChanged: valueChanged()
            function acquire(reading) {
                if (value === reading) {
                    valueChanged();
                } else {
                    value = reading;
                }
            }
        }
    }

    Component {
        id: monitorFactory
        Local.SensorMonitor {
            metricId: "cpu"
            sensorId: "cpu/all/usage"
            sensorComponent: fakeSensor
            clock: function() { return testCase.time; }
            unavailableText: "N/A"
            disabledText: "Off"
        }
    }

    function init() { time = 100000; }

    function makeMonitor(properties) {
        var monitor = createTemporaryObject(monitorFactory, testCase, properties || {});
        verify(monitor !== null);
        compare(monitor.status, "loading");
        return monitor;
    }

    function acquire(monitor, reading) {
        monitor.sensor.status = Sensors.Sensor.Ready;
        monitor.sensor.acquire(reading);
    }

    function test_readinessIsNotAcquisition() {
        var monitor = makeMonitor();
        monitor.sensor.status = Sensors.Sensor.Ready;
        compare(monitor.status, "loading");
        compare(monitor.value, null);
        compare(monitor.lastConfirmedAt, null);
        monitor.sensor.acquire(0);
        compare(monitor.status, "available");
        compare(monitor.value, 0);
        compare(monitor.percent, 0);
    }

    function test_constantZeroAndEqualPositiveStayAvailable() {
        var monitor = makeMonitor();
        acquire(monitor, 0);
        var originalSensor = monitor.sensor;
        for (var i = 0; i < 20; ++i) {
            time += 1000;
            monitor.sensor.acquire(0);
            monitor.checkHealth(time);
            compare(monitor.status, "available");
            compare(monitor.value, 0);
            compare(monitor.lastConfirmedAt, time);
            compare(monitor.sensor, originalSensor);
        }
        acquire(monitor, 35);
        time += 1000;
        monitor.sensor.acquire(35);
        compare(monitor.lastConfirmedAt, time);
        compare(monitor.percent, 35);
    }

    function test_invalid_data() {
        return [
            { tag: "null", reading: null },
            { tag: "undefined", reading: undefined },
            { tag: "empty", reading: "" },
            { tag: "whitespace", reading: " " },
            { tag: "nan", reading: NaN },
            { tag: "infinity", reading: Infinity },
            { tag: "boolean", reading: false },
            { tag: "localized", reading: "1,5%" }
        ];
    }

    function test_invalid(data) {
        var monitor = makeMonitor();
        acquire(monitor, data.reading);
        compare(monitor.status, "unavailable");
        compare(monitor.value, null);
        compare(monitor.percent, null);
        compare(monitor.text, "N/A");
        acquire(monitor, 0);
        compare(monitor.status, "available");
        compare(monitor.value, 0);
    }

    function test_missingAndDisabled() {
        var monitor = makeMonitor();
        time += monitor.staleAfter;
        monitor.checkHealth(time);
        compare(monitor.status, "unavailable");
        compare(monitor.sensorId, "cpu/all/usage");
        monitor.active = false;
        compare(monitor.status, "disabled");
        compare(monitor.sensor, null);
        compare(monitor.value, null);
        compare(monitor.text, "Off");
        time += 100000;
        monitor.checkHealth(time);
        compare(monitor.sensor, null);
        monitor.active = true;
        compare(monitor.status, "loading");
        acquire(monitor, 0);
        compare(monitor.status, "available");
        monitor.sensorId = "";
        compare(monitor.status, "disabled");
        compare(monitor.sensor, null);
    }

    function test_missingOptionalGpuMetricDiffersFromDisabled() {
        var monitor = createTemporaryObject(monitorFactory, testCase, { sensorId: "", emptyIsUnavailable: true });
        compare(monitor.status, "unavailable");
        compare(monitor.value, null);
        monitor.active = false;
        compare(monitor.status, "disabled");
    }

    function test_sourceChangeDropsOldReading() {
        var monitor = makeMonitor();
        acquire(monitor, 75);
        var generation = monitor.generation;
        monitor.sensorId = "cpu/cpu0/usage";
        verify(monitor.generation > generation);
        compare(monitor.sourceKey, "cpu/cpu0/usage");
        compare(monitor.sensor.sensorId, monitor.sensorId);
        compare(monitor.status, "loading");
        compare(monitor.value, null);
        compare(monitor.lastKnownValue, null);
        compare(monitor.lastConfirmedAt, null);
        acquire(monitor, 0);
        compare(monitor.status, "available");
    }

    function test_backendLossAndRecovery() {
        var monitor = makeMonitor();
        acquire(monitor, 0);
        var confirmedAt = monitor.lastConfirmedAt;
        time += monitor.staleAfter;
        monitor.checkHealth(time);
        compare(monitor.status, "stale");
        compare(monitor.value, null);
        compare(monitor.lastKnownValue, 0);
        compare(monitor.lastConfirmedAt, confirmedAt);
        compare(monitor.sensorId, "cpu/all/usage");
        var retriedSensor = monitor.sensor;
        time += 1000;
        monitor.checkHealth(time);
        compare(monitor.sensor, retriedSensor);
        acquire(monitor, 0);
        compare(monitor.status, "available");
        compare(monitor.lastConfirmedAt, time);
    }

    function test_statusLossCannotKeepCachedValue() {
        var monitor = makeMonitor();
        acquire(monitor, 42);
        monitor.sensor.status = Sensors.Sensor.Removed;
        compare(monitor.status, "unavailable");
        compare(monitor.value, null);
        monitor.sensor.status = Sensors.Sensor.Ready;
        compare(monitor.status, "loading");
        compare(monitor.value, null);
        monitor.sensor.acquire(42);
        compare(monitor.status, "available");
    }

    function test_samplingDoesNotConfirmAcquisition() {
        var monitor = makeMonitor();
        acquire(monitor, 50);
        var confirmed = monitor.lastConfirmedAt;
        time += 1000;
        var snapshot = monitor.snapshot(time);
        compare(snapshot.sampledAt, time);
        compare(snapshot.lastConfirmedAt, confirmed);
        compare(snapshot.sourceKey, monitor.sensorId);
        compare(snapshot.value, 50);
        time += 100000;
        snapshot = monitor.snapshot(time);
        compare(snapshot.status, "stale");
        compare(snapshot.value, null);
    }

    function test_clockRollbackBeforeFirstAcquisitionRebasesRetry() {
        var monitor = makeMonitor();
        time = 1000;
        monitor.checkHealth(time);
        var rebasedSensor = monitor.sensor;
        time = 6000;
        monitor.checkHealth(time);
        compare(monitor.status, "unavailable");
        verify(monitor.sensor !== rebasedSensor);
    }

    function test_clockRollbackDuringOutageRebasesRetry() {
        var monitor = makeMonitor();
        acquire(monitor, 0);
        time = 200000;
        monitor.checkHealth(time);
        compare(monitor.status, "stale");
        time = 150000; // Still newer than the last successful acquisition.
        monitor.checkHealth(time);
        var rebasedSensor = monitor.sensor;
        time = 155000;
        monitor.checkHealth(time);
        compare(monitor.status, "unavailable");
        verify(monitor.sensor !== rebasedSensor);
    }

    function test_increasingIntervalExtendsFreshnessDeadline() {
        var monitor = makeMonitor();
        acquire(monitor, 0);
        time += 1000;
        monitor.updateRateLimit = 10000;
        var originalSensor = monitor.sensor;
        time += 6000;
        monitor.checkHealth(time);
        compare(monitor.status, "available");
        compare(monitor.sensor, originalSensor);
        time = 130000;
        monitor.checkHealth(time);
        compare(monitor.status, "stale");
    }

    function test_signedValuesAreMetricSpecific() {
        var monitor = makeMonitor({ valueMode: "percent" });
        acquire(monitor, -1);
        compare(monitor.status, "unavailable");
        compare(monitor.value, null);
        monitor.valueMode = "raw";
        acquire(monitor, -10);
        compare(monitor.status, "available");
        compare(monitor.value, -10);
    }

    function test_percentMetadataAndRateUnits() {
        var monitor = makeMonitor();
        monitor.sensor.maximum = 200;
        acquire(monitor, 50);
        compare(monitor.percent, 25);
        monitor.valueMode = "bytesPerSecond";
        monitor.sensor.unit = Formatter.Units.UnitKiloByteRate;
        monitor.sensor.formattedValue = "localized text is ignored";
        acquire(monitor, 2);
        compare(monitor.value, 2048);
        compare(monitor.unit, "B/s");
        monitor.sensor.unit = Formatter.Units.UnitKiloBitRate;
        acquire(monitor, 8);
        compare(monitor.value, 1024);
        monitor.sensor.unit = Formatter.Units.UnitPercent;
        acquire(monitor, 5);
        compare(monitor.status, "unavailable");
    }
}
