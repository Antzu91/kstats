import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: rates
    property string uploadText
    property string downloadText
    property color accentColor: Kirigami.Theme.visitedLinkColor
    readonly property real innerSpacing: Math.max(1, Kirigami.Units.smallSpacing / 4)

    function networkRateNumber(text) {
        const value = String(text).trim();
        const match = value.match(/^(.*\S)\s+(\S+\/s)$/);
        return match ? match[1] : value;
    }

    function networkRateUnit(text) {
        const value = String(text).trim();
        const match = value.match(/^(.*\S)\s+(\S+\/s)$/);
        return match ? match[2] : "";
    }

    ColumnLayout {
        id: networkRates

        readonly property real rateFontSize: Math.max(7, Kirigami.Theme.smallFont.pixelSize - 2)
        readonly property real arrowWidth: Math.ceil(networkArrowMetrics.width)
        readonly property real valueGap: Math.max(2, rates.innerSpacing)
        readonly property real unitGap: Math.max(2, rates.innerSpacing)
        readonly property real valuePadding: Math.max(2, Kirigami.Units.smallSpacing / 2)
        readonly property real valueWidth: Math.ceil(networkValueMetrics.width) + valuePadding
        readonly property real unitWidth: Math.ceil(networkUnitMetrics.width)
        readonly property real valueSlotWidth: valueWidth + valueGap
        readonly property real unitSlotWidth: unitWidth + unitGap
        readonly property real fixedWidth: arrowWidth + valueSlotWidth + unitSlotWidth
        readonly property real rowHeight: rateFontSize + 1

        spacing: 1
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: fixedWidth
        Layout.preferredWidth: fixedWidth
        Layout.maximumWidth: fixedWidth
        Layout.preferredHeight: rowHeight * 2 + spacing

        TextMetrics {
            id: networkArrowMetrics

            font.pixelSize: networkRates.rateFontSize
            font.weight: Font.DemiBold
            text: i18nc("@label upload", "↑")
        }

        TextMetrics {
            id: networkValueMetrics

            font.pixelSize: networkRates.rateFontSize
            text: "999.9"
        }

        TextMetrics {
            id: networkUnitMetrics

            font.pixelSize: networkRates.rateFontSize
            text: "MiB/s"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: networkRates.rowHeight
            spacing: 0

            Controls.Label {
                text: i18nc("@label upload", "↑")
                color: rates.accentColor
                font.pixelSize: networkRates.rateFontSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                Layout.minimumWidth: networkRates.arrowWidth
                Layout.preferredWidth: networkRates.arrowWidth
                Layout.maximumWidth: networkRates.arrowWidth
                Layout.preferredHeight: networkRates.rowHeight
            }

            Controls.Label {
                text: rates.networkRateNumber(rates.uploadText)
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                font.pixelSize: networkRates.rateFontSize
                font.features: { "tnum": 1 }
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                leftPadding: networkRates.valueGap
                Layout.minimumWidth: networkRates.valueSlotWidth
                Layout.preferredWidth: networkRates.valueSlotWidth
                Layout.maximumWidth: networkRates.valueSlotWidth
                Layout.preferredHeight: networkRates.rowHeight
            }

            Controls.Label {
                text: rates.networkRateUnit(rates.uploadText)
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                font.pixelSize: networkRates.rateFontSize
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                leftPadding: networkRates.unitGap
                Layout.minimumWidth: networkRates.unitSlotWidth
                Layout.preferredWidth: networkRates.unitSlotWidth
                Layout.maximumWidth: networkRates.unitSlotWidth
                Layout.preferredHeight: networkRates.rowHeight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: networkRates.rowHeight
            spacing: 0

            Controls.Label {
                text: i18nc("@label download", "↓")
                color: rates.accentColor
                font.pixelSize: networkRates.rateFontSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                Layout.minimumWidth: networkRates.arrowWidth
                Layout.preferredWidth: networkRates.arrowWidth
                Layout.maximumWidth: networkRates.arrowWidth
                Layout.preferredHeight: networkRates.rowHeight
            }

            Controls.Label {
                text: rates.networkRateNumber(rates.downloadText)
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                font.pixelSize: networkRates.rateFontSize
                font.features: { "tnum": 1 }
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                leftPadding: networkRates.valueGap
                Layout.minimumWidth: networkRates.valueSlotWidth
                Layout.preferredWidth: networkRates.valueSlotWidth
                Layout.maximumWidth: networkRates.valueSlotWidth
                Layout.preferredHeight: networkRates.rowHeight
            }

            Controls.Label {
                text: rates.networkRateUnit(rates.downloadText)
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                font.pixelSize: networkRates.rateFontSize
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                leftPadding: networkRates.unitGap
                Layout.minimumWidth: networkRates.unitSlotWidth
                Layout.preferredWidth: networkRates.unitSlotWidth
                Layout.maximumWidth: networkRates.unitSlotWidth
                Layout.preferredHeight: networkRates.rowHeight
            }
        }
    }
}
