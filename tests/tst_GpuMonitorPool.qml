import QtQuick
import QtTest
import org.kde.ksysguard.sensors as Sensors
import "../contents/ui" as Local
import "../contents/ui/History.js" as History

TestCase {
    id: testCase
    name: "GpuMonitorPool"
    when: windowShown
    property real time: 100000
    function i18nc(context, text) { return text; }

    Component {
        id: fakeSensor
        QtObject {
            property string sensorId: ""
            property int updateRateLimit: 1000
            property int updateInterval: 500
            property bool enabled: true
            property int status: Sensors.Sensor.Loading
            property var value: 0
            property int unit: 0
            property real maximum: 100
            property string formattedValue: "0%"
            onStatusChanged: valueChanged()
            function acquire(reading) {
                status = Sensors.Sensor.Ready;
                value = reading;
                valueChanged();
            }
        }
    }
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property alias pool: pool
            property alias store: store
            Local.HistoryStore { id: store; clock: function() { return testCase.time; } }
            Local.GpuMonitorPool {
                id: pool
                historyStore: store
                selectedDeviceId: "gpu0"
                panelDemand: true
                sensorComponent: fakeSensor
            }
            function tick() { store.advance(testCase.time); pool.sample(testCase.time); }
        }
    }
    function devices() {
        return [{ key: "gpu0", usageSensorId: "gpu/gpu0/usage", memorySensorId: "", temperatureSensorId: "" },
            { key: "gpu1", usageSensorId: "gpu/gpu1/usage", memorySensorId: "", temperatureSensorId: "" }];
    }
    function init() { time = 100000; }
    function make() {
        var fixture = createTemporaryObject(fixtureFactory, testCase);
        verify(fixture !== null);
        fixture.pool.devices = devices();
        return fixture;
    }
    function samples(f, key) { return f.store.samplesFor("gpuUsage/" + key, "gpu/" + key + "/usage"); }

    function test_selectionTransfersDemandOnSameOwner() {
        var f = make();
        f.pool.popupDemand = true;
        var zero = f.pool.monitorFor("gpu0").usage;
        var one = f.pool.monitorFor("gpu1").usage;
        var zeroSensor = zero.sensor;
        var oneSensor = one.sensor;
        time += 1000;
        zero.sensor.acquire(0);
        one.sensor.acquire(25);
        f.tick();
        var zeroCount = samples(f, "gpu0").length;
        var oneCount = samples(f, "gpu1").length;
        f.pool.selectedDeviceId = "gpu1";
        compare(f.pool.selectedUsage, one);
        compare(f.pool.monitorFor("gpu0").usage, zero);
        compare(zero.sensor, zeroSensor);
        compare(one.sensor, oneSensor);
        compare(samples(f, "gpu0").length, zeroCount);
        compare(samples(f, "gpu1").length, oneCount);
        f.pool.popupDemand = false;
        compare(one.sensor, oneSensor);
        compare(samples(f, "gpu1")[oneCount - 1].status, "available");
        f.pool.popupDemand = true;
        f.pool.popupDemand = false;
        compare(samples(f, "gpu1").length, oneCount);
        compare(samples(f, "gpu1")[oneCount - 1].value, 25);
    }

    function test_rapidCompletePauseRecordsGapWithoutSecondOwner() {
        var f = make();
        var monitor = f.pool.selectedUsage;
        time += 1000;
        monitor.sensor.acquire(0);
        f.tick();
        time += 100;
        f.pool.panelDemand = false;
        compare(samples(f, "gpu0")[samples(f, "gpu0").length - 1].status, "disabled");
        time += 100;
        f.pool.panelDemand = true;
        compare(f.pool.selectedUsage, monitor);
        time += 100;
        monitor.sensor.acquire(0);
        f.tick();
        compare(History.segments(samples(f, "gpu0"), 60000, time).length, 2);
    }

    function test_disappearanceRetainsManualIdentityAndReappears() {
        var f = make();
        var monitor = f.pool.selectedUsage;
        monitor.sensor.acquire(0);
        f.tick();
        f.pool.devices = [devices()[1]];
        compare(f.pool.selectedUsage, monitor);
        compare(monitor.sensorId, "gpu/gpu0/usage");
        time += 6000;
        f.tick();
        compare(monitor.status, "stale");
        compare(monitor.value, null);
        compare(monitor.text, "N/A");
        f.pool.devices = devices();
        compare(f.pool.selectedUsage, monitor);
        time += 1000;
        monitor.sensor.acquire(0);
        f.tick();
        compare(monitor.status, "available");
        compare(samples(f, "gpu0")[samples(f, "gpu0").length - 1].value, 0);
    }

    function test_neverSeenSelectionHasSafeFallbackAndChurnIsBounded() {
        var f = make();
        f.pool.selectedDeviceId = "gpu42";
        verify(f.pool.selectedUsage !== null);
        compare(f.pool.selectedUsage.status, "unavailable");
        compare(f.pool.selectedUsage.value, null);
        compare(f.pool.selectedUsage.text, "N/A");
        f.pool.devices = [];
        compare(Object.keys(f.pool.monitors).length, 0);
        f.pool.devices = devices();
        f.pool.selectedDeviceId = "gpu0";
        compare(f.pool.selectedUsage, f.pool.monitorFor("gpu0").usage);
        f.pool.devices = [];
        compare(Object.keys(f.pool.monitors).length, 1);
        f.pool.selectedDeviceId = "gpu42";
        compare(Object.keys(f.pool.monitors).length, 0);
    }
}
