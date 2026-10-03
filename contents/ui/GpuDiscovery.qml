import QtQuick
import QtQml.Models

import org.kde.ksysguard.sensors as Sensors
import "." as Local

Item {
    id: discovery

    property bool active: true
    property var devices: []
    property var sensorNames: ({})
    property var hardwareNames: []
    readonly property var sensorTree: treeLoader.item

    function deviceName(device) {
        var name = sensorNames[device.key] || device.name;
        var index = Number(device.key.substring(3));
        var genericName = i18nc("@title %1 is GPU number", "GPU %1", index + 1);
        if (name !== device.key && name !== genericName && !/^GPU \d+$/.test(name)) {
            return i18nc("@label GPU number and model", "%1: %2", genericName, name);
        }
        // Only use the PCI ordering when every KDE device has a matching slot.
        if (hardwareNames.length === devices.length && devices.every(function(entry, slot) {
            return entry.key === "gpu" + slot;
        }) && hardwareNames[index]) {
            return i18nc("@label GPU number and model", "%1: %2", genericName, hardwareNames[index]);
        }
        return name;
    }

    function loadHardwareNames() {
        var path = decodeURIComponent(Qt.resolvedUrl("../code/gpu-names.sh").toString().replace(/^file:\/\//, ""));
        hardwareCommand.exec("sh '" + path.replace(/'/g, "'\\''") + "'", function(result) {
            if (result.exitCode !== 0) {
                discovery.hardwareNames = [];
                return;
            }
            discovery.hardwareNames = result.stdout.split("\n").filter(function(line) {
                return line.indexOf("\t") >= 0;
            }).map(function(line) {
                return line.substring(line.indexOf("\t") + 1).trim();
            });
        });
    }

    function collectDevices(parentIndex, pathNames, devicesByKey) {
        var rows = parentIndex === undefined ? sensorTree.rowCount() : sensorTree.rowCount(parentIndex);
        for (var row = 0; row < rows; row++) {
            var index = parentIndex === undefined ? sensorTree.index(row, 0) : sensorTree.index(row, 0, parentIndex);
            var display = String(sensorTree.data(index, Qt.DisplayRole) || "").trim();
            var sensorId = String(sensorTree.data(index, Sensors.SensorTreeModel.SensorId) || "");
            var nextPath = pathNames.concat([display]);
            if (sensorTree.rowCount(index) > 0) {
                collectDevices(index, nextPath, devicesByKey);
                continue;
            }

            // Exclude VRAM percentages, hotspot temperatures, and grouped sensors.
            var match = sensorId.match(/^gpu\/(gpu\d+)\/(usage|usedVram|temperature)$/);
            if (!match) {
                continue;
            }
            var key = match[1];
            if (!devicesByKey[key]) {
                devicesByKey[key] = {
                    key: key,
                    name: pathNames[pathNames.length - 1] || key,
                    usageSensorId: "",
                    memorySensorId: "",
                    temperatureSensorId: ""
                };
            }
            var metric = match[2] === "usedVram" ? "memory" : match[2];
            devicesByKey[key][metric + "SensorId"] = sensorId;
        }
    }

    function rebuildDevices() {
        var devicesByKey = {};
        if (sensorTree) {
            collectDevices(undefined, [], devicesByKey);
        }
        var keys = Object.keys(devicesByKey).sort(function(left, right) {
            return Number(left.substring(3)) - Number(right.substring(3));
        });
        var next = keys.map(function(key) {
            return devicesByKey[key];
        });
        // Metadata updates must not recreate the popup cards and erase history.
        if (JSON.stringify(next) !== JSON.stringify(devices)) {
            sensorNames = ({});
            hardwareNames = [];
            devices = next;
            loadHardwareNames();
        }
    }

    Component.onCompleted: rebuildTimer.restart()

    Loader {
        id: treeLoader
        sourceComponent: Component {
            Sensors.SensorTreeModel {}
        }
        onLoaded: rebuildTimer.restart()
    }

    Timer {
        interval: 5000
        running: discovery.active && discovery.devices.length === 0
        repeat: true
        onTriggered: {
            // A failed initial query needs a fresh model to request sensors again.
            treeLoader.active = false;
            treeLoader.active = true;
        }
    }

    Local.RunCommand {
        id: hardwareCommand
    }

    Instantiator {
        model: discovery.devices

        delegate: Sensors.Sensor {
            required property var modelData

            // Static names must not keep the GPU's monitoring backend running.
            enabled: discovery.active && !discovery.sensorNames[modelData.key]
            sensorId: "gpu/" + modelData.key + "/name"
            updateRateLimit: 60000
            onValueChanged: {
                if (status === Sensors.Sensor.Ready && typeof value === "string" && value.trim().length > 0) {
                    var names = Object.assign({}, discovery.sensorNames);
                    names[modelData.key] = value.trim();
                    discovery.sensorNames = names;
                }
            }
        }
    }

    Connections {
        target: discovery.sensorTree

        function onModelReset() {
            rebuildTimer.restart();
        }
        function onRowsInserted() {
            rebuildTimer.restart();
        }
        function onRowsRemoved() {
            rebuildTimer.restart();
        }
        function onDataChanged() {
            rebuildTimer.restart();
        }
    }

    Timer {
        id: rebuildTimer
        interval: 100
        onTriggered: discovery.rebuildDevices()
    }
}
