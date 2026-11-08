import QtQuick

import org.kde.ksysguard.sensors as Sensors
import "NetworkSource.js" as NetworkSource

// Interfaces that have KSysGuard rate sensors, for the settings source picker.
// Without a sensor daemon the list stays empty; settings still offer the rest.
Item {
    id: discovery

    property var interfaces: []
    readonly property var sensorTree: treeLoader.item

    function collect(parentIndex, found) {
        var rows = parentIndex === undefined ? sensorTree.rowCount() : sensorTree.rowCount(parentIndex);
        for (var row = 0; row < rows; row++) {
            var index = parentIndex === undefined ? sensorTree.index(row, 0) : sensorTree.index(row, 0, parentIndex);
            if (sensorTree.rowCount(index) > 0) {
                collect(index, found);
                continue;
            }
            var name = NetworkSource.interfaceFromSensorId(String(sensorTree.data(index, Sensors.SensorTreeModel.SensorId) || ""));
            if (name.length > 0 && found.indexOf(name) < 0) {
                found.push(name);
            }
        }
    }

    function rebuild() {
        var found = [];
        if (sensorTree) {
            collect(undefined, found);
        }
        found.sort();
        if (JSON.stringify(found) !== JSON.stringify(interfaces)) {
            interfaces = found;
        }
    }

    Loader {
        id: treeLoader
        sourceComponent: Component {
            Sensors.SensorTreeModel {}
        }
        onLoaded: rebuildTimer.restart()
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
    }

    Timer {
        id: rebuildTimer
        interval: 100
        onTriggered: discovery.rebuild()
    }
}
