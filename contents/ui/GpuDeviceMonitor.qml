import QtQuick
import org.kde.ksysguard.sensors as Sensors

// Exactly one utilization subscription and sampler per device. Selecting the
// panel GPU transfers demand, not ownership of the source or its history.
Item {
    id: deviceMonitor
    required property var device
    required property var historyStore
    property bool selected: false
    property bool panelDemand: false
    property bool popupDemand: false
    property int updateRateLimit: 1000
    property Component sensorComponent: Component { Sensors.Sensor {} }
    property alias usage: usage
    property alias memory: memory
    property alias temperature: temperature

    GpuSensor {
        id: usage
        metricId: "gpuUsage/" + deviceMonitor.device.key
        valueMode: "percent"
        active: (deviceMonitor.panelDemand && deviceMonitor.selected) || deviceMonitor.popupDemand
        sensorId: deviceMonitor.device.usageSensorId
        updateRateLimit: deviceMonitor.updateRateLimit
        sensorComponent: deviceMonitor.sensorComponent
        clock: deviceMonitor.historyStore.clock
    }
    GpuSensor {
        id: memory
        metricId: "gpuMemory/" + deviceMonitor.device.key
        valueMode: "percent"
        active: deviceMonitor.popupDemand
        sensorId: deviceMonitor.device.memorySensorId
        updateRateLimit: deviceMonitor.updateRateLimit
        sensorComponent: deviceMonitor.sensorComponent
        clock: deviceMonitor.historyStore.clock
    }
    GpuSensor {
        id: temperature
        metricId: "gpuTemperature/" + deviceMonitor.device.key
        active: deviceMonitor.popupDemand
        sensorId: deviceMonitor.device.temperatureSensorId
        updateRateLimit: deviceMonitor.updateRateLimit
        sensorComponent: deviceMonitor.sensorComponent
        clock: deviceMonitor.historyStore.clock
    }
    HistorySampler { id: usageHistory; monitor: usage; store: deviceMonitor.historyStore }
    HistorySampler { id: memoryHistory; monitor: memory; store: deviceMonitor.historyStore }
    HistorySampler { id: temperatureHistory; monitor: temperature; store: deviceMonitor.historyStore }

    function sample(timestamp) {
        usageHistory.sample(timestamp);
        memoryHistory.sample(timestamp);
        temperatureHistory.sample(timestamp);
    }
}
