import QtQuick
import "History.js" as History

import org.kde.kirigami as Kirigami

Canvas {
    id: chart

    // Passive renderer: both arrays contain timestamped HistoryStore observations
    // in bytes/second. Bind now and windowDuration to the same clock/window as the panel.
    property var uploadSamples: []
    property var downloadSamples: []
    property real windowDuration: 60000
    property real now: 0
    readonly property var uploadSegments: History.segments(uploadSamples, windowDuration, now)
    readonly property var downloadSegments: History.segments(downloadSamples, windowDuration, now)
    property color uploadColor: Kirigami.Theme.negativeTextColor
    property color downloadColor: Kirigami.Theme.focusColor
    property bool showScale: true
    property color scaleColor: Kirigami.Theme.disabledTextColor

    antialiasing: true

    onUploadSegmentsChanged: requestPaint()
    onDownloadSegmentsChanged: requestPaint()
    onUploadColorChanged: requestPaint()
    onDownloadColorChanged: requestPaint()
    onShowScaleChanged: requestPaint()
    onScaleColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function maxSample() {
        var maximum = 1;
        var allSegments = uploadSegments.concat(downloadSegments);
        for (var i = 0; i < allSegments.length; i++) {
            for (var j = 0; j < allSegments[i].length; j++) {
                maximum = Math.max(maximum, allSegments[i][j].value);
            }
        }
        return maximum;
    }

    function formatRate(bytesPerSecond) {
        var value = Math.max(0, Number(bytesPerSecond) || 0);
        if (value >= 1048576) {
            return i18nc("@label rate in megabytes per second", "%1 MB/s", (value / 1048576).toFixed(value >= 10485760 ? 1 : 2));
        }
        if (value >= 1024) {
            return i18nc("@label rate in kilobytes per second", "%1 KB/s", (value / 1024).toFixed(value >= 10240 ? 0 : 1));
        }
        return i18nc("@label rate in bytes per second", "%1 B/s", Math.round(value));
    }

    function drawSeries(ctx, segments, color, baseline, scale, direction, plotLeft, plotWidth) {
        for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
            var segment = segments[segmentIndex];
            if (segment.length < 2) {
                continue;
            }
            var startX = plotLeft + History.xPosition(segment[0].timestamp, windowDuration, now) * plotWidth;
            var endX = plotLeft + History.xPosition(segment[segment.length - 1].timestamp, windowDuration, now) * plotWidth;
            ctx.fillStyle = color;
            ctx.globalAlpha = 0.12;
            ctx.beginPath();
            ctx.moveTo(startX, baseline);
            for (var fillIndex = 0; fillIndex < segment.length; fillIndex++) {
                var fillX = plotLeft + History.xPosition(segment[fillIndex].timestamp, windowDuration, now) * plotWidth;
                var fillY = baseline + direction * segment[fillIndex].value * scale;
                ctx.lineTo(fillX, fillY);
            }
            ctx.lineTo(endX, baseline);
            ctx.closePath();
            ctx.fill();

            ctx.strokeStyle = color;
            ctx.globalAlpha = 0.9;
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.beginPath();
            for (var i = 0; i < segment.length; i++) {
                var x = plotLeft + History.xPosition(segment[i].timestamp, windowDuration, now) * plotWidth;
                var y = baseline + direction * segment[i].value * scale;
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        if (width <= 0 || height <= 0) {
            return;
        }

        var baseline = height / 2;
        var maxValue = maxSample();
        var fontSize = Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1);
        ctx.font = fontSize + "px sans-serif";

        var maxLabel = showScale ? formatRate(maxValue) : "";
        var zeroLabel = showScale ? formatRate(0) : "";
        var leftInset = showScale
            ? Math.ceil(Math.max(ctx.measureText(maxLabel).width, ctx.measureText(zeroLabel).width) + Kirigami.Units.smallSpacing)
            : 0;
        var plotLeft = leftInset;
        var plotTop = showScale ? 2 : 0;
        var plotWidth = Math.max(1, width - plotLeft);
        var plotHeight = Math.max(1, height - (showScale ? 4 : 0));
        baseline = plotTop + plotHeight / 2;

        var scale = Math.max(1, plotHeight / 2 - 6) / maxValue;
        var topLine = baseline - maxValue * scale;
        var bottomLine = baseline + maxValue * scale;

        ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14);
        ctx.lineWidth = 1;
        ctx.globalAlpha = 1;
        ctx.beginPath();
        ctx.moveTo(plotLeft, topLine);
        ctx.lineTo(width, topLine);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(plotLeft, baseline);
        ctx.lineTo(width, baseline);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(plotLeft, bottomLine);
        ctx.lineTo(width, bottomLine);
        ctx.stroke();

        if (showScale) {
            ctx.fillStyle = scaleColor;
            ctx.textBaseline = "middle";
            ctx.globalAlpha = 0.72;
            ctx.fillText(maxLabel, 0, Math.max(fontSize / 2, topLine));
            ctx.fillText(zeroLabel, 0, baseline);
            ctx.fillText(maxLabel, 0, Math.min(height - fontSize / 2, bottomLine));
        }

        drawSeries(ctx, uploadSegments, uploadColor, baseline, scale, -1, plotLeft, plotWidth);
        drawSeries(ctx, downloadSegments, downloadColor, baseline, scale, 1, plotLeft, plotWidth);
    }
}
