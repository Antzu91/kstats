import QtQuick
import org.kde.ksysguard.sensors as Sensors

// One owner per device collects every history metric while the GPU module is
// enabled or its page is visible. Panel selection only chooses what is shown.
Item {
    id: deviceMonitor
    required property var device
    required property var historyStore
    property bool panelDemand: false
    property bool popupDemand: false
    readonly property bool historyDemand: panelDemand || popupDemand
    property int updateRateLimit: 1000
    property Component sensorComponent: Component { Sensors.Sensor {} }
    property alias usage: usage
    property alias memory: memory
    property alias temperature: temperature

    GpuSensor {
        id: usage
        metricId: "gpuUsage/" + deviceMonitor.device.key
        valueMode: "percent"
        active: deviceMonitor.historyDemand
        sensorId: deviceMonitor.device.usageSensorId
        updateRateLimit: deviceMonitor.updateRateLimit
        sensorComponent: deviceMonitor.sensorComponent
        clock: deviceMonitor.historyStore.clock
    }
    GpuSensor {
        id: memory
        metricId: "gpuMemory/" + deviceMonitor.device.key
        valueMode: "percent"
        active: deviceMonitor.historyDemand
        sensorId: deviceMonitor.device.memorySensorId
        updateRateLimit: deviceMonitor.updateRateLimit
        sensorComponent: deviceMonitor.sensorComponent
        clock: deviceMonitor.historyStore.clock
    }
    GpuSensor {
        id: temperature
        metricId: "gpuTemperature/" + deviceMonitor.device.key
        active: deviceMonitor.historyDemand
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
