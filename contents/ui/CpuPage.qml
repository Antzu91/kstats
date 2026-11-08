import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "CpuSensorChoice.js" as CpuSensorChoice
import "." as Local

Item {
    id: page

    required property var rootItem
    property string cpuModel: ""
    readonly property var temperatureChoice: CpuSensorChoice.selection(rootItem.cpuTemperatureSetting)
    readonly property var fanChoice: CpuSensorChoice.selection(rootItem.cpuFanSetting)
    // Automatic candidates; rescanned whenever the sensor tree changes.
    property string discoveredTemperatureSensorId: ""
    property string discoveredFanSensorId: ""
    readonly property string temperatureSensorId: CpuSensorChoice.resolvedSensorId(temperatureChoice, discoveredTemperatureSensorId)
    readonly property string fanSensorId: CpuSensorChoice.resolvedSensorId(fanChoice, discoveredFanSensorId)

    clip: true
    implicitHeight: pageContent.implicitHeight
    Layout.fillWidth: true
    Layout.fillHeight: true

    function cpuModelText() {
        return page.cpuModel.length > 0 ? page.cpuModel : i18nc("@label fallback CPU title", "Processor");
    }

    function optionalSensorText(sensor, sensorId, choice) {
        if (choice.mode === "off") {
            return i18nc("@info:status", "Off");
        }
        if (sensorId.length === 0) {
            return i18nc("@info:status", "N/A");
        }
        return page.rootItem.sensorText(sensor);
    }

    function parseCpuModel(text) {
        var fallback = "";
        var lines = String(text || "").split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
            var separator = lines[i].indexOf(":");
            if (separator < 0) {
                continue;
            }

            var key = lines[i].slice(0, separator).trim().toLowerCase();
            var value = lines[i].slice(separator + 1).trim();
            if (value.length === 0) {
                continue;
            }

            if (key === "model name") {
                return value;
            }
            if ((key === "hardware" || key === "processor" || key === "cpu model") && fallback.length === 0) {
                fallback = value;
            }
        }

        return fallback;
    }

    function loadCpuModel() {
        cpuInfoCommand.exec("cat /proc/cpuinfo", function(result) {
            if (result.exitCode !== 0) {
                page.cpuModel = "";
                return;
            }
            page.cpuModel = page.parseCpuModel(result.stdout);
        });
    }

    function cleanName(value) {
        return String(value || "").trim();
    }

    function collectSensors(parentIndex, pathNames, entries) {
        var rows = parentIndex === undefined ? cpuSensorTree.rowCount() : cpuSensorTree.rowCount(parentIndex);
        for (var row = 0; row < rows; row++) {
            var index = parentIndex === undefined ? cpuSensorTree.index(row, 0) : cpuSensorTree.index(row, 0, parentIndex);
            var display = page.cleanName(cpuSensorTree.data(index, Qt.DisplayRole));
            var sensorId = page.cleanName(cpuSensorTree.data(index, Sensors.SensorTreeModel.SensorId));
            var nextPath = pathNames.slice(0);
            if (display.length > 0) {
                nextPath.push(display);
            }

            if (sensorId.length > 0) {
                entries.push({ sensorId: sensorId, pathNames: nextPath });
            } else {
                page.collectSensors(index, nextPath, entries);
            }
        }
    }

    function rebuildHardwareSensors() {
        if (temperatureChoice.mode !== "auto" && fanChoice.mode !== "auto") {
            return;
        }
        var entries = [];
        page.collectSensors(undefined, [], entries);
        // Automatic keeps a sensor while it exists and recovers when it vanishes.
        page.discoveredTemperatureSensorId = CpuSensorChoice.automaticSensor(page.discoveredTemperatureSensorId, entries, "temperature");
        page.discoveredFanSensorId = CpuSensorChoice.automaticSensor(page.discoveredFanSensorId, entries, "fan");
    }

    function scheduleHardwareDiscovery() {
        hardwareDiscoveryTimer.restart();
    }

    onTemperatureChoiceChanged: scheduleHardwareDiscovery()
    onFanChoiceChanged: scheduleHardwareDiscovery()

    Component.onCompleted: {
        page.loadCpuModel();
        page.scheduleHardwareDiscovery();
    }

    component CpuSummaryRow: RowLayout {
        property string label: ""
        property string value: ""
        property color markerColor: Kirigami.Theme.positiveTextColor
        property bool showMarker: true
        property real valueMaximumWidth: Kirigami.Units.gridUnit * 10

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 2
            opacity: showMarker ? 1 : 0
            color: markerColor
        }

        Controls.Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            elide: Text.ElideRight
            Layout.minimumWidth: 0
            Layout.fillWidth: true
        }

        Controls.Label {
            text: value
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.minimumWidth: 0
            Layout.maximumWidth: valueMaximumWidth
        }
    }

    Local.RunCommand {
        id: cpuInfoCommand
    }

    Sensors.SensorTreeModel {
        id: cpuSensorTree
    }

    Connections {
        target: cpuSensorTree

        function onModelReset() {
            page.scheduleHardwareDiscovery();
        }

        function onRowsInserted() {
            page.scheduleHardwareDiscovery();
        }

        function onRowsRemoved() {
            page.scheduleHardwareDiscovery();
        }
    }

    Timer {
        id: hardwareDiscoveryTimer

        interval: 100
        repeat: false
        onTriggered: page.rebuildHardwareSensors()
    }

    Sensors.Sensor {
        id: cpuTemperatureSensor

        enabled: page.rootItem.cpuDetailsVisible && page.temperatureSensorId.length > 0
        sensorId: page.temperatureSensorId
        updateRateLimit: page.rootItem.sensorUpdateRate
    }

    Sensors.Sensor {
        id: cpuFanSensor

        enabled: page.rootItem.cpuDetailsVisible && page.fanSensorId.length > 0
        sensorId: page.fanSensorId
        updateRateLimit: page.rootItem.sensorUpdateRate
    }

    ColumnLayout {
        id: pageContent

        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 7.2, cpuSummaryContent.implicitHeight + Kirigami.Units.smallSpacing * 2)
            clip: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            RowLayout {
                id: cpuSummaryContent

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing

                Local.RingGauge {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
                    value: page.rootItem.cpuUsageMonitor.percent ?? 0
                    dataAvailable: page.rootItem.cpuUsageMonitor.available
                    label: i18nc("@label", "CPU")
                    accentColor: Kirigami.Theme.positiveTextColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    // The ring already carries the usage reading; the title names the hardware.
                    Controls.Label {
                        text: page.cpuModelText()
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    CpuSummaryRow {
                        label: i18nc("@label", "Logical CPUs")
                        value: page.rootItem.sensorText(page.rootItem.cpuCountSensor)
                        showMarker: false
                    }

                    CpuSummaryRow {
                        label: i18nc("@label", "Cores")
                        value: page.rootItem.sensorText(page.rootItem.cpuCoreCountSensor)
                        markerColor: Kirigami.Theme.positiveTextColor
                    }

                    CpuSummaryRow {
                        label: i18nc("@label", "Temperature")
                        value: page.optionalSensorText(cpuTemperatureSensor, page.temperatureSensorId, page.temperatureChoice)
                        markerColor: Kirigami.Theme.neutralTextColor
                    }

                    CpuSummaryRow {
                        label: i18nc("@label", "Fan")
                        value: page.optionalSensorText(cpuFanSensor, page.fanSensorId, page.fanChoice)
                        markerColor: Kirigami.Theme.visitedLinkColor
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        Local.CpuCoreBars {
            active: page.rootItem.cpuDetailsVisible
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4.6
            refreshInterval: Math.max(1000, page.rootItem.sensorUpdateRate)
        }

        Local.CpuBreakdown {
            detailHistory: page.rootItem.cpuDetailHistory
            windowDuration: page.rootItem.historyWindowDuration
            now: page.rootItem.historyNow
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5.8
        }

        Local.TopApplicationList {
            active: page.rootItem.cpuDetailsVisible
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            metric: "cpu"
            limit: 5
            refreshInterval: Math.max(1500, page.rootItem.sensorUpdateRate * 2)
        }
    }
}
