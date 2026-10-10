import QtQuick
import "History.js" as History

import org.kde.kirigami as Kirigami

Canvas {
    id: spark

    // Passive renderer: replace samples with HistoryStore observations and bind
    // now to the sampler clock. Select 60000, 300000, or 900000 ms without resetting.
    property var samples: []
    property real windowDuration: 60000
    property real now: 0
    readonly property var renderSegments: History.segments(samples, windowDuration, now)
    property color lineColor: "white"
    property bool showFill: false
    property bool showGrid: false
    property bool showScale: false
    property var scaleTicks: [100, 50, 0]
    property string scaleSuffix: "%"
    property color scaleColor: Kirigami.Theme.disabledTextColor

    antialiasing: true

    onRenderSegmentsChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onShowFillChanged: requestPaint()
    onShowGridChanged: requestPaint()
    onShowScaleChanged: requestPaint()
    onScaleTicksChanged: requestPaint()
    onScaleSuffixChanged: requestPaint()
    onScaleColorChanged: requestPaint()

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

        for (var segmentIndex = 0; segmentIndex < renderSegments.length; segmentIndex++) {
            var segment = renderSegments[segmentIndex];
            if (segment.length < 2) {
                continue;
            }
            var startX = plotLeft + History.xPosition(segment[0].timestamp, windowDuration, now) * plotWidth;
            var endX = plotLeft + History.xPosition(segment[segment.length - 1].timestamp, windowDuration, now) * plotWidth;
            if (showFill) {
                ctx.fillStyle = lineColor;
                ctx.globalAlpha = 0.16;
                ctx.beginPath();
                ctx.moveTo(startX, plotTop + plotHeight);
                for (var fillIndex = 0; fillIndex < segment.length; fillIndex++) {
                    var fillX = plotLeft + History.xPosition(segment[fillIndex].timestamp, windowDuration, now) * plotWidth;
                    var fillY = plotTop + plotHeight - (Math.min(100, segment[fillIndex].value) / 100 * plotHeight);
                    ctx.lineTo(fillX, fillY);
                }
                ctx.lineTo(endX, plotTop + plotHeight);
                ctx.closePath();
                ctx.fill();
            }

            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = lineColor;
            ctx.globalAlpha = 0.9;
            ctx.beginPath();
            for (var i = 0; i < segment.length; i++) {
                var x = plotLeft + History.xPosition(segment[i].timestamp, windowDuration, now) * plotWidth;
                var y = plotTop + plotHeight - (Math.min(100, segment[i].value) / 100 * plotHeight);
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
