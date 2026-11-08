import QtQuick

import org.kde.ksysguard.sensors as Sensors

// Lists objects that have a matching KSysGuard sensor, for settings pickers.
// keyFromSensorId returns the object's key for a matching sensor ID, else "".
// Without a sensor daemon the list stays empty; settings still offer the rest.
Item {
    id: listing

    property var keyFromSensorId: function(sensorId) { return ""; }
    // [{ key, name, label }] sorted by name: name is the owning object's label
    // (an interface, volume or chip) and label the matching sensor's own label.
    property var entries: []
    readonly property var keys: entries.map(function(entry) { return entry.key; })
    readonly property var sensorTree: treeLoader.item

    visible: false

    function nameFor(key) {
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].key === key) {
                return entries[i].name;
            }
        }
        return "";
    }

    function collect(parentIndex, parentName, found) {
        var rows = parentIndex === undefined ? sensorTree.rowCount() : sensorTree.rowCount(parentIndex);
        for (var row = 0; row < rows; row++) {
            var index = parentIndex === undefined ? sensorTree.index(row, 0) : sensorTree.index(row, 0, parentIndex);
            var display = String(sensorTree.data(index, Qt.DisplayRole) || "").trim();
            if (sensorTree.rowCount(index) > 0) {
                collect(index, display, found);
                continue;
            }
            var key = keyFromSensorId(String(sensorTree.data(index, Sensors.SensorTreeModel.SensorId) || ""));
            if (key.length > 0 && !found.some(function(entry) { return entry.key === key; })) {
                found.push({ key: key, name: parentName.length > 0 ? parentName : key, label: display });
            }
        }
    }

    function rebuild() {
        var found = [];
        if (sensorTree) {
            collect(undefined, "", found);
        }
        found.sort(function(left, right) {
            return left.name.localeCompare(right.name) || left.key.localeCompare(right.key);
        });
        if (JSON.stringify(found) !== JSON.stringify(entries)) {
            entries = found;
        }
    }

    onKeyFromSensorIdChanged: rebuildTimer.restart()

    Loader {
        id: treeLoader
        sourceComponent: Component {
            Sensors.SensorTreeModel {}
        }
        onLoaded: rebuildTimer.restart()
    }

    Connections {
        target: listing.sensorTree

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
        onTriggered: listing.rebuild()
    }
}
