import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "CpuSensorChoice.js" as CpuSensorChoice
import "DiskSource.js" as DiskSource
import "ModuleCatalog.js" as ModuleCatalog
import "PanelPresentation.js" as PanelPresentation
import "NetworkSource.js" as NetworkSource
import "." as Local

KCM.SimpleKCM {
    id: root

    property int cfg_historyWindowMinutes: 1
    property int cfg_historyWindowMinutesDefault
    property alias cfg_updateRateLimit: updateRateLimit.value
    property alias cfg_compactBarLength: compactBarLength.value
    property bool cfg_showCpu: true
    property bool cfg_showMemory: true
    property bool cfg_showGpu: true
    property string cfg_gpuDeviceId: "gpu0"
    property string cfg_networkSource: "all"
    property string cfg_diskSource: "all"
    property string cfg_moduleOrder: ModuleCatalog.defaultOrder
    property bool cfg_monochrome: false
    property string cfg_cpuPresentation: "numberGraph"
    property bool cfg_cpuShowLabel: true
    property string cfg_memoryPresentation: "numberGraph"
    property bool cfg_memoryShowLabel: true
    property string cfg_gpuPresentation: "numberGraph"
    property bool cfg_gpuShowLabel: true
    property string cfg_diskPresentation: "bar"
    property bool cfg_diskShowLabel: true
    property string cfg_networkPresentation: "numbers"
    property bool cfg_networkShowLabel: true
    property string cfg_cpuTemperatureSensor: "auto"
    property string cfg_cpuFanSensor: "auto"
    property bool cfg_showDisk: true
    property bool cfg_showNetwork: true
    property alias cfg_publicIpLookup: publicIpLookup.checked
    property string cfg_popupDensity: "comfortable"
    property string cfg_popupDensityDefault
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
    property string cfg_networkSourceDefault
    property string cfg_diskSourceDefault
    property string cfg_moduleOrderDefault
    property bool cfg_monochromeDefault
    property string cfg_cpuPresentationDefault
    property bool cfg_cpuShowLabelDefault
    property string cfg_memoryPresentationDefault
    property bool cfg_memoryShowLabelDefault
    property string cfg_gpuPresentationDefault
    property bool cfg_gpuShowLabelDefault
    property string cfg_diskPresentationDefault
    property bool cfg_diskShowLabelDefault
    property string cfg_networkPresentationDefault
    property bool cfg_networkShowLabelDefault
    property string cfg_cpuTemperatureSensorDefault
    property string cfg_cpuFanSensorDefault
    property bool cfg_showDiskDefault
    property bool cfg_showNetworkDefault
    property bool cfg_publicIpLookupDefault
    property string cfg_cpuSensorIdDefault
    property string cfg_memorySensorIdDefault
    property string cfg_diskSensorIdDefault
    property string cfg_diskReadSensorIdDefault
    property string cfg_diskWriteSensorIdDefault
    property string cfg_networkDownloadSensorIdDefault
    property string cfg_networkUploadSensorIdDefault

    property Local.GpuDiscovery gpuDiscovery: Local.GpuDiscovery {}
    property Local.ModuleCatalog moduleCatalog: Local.ModuleCatalog {}
    readonly property var moduleOrderList: ModuleCatalog.normalizeOrder(root.cfg_moduleOrder)

    readonly property string activePreset: PanelPresentation.matchingPreset({
        cpu: { presentation: root.cfg_cpuPresentation, label: root.cfg_cpuShowLabel },
        memory: { presentation: root.cfg_memoryPresentation, label: root.cfg_memoryShowLabel },
        gpu: { presentation: root.cfg_gpuPresentation, label: root.cfg_gpuShowLabel },
        disk: { presentation: root.cfg_diskPresentation, label: root.cfg_diskShowLabel },
        network: { presentation: root.cfg_networkPresentation, label: root.cfg_networkShowLabel }
    })

    function applyPreset(name) {
        var preset = PanelPresentation.presets[name];
        if (!preset) {
            return;
        }
        root.cfg_cpuPresentation = preset.presentation.cpu;
        root.cfg_memoryPresentation = preset.presentation.memory;
        root.cfg_gpuPresentation = preset.presentation.gpu;
        root.cfg_diskPresentation = preset.presentation.disk;
        root.cfg_networkPresentation = preset.presentation.network;
        root.cfg_cpuShowLabel = preset.labels;
        root.cfg_memoryShowLabel = preset.labels;
        root.cfg_gpuShowLabel = preset.labels;
        root.cfg_diskShowLabel = preset.labels;
        root.cfg_networkShowLabel = preset.labels;
    }

    function presentationLabel(mode) {
        switch (mode) {
        case "number":
            return i18nc("@item:inlistbox panel presentation", "Number");
        case "numbers":
            return i18nc("@item:inlistbox panel presentation", "Numbers");
        case "graph":
            return i18nc("@item:inlistbox panel presentation", "Graph");
        case "numberGraph":
            return i18nc("@item:inlistbox panel presentation", "Number and graph");
        case "numbersGraph":
            return i18nc("@item:inlistbox panel presentation", "Numbers and graph");
        default:
            return i18nc("@item:inlistbox panel presentation", "Bar");
        }
    }

    // Shows a module, picks how the panel draws it, and toggles its label.
    // Bindings are restored after each edit so presets can update them.
    component ModuleRow: RowLayout {
        id: moduleRow

        required property string moduleId
        property bool shown: true
        property string presentation: ""
        property bool labelShown: true
        readonly property var modes: PanelPresentation.modesFor(moduleId)
        readonly property string moduleName: root.moduleCatalog.module(moduleId).name

        signal shownEdited(bool value)
        signal presentationEdited(string value)
        signal labelEdited(bool value)

        spacing: Kirigami.Units.smallSpacing

        Controls.CheckBox {
            text: i18nc("@option:check", "Show in bar")
            checked: moduleRow.shown
            onToggled: {
                moduleRow.shownEdited(checked);
                checked = Qt.binding(() => moduleRow.shown);
            }
        }

        Controls.ComboBox {
            objectName: moduleRow.moduleId + "Presentation"
            enabled: moduleRow.shown
            model: moduleRow.modes.map(mode => root.presentationLabel(mode))
            currentIndex: moduleRow.modes.indexOf(PanelPresentation.presentation(moduleRow.moduleId, moduleRow.presentation))
            onActivated: index => {
                moduleRow.presentationEdited(moduleRow.modes[index]);
                currentIndex = Qt.binding(() => moduleRow.modes.indexOf(PanelPresentation.presentation(moduleRow.moduleId, moduleRow.presentation)));
            }
            Accessible.name: i18nc("@label accessible name", "%1 panel display", moduleRow.moduleName)
        }

        Controls.CheckBox {
            enabled: moduleRow.shown
            text: i18nc("@option:check show the module's name in the panel", "Label")
            checked: moduleRow.labelShown
            onToggled: {
                moduleRow.labelEdited(checked);
                checked = Qt.binding(() => moduleRow.labelShown);
            }
        }
    }

    function moveModule(id, delta) {
        root.cfg_moduleOrder = ModuleCatalog.move(root.cfg_moduleOrder, id, delta);
    }
    property Local.SensorListing networkInterfaces: Local.SensorListing {
        keyFromSensorId: NetworkSource.interfaceFromSensorId
    }
    property Local.SensorListing diskVolumes: Local.SensorListing {
        keyFromSensorId: DiskSource.volumeFromSensorId
    }
    property Local.NetworkLabels networkLabels: Local.NetworkLabels {}

    // Legacy custom sensor IDs resolve to the Custom source, as in the widget.
    readonly property string effectiveNetworkSource: NetworkSource.effectiveSource(root.cfg_networkSource,
        networkDownloadSensorId.text, networkUploadSensorId.text)
    readonly property var networkChoices: {
        var keys = ["all", "auto"].concat(networkInterfaces.keys.map(function(name) {
            return NetworkSource.interfaceSource(name);
        }));
        // Keep a configured interface selectable even while it is absent.
        if (keys.indexOf(root.effectiveNetworkSource) < 0 && root.effectiveNetworkSource !== "custom") {
            keys.push(root.effectiveNetworkSource);
        }
        keys.push("custom");
        return keys.map(function(key) {
            var name = root.networkLabels.sourceLabel(key);
            if (NetworkSource.mode(key) === "interface"
                    && root.networkInterfaces.keys.indexOf(NetworkSource.interfaceFromSource(key)) < 0) {
                name = i18nc("@item:inlistbox unavailable network interface", "%1 (unavailable)", name);
            }
            return { key: key, name: name };
        });
    }

    readonly property string effectiveDiskSource: DiskSource.effectiveSource(root.cfg_diskSource,
        diskSensorId.text, diskReadSensorId.text, diskWriteSensorId.text)
    readonly property var diskChoices: {
        var choices = [{ key: "all", name: i18nc("@item:inlistbox disk source", "All disks (combined)") }];
        diskVolumes.entries.forEach(function(entry) {
            choices.push({ key: DiskSource.volumeSource(entry.key), name: entry.name });
        });
        // Keep a configured volume selectable even while it is unmounted.
        if (DiskSource.mode(root.effectiveDiskSource) === "volume"
                && !choices.some(function(choice) { return choice.key === root.effectiveDiskSource; })) {
            choices.push({ key: root.effectiveDiskSource, name: i18nc("@item:inlistbox unavailable disk volume", "%1 (unavailable)",
                DiskSource.volumeFromSource(root.effectiveDiskSource)) });
        }
        choices.push({ key: "custom", name: i18nc("@item:inlistbox disk source", "Custom sensor IDs") });
        return choices;
    }

    // Picker target: "temperature" or "fan".
    property string sensorPickerTarget: ""
    property Local.SensorPickerDialog sensorPicker: Local.SensorPickerDialog {
        // A popup without a visual parent cannot centre itself (binding loop on y).
        parent: root
        onSensorChosen: sensorId => root.setCpuSensor(root.sensorPickerTarget, sensorId)
    }

    function cpuSensorModeIndex(setting) {
        var mode = CpuSensorChoice.selection(setting).mode;
        return mode === "off" ? 1 : mode === "manual" ? 2 : 0;
    }

    function cpuSensorChoices(setting) {
        var choice = CpuSensorChoice.selection(setting);
        return [i18nc("@item:inlistbox sensor selection", "Automatic"),
            i18nc("@item:inlistbox sensor selection", "Off"),
            choice.mode === "manual"
                ? i18nc("@item:inlistbox chosen sensor ID", "Sensor: %1", choice.sensorId)
                : i18nc("@item:inlistbox", "Choose sensor…")];
    }

    function setCpuSensor(target, setting) {
        if (target === "temperature") {
            root.cfg_cpuTemperatureSensor = setting;
        } else if (target === "fan") {
            root.cfg_cpuFanSensor = setting;
        }
    }

    function activateCpuSensorMode(target, index, currentSetting) {
        if (index === 0) {
            setCpuSensor(target, CpuSensorChoice.automatic);
        } else if (index === 1) {
            setCpuSensor(target, CpuSensorChoice.disabled);
        } else {
            root.sensorPickerTarget = target;
            root.sensorPicker.openWith(target === "fan" ? "fan" : "temp",
                CpuSensorChoice.selection(currentSetting).sensorId);
        }
    }

    function selectDiskSource(key) {
        root.cfg_diskSource = key;
        if (key !== "custom") {
            // Friendly sources own their sensors; reset legacy IDs so they cannot
            // turn the choice back into Custom on the next load.
            diskSensorId.text = DiskSource.defaults.usage;
            diskReadSensorId.text = DiskSource.defaults.read;
            diskWriteSensorId.text = DiskSource.defaults.write;
        }
    }

    function selectNetworkSource(key) {
        root.cfg_networkSource = key;
        if (key !== "custom") {
            // Friendly sources own their sensors; clear legacy IDs so they cannot
            // turn the choice back into Custom on the next load.
            networkDownloadSensorId.text = NetworkSource.defaultDownloadSensorId;
            networkUploadSensorId.text = NetworkSource.defaultUploadSensorId;
        }
    }

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

        Controls.ComboBox {
            Kirigami.FormData.label: i18nc("@label", "Popup density:")
            model: [i18nc("@item:inlistbox popup density", "Comfortable"),
                i18nc("@item:inlistbox popup density", "Compact")]
            currentIndex: root.cfg_popupDensity === "compact" ? 1 : 0
            onActivated: index => {
                root.cfg_popupDensity = index === 1 ? "compact" : "comfortable";
                currentIndex = Qt.binding(() => root.cfg_popupDensity === "compact" ? 1 : 0);
            }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18nc("@info:tooltip", "Compact tightens spacing, shortens charts and starts secondary sections collapsed. Sections you open or close stay that way.")
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

        ModuleRow {
            Kirigami.FormData.label: i18nc("@label", "CPU:")
            moduleId: "cpu"
            shown: root.cfg_showCpu
            presentation: root.cfg_cpuPresentation
            labelShown: root.cfg_cpuShowLabel
            onShownEdited: value => root.cfg_showCpu = value
            onPresentationEdited: value => root.cfg_cpuPresentation = value
            onLabelEdited: value => root.cfg_cpuShowLabel = value
        }

        // Choosing a sensor opens the picker; cancelling it keeps the old choice.
        Controls.ComboBox {
            id: cpuTemperatureMode
            Kirigami.FormData.label: i18nc("@label", "CPU temperature:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            model: root.cpuSensorChoices(root.cfg_cpuTemperatureSensor)
            currentIndex: root.cpuSensorModeIndex(root.cfg_cpuTemperatureSensor)
            onActivated: index => {
                root.activateCpuSensorMode("temperature", index, root.cfg_cpuTemperatureSensor);
                currentIndex = Qt.binding(() => root.cpuSensorModeIndex(root.cfg_cpuTemperatureSensor));
            }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18nc("@info:tooltip", "Automatic picks the most likely CPU sensor and switches only if it disappears. A chosen sensor stays selected and shows N/A while missing.")
        }

        Controls.ComboBox {
            id: cpuFanMode
            Kirigami.FormData.label: i18nc("@label", "CPU fan:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            model: root.cpuSensorChoices(root.cfg_cpuFanSensor)
            currentIndex: root.cpuSensorModeIndex(root.cfg_cpuFanSensor)
            onActivated: index => {
                root.activateCpuSensorMode("fan", index, root.cfg_cpuFanSensor);
                currentIndex = Qt.binding(() => root.cpuSensorModeIndex(root.cfg_cpuFanSensor));
            }
        }

        ModuleRow {
            Kirigami.FormData.label: i18nc("@label", "Memory:")
            moduleId: "memory"
            shown: root.cfg_showMemory
            presentation: root.cfg_memoryPresentation
            labelShown: root.cfg_memoryShowLabel
            onShownEdited: value => root.cfg_showMemory = value
            onPresentationEdited: value => root.cfg_memoryPresentation = value
            onLabelEdited: value => root.cfg_memoryShowLabel = value
        }

        ModuleRow {
            Kirigami.FormData.label: i18nc("@label", "GPU:")
            moduleId: "gpu"
            shown: root.cfg_showGpu
            presentation: root.cfg_gpuPresentation
            labelShown: root.cfg_gpuShowLabel
            onShownEdited: value => root.cfg_showGpu = value
            onPresentationEdited: value => root.cfg_gpuPresentation = value
            onLabelEdited: value => root.cfg_gpuShowLabel = value
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

        ModuleRow {
            Kirigami.FormData.label: i18nc("@label", "Disk:")
            moduleId: "disk"
            shown: root.cfg_showDisk
            presentation: root.cfg_diskPresentation
            labelShown: root.cfg_diskShowLabel
            onShownEdited: value => root.cfg_showDisk = value
            onPresentationEdited: value => root.cfg_diskPresentation = value
            onLabelEdited: value => root.cfg_diskShowLabel = value
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18nc("@label", "Disk source:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            model: root.diskChoices
            textRole: "name"
            valueRole: "key"
            currentIndex: root.diskChoices.findIndex(function(choice) {
                return choice.key === root.effectiveDiskSource;
            })
            onActivated: root.selectDiskSource(currentValue)
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18nc("@info:tooltip", "Usage, read and write rates in the panel, popup and history all follow this source.")
        }

        ModuleRow {
            Kirigami.FormData.label: i18nc("@label", "Network:")
            moduleId: "network"
            shown: root.cfg_showNetwork
            presentation: root.cfg_networkPresentation
            labelShown: root.cfg_networkShowLabel
            onShownEdited: value => root.cfg_showNetwork = value
            onPresentationEdited: value => root.cfg_networkPresentation = value
            onLabelEdited: value => root.cfg_networkShowLabel = value
        }

        Controls.ComboBox {
            id: networkSource
            Kirigami.FormData.label: i18nc("@label", "Network source:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            model: root.networkChoices
            textRole: "name"
            valueRole: "key"
            currentIndex: root.networkChoices.findIndex(function(choice) {
                return choice.key === root.effectiveNetworkSource;
            })
            onActivated: root.selectNetworkSource(currentValue)
        }

        Controls.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: {
                switch (NetworkSource.mode(root.effectiveNetworkSource)) {
                case "auto":
                    return i18nc("@info", "Follows the interface used by the default route. Shows N/A when no route is available.");
                case "interface":
                    return i18nc("@info", "Always measures this interface, even while it is disconnected.");
                case "custom":
                    return i18nc("@info", "Uses the network sensor IDs below.");
                default:
                    return i18nc("@info", "Combined traffic of every interface. Virtual and VPN interfaces can count the same traffic more than once.");
                }
            }
        }

        Controls.CheckBox {
            id: publicIpLookup
            Kirigami.FormData.label: i18nc("@label", "Public IP:")
            text: i18nc("@option:check", "Look up when the Network page opens")
        }

        Controls.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18nc("@info", "Sends a request to api64.ipify.org, which sees your public IP address. Only when the Network page opens or you press Refresh; never in the background.")
        }

        // Explicit actions: a preset only rewrites display styles and labels.
        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Preset:")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [
                    { name: "current", text: i18nc("@action:button panel preset", "Current") },
                    { name: "compact", text: i18nc("@action:button panel preset", "Compact") },
                    { name: "graphs", text: i18nc("@action:button panel preset", "Graph-focused") }
                ]

                delegate: Controls.Button {
                    required property var modelData

                    objectName: "preset-" + modelData.name
                    text: modelData.text
                    checkable: false
                    highlighted: root.activePreset === modelData.name
                    onClicked: root.applyPreset(modelData.name)
                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: i18nc("@info:tooltip", "Changes only how modules are drawn and their labels. Visibility, order, fonts and sensors stay as they are.")
                }
            }
        }

        Controls.CheckBox {
            Kirigami.FormData.label: i18nc("@label", "Colors:")
            text: i18nc("@option:check", "Monochrome panel")
            checked: root.cfg_monochrome
            onToggled: {
                root.cfg_monochrome = checked;
                checked = Qt.binding(() => root.cfg_monochrome);
            }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18nc("@info:tooltip", "Draw labels, graphs and bars in the text color. Readings and N/A stay as text.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Module Order")
            Layout.fillWidth: true
        }

        // One static child: FormLayout breaks when a Repeater recreates its rows.
        ColumnLayout {
            Kirigami.FormData.label: i18nc("@label", "Order:")
            spacing: 0

            Repeater {
                model: root.moduleOrderList

                delegate: RowLayout {
                    id: orderRow

                    required property string modelData
                    required property int index
                    readonly property string moduleName: root.moduleCatalog.module(modelData).name

                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: i18nc("@label position and module name", "%1. %2", orderRow.index + 1, orderRow.moduleName)
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 7
                    }

                    Controls.ToolButton {
                        icon.name: "arrow-up"
                        display: Controls.AbstractButton.IconOnly
                        text: i18nc("@action:button", "Move %1 up", orderRow.moduleName)
                        enabled: orderRow.index > 0
                        onClicked: root.moveModule(orderRow.modelData, -1)
                        Controls.ToolTip.visible: hovered
                        Controls.ToolTip.text: text
                    }

                    Controls.ToolButton {
                        icon.name: "arrow-down"
                        display: Controls.AbstractButton.IconOnly
                        text: i18nc("@action:button", "Move %1 down", orderRow.moduleName)
                        enabled: orderRow.index < root.moduleOrderList.length - 1
                        onClicked: root.moveModule(orderRow.modelData, 1)
                        Controls.ToolTip.visible: hovered
                        Controls.ToolTip.text: text
                    }
                }
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18nc("@info", "The panel and the popup tabs use this order. Modules hidden from the panel keep their popup tab.")
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
            enabled: DiskSource.mode(root.effectiveDiskSource) === "custom"
            Kirigami.FormData.label: i18nc("@label", "Disk:")
            placeholderText: root.cfg_diskSensorIdDefault
        }

        Controls.TextField {
            id: diskReadSensorId
            enabled: DiskSource.mode(root.effectiveDiskSource) === "custom"
            Kirigami.FormData.label: i18nc("@label", "Disk read:")
            placeholderText: root.cfg_diskReadSensorIdDefault
        }

        Controls.TextField {
            id: diskWriteSensorId
            enabled: DiskSource.mode(root.effectiveDiskSource) === "custom"
            Kirigami.FormData.label: i18nc("@label", "Disk write:")
            placeholderText: root.cfg_diskWriteSensorIdDefault
        }

        Controls.TextField {
            id: networkDownloadSensorId
            enabled: NetworkSource.mode(root.effectiveNetworkSource) === "custom"
            Kirigami.FormData.label: i18nc("@label", "Network down:")
            placeholderText: root.cfg_networkDownloadSensorIdDefault
        }

        Controls.TextField {
            id: networkUploadSensorId
            enabled: NetworkSource.mode(root.effectiveNetworkSource) === "custom"
            Kirigami.FormData.label: i18nc("@label", "Network up:")
            placeholderText: root.cfg_networkUploadSensorIdDefault
        }
    }
}
