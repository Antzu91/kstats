import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "." as Local

Item {
    id: page

    required property var rootItem
    readonly property var gpuDevices: rootItem.gpuDevices

    clip: true
    Layout.fillWidth: true
    Layout.fillHeight: true

    Controls.ScrollView {
        id: gpuScroll

        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: gpuScroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: page.gpuDevices

                delegate: Rectangle {
                    id: gpuCard

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: gpuCardContent.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

                    readonly property var monitors: page.rootItem.gpuMonitors(modelData.key)
                    readonly property var usage: monitors ? monitors.usage : null
                    readonly property var memory: monitors ? monitors.memory : null
                    readonly property var temperature: monitors ? monitors.temperature : null

                    ColumnLayout {
                        id: gpuCardContent

                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: "video-display"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                            }

                            Controls.Label {
                                text: page.rootItem.gpuName(gpuCard.modelData)
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                            }
                        }

                        Local.DropdownMetric {
                            visible: gpuCard.modelData.usageSensorId.length > 0
                            title: i18nc("@label", "GPU")
                            iconName: "video-display"
                            primaryValue: gpuCard.usage ? gpuCard.usage.text : i18nc("@info:status", "N/A")
                            showSparkline: gpuCard.usage !== null && gpuCard.usage.available
                            showProgress: gpuCard.usage !== null && gpuCard.usage.available
                            secondaryValue: i18nc("@label", "Graphics processor usage")
                            sensorId: gpuCard.modelData.usageSensorId
                            percent: gpuCard.usage ? (gpuCard.usage.percent ?? 0) : 0
                            samples: gpuCard.usage ? page.rootItem.histories.samplesFor(gpuCard.usage.metricId, gpuCard.usage.sourceKey) : []
                            windowDuration: page.rootItem.historyWindowDuration
                            now: page.rootItem.historyNow
                            accentColor: Kirigami.Theme.negativeTextColor
                        }

                        Local.DropdownMetric {
                            visible: gpuCard.modelData.memorySensorId.length > 0
                            title: i18nc("@label", "GPU Memory")
                            iconName: "memory"
                            primaryValue: gpuCard.memory ? gpuCard.memory.text : i18nc("@info:status", "N/A")
                            showSparkline: gpuCard.memory !== null && gpuCard.memory.available
                            showProgress: gpuCard.memory !== null && gpuCard.memory.available
                            secondaryValue: i18nc("@label", "Graphics memory used")
                            sensorId: gpuCard.modelData.memorySensorId
                            percent: gpuCard.memory ? (gpuCard.memory.percent ?? 0) : 0
                            samples: gpuCard.memory ? page.rootItem.histories.samplesFor(gpuCard.memory.metricId, gpuCard.memory.sourceKey) : []
                            windowDuration: page.rootItem.historyWindowDuration
                            now: page.rootItem.historyNow
                            accentColor: Kirigami.Theme.focusColor
                        }

                        Local.DropdownMetric {
                            visible: gpuCard.modelData.temperatureSensorId.length > 0
                            title: i18nc("@label", "GPU Temperature")
                            iconName: "temperature-normal"
                            primaryValue: gpuCard.temperature ? gpuCard.temperature.text : i18nc("@info:status", "N/A")
                            showSparkline: gpuCard.temperature !== null && gpuCard.temperature.available
                            showProgress: gpuCard.temperature !== null && gpuCard.temperature.available
                            secondaryValue: i18nc("@label", "Graphics processor temperature")
                            sensorId: gpuCard.modelData.temperatureSensorId
                            percent: gpuCard.temperature ? (gpuCard.temperature.percent ?? 0) : 0
                            samples: gpuCard.temperature ? page.rootItem.histories.samplesFor(gpuCard.temperature.metricId, gpuCard.temperature.sourceKey) : []
                            windowDuration: page.rootItem.historyWindowDuration
                            now: page.rootItem.historyNow
                            accentColor: Kirigami.Theme.neutralTextColor
                        }
                    }
                }
            }

            Controls.Label {
                visible: page.gpuDevices.length === 0
                text: i18nc("@info:status", "No GPU sensors found")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
