import QtQuick

import org.kde.ksysguard.sensors as Sensors
import "DiskSource.js" as DiskSource

// Owns disk scope for the panel, popup, tooltip and history: which capacity
// and activity sensors are measured. A chosen volume never switches, even
// while it is unmounted; it shows N/A instead.
Item {
    id: scope

    property string source: "all"
    property string usageSensorIdSetting: DiskSource.defaults.usage
    property string readSensorIdSetting: DiskSource.defaults.read
    property string writeSensorIdSetting: DiskSource.defaults.write
    // Demand for the volume's display name.
    property bool active: false

    readonly property string effectiveSource: DiskSource.effectiveSource(source,
        usageSensorIdSetting, readSensorIdSetting, writeSensorIdSetting)
    readonly property string mode: DiskSource.mode(effectiveSource)
    readonly property string volumeId: DiskSource.volumeFromSource(effectiveSource)
    readonly property var sensorIds: DiskSource.sensorIds(effectiveSource,
        usageSensorIdSetting, readSensorIdSetting, writeSensorIdSetting)
    readonly property string volumeName: nameSensor.status === Sensors.Sensor.Ready
        && typeof nameSensor.value === "string" ? nameSensor.value.trim() : ""
    readonly property string scopeText: mode === "volume"
        ? (volumeName.length > 0 ? volumeName : volumeId)
        : mode === "custom" ? i18nc("@label disk scope", "Custom sensors")
        : i18nc("@label disk scope", "All disks")

    visible: false

    Sensors.Sensor {
        id: nameSensor
        sensorId: scope.mode === "volume" ? "disk/" + scope.volumeId + "/name" : ""
        enabled: scope.active && sensorId.length > 0
        updateRateLimit: 60000
    }
}
