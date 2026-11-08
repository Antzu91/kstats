import QtQuick
import QtTest

// The settings page owns upgrade behaviour for network and disk sources: legacy
// custom sensor IDs must stay custom, and friendly choices must not be undone by them.
TestCase {
    id: testCase
    name: "ConfigSources"
    when: windowShown
    visible: true
    width: 600
    height: 900

    function substitute(text, args) {
        var result = String(text);
        for (var i = 0; i < args.length; ++i) {
            result = result.replace("%" + (i + 1), String(args[i]));
        }
        return result;
    }
    function i18n(text) { return substitute(text, Array.prototype.slice.call(arguments, 1)); }
    function i18nc(context, text) { return substitute(text, Array.prototype.slice.call(arguments, 2)); }

    readonly property Component pageComponent: Qt.createComponent(Qt.resolvedUrl("../contents/ui/configGeneral.qml"))

    function init() {
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }

    // The KCM always injects stored values; start from the schema defaults.
    function make(properties) {
        compare(pageComponent.status, Component.Ready, pageComponent.errorString());
        // Sized like the settings window, so popups have room to centre.
        var initial = { width: 600, height: 900, cfg_networkSource: "all",
            cfg_networkDownloadSensorId: "network/all/download",
            cfg_networkUploadSensorId: "network/all/upload",
            cfg_diskSource: "all",
            cfg_diskSensorId: "disk/all/usedPercent",
            cfg_diskReadSensorId: "disk/all/read",
            cfg_diskWriteSensorId: "disk/all/write" };
        Object.keys(properties || {}).forEach(function(key) { initial[key] = properties[key]; });
        var page = createTemporaryObject(pageComponent, testCase, initial);
        verify(page !== null);
        return page;
    }

    function keys(page) {
        return page.networkChoices.map(function(choice) { return choice.key; });
    }

    function test_defaultsShowAggregate() {
        var page = make();
        compare(page.effectiveNetworkSource, "all");
        compare(keys(page), ["all", "auto", "custom"]);
    }

    function test_legacyCustomIdsStayCustom() {
        var page = make({ cfg_networkDownloadSensorId: "network/wlan0/download",
            cfg_networkUploadSensorId: "network/wlan0/upload" });
        compare(page.cfg_networkSource, "all");
        compare(page.effectiveNetworkSource, "custom");
        compare(page.cfg_networkDownloadSensorId, "network/wlan0/download");
    }

    function test_friendlyChoiceClearsLegacyIds() {
        var page = make({ cfg_networkDownloadSensorId: "network/wlan0/download",
            cfg_networkUploadSensorId: "network/wlan0/upload" });
        page.selectNetworkSource("auto");
        compare(page.cfg_networkSource, "auto");
        compare(page.cfg_networkDownloadSensorId, "network/all/download");
        compare(page.cfg_networkUploadSensorId, "network/all/upload");
        compare(page.effectiveNetworkSource, "auto");
        page.selectNetworkSource("all");
        compare(page.effectiveNetworkSource, "all");
    }

    function test_customKeepsEditedIds() {
        var page = make();
        page.selectNetworkSource("custom");
        page.cfg_networkDownloadSensorId = "network/eno1/download";
        compare(page.effectiveNetworkSource, "custom");
        compare(page.cfg_networkDownloadSensorId, "network/eno1/download");
    }

    function test_missingConfiguredInterfaceStaysSelectable() {
        // No sensor daemon in CI: discovery is empty, so the interface is absent.
        var page = make({ cfg_networkSource: "interface:wlan0" });
        compare(page.effectiveNetworkSource, "interface:wlan0");
        compare(keys(page), ["all", "auto", "interface:wlan0", "custom"]);
        compare(page.networkChoices[2].name, "Wi-Fi (wlan0) (unavailable)");
    }

    function test_unsafeStoredInterfaceIsSanitized() {
        var page = make({ cfg_networkSource: "interface:eth0;reboot" });
        compare(page.effectiveNetworkSource, "all");
        compare(keys(page), ["all", "auto", "custom"]);
    }

    function diskKeys(page) {
        return page.diskChoices.map(function(choice) { return choice.key; });
    }

    function test_diskDefaultsShowAggregate() {
        var page = make();
        compare(page.effectiveDiskSource, "all");
        compare(diskKeys(page), ["all", "custom"]);
    }

    function test_diskLegacyCustomIdsStayCustomUntilFriendlyChoice() {
        var page = make({ cfg_diskSensorId: "disk/1792e22e/usedPercent" });
        compare(page.effectiveDiskSource, "custom");
        page.selectDiskSource("all");
        compare(page.cfg_diskSource, "all");
        compare(page.cfg_diskSensorId, "disk/all/usedPercent");
        compare(page.effectiveDiskSource, "all");
    }

    function test_diskMissingVolumeStaysSelectable() {
        var page = make({ cfg_diskSource: "volume:1792e22e-bc5e" });
        compare(page.effectiveDiskSource, "volume:1792e22e-bc5e");
        compare(diskKeys(page), ["all", "volume:1792e22e-bc5e", "custom"]);
        compare(page.diskChoices[1].name, "1792e22e-bc5e (unavailable)");
    }

    function test_cpuSensorModes() {
        var page = make({ cfg_cpuTemperatureSensor: "auto", cfg_cpuFanSensor: "lmsensors/it8686-isa-0a40/fan1" });
        compare(page.cpuSensorModeIndex(page.cfg_cpuTemperatureSensor), 0);
        compare(page.cpuSensorModeIndex(page.cfg_cpuFanSensor), 2);
        compare(page.cpuSensorChoices(page.cfg_cpuFanSensor)[2], "Sensor: lmsensors/it8686-isa-0a40/fan1");
        page.activateCpuSensorMode("temperature", 1, page.cfg_cpuTemperatureSensor);
        compare(page.cfg_cpuTemperatureSensor, "off");
        page.activateCpuSensorMode("fan", 0, page.cfg_cpuFanSensor);
        compare(page.cfg_cpuFanSensor, "auto");
    }

    function test_cpuSensorPickerChoosesAndCancels() {
        var page = make({ cfg_cpuTemperatureSensor: "auto" });
        var picker = page.sensorPicker;
        verify(!picker.preview.enabled);
        page.activateCpuSensorMode("temperature", 2, page.cfg_cpuTemperatureSensor);
        tryCompare(picker, "visible", true);
        picker.entries = [
            { key: "lmsensors/k10temp-pci-00c3/temp1", name: "k10temp-pci-00c3", label: "Tctl" },
            { key: "lmsensors/nct6799-isa-0290/fan1", name: "nct6799-isa-0290", label: "CPU Fan" }
        ];
        // The picker opened filtered to temperatures.
        compare(picker.filteredEntries.length, 1);
        picker.selectedSensorId = "lmsensors/k10temp-pci-00c3/temp1";
        verify(picker.preview.enabled);
        picker.reject();
        tryCompare(picker, "visible", false);
        compare(page.cfg_cpuTemperatureSensor, "auto");
        // Closing stops the preview subscription.
        verify(!picker.preview.enabled);

        page.activateCpuSensorMode("temperature", 2, page.cfg_cpuTemperatureSensor);
        tryCompare(picker, "visible", true);
        picker.selectedSensorId = "lmsensors/k10temp-pci-00c3/temp1";
        picker.accept();
        compare(page.cfg_cpuTemperatureSensor, "lmsensors/k10temp-pci-00c3/temp1");
        compare(page.cpuSensorModeIndex(page.cfg_cpuTemperatureSensor), 2);
    }

    function test_cpuSensorPickerIgnoresInvalidIds() {
        var page = make({ cfg_cpuFanSensor: "auto" });
        page.activateCpuSensorMode("fan", 2, page.cfg_cpuFanSensor);
        tryCompare(page.sensorPicker, "visible", true);
        page.sensorPicker.selectedSensorId = "not a sensor";
        page.sensorPicker.accept();
        compare(page.cfg_cpuFanSensor, "auto");
    }

    function test_moduleOrderMoves() {
        var page = make({ cfg_moduleOrder: "cpu,memory,gpu,disk,network" });
        compare(page.moduleOrderList, ["cpu", "memory", "gpu", "disk", "network"]);
        page.moveModule("network", -1);
        compare(page.cfg_moduleOrder, "cpu,memory,gpu,network,disk");
        page.moveModule("cpu", -1);
        compare(page.cfg_moduleOrder, "cpu,memory,gpu,network,disk");
    }
}
