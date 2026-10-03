import QtQuick

import org.kde.ksysguard.sensors as Sensors

Item {
    id: monitor

    property string sensorId: ""
    property bool active: false
    property int updateRateLimit: 1000
    property real lastReadingAt: 0
    readonly property int staleAfter: Math.max(5000, updateRateLimit * 3)
    readonly property var sensor: sensorLoader.item
    readonly property bool available: active && sensor !== null && sensor.enabled
        && sensor.status === Sensors.Sensor.Ready && lastReadingAt > 0
        && validValue(sensor.value)
    readonly property string text: available ? sensor.formattedValue : i18nc("@info:status", "N/A")
    readonly property real percent: available
        ? Math.max(0, Math.min(100, sensor.maximum > 0 ? Number(sensor.value) / sensor.maximum * 100 : Number(sensor.value)))
        : 0

    function validValue(value) {
        return value !== undefined && value !== null && value !== "" && isFinite(Number(value));
    }

    function reload() {
        // Recreate the sensor to drop cached readings and renew its subscription.
        sensorLoader.active = false;
        lastReadingAt = 0;
        sensorLoader.active = active && sensorId.length > 0;
        staleTimer.stop();
        if (active && sensorId.length > 0) {
            staleTimer.start();
        }
    }

    onSensorIdChanged: reload()
    onActiveChanged: reload()
    Component.onCompleted: reload()

    Loader {
        id: sensorLoader
        active: false
        sourceComponent: Component {
            Sensors.Sensor {
                sensorId: monitor.sensorId
                updateRateLimit: monitor.updateRateLimit
                onValueChanged: {
                    if (status === Sensors.Sensor.Ready && monitor.validValue(value)) {
                        monitor.lastReadingAt = Date.now();
                    }
                }
            }
        }
    }

    Timer {
        id: staleTimer
        interval: monitor.staleAfter
        repeat: true
        onTriggered: {
            if (Date.now() - monitor.lastReadingAt >= monitor.staleAfter) {
                monitor.reload();
            }
        }
    }
}
