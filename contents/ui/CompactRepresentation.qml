import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "." as Local

Item {
    id: compact

    required property var rootItem
    readonly property real horizontalPadding: Math.max(1, Kirigami.Units.smallSpacing / 2)
    readonly property real moduleSpacing: Math.max(1, Kirigami.Units.smallSpacing / 2)
    readonly property real innerSpacing: Math.max(1, Kirigami.Units.smallSpacing / 4)
    readonly property real minimumBarWidth: Kirigami.Units.gridUnit * 4
    readonly property real configuredBarLength: Number(Plasmoid.configuration.compactBarLength)
    readonly property bool hasConfiguredBarLength: configuredBarLength > 0
    readonly property real adaptiveBarLength: row.implicitWidth
    readonly property real fixedWidth: Math.max(minimumBarWidth, hasConfiguredBarLength ? configuredBarLength : adaptiveBarLength)
    readonly property real contentWidth: Math.max(0, hasConfiguredBarLength ? fixedWidth - horizontalPadding * 2 : fixedWidth)

    Layout.minimumWidth: fixedWidth
    Layout.minimumHeight: Kirigami.Units.gridUnit
    Layout.preferredWidth: fixedWidth
    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
    Layout.maximumWidth: fixedWidth

    implicitWidth: fixedWidth
    implicitHeight: Layout.preferredHeight
    clip: true

    component ClickTarget: Item {
        id: target

        property int tabIndex: 0
        property string accessibleName
        property string detailText
        Controls.ToolTip.visible: targetMouse.containsMouse
        Controls.ToolTip.text: detailText
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: accessibleName
        Accessible.onPressAction: compact.rootItem.toggleTab(tabIndex)
        Keys.onSpacePressed: compact.rootItem.toggleTab(tabIndex)
        Keys.onReturnPressed: compact.rootItem.toggleTab(tabIndex)
        property color accentColor: Kirigami.Theme.highlightColor
        default property alias content: contentRow.data
        readonly property real horizontalPadding: compact.horizontalPadding
        readonly property real fixedWidth: contentRow.implicitWidth + horizontalPadding * 2
        readonly property bool active: compact.rootItem.selectedTab === tabIndex && compact.rootItem.expanded

        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: fixedWidth
        Layout.preferredWidth: fixedWidth
        Layout.maximumWidth: fixedWidth
        Layout.preferredHeight: compact.height
        implicitWidth: fixedWidth
        implicitHeight: Layout.preferredHeight

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: target.active
                ? Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.16)
                : targetMouse.containsMouse
                    ? Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.10)
                    : "transparent"
            border.width: target.active || target.activeFocus ? 1 : 0
            border.color: Qt.rgba(target.accentColor.r, target.accentColor.g, target.accentColor.b, 0.32)
        }

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: compact.innerSpacing
        }

        MouseArea {
            id: targetMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: compact.rootItem.toggleTab(target.tabIndex)
        }
    }

    RowLayout {
        id: row

        readonly property real fitScale: Math.min(1, compact.contentWidth / Math.max(1, implicitWidth))

        x: (compact.width - row.implicitWidth * fitScale) / 2
        y: (compact.height - row.implicitHeight * fitScale) / 2
        height: parent.height
        scale: fitScale
        transformOrigin: Item.TopLeft
        spacing: compact.moduleSpacing

        Repeater {
            model: compact.rootItem.modules.ordered

            ClickTarget {
                id: moduleTarget
                required property var modelData
                readonly property var sensor: compact.rootItem.panelSensor(modelData.id)
                visible: Boolean(Plasmoid.configuration[modelData.visibilityKey])
                accentColor: modelData.color
                tabIndex: modelData.tabId
                accessibleName: modelData.label
                detailText: modelData.id === "network"
                    ? i18nc("@info:tooltip", "%1: Upload %2, download %3", modelData.label,
                        compact.rootItem.sensorText(compact.rootItem.networkUploadSensor),
                        compact.rootItem.sensorText(compact.rootItem.networkDownloadSensor))
                    : i18nc("@info:tooltip", "%1: %2", modelData.label,
                        panelStat.dataAvailable ? panelStat.value : i18nc("@info:status", "N/A"))

                Local.BarStat {
                    id: panelStat
                    visible: moduleTarget.modelData.id !== "network"
                    label: moduleTarget.modelData.label
                    showLabel: Boolean(Plasmoid.configuration[moduleTarget.modelData.id + "ShowLabel"])
                    presentation: String(Plasmoid.configuration[moduleTarget.modelData.id + "Presentation"])
                    value: moduleTarget.modelData.id === "gpu"
                        ? (compact.rootItem.gpuUsageMonitor.available
                            ? i18nc("@label GPU utilization percentage", "%1%", Math.round(compact.rootItem.gpuUsageMonitor.percent))
                            : compact.rootItem.gpuUsageMonitor.text)
                        : compact.rootItem.sensorText(moduleTarget.sensor)
                    percent: moduleTarget.modelData.id === "gpu"
                        ? compact.rootItem.gpuUsageMonitor.percent
                        : compact.rootItem.sensorPercent(moduleTarget.sensor)
                    dataAvailable: moduleTarget.modelData.id === "gpu"
                        ? compact.rootItem.gpuUsageMonitor.available
                        : compact.rootItem.sensorAvailable(moduleTarget.sensor)
                    historyKey: moduleTarget.modelData.id === "gpu" ? compact.rootItem.gpuDeviceId
                        : (moduleTarget.sensor ? moduleTarget.sensor.sensorId : "")
                    sampleInterval: compact.rootItem.sensorUpdateRate
                    accentColor: moduleTarget.accentColor
                }

                Controls.Label {
                    visible: moduleTarget.modelData.id === "network" && Plasmoid.configuration.networkShowLabel
                    text: moduleTarget.modelData.label
                    color: moduleTarget.accentColor
                    font.pixelSize: Plasmoid.configuration.barLabelFontSize || Kirigami.Theme.smallFont.pixelSize
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignVCenter
                }

                Local.NetworkRates {
                    visible: moduleTarget.modelData.id === "network"
                    uploadText: compact.rootItem.sensorText(compact.rootItem.networkUploadSensor)
                    downloadText: compact.rootItem.sensorText(compact.rootItem.networkDownloadSensor)
                    accentColor: moduleTarget.accentColor
                }
            }
        }

        Controls.ToolButton {
            visible: compact.rootItem.activeCount() === 0
            text: i18n("KStats")
            icon.name: "utilities-system-monitor"
            display: Controls.AbstractButton.IconOnly
            onClicked: compact.rootItem.expanded = !compact.rootItem.expanded
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: text
        }
    }
}
