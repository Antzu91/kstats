import QtQuick
import QtTest
import "../contents/ui" as Local

Item {
    width: 600
    height: 240

    Local.Sparkline {
        id: spark
        width: 600
        height: 100
        lineColor: "red"
        showFill: true
        now: 60000
    }

    Local.NetworkHistoryChart {
        id: network
        y: 120
        width: 600
        height: 100
        showScale: false
        uploadColor: "red"
        downloadColor: "blue"
        now: 60000
    }

    SignalSpy { id: sparkPaint; target: spark; signalName: "painted" }
    SignalSpy { id: networkPaint; target: network; signalName: "painted" }

    TestCase {
        name: "HistoryCharts"
        when: windowShown

        function points() {
            return [
                { timestamp: 10000, value: 50, status: "available", sourceKey: "source" },
                { timestamp: 20000, value: 50, status: "available", sourceKey: "source" },
                { timestamp: 30000, value: null, status: "unavailable", sourceKey: "source" },
                { timestamp: 40000, value: 50, status: "available", sourceKey: "source" },
                { timestamp: 50000, value: 50, status: "available", sourceKey: "source" }
            ];
        }

        function init() {
            spark.samples = points();
            spark.windowDuration = 60000;
            spark.now = 60000;
            network.uploadSamples = points();
            network.downloadSamples = points();
            network.windowDuration = 60000;
            network.now = 60000;
        }

        function test_sparklineGapInFillAndLine() {
            sparkPaint.clear();
            spark.requestPaint();
            sparkPaint.wait();
            var image = grabImage(spark);
            // Compare with an empty plot pixel; works with opaque or alpha windows.
            var empty = image.pixel(50, 75);
            verify(image.pixel(150, 75) !== empty); // First segment fill.
            verify(image.pixel(450, 75) !== empty); // Second segment fill.
            compare(image.pixel(300, 75), empty); // Fill does not bridge the gap.
            compare(image.pixel(300, 50), empty); // Stroke does not bridge the gap.
            verify(image.pixel(150, 50) !== empty);
            compare(image.pixel(550, 75), empty); // No extension to "now".
        }

        function test_networkGapInBothDirections() {
            networkPaint.clear();
            network.requestPaint();
            networkPaint.wait();
            var image = grabImage(network);
            var emptyTop = image.pixel(50, 25);
            var emptyBottom = image.pixel(50, 75);
            verify(image.pixel(150, 25) !== emptyTop);
            verify(image.pixel(450, 75) !== emptyBottom);
            compare(image.pixel(300, 25), emptyTop);
            compare(image.pixel(300, 75), emptyBottom);
            compare(image.pixel(300, 6), image.pixel(50, 6));
            compare(image.pixel(300, 94), image.pixel(50, 94));
        }

        function test_windowAndClockUpdateWithoutCollection() {
            var original = spark.samples;
            spark.now = 80000;
            compare(spark.renderSegments[0][0].timestamp, 20000);
            spark.now = 120000;
            compare(spark.renderSegments.length, 0);
            spark.windowDuration = 300000;
            compare(spark.renderSegments.length, 2);
            compare(spark.samples, original);
            network.now = 120000;
            compare(network.uploadSegments.length, 0);
            network.windowDuration = 900000;
            compare(network.uploadSegments.length, 2);
        }

        function test_scaleIgnoresExpiredAndMissingReadings() {
            network.now = 120000;
            network.uploadSamples = [
                { timestamp: 1000, value: 10000, status: "available", sourceKey: "source" },
                { timestamp: 2000, value: null, status: "stale", sourceKey: "source" },
                { timestamp: 100000, value: 5, status: "available", sourceKey: "source" },
                { timestamp: 110000, value: 500, status: "stale", sourceKey: "source" }
            ];
            network.downloadSamples = [];
            compare(network.maxSample(), 5);
            compare(network.uploadSegments.length, 1);
            compare(network.uploadSegments[0].length, 1);
        }
    }
}
