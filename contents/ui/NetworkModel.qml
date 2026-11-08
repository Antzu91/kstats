import QtQuick

import "NetworkSource.js" as NetworkSource
import "." as Local

// Owns network scope for the panel, popup headline, tooltip and history: which
// sensors are measured and which interface the popup details describe.
// Automatic follows the default route; it never guesses when no route resolves.
// A fixed interface never switches, even if it disappears.
Item {
    id: model

    property string source: "all"
    property string customDownloadSensorId: NetworkSource.defaultDownloadSensorId
    property string customUploadSensorId: NetworkSource.defaultUploadSensorId
    // Metric demand (panel module or page) and details demand (page only).
    property bool active: false
    property bool detailsDemand: false
    property int routeRefreshInterval: 10000
    // Replace in fixtures to hold, reorder or fail route lookups.
    property Component commandComponent: Component { Local.RunCommand {} }

    readonly property string effectiveSource: NetworkSource.effectiveSource(source, customDownloadSensorId, customUploadSensorId)
    readonly property string mode: NetworkSource.mode(effectiveSource)
    readonly property string selectedInterface: NetworkSource.interfaceFromSource(effectiveSource)
    property string routeInterface: ""
    // "unknown" until a lookup completes for the current demand, then
    // "resolved" or "unresolved" (no route, or the ip command is missing).
    property string routeStatus: "unknown"
    readonly property string measuredInterface: mode === "auto" ? routeInterface : selectedInterface
    readonly property var sensorIds: NetworkSource.sensorIds(mode, measuredInterface, customDownloadSensorId, customUploadSensorId)
    readonly property string downloadSensorId: sensorIds.download
    readonly property string uploadSensorId: sensorIds.upload
    // Aggregate and custom sources have no single interface; describe the default route.
    readonly property string detailsInterface: mode === "auto" || mode === "interface" ? measuredInterface : routeInterface
    readonly property bool detailsDescribeRoute: mode === "all" || mode === "custom"
    // A fixed interface never needs the route; the others need it for metrics
    // (automatic) or to name the default-route interface in the details.
    readonly property bool routeNeeded: completed && (mode === "auto" ? active || detailsDemand
        : detailsDemand && detailsDescribeRoute)
    readonly property string scopeText: {
        if (mode === "auto") {
            return routeStatus === "resolved"
                ? i18nc("@label network scope", "Automatic: %1", labelHelper.interfaceLabel(routeInterface))
                : routeStatus === "unresolved"
                    ? i18nc("@label network scope", "Automatic: no default route")
                    : i18nc("@label network scope", "Automatic");
        }
        if (mode === "interface") {
            return labelHelper.interfaceLabel(selectedInterface);
        }
        if (mode === "custom") {
            return i18nc("@label network scope", "Custom sensors");
        }
        return i18nc("@label network scope", "All interfaces");
    }
    property alias labels: labelHelper

    property bool completed: false
    property int generation: 0
    property bool inFlight: false

    function refreshRoute() {
        if (!routeNeeded || inFlight || !commands.provider) {
            return;
        }
        inFlight = true;
        var requestGeneration = generation;
        commands.provider.exec(NetworkSource.routeCommand, function(result) {
            model.inFlight = false;
            if (requestGeneration !== model.generation || !model.routeNeeded) {
                if (model.routeNeeded) {
                    // Let RunCommand disconnect its old source before requesting it again.
                    Qt.callLater(model.refreshRoute);
                }
                return;
            }
            var name = result && result.exitCode === 0 ? NetworkSource.routeInterface(result.stdout) : "";
            model.routeInterface = name;
            model.routeStatus = name.length > 0 ? "resolved" : "unresolved";
        });
    }

    onRouteNeededChanged: {
        generation++;
        if (!routeNeeded) {
            // A route seen before demand stopped may be obsolete after sleep or roaming.
            routeInterface = "";
            routeStatus = "unknown";
        }
    }
    Component.onCompleted: completed = true

    Local.NetworkLabels {
        id: labelHelper
    }

    Loader {
        id: commands
        readonly property var provider: item
        sourceComponent: model.commandComponent
    }

    Timer {
        interval: Math.max(1000, model.routeRefreshInterval)
        repeat: true
        running: model.routeNeeded
        triggeredOnStart: true
        onTriggered: model.refreshRoute()
    }
}
