import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "." as Local

// One percentage module in the panel: an optional label, an optional meter
// (sparkline or bar) and an optional value. Widths depend only on the parts
// shown and a sample value, never on the current reading, so the panel does
// not shift when a reading changes or becomes unavailable.
RowLayout {
    id: stat

    property string label
    property string value
    property string valueWidthSample: "100.0%"
    property real percent: 0
    property var samples: []
    property real windowDuration: 60000
    property real now: 0
    property color accentColor: Kirigami.Theme.highlightColor
    property bool dataAvailable: true
    property bool showLabel: true
    property bool showValue: true
    // "sparkline", "bar" or "none".
    property string meterMode: "sparkline"
    // 0 keeps the theme's small font.
    property int labelFontSize: 0
    property int valueFontSize: 0

    readonly property bool showMeter: meterMode === "sparkline" || meterMode === "bar"
    readonly property real labelWidth: showLabel
        ? Math.ceil(Math.max(labelText.implicitWidth, stat.label.length <= 1 ? Kirigami.Units.gridUnit * 0.7 : Kirigami.Units.gridUnit * 1.25))
        : 0
    readonly property real valueWidth: showValue ? Math.ceil(valueMetrics.width + 1) : 0
    readonly property real meterWidth: showMeter
        ? Math.ceil(meterMode === "bar" ? Kirigami.Units.gridUnit * 0.85 : Kirigami.Units.gridUnit * 2.2)
        : 0
    readonly property int partCount: (showLabel ? 1 : 0) + (showMeter ? 1 : 0) + (showValue ? 1 : 0)
    readonly property real fixedWidth: labelWidth + meterWidth + valueWidth + spacing * Math.max(0, partCount - 1)

    spacing: Math.max(1, Kirigami.Units.smallSpacing / 4)
    Layout.alignment: Qt.AlignVCenter
    Layout.minimumWidth: fixedWidth
    Layout.preferredWidth: fixedWidth
    Layout.maximumWidth: fixedWidth
    implicitWidth: fixedWidth

    TextMetrics {
        id: valueMetrics

        font: valueText.font
        text: stat.valueWidthSample
    }

    Controls.Label {
        id: labelText

        visible: stat.showLabel
        text: stat.label
        color: stat.accentColor
        elide: Text.ElideRight
        font.pixelSize: stat.labelFontSize > 0 ? stat.labelFontSize : Kirigami.Theme.smallFont.pixelSize
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: stat.labelWidth
        Layout.preferredWidth: stat.labelWidth
        Layout.maximumWidth: stat.labelWidth
    }

    Rectangle {
        visible: stat.showMeter
        // With the value shown, its N/A explains a missing reading; a meter
        // alone keeps its frame and says N/A itself.
        opacity: stat.dataAvailable || !stat.showValue ? 1 : 0
        clip: true
        Layout.minimumWidth: stat.meterWidth
        Layout.preferredWidth: stat.meterWidth
        Layout.maximumWidth: stat.meterWidth
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 0.9, stat.height - Kirigami.Units.smallSpacing)
        radius: 2
        color: Qt.rgba(0, 0, 0, 0.86)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.32)

        Rectangle {
            visible: stat.dataAvailable && stat.meterMode === "sparkline"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0, Math.min(100, stat.percent)) / 100
            color: Qt.rgba(stat.accentColor.r, stat.accentColor.g, stat.accentColor.b, 0.28)
        }

        Rectangle {
            visible: stat.dataAvailable && stat.meterMode === "bar"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.bottomMargin: 2
            height: Math.max(0, parent.height - 4) * Math.max(0, Math.min(100, stat.percent)) / 100
            color: Qt.rgba(stat.accentColor.r, stat.accentColor.g, stat.accentColor.b, 0.72)
        }

        Loader {
            id: sparklineLoader
            active: stat.dataAvailable && stat.meterMode === "sparkline"
            anchors.fill: parent
            anchors.margins: 2
            sourceComponent: Component {
                Local.Sparkline {
                    samples: stat.samples
                    windowDuration: stat.windowDuration
                    now: stat.now
                    lineColor: stat.accentColor
                    showFill: true
                }
            }
        }

        Controls.Label {
            objectName: "meterUnavailable"
            anchors.centerIn: parent
            visible: !stat.dataAvailable && !stat.showValue
            text: i18nc("@info:status", "N/A")
            color: Kirigami.Theme.textColor
            font.pixelSize: Math.max(7, Kirigami.Theme.smallFont.pixelSize - 2)
        }
    }

    Controls.Label {
        id: valueText

        visible: stat.showValue
        text: stat.value
        color: Kirigami.Theme.textColor
        elide: Text.ElideRight
        font.pixelSize: stat.valueFontSize > 0 ? stat.valueFontSize : Kirigami.Theme.smallFont.pixelSize
        font.features: { "tnum": 1 }
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: stat.valueWidth
        Layout.preferredWidth: stat.valueWidth
        Layout.maximumWidth: stat.valueWidth
    }
}
