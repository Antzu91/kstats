import QtQuick

import org.kde.ksysguard.sensors as Sensors

Item {
    id: discovery

    property bool active: true
    property var devices: []
    readonly property var sensorTree: treeLoader.item

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
            devices = next;
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
