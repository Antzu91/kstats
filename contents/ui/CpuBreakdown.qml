import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import "History.js" as History

import org.kde.kirigami as Kirigami
import "." as Local

Rectangle {
    id: root

    property int refreshInterval: 1500
    property bool active: false
    property real windowDuration: 60000
    property real now: 0
    readonly property var userPercent: detailHistory.userPercent
    readonly property var systemPercent: detailHistory.systemPercent
    readonly property var idlePercent: detailHistory.idlePercent
    readonly property string errorText: detailHistory.errorCode === "read"
        ? i18nc("@info:status", "Unable to read CPU details")
        : detailHistory.errorCode === "format"
            ? i18nc("@info:status", "Unexpected CPU detail format") : ""

    onNowChanged: detailHistory.advance()

    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 8

    function percentText(value) {
        return value === null ? i18nc("@label unavailable metric", "N/A")
            : i18nc("@label percent", "%1%", value.toFixed(1));
    }

    Local.CpuHistory {
        id: detailHistory
        active: root.active
        refreshInterval: root.refreshInterval
        provider: function(callback) {
            command.exec("awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' /proc/stat", callback);
        }
    }

    Local.RunCommand {
        id: command
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            Controls.Label {
                text: i18nc("@label", "Details")
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Controls.Label {
                text: root.errorText
                visible: root.errorText.length > 0
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
            }
        }

        Canvas {
            id: chart

            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true
            property bool showScale: true
            readonly property var userSegments: History.segments(detailHistory.userSamples, root.windowDuration, root.now)
            readonly property var systemSegments: History.segments(detailHistory.systemSamples, root.windowDuration, root.now)
            readonly property var idleSegments: History.segments(detailHistory.idleSamples, root.windowDuration, root.now)

            onUserSegmentsChanged: requestPaint()
            onSystemSegmentsChanged: requestPaint()
            onIdleSegmentsChanged: requestPaint()

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                if (width <= 0 || height <= 0) {
                    return;
                }

                var fontSize = Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1);
                ctx.font = fontSize + "px sans-serif";
                var scaleWidth = chart.showScale ? Math.ceil(ctx.measureText("100%").width + Kirigami.Units.smallSpacing) : 0;
                var plotLeft = scaleWidth;
                var plotTop = chart.showScale ? 2 : 0;
                var plotWidth = Math.max(1, width - plotLeft);
                var plotHeight = Math.max(1, height - (chart.showScale ? 4 : 0));
                var gridTicks = [100, 75, 50, 25, 0];
                var labelTicks = [100, 50, 0];

                ctx.lineWidth = 1;
                ctx.strokeStyle = Kirigami.Theme.textColor;
                for (var grid = 0; grid < gridTicks.length; grid++) {
                    var gy = plotTop + plotHeight - (gridTicks[grid] / 100 * plotHeight);
                    ctx.globalAlpha = gridTicks[grid] === 0 || gridTicks[grid] === 100 ? 0.08 : 0.12;
                    ctx.beginPath();
                    ctx.moveTo(plotLeft, gy);
                    ctx.lineTo(width, gy);
                    ctx.stroke();
                }

                if (chart.showScale) {
                    ctx.fillStyle = Kirigami.Theme.disabledTextColor;
                    ctx.textBaseline = "middle";
                    ctx.globalAlpha = 0.68;
                    for (var labelIndex = 0; labelIndex < labelTicks.length; labelIndex++) {
                        var tick = labelTicks[labelIndex];
                        var labelY = plotTop + plotHeight - (tick / 100 * plotHeight);
                        labelY = Math.max(fontSize / 2, Math.min(height - fontSize / 2, labelY));
                        ctx.fillText(tick.toString() + "%", 0, labelY);
                    }
                }

                drawLine(ctx, idleSegments, "idle", Kirigami.Theme.disabledTextColor, plotLeft, plotTop, plotWidth, plotHeight);
                drawLine(ctx, systemSegments, "system", Kirigami.Theme.neutralTextColor, plotLeft, plotTop, plotWidth, plotHeight);
                drawLine(ctx, userSegments, "user", Kirigami.Theme.positiveTextColor, plotLeft, plotTop, plotWidth, plotHeight);
            }

            function drawLine(ctx, segments, key, color, plotLeft, plotTop, plotWidth, plotHeight) {
                ctx.lineWidth = key === "user" ? 2.25 : 1.8;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.strokeStyle = color;
                ctx.globalAlpha = key === "idle" ? 0.60 : 0.90;
                for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
                    var segment = segments[segmentIndex];
                    if (segment.length < 2) {
                        continue;
                    }
                    ctx.beginPath();
                    for (var i = 0; i < segment.length; i++) {
                        var x = plotLeft + History.xPosition(segment[i].timestamp, root.windowDuration, root.now) * plotWidth;
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            LegendValue {
                label: i18nc("@label", "User")
                value: root.percentText(root.userPercent)
                color: Kirigami.Theme.positiveTextColor
                Layout.fillWidth: true
            }

            LegendValue {
                label: i18nc("@label", "System")
                value: root.percentText(root.systemPercent)
                color: Kirigami.Theme.neutralTextColor
                Layout.fillWidth: true
            }

            LegendValue {
                label: i18nc("@label", "Idle")
                value: root.percentText(root.idlePercent)
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
        }
    }

    component LegendValue: RowLayout {
        property string label
        property string value
        property color color

        spacing: Kirigami.Units.smallSpacing / 2

        Rectangle {
            Layout.preferredWidth: 7
            Layout.preferredHeight: 7
            radius: width / 2
            color: parent.color
        }

        Controls.Label {
            text: parent.label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        Controls.Label {
            text: parent.value
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
