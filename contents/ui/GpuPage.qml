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

                    readonly property var usage: modelData.key === page.rootItem.gpuDeviceId
                        ? page.rootItem.gpuUsageMonitor : usageSensor

                    Local.GpuSensor {
                        id: usageSensor
                        valueMode: "percent"

                        active: page.rootItem.gpuDetailsVisible && gpuCard.modelData.key !== page.rootItem.gpuDeviceId
                        sensorId: gpuCard.modelData.usageSensorId
                        updateRateLimit: page.rootItem.sensorUpdateRate
                    }

                    Local.GpuSensor {
                        id: memorySensor
                        valueMode: "percent"

                        active: page.rootItem.gpuDetailsVisible
                        sensorId: gpuCard.modelData.memorySensorId
                        updateRateLimit: page.rootItem.sensorUpdateRate
                    }

                    Local.GpuSensor {
                        id: temperatureSensor

                        active: page.rootItem.gpuDetailsVisible
                        sensorId: gpuCard.modelData.temperatureSensorId
                        updateRateLimit: page.rootItem.sensorUpdateRate
                    }

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
                            primaryValue: gpuCard.usage.text
                            showSparkline: gpuCard.usage.available
                            showProgress: gpuCard.usage.available
                            secondaryValue: i18nc("@label", "Graphics processor usage")
                            sensorId: usageSensor.sensorId
                            percent: gpuCard.usage.percent ?? 0
                            accentColor: Kirigami.Theme.negativeTextColor
                        }

                        Local.DropdownMetric {
                            visible: gpuCard.modelData.memorySensorId.length > 0
                            title: i18nc("@label", "GPU Memory")
                            iconName: "memory"
                            primaryValue: memorySensor.text
                            showSparkline: memorySensor.available
                            showProgress: memorySensor.available
                            secondaryValue: i18nc("@label", "Graphics memory used")
                            sensorId: memorySensor.sensorId
                            percent: memorySensor.percent ?? 0
                            accentColor: Kirigami.Theme.focusColor
                        }

                        Local.DropdownMetric {
                            visible: gpuCard.modelData.temperatureSensorId.length > 0
                            title: i18nc("@label", "GPU Temperature")
                            iconName: "temperature-normal"
                            primaryValue: temperatureSensor.text
                            showSparkline: temperatureSensor.available
                            showProgress: temperatureSensor.available
                            secondaryValue: i18nc("@label", "Graphics processor temperature")
                            sensorId: temperatureSensor.sensorId
                            percent: temperatureSensor.percent ?? 0
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
