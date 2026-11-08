import QtQuick

import "DiskHealth.js" as DiskHealth
import "." as Local

// Reads SMART health from UDisks2 while the Disk page is visible: once on
// activation, then every refreshInterval. UDisks itself refreshes SMART data
// about every ten minutes, so polling faster would only repeat cached values.
// Results stay available while hidden so reopening shows them immediately.
Item {
    id: collector

    property bool active: false
    property int refreshInterval: 600000
    // Replace in fixtures to hold, reorder or fail busctl calls.
    property Component commandComponent: Component { Local.RunCommand {} }
    // Kernel disk name (sda, nvme0n1) -> { model, kind, summary }.
    property var byDevice: ({})
    // "idle" before the first read, then "ready" or "unavailable" (no UDisks or busctl).
    property string readStatus: "idle"
    property bool inFlight: false
    property int generation: 0

    visible: false

    function healthFor(deviceName) {
        return byDevice[deviceName] || null;
    }

    function accept(requestGeneration) {
        if (requestGeneration === generation && active) {
            return true;
        }
        inFlight = false;
        if (active) {
            Qt.callLater(collector.refresh);
        }
        return false;
    }

    function publish(layout, attributes) {
        var next = {};
        Object.keys(layout.deviceToDrive).forEach(function(device) {
            var drive = layout.drives[layout.deviceToDrive[device]];
            if (drive) {
                next[device] = {
                    model: drive.model,
                    kind: drive.kind,
                    summary: DiskHealth.summarize(drive, attributes[drive.path] || null)
                };
            }
        });
        byDevice = next;
        readStatus = "ready";
        inFlight = false;
    }

    function refresh() {
        if (!active || inFlight || !objectsCommand.provider || !attributesCommand.provider) {
            return;
        }
        inFlight = true;
        var requestGeneration = generation;
        objectsCommand.provider.exec(DiskHealth.managedObjectsCommand, function(result) {
            // The collector may be destroyed (widget removed) before a reply arrives.
            if (!collector || !collector.accept(requestGeneration)) {
                return;
            }
            var layout = result.exitCode === 0 ? DiskHealth.parseManagedObjects(result.stdout) : null;
            if (!layout) {
                collector.byDevice = ({});
                collector.readStatus = "unavailable";
                collector.inFlight = false;
                return;
            }
            var drives = Object.keys(layout.drives).map(function(path) { return layout.drives[path]; });
            var command = DiskHealth.attributesCommand(drives);
            if (command.length === 0) {
                collector.publish(layout, {});
                return;
            }
            attributesCommand.provider.exec(command, function(attributeResult) {
                if (!collector || !collector.accept(requestGeneration)) {
                    return;
                }
                // Extended attributes are optional; base SMART properties still count.
                collector.publish(layout, DiskHealth.parseAttributesBatch(attributeResult.stdout));
            });
        });
    }

    onActiveChanged: {
        generation++;
        if (active) {
            refresh();
        }
    }
    Component.onCompleted: {
        if (active) {
            refresh();
        }
    }

    Loader {
        id: objectsCommand
        readonly property var provider: item
        sourceComponent: collector.commandComponent
    }

    Loader {
        id: attributesCommand
        readonly property var provider: item
        sourceComponent: collector.commandComponent
    }

    Timer {
        interval: Math.max(60000, collector.refreshInterval)
        repeat: true
        running: collector.active
        onTriggered: collector.refresh()
    }
}
