import QtQuick
import org.kde.ksysguard.sensors as Sensors

Item {
    id: pool
    required property var historyStore
    property var devices: []
    property string selectedDeviceId: ""
    property bool panelDemand: false
    property bool popupDemand: false
    property int updateRateLimit: 1000
    property Component sensorComponent: Component { Sensors.Sensor {} }
    property var monitors: ({})
    property bool completed: false
    readonly property var selectedUsage: monitors[selectedDeviceId]
        ? monitors[selectedDeviceId].usage : missingUsage

    // Safe even before discovery or if a never-seen configured device is absent.
    GpuSensor {
        id: missingUsage
        metricId: "gpuUsage/" + pool.selectedDeviceId
        active: pool.panelDemand || pool.popupDemand
    }

    Component {
        id: deviceFactory
        GpuDeviceMonitor {
            historyStore: pool.historyStore
            panelDemand: pool.panelDemand
            popupDemand: pool.popupDemand
            updateRateLimit: pool.updateRateLimit
            sensorComponent: pool.sensorComponent
        }
    }

    function monitorFor(key) { return monitors[key] || null; }

    function reconcile() {
        if (!completed) {
            return;
        }
        var next = {};
        for (var i = 0; i < devices.length; ++i) {
            var device = devices[i];
            var monitor = monitors[device.key];
            if (monitor) {
                monitor.device = device;
            } else {
                monitor = deviceFactory.createObject(pool, { device: device });
            }
            next[device.key] = monitor;
        }
        // Preserve a missing manual selection and its exact sensor IDs. Retry
        // that source; never silently select another device after disappearance.
        if (!next[selectedDeviceId] && monitors[selectedDeviceId]) {
            next[selectedDeviceId] = monitors[selectedDeviceId];
        }
        var previous = monitors;
        monitors = next;
        Object.keys(previous).forEach(function(key) {
            if (!next[key]) {
                previous[key].destroy();
            }
        });
    }

    function sample(timestamp) {
        Object.keys(monitors).forEach(function(key) {
            monitors[key].sample(timestamp);
        });
    }

    onDevicesChanged: reconcile()
    onSelectedDeviceIdChanged: reconcile()
    Component.onCompleted: { completed = true; reconcile(); }
}
