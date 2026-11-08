import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "CpuSensorChoice.js" as CpuSensorChoice
import "." as Local

// Searchable list of KSysGuard sensors with a live preview of the highlighted
// one. The sensor tree loads and the preview subscribes only while open.
Kirigami.Dialog {
    id: dialog

    property string selectedSensorId: ""
    // Replace in fixtures; defaults to every sensor the daemon reports.
    readonly property var listing: listingLoader.item
    property var entries: listing ? listing.entries : []
    readonly property int maximumResults: 200
    readonly property var filteredEntries: {
        var needle = search.text.trim().toLowerCase();
        var matches = entries.filter(function(entry) {
            return needle.length === 0
                || (entry.label + " " + entry.name + " " + entry.key).toLowerCase().indexOf(needle) >= 0;
        });
        return matches.slice(0, maximumResults);
    }
    readonly property bool previewReady: preview.enabled && preview.status === Sensors.Sensor.Ready
        && preview.formattedValue.length > 0

    signal sensorChosen(string sensorId)

    function openWith(filterText, currentSensorId) {
        search.text = filterText || "";
        selectedSensorId = CpuSensorChoice.validSensorId(currentSensorId) ? currentSensorId : "";
        rawId.text = selectedSensorId;
        open();
    }

    title: i18nc("@title:window", "Choose Sensor")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    preferredWidth: Kirigami.Units.gridUnit * 30
    padding: Kirigami.Units.largeSpacing

    onAccepted: {
        if (CpuSensorChoice.validSensorId(selectedSensorId)) {
            sensorChosen(selectedSensorId);
        }
    }

    property Loader listingLoader: Loader {
        active: dialog.visible
        sourceComponent: Component {
            Local.SensorListing {
                keyFromSensorId: function(sensorId) {
                    return CpuSensorChoice.validSensorId(sensorId) ? sensorId : "";
                }
            }
        }
    }

    property Sensors.Sensor preview: Sensors.Sensor {
        sensorId: CpuSensorChoice.validSensorId(dialog.selectedSensorId) ? dialog.selectedSensorId : ""
        enabled: dialog.visible && sensorId.length > 0
        updateRateLimit: 1000
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.SearchField {
            id: search
            Layout.fillWidth: true
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            clip: true
            model: dialog.filteredEntries

            delegate: Controls.ItemDelegate {
                required property var modelData

                width: ListView.view.width
                highlighted: modelData.key === dialog.selectedSensorId
                onClicked: {
                    dialog.selectedSensorId = modelData.key;
                    rawId.text = modelData.key;
                }

                contentItem: ColumnLayout {
                    spacing: 0

                    Controls.Label {
                        text: modelData.label.length > 0
                            ? i18nc("@item sensor label and its device", "%1 · %2", modelData.label, modelData.name)
                            : modelData.name
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Controls.Label {
                        text: modelData.key
                        color: Kirigami.Theme.disabledTextColor
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: list.count === 0
                text: dialog.entries.length === 0
                    ? i18nc("@info", "No sensors reported. Is KSystemStats running?")
                    : i18nc("@info", "No sensors match the search.")
            }
        }

        // A plain grid: FormLayout's width-dependent height loops with the
        // dialog's own centring.
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: i18nc("@label live value of the selected sensor", "Current value:")
            }

            Controls.Label {
                text: dialog.selectedSensorId.length === 0 ? i18nc("@info:status nothing selected", "—")
                    : dialog.previewReady ? dialog.preview.formattedValue : i18nc("@info:status", "N/A")
                Layout.fillWidth: true
            }

            Controls.Label {
                text: i18nc("@label", "Sensor ID:")
            }

            // Advanced: any sensor ID, including ones not listed right now.
            Controls.TextField {
                id: rawId
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "e.g. lmsensors/k10temp-pci-00c3/temp1")
                onTextEdited: dialog.selectedSensorId = text.trim()
            }
        }
    }
}
