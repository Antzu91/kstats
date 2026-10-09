import QtQuick

import org.kde.kirigami as Kirigami
import "TimedHistory.js" as TimedHistory

Canvas {
    id: spark

    property real sampleValue: 0
    property int sampleLimit: 36
    property var samples: []
    property bool autoSample: true
    property bool dataAvailable: true
    property string historyKey: ""
    property int sampleInterval: 1000
    readonly property int historyDuration: 60000
    property var timedSamples: []
    property real sampledAt: 0
    property bool initialized: false
    property color lineColor: "white"
    property bool showFill: false
    property bool showGrid: false
    property bool showScale: false
    property var scaleTicks: [100, 50, 0]
    property string scaleSuffix: "%"
    property color scaleColor: Kirigami.Theme.disabledTextColor

    antialiasing: true

    onSamplesChanged: requestPaint()
    onTimedSamplesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onHistoryKeyChanged: resetHistory()
    onVisibleChanged: resetHistory()
    onAutoSampleChanged: resetHistory()
    onDataAvailableChanged: collectSample()
    onSampleIntervalChanged: collectSample()
    Component.onCompleted: {
        initialized = true;
        resetHistory();
    }

    function resetHistory() {
        timedSamples = [];
        collectSample();
    }

    function collectSample() {
        if (!initialized || !autoSample || !visible) {
            return;
        }
        sampledAt = Date.now();
        timedSamples = TimedHistory.append(timedSamples, sampleValue, dataAvailable,
            sampledAt, Math.max(100, sampleInterval), historyDuration);
    }

    Timer {
        interval: Math.max(100, spark.sampleInterval)
        repeat: true
        running: spark.initialized && spark.autoSample && spark.visible
        onTriggered: spark.collectSample()
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function scaleLabel(value) {
        return Math.round(value).toString() + scaleSuffix;
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        if (width <= 0 || height <= 0) {
            return;
        }

        var fontSize = Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1);
        ctx.font = fontSize + "px sans-serif";

        var leftInset = 0;
        if (showScale) {
            for (var measureIndex = 0; measureIndex < scaleTicks.length; measureIndex++) {
                leftInset = Math.max(leftInset, ctx.measureText(scaleLabel(scaleTicks[measureIndex])).width);
            }
            leftInset = Math.ceil(leftInset + Kirigami.Units.smallSpacing);
        }

        var plotLeft = leftInset;
        var plotTop = showScale ? 2 : 0;
        var plotWidth = Math.max(1, width - plotLeft);
        var plotHeight = Math.max(1, height - (showScale ? 4 : 0));

        if (showGrid || showScale) {
            ctx.lineWidth = 1;
            ctx.strokeStyle = showScale ? scaleColor : lineColor;

            if (showScale) {
                ctx.fillStyle = scaleColor;
                ctx.textBaseline = "middle";
                ctx.globalAlpha = 0.68;
                for (var tickIndex = 0; tickIndex < scaleTicks.length; tickIndex++) {
                    var tick = Math.max(0, Math.min(100, Number(scaleTicks[tickIndex]) || 0));
                    var ty = plotTop + plotHeight - (tick / 100 * plotHeight);
                    var labelY = Math.max(fontSize / 2, Math.min(height - fontSize / 2, ty));
                    ctx.fillText(scaleLabel(tick), 0, labelY);
                    ctx.globalAlpha = tick === 0 || tick === 100 ? 0.10 : 0.16;
                    ctx.beginPath();
                    ctx.moveTo(plotLeft, ty);
                    ctx.lineTo(width, ty);
                    ctx.stroke();
                    ctx.globalAlpha = 0.68;
                }
            } else {
                ctx.globalAlpha = 0.12;
            }

            if (!showScale) {
                for (var grid = 1; grid < 4; grid++) {
                    var gy = plotTop + plotHeight * grid / 4;
                    ctx.beginPath();
                    ctx.moveTo(plotLeft, gy);
                    ctx.lineTo(width, gy);
                    ctx.stroke();
                }
            }
        }

        var paths;
        if (autoSample) {
            paths = TimedHistory.segments(timedSamples, sampledAt, historyDuration);
        } else {
            // External histories use sample indices rather than timestamps.
            paths = [samples.map(function(value, index) {
                return { x: 1 - (samples.length - 1 - index) / Math.max(1, sampleLimit - 1), value: value };
            })];
        }

        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = lineColor;
        ctx.fillStyle = lineColor;
        for (var pathIndex = 0; pathIndex < paths.length; pathIndex++) {
            var path = paths[pathIndex];
            if (path.length < 2) {
                continue;
            }
            if (showFill) {
                ctx.globalAlpha = 0.16;
                ctx.beginPath();
                ctx.moveTo(plotLeft + path[0].x * plotWidth, plotTop + plotHeight);
                for (var fillIndex = 0; fillIndex < path.length; fillIndex++) {
                    ctx.lineTo(plotLeft + path[fillIndex].x * plotWidth,
                        plotTop + plotHeight - path[fillIndex].value / 100 * plotHeight);
                }
                ctx.lineTo(plotLeft + path[path.length - 1].x * plotWidth, plotTop + plotHeight);
                ctx.closePath();
                ctx.fill();
            }

            ctx.globalAlpha = 0.9;
            ctx.beginPath();
            for (var i = 0; i < path.length; i++) {
                var x = plotLeft + path[i].x * plotWidth;
                var y = plotTop + plotHeight - path[i].value / 100 * plotHeight;
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        }
    }
}
