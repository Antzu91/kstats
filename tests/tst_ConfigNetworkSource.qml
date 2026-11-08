import QtQuick
import QtTest

// The settings page owns upgrade behaviour for network sources: legacy custom
// sensor IDs must stay custom, and friendly choices must not be undone by them.
TestCase {
    id: testCase
    name: "ConfigNetworkSource"
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
        var initial = { cfg_networkSource: "all",
            cfg_networkDownloadSensorId: "network/all/download",
            cfg_networkUploadSensorId: "network/all/upload" };
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
}
