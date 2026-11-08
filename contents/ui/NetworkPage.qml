import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "NetworkSource.js" as NetworkSource
import "." as Local

Item {
    id: page

    required property var rootItem
    // Rates, history and scope come from the shared model the panel also uses.
    readonly property var scope: rootItem.networkModel
    readonly property bool active: rootItem.networkDetailsVisible
    readonly property string detailsInterface: scope.detailsInterface
    readonly property bool detailsAvailable: NetworkSource.validInterfaceName(detailsInterface)
    // Replace in fixtures to hold, reorder or fail detail lookups.
    property Component commandComponent: Component { Local.RunCommand {} }
    property int detailsGeneration: 0
    property bool detailsInFlight: false
    property string localIp: ""
    property string physicalAddress: ""
    property string publicIp: i18nc("@info:status", "N/A")
    readonly property string networkName: {
        if (networkNameSensor.status === Sensors.Sensor.Ready && typeof networkNameSensor.value === "string"
                && networkNameSensor.value.trim().length > 0) {
            return networkNameSensor.value.trim();
        }
        switch (NetworkSource.interfaceKind(detailsInterface)) {
        case "wifi":
            return i18nc("@label", "Wi-Fi");
        case "ethernet":
            return i18nc("@label", "Wired");
        case "vpn":
            return i18nc("@label", "VPN");
        default:
            return i18nc("@info:status", "N/A");
        }
    }

    clip: true
    Layout.fillWidth: true
    Layout.fillHeight: true

    function orMissing(value) {
        return value.length > 0 ? value : i18nc("@info:status", "N/A");
    }

    function parseAddress(output) {
        var ipv4 = String(output || "").match(/\binet\s+([0-9.]+)/);
        if (ipv4) {
            return ipv4[1];
        }
        var ipv6 = String(output || "").match(/\binet6\s+([0-9a-fA-F:]+)/);
        return ipv6 ? ipv6[1] : "";
    }

    // Interface changes clear old addresses so they cannot describe the new scope.
    function resetDetails() {
        detailsGeneration++;
        localIp = "";
        physicalAddress = "";
    }

    function acceptDetails(generation) {
        if (generation === detailsGeneration && active) {
            return true;
        }
        detailsInFlight = false;
        if (active) {
            Qt.callLater(page.refreshDetails);
        }
        return false;
    }

    function refreshDetails() {
        // Read the model directly: derived bindings on this page may not have
        // updated yet when a change handler calls in.
        var name = scope.detailsInterface;
        if (!active || detailsInFlight || !NetworkSource.validInterfaceName(name)
                || !addressCommand.provider || !macCommand.provider) {
            return;
        }
        detailsInFlight = true;
        var generation = detailsGeneration;
        addressCommand.provider.exec("ip -o addr show dev " + name + " scope global", function(addressResult) {
            if (!page.acceptDetails(generation)) {
                return;
            }
            page.localIp = addressResult.exitCode === 0 ? page.parseAddress(addressResult.stdout) : "";
            macCommand.provider.exec("cat /sys/class/net/" + name + "/address", function(macResult) {
                if (!page.acceptDetails(generation)) {
                    return;
                }
                page.detailsInFlight = false;
                page.physicalAddress = macResult.exitCode === 0 ? macResult.stdout.trim() : "";
            });
        });
    }

    onDetailsInterfaceChanged: {
        resetDetails();
        Qt.callLater(page.refreshDetails);
    }
    onActiveChanged: {
        detailsGeneration++;
        refreshDetails();
    }
    Component.onCompleted: refreshDetails()

    Timer {
        interval: 10000
        repeat: true
        running: page.active
        onTriggered: page.refreshDetails()
    }

    Loader {
        id: addressCommand
        readonly property var provider: item
        sourceComponent: page.commandComponent
    }

    Loader {
        id: macCommand
        readonly property var provider: item
        sourceComponent: page.commandComponent
    }

    Sensors.Sensor {
        id: networkNameSensor
        // Connection name or SSID for interfaces ksystemstats knows about.
        sensorId: page.detailsAvailable ? "network/" + page.detailsInterface + "/network" : ""
        enabled: page.active && sensorId.length > 0
        updateRateLimit: 5000
    }

    component NetworkDetailRow: RowLayout {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Controls.Label {
            text: value
            horizontalAlignment: Text.AlignRight
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            elide: Text.ElideRight
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
    }

    component RateValue: ColumnLayout {
        property string value: ""
        property string label: ""
        property color markerColor: Kirigami.Theme.focusColor

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing / 2

        Controls.Label {
            text: value
            color: Kirigami.Theme.textColor
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.45
            font.weight: Font.DemiBold
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing / 2

            Rectangle {
                Layout.preferredWidth: 9
                Layout.preferredHeight: 9
                radius: 2
                color: markerColor
            }

            Controls.Label {
                text: label
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: rateContent.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                id: rateContent

                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    RateValue {
                        value: page.rootItem.networkUploadMonitor.text
                        label: i18nc("@label", "Upload")
                        markerColor: Kirigami.Theme.negativeTextColor
                    }

                    RateValue {
                        value: page.rootItem.networkDownloadMonitor.text
                        label: i18nc("@label", "Download")
                        markerColor: Kirigami.Theme.focusColor
                    }
                }

                // Names the scope so combined and single-interface rates are never confused.
                Controls.Label {
                    text: page.scope.scopeText
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5.2
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Controls.Label {
                    text: i18nc("@label history and coverage", "Usage History · %1", page.rootItem.historyCoverageText(page.rootItem.networkDownloadSamples))
                    color: Kirigami.Theme.disabledTextColor
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Local.NetworkHistoryChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    uploadSamples: page.rootItem.networkUploadSamples
                    downloadSamples: page.rootItem.networkDownloadSamples
                    windowDuration: page.rootItem.historyWindowDuration
                    now: page.rootItem.historyNow
                    uploadColor: Kirigami.Theme.negativeTextColor
                    downloadColor: Kirigami.Theme.focusColor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: detailsContent.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                id: detailsContent

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                Controls.Label {
                    text: i18nc("@label", "Details")
                    color: Kirigami.Theme.disabledTextColor
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                NetworkDetailRow {
                    label: page.scope.detailsDescribeRoute ? i18nc("@label interface used by the default route", "Default route")
                        : i18nc("@label", "Interface")
                    value: page.detailsAvailable ? page.scope.labels.interfaceLabel(page.detailsInterface)
                        : i18nc("@info:status", "N/A")
                }

                NetworkDetailRow {
                    label: i18nc("@label", "Network")
                    value: page.detailsAvailable ? page.networkName : i18nc("@info:status", "N/A")
                }

                NetworkDetailRow {
                    label: i18nc("@label", "Local IP")
                    value: page.orMissing(page.localIp)
                }

                NetworkDetailRow {
                    label: i18nc("@label", "Physical address")
                    value: page.orMissing(page.physicalAddress)
                }

                NetworkDetailRow {
                    label: i18nc("@label", "Public IP")
                    value: page.publicIp
                }
            }
        }

        Local.TopApplicationList {
            active: page.active
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            metric: "network"
            limit: 5
            refreshInterval: Math.max(3000, page.rootItem.sensorUpdateRate * 3)
        }
    }
}
