import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "." as Local

KCM.SimpleKCM {
    id: root

    property alias cfg_updateRateLimit: updateRateLimit.value
    property alias cfg_compactBarLength: compactBarLength.value
    property bool cfg_showCpu
    property bool cfg_showMemory
    property bool cfg_showGpu
    property string cfg_gpuDeviceId: "gpu0"
    property bool cfg_showDisk
    property bool cfg_showNetwork
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

    property string cfg_moduleOrder
    property string cfg_moduleOrderDefault
    property bool cfg_cpuShowLabel
    property bool cfg_cpuShowLabelDefault
    property string cfg_cpuPresentation
    property string cfg_cpuPresentationDefault
    property bool cfg_memoryShowLabel
    property bool cfg_memoryShowLabelDefault
    property string cfg_memoryPresentation
    property string cfg_memoryPresentationDefault
    property bool cfg_gpuShowLabel
    property bool cfg_gpuShowLabelDefault
    property string cfg_gpuPresentation
    property string cfg_gpuPresentationDefault
    property bool cfg_diskShowLabel
    property bool cfg_diskShowLabelDefault
    property string cfg_diskPresentation
    property string cfg_diskPresentationDefault
    property bool cfg_networkShowLabel
    property bool cfg_networkShowLabelDefault

    readonly property Local.ModuleDefinitions modules: Local.ModuleDefinitions {
        order: root.cfg_moduleOrder
    }

    function moveModule(index, direction) {
        var ids = modules.ordered.map(function(module) { return module.id; });
        var destination = index + direction;
        if (destination < 0 || destination >= ids.length) {
            return;
        }
        var moved = ids.splice(index, 1)[0];
        ids.splice(destination, 0, moved);
        cfg_moduleOrder = ids.join(",");
    }

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

        Controls.SpinBox {
            id: compactBarLength
            Kirigami.FormData.label: i18nc("@label", "Panel width:")
            from: 0
            to: 4000
            stepSize: 8
            textFromValue: function(value) {
                if (value === 0) {
                    return i18nc("@label adaptive bar length", "Automatic");
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

        Controls.Label {
            text: i18nc("@info", "Order also applies to popup tabs. Hidden panel modules remain available in the popup.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Nest delegates so FormLayout cannot move them past later sections.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.modules.ordered

                ColumnLayout {
                    id: moduleSettings
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: moduleSettings.modelData.label
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Controls.CheckBox {
                            text: i18nc("@option:check", "Show in panel")
                            checked: Boolean(root["cfg_" + moduleSettings.modelData.visibilityKey])
                            onToggled: root["cfg_" + moduleSettings.modelData.visibilityKey] = checked
                        }
                        Controls.CheckBox {
                            text: i18nc("@option:check", "Show label")
                            checked: Boolean(root["cfg_" + moduleSettings.modelData.id + "ShowLabel"])
                            onToggled: root["cfg_" + moduleSettings.modelData.id + "ShowLabel"] = checked
                        }
                        Controls.ToolButton {
                            icon.name: "go-up"
                            text: i18nc("@action", "Move %1 earlier", moduleSettings.modelData.label)
                            display: Controls.AbstractButton.IconOnly
                            enabled: moduleSettings.index > 0
                            onClicked: root.moveModule(moduleSettings.index, -1)
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: text
                        }
                        Controls.ToolButton {
                            icon.name: "go-down"
                            text: i18nc("@action", "Move %1 later", moduleSettings.modelData.label)
                            display: Controls.AbstractButton.IconOnly
                            enabled: moduleSettings.index < root.modules.ordered.length - 1
                            onClicked: root.moveModule(moduleSettings.index, 1)
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: text
                        }
                    }

                    Controls.ComboBox {
                        visible: moduleSettings.modelData.id !== "network"
                        Layout.fillWidth: true
                        model: [
                            { key: "number", text: i18nc("@item:inlistbox", "Number") },
                            { key: "graph", text: i18nc("@item:inlistbox", "Graph") },
                            { key: "numberGraph", text: i18nc("@item:inlistbox", "Number + graph") },
                            { key: "bar", text: i18nc("@item:inlistbox", "Bar") }
                        ]
                        textRole: "text"
                        valueRole: "key"
                        currentIndex: model.findIndex(function(mode) {
                            return mode.key === root["cfg_" + moduleSettings.modelData.id + "Presentation"];
                        })
                        onActivated: root["cfg_" + moduleSettings.modelData.id + "Presentation"] = currentValue
                        Accessible.name: i18nc("@label", "%1 presentation", moduleSettings.modelData.label)
                    }
                    Controls.Label {
                        visible: moduleSettings.modelData.id === "network"
                        text: i18nc("@label", "Upload and download rates")
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18nc("@label", "Panel GPU:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            enabled: root.cfg_showGpu
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
