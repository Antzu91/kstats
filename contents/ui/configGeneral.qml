import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "." as Local

KCM.SimpleKCM {
    id: root

    property int cfg_historyWindowMinutes: 1
    property int cfg_historyWindowMinutesDefault
    property alias cfg_updateRateLimit: updateRateLimit.value
    property alias cfg_compactBarLength: compactBarLength.value
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showGpu: showGpu.checked
    property string cfg_gpuDeviceId: "gpu0"
    property alias cfg_showDisk: showDisk.checked
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_cpuSensorId: cpuSensorId.text
    property alias cfg_memorySensorId: memorySensorId.text
    property alias cfg_diskSensorId: diskSensorId.text
    property alias cfg_diskReadSensorId: diskReadSensorId.text
    property alias cfg_diskWriteSensorId: diskWriteSensorId.text
    property alias cfg_networkDownloadSensorId: networkDownloadSensorId.text
    property alias cfg_networkUploadSensorId: networkUploadSensorId.text
    property alias cfg_barLabelFontSize: barLabelFontSize.value
    property alias cfg_barValueFontSize: barValueFontSize.value

    property int cfg_updateRateLimitDefault
    property int cfg_compactBarLengthDefault
    property bool cfg_showCpuDefault
    property bool cfg_showMemoryDefault
    property bool cfg_showGpuDefault
    property string cfg_gpuDeviceIdDefault
    property bool cfg_showDiskDefault
    property bool cfg_showNetworkDefault
    property string cfg_cpuSensorIdDefault
    property string cfg_memorySensorIdDefault
    property string cfg_diskSensorIdDefault
    property string cfg_diskReadSensorIdDefault
    property string cfg_diskWriteSensorIdDefault
    property string cfg_networkDownloadSensorIdDefault
    property string cfg_networkUploadSensorIdDefault

    property Local.GpuDiscovery gpuDiscovery: Local.GpuDiscovery {}

    readonly property var gpuChoices: {
        var choices = gpuDiscovery.devices.map(function(device) {
            return { key: device.key, name: gpuDiscovery.deviceName(device) };
        });
        if (!choices.some(function(device) {
            return device.key === root.cfg_gpuDeviceId;
        })) {
            choices.push({
                key: root.cfg_gpuDeviceId,
                name: i18nc("@item:inlistbox unavailable GPU", "%1 (unavailable)", root.cfg_gpuDeviceId || i18n("GPU"))
            });
        }
        return choices;
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        Controls.SpinBox {
            id: updateRateLimit
            Kirigami.FormData.label: i18nc("@label", "Update interval:")
            from: 500
            to: 10000
            stepSize: 250
            textFromValue: function(value) {
                return i18nc("@label milliseconds", "%1 ms", value);
            }
            valueFromText: function(text) {
                return Number.parseInt(text);
            }
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18nc("@label", "History window:")
            model: [i18nc("@item:inlistbox history duration", "1 minute"),
                i18nc("@item:inlistbox history duration", "5 minutes"),
                i18nc("@item:inlistbox history duration", "15 minutes")]
            currentIndex: Math.max(0, [1, 5, 15].indexOf(root.cfg_historyWindowMinutes))
            onActivated: root.cfg_historyWindowMinutes = [1, 5, 15][currentIndex]
        }

        Controls.SpinBox {
            id: compactBarLength
            Kirigami.FormData.label: i18nc("@label", "Bar length:")
            from: 0
            to: 4000
            stepSize: 8
            textFromValue: function(value) {
                if (value === 0) {
                    return i18nc("@label adaptive bar length", "Adaptive");
                }
                return i18nc("@label pixels", "%1 px", value);
            }
            valueFromText: function(text) {
                var parsed = Number.parseInt(text);
                return isFinite(parsed) ? parsed : 0;
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Bar Modules")
            Layout.fillWidth: true
        }

        Controls.CheckBox {
            id: showCpu
            Kirigami.FormData.label: i18nc("@label", "CPU:")
            text: i18nc("@option:check", "Show in bar")
        }

        Controls.CheckBox {
            id: showMemory
            Kirigami.FormData.label: i18nc("@label", "Memory:")
            text: i18nc("@option:check", "Show in bar")
        }

        Controls.CheckBox {
            id: showGpu
            Kirigami.FormData.label: i18nc("@label", "GPU:")
            text: i18nc("@option:check", "Show in bar")
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18nc("@label", "Panel GPU:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            enabled: showGpu.checked
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: currentText
            model: root.gpuChoices
            textRole: "name"
            valueRole: "key"
            currentIndex: root.gpuChoices.findIndex(function(device) {
                return device.key === root.cfg_gpuDeviceId;
            })
            onActivated: root.cfg_gpuDeviceId = currentValue
        }

        Controls.CheckBox {
            id: showDisk
            Kirigami.FormData.label: i18nc("@label", "Disk:")
            text: i18nc("@option:check", "Show in bar")
        }

        Controls.CheckBox {
            id: showNetwork
            Kirigami.FormData.label: i18nc("@label", "Network:")
            text: i18nc("@option:check", "Show in bar")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Font sizes")
            Layout.fillWidth: true
        }
        
        Controls.SpinBox {
            id: barLabelFontSize
            Kirigami.FormData.label: i18nc("@label", "Bar label font size:")
            from: 0
            to: 64
            stepSize: 1
            textFromValue: function(value) {
                if (value === 0) {
                    return i18nc("@label default bar label font size", "Default");
                }
                return i18nc("@label pixels", "%1 px", value);
            }
            valueFromText: function(text) {
                var parsed = Number.parseInt(text);
                return isFinite(parsed) ? parsed : 0;
            }
        }
        
        Controls.SpinBox {
            id: barValueFontSize
            Kirigami.FormData.label: i18nc("@label", "Bar value font size:")
            from: 0
            to: 64
            stepSize: 1
            textFromValue: function(value) {
                if (value === 0) {
                    return i18nc("@label default bar value font size", "Default");
                }
                return i18nc("@label pixels", "%1 px", value);
            }
            valueFromText: function(text) {
                var parsed = Number.parseInt(text);
                return isFinite(parsed) ? parsed : 0;
            }
        }
        
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Sensor IDs")
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: cpuSensorId
            Kirigami.FormData.label: i18nc("@label", "CPU:")
            placeholderText: root.cfg_cpuSensorIdDefault
        }

        Controls.TextField {
            id: memorySensorId
            Kirigami.FormData.label: i18nc("@label", "Memory:")
            placeholderText: root.cfg_memorySensorIdDefault
        }

        Controls.TextField {
            id: diskSensorId
            Kirigami.FormData.label: i18nc("@label", "Disk:")
            placeholderText: root.cfg_diskSensorIdDefault
        }

        Controls.TextField {
            id: diskReadSensorId
            Kirigami.FormData.label: i18nc("@label", "Disk read:")
            placeholderText: root.cfg_diskReadSensorIdDefault
        }

        Controls.TextField {
            id: diskWriteSensorId
            Kirigami.FormData.label: i18nc("@label", "Disk write:")
            placeholderText: root.cfg_diskWriteSensorIdDefault
        }

        Controls.TextField {
            id: networkDownloadSensorId
            Kirigami.FormData.label: i18nc("@label", "Network down:")
            placeholderText: root.cfg_networkDownloadSensorIdDefault
        }

        Controls.TextField {
            id: networkUploadSensorId
            Kirigami.FormData.label: i18nc("@label", "Network up:")
            placeholderText: root.cfg_networkUploadSensorIdDefault
        }
    }
}
