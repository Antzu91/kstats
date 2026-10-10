import QtQuick
import QtTest
import org.kde.ksysguard.sensors as Sensors
import "../contents/ui" as Local
import "../contents/ui/History.js" as History

TestCase {
    id: testCase
    name: "HistoryIntegration"
    when: windowShown
    property real time: 100000

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
            function acquire(value) {
                status = Sensors.Sensor.Ready;
                this.value = value;
                valueChanged();
            }
        }
    }
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property alias monitor: monitor
            property alias store: store
            property alias sampler: sampler
            property alias panel: panel
            property alias popup: popup
            property bool panelDemand: true
            property bool popupDemand: false
            Local.SensorMonitor {
                id: monitor
                metricId: "cpu"
                sensorId: "cpu/all/usage"
                valueMode: "percent"
                active: fixture.panelDemand || fixture.popupDemand
                clock: function() { return testCase.time; }
                sensorComponent: fakeSensor
                unavailableText: "N/A"
                disabledText: "Off"
            }
            Local.HistoryStore {
                id: store
                clock: function() { return testCase.time; }
                sampleInterval: monitor.updateRateLimit
            }
            Local.HistorySampler { id: sampler; monitor: monitor; store: store }
            Local.Sparkline {
                id: panel
                samples: sampler.samples
                now: store.now
            }
            Local.Sparkline {
                id: popup
                samples: sampler.samples
                now: store.now
                windowDuration: panel.windowDuration
            }
            function tick() {
                store.advance(testCase.time);
                sampler.sample(testCase.time);
            }
        }
    }
    Component {
        id: extraSamplerFactory
        Local.HistorySampler {}
    }

    function init() { time = 100000; }
    function fixture() {
        var fixture = createTemporaryObject(fixtureFactory, testCase);
        verify(fixture !== null);
        return fixture;
    }
    function reading(f, value, elapsed) {
        time += elapsed;
        f.monitor.sensor.acquire(value);
        f.tick();
    }

    function test_closedPopupStillCollectsFlatPanelSeries() {
        var f = fixture();
        for (var i = 0; i < 10; ++i) {
            reading(f, 0, 1000);
        }
        compare(f.sampler.samples.length, 11);
        compare(f.panel.samples, f.popup.samples);
        compare(f.panel.renderSegments[0].length, 10);
        compare(f.panel.renderSegments[0][9].timestamp - f.panel.renderSegments[0][0].timestamp, 9000);
        compare(f.panel.renderSegments[0][9].value, 0);
        f.popupDemand = true;
        compare(f.panel.samples, f.popup.samples);
        compare(f.sampler.samples.length, 11);
    }

    function test_shortDemandPauseMakesGap() {
        var f = fixture();
        reading(f, 50, 1000);
        reading(f, 50, 1000);
        time += 100;
        f.panelDemand = false;
        compare(f.sampler.samples[f.sampler.samples.length - 1].status, "disabled");
        compare(f.monitor.sensor, null);
        time += 100;
        f.popupDemand = true;
        reading(f, 50, 100);
        reading(f, 50, 1000);
        compare(f.panel.renderSegments.length, 2);
        compare(f.popup.renderSegments, f.panel.renderSegments);
    }

    function test_unavailableNeverPlotsZero() {
        var f = fixture();
        reading(f, 50, 1000);
        reading(f, null, 1000);
        compare(f.sampler.samples[f.sampler.samples.length - 1].value, null);
        compare(f.sampler.samples[f.sampler.samples.length - 1].status, "unavailable");
        reading(f, 0, 1000);
        compare(f.panel.renderSegments.length, 2);
        compare(f.panel.renderSegments[1][0].value, 0);
    }

    function test_sourceSwapPreservesSeparateSeriesAndGapOnReturn() {
        var f = fixture();
        reading(f, 50, 1000);
        reading(f, 50, 1000);
        time += 100;
        f.monitor.sensorId = "cpu/cpu0/usage";
        compare(f.sampler.samples.length, 1);
        compare(f.sampler.samples[0].status, "loading");
        reading(f, 25, 1000);
        time += 100;
        f.monitor.sensorId = "cpu/all/usage";
        reading(f, 50, 1000);
        compare(f.panel.renderSegments.length, 2);
        compare(f.store.samplesFor("cpu", "cpu/cpu0/usage")[1].value, 25);
    }

    function test_intervalAndWindowChangesPreserveTimestamps() {
        var f = fixture();
        f.monitor.updateRateLimit = 500;
        reading(f, 50, 500);
        reading(f, 50, 500);
        var earliest = f.sampler.samples[1].timestamp;
        f.monitor.updateRateLimit = 5000;
        reading(f, 50, 5000);
        compare(f.sampler.samples[1].timestamp, earliest);
        compare(f.panel.renderSegments.length, 1);
        f.panel.windowDuration = 900000;
        compare(f.popup.windowDuration, 900000);
        compare(f.sampler.samples[1].timestamp, earliest);
        compare(f.panel.samples, f.popup.samples);
    }

    function test_staleAfterSuspensionDoesNotExtendCachedLine() {
        var f = fixture();
        reading(f, 50, 1000);
        reading(f, 50, 1000);
        time += 60000;
        f.tick();
        compare(f.sampler.samples[f.sampler.samples.length - 1].status, "stale");
        compare(f.sampler.samples[f.sampler.samples.length - 1].value, null);
        compare(f.monitor.value, null);
        reading(f, 50, 1000);
        compare(f.panel.renderSegments[f.panel.renderSegments.length - 1][0].timestamp, time);
    }

    function test_inactiveDuplicateSamplerDoesNotBreakSharedGpuSeries() {
        var f = fixture();
        reading(f, 50, 1000);
        var inactiveMonitor = Qt.createQmlObject('import QtQml; QtObject { property bool collecting: false; property string metricId: "cpu"; property string sourceKey: "cpu/all/usage" }', testCase);
        var duplicate = createTemporaryObject(extraSamplerFactory, testCase, { monitor: inactiveMonitor, store: f.store });
        verify(duplicate !== null);
        var count = f.sampler.samples.length;
        duplicate.destroy();
        wait(0);
        compare(f.sampler.samples.length, count);
        reading(f, 50, 1000);
        compare(f.panel.renderSegments.length, 1);
        inactiveMonitor.destroy();
    }

    function test_coverageExcludesInactivityAndExpiredWindow() {
        var f = fixture();
        reading(f, 50, 1000);
        reading(f, 50, 1000);
        compare(History.coverageDuration(f.sampler.samples, 60000, time), 1000);
        time += 100;
        f.panelDemand = false;
        time += 30000;
        compare(History.coverageDuration(f.sampler.samples, 60000, time), 1000);
        time += 60000;
        compare(History.coverageDuration(f.sampler.samples, 60000, time), 0);
    }

    function test_inactiveHistoryExpiresWithoutSampling() {
        var f = fixture();
        reading(f, 0, 1000);
        f.panelDemand = false;
        time += 900001;
        f.tick();
        compare(f.sampler.samples.length, 0);
        compare(f.store.seriesCount, 0);
    }
}
