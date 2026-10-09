import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "." as Local

RowLayout {
    id: stat

    property string label
    property string value
    property string valueWidthSample: "100.0%"
    property real percent: 0
    property color accentColor: Kirigami.Theme.highlightColor
    property bool showLabel: true
    property bool dataAvailable: true
    property string historyKey: ""
    property int sampleInterval: 1000
    property string presentation: "numberGraph"
    readonly property bool showNumber: presentation === "number" || presentation === "numberGraph"
        || ["graph", "bar"].indexOf(presentation) < 0
    readonly property bool showGraph: presentation === "graph" || presentation === "numberGraph"
    readonly property bool showMeter: showGraph || presentation === "bar"
    readonly property real labelWidth: showLabel ? Math.ceil(labelText.implicitWidth) : 0
    readonly property real valueWidth: showNumber ? Math.ceil(valueMetrics.width + 1) : 0
    readonly property real previewWidth: showMeter
        ? Math.ceil(presentation === "bar" ? Math.max(Kirigami.Units.gridUnit * 0.85, unavailableMetrics.width + 4) : Kirigami.Units.gridUnit * 2.2) : 0
    readonly property int visibleSlots: Number(showLabel) + Number(showNumber) + Number(showMeter)
    readonly property real fixedWidth: labelWidth + valueWidth + previewWidth + Math.max(0, visibleSlots - 1) * spacing

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

    TextMetrics {
        id: unavailableMetrics
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        text: i18nc("@info:status", "N/A")
    }

    Controls.Label {
        id: labelText

        visible: stat.showLabel
        text: stat.label
        color: stat.accentColor
        elide: Text.ElideRight
        font.pixelSize: (Plasmoid.configuration.barLabelFontSize != 0) ? Plasmoid.configuration.barLabelFontSize : Kirigami.Theme.smallFont.pixelSize
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: stat.labelWidth
        Layout.preferredWidth: stat.labelWidth
        Layout.maximumWidth: stat.labelWidth
    }

    Rectangle {
        visible: stat.showMeter
        clip: true
        Layout.minimumWidth: stat.previewWidth
        Layout.preferredWidth: stat.previewWidth
        Layout.maximumWidth: stat.previewWidth
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 0.9, stat.height - Kirigami.Units.smallSpacing)
        radius: 2
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.32)

        Rectangle {
            visible: stat.presentation === "bar"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.bottomMargin: 2
            height: Math.max(0, parent.height - 4) * (stat.dataAvailable ? Math.max(0, Math.min(100, stat.percent)) / 100 : 0)
            color: Qt.rgba(stat.accentColor.r, stat.accentColor.g, stat.accentColor.b, 0.72)
        }

        Loader {
            id: sparklineLoader
            active: stat.showGraph
            opacity: stat.dataAvailable ? 1 : 0.25
            anchors.fill: parent
            anchors.margins: 2
            sourceComponent: Component {
                Local.Sparkline {
                    sampleValue: stat.percent
                    sampleInterval: stat.sampleInterval
                    dataAvailable: stat.dataAvailable
                    historyKey: stat.historyKey
                    lineColor: stat.accentColor
                    showFill: true
                }
            }
        }

        Controls.Label {
            anchors.centerIn: parent
            visible: !stat.dataAvailable
            text: i18nc("@info:status", "N/A")
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    Controls.Label {
        id: valueText

        visible: stat.showNumber
        text: stat.dataAvailable ? stat.value : i18nc("@info:status", "N/A")
        color: Kirigami.Theme.textColor
        elide: Text.ElideRight
        font.pixelSize: Plasmoid.configuration.barValueFontSize || Kirigami.Theme.smallFont.pixelSize
        font.features: { "tnum": 1 }
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: stat.valueWidth
        Layout.preferredWidth: stat.valueWidth
        Layout.maximumWidth: stat.valueWidth
    }
}
