import QtQuick
import QtTest
import "../contents/ui/NetworkSource.js" as NetworkSource

TestCase {
    name: "NetworkSource"

    readonly property string down: NetworkSource.defaultDownloadSensorId
    readonly property string up: NetworkSource.defaultUploadSensorId

    function test_upgradeDefaultsToAggregate() {
        compare(NetworkSource.effectiveSource("all", down, up), "all");
        compare(NetworkSource.effectiveSource("", down, up), "all");
        compare(NetworkSource.effectiveSource(undefined, down, up), "all");
    }

    function test_legacyCustomIdsMigrateToCustom_data() {
        return [
            { tag: "custom download", download: "network/wlan0/download", upload: up },
            { tag: "custom upload", download: down, upload: "network/wlan0/upload" },
            { tag: "cleared ids", download: "", upload: "" }
        ];
    }
    function test_legacyCustomIdsMigrateToCustom(data) {
        compare(NetworkSource.effectiveSource("all", data.download, data.upload), "custom");
        compare(NetworkSource.effectiveSource("bogus", data.download, data.upload), "custom");
    }

    function test_explicitSourcesWin() {
        compare(NetworkSource.effectiveSource("auto", "x", "y"), "auto");
        compare(NetworkSource.effectiveSource("custom", down, up), "custom");
        compare(NetworkSource.effectiveSource("interface:eno1", down, up), "interface:eno1");
    }

    function test_unknownOrUnsafeSourcesAreSanitized_data() {
        return [
            { tag: "unknown mode", source: "fastest" },
            { tag: "empty interface", source: "interface:" },
            { tag: "shell characters", source: "interface:eth0;rm" },
            { tag: "path", source: "interface:../x" },
            { tag: "too long", source: "interface:abcdefghijklmnop" },
            { tag: "aggregate name", source: "interface:all" }
        ];
    }
    function test_unknownOrUnsafeSourcesAreSanitized(data) {
        compare(NetworkSource.effectiveSource(data.source, down, up), "all");
    }

    function test_sensorIdsFollowMode() {
        compare(NetworkSource.sensorIds("all", "", "a", "b"), { download: down, upload: up });
        compare(NetworkSource.sensorIds("auto", "eno1", "a", "b"),
            { download: "network/eno1/download", upload: "network/eno1/upload" });
        compare(NetworkSource.sensorIds("interface", "wlp1s0", "a", "b"),
            { download: "network/wlp1s0/download", upload: "network/wlp1s0/upload" });
        compare(NetworkSource.sensorIds("custom", "", " a ", "b"), { download: "a", upload: "b" });
    }

    function test_unresolvedInterfaceNeverFallsBack() {
        compare(NetworkSource.sensorIds("auto", "", "a", "b"), { download: "", upload: "" });
        compare(NetworkSource.sensorIds("interface", "bad name", "a", "b"), { download: "", upload: "" });
    }

    function test_routeParsing() {
        compare(NetworkSource.routeInterface("1.1.1.1 via 192.168.0.1 dev eno1 src 192.168.0.166 uid 1000 \n    cache \n"), "eno1");
        compare(NetworkSource.routeInterface("2606:4700:4700::1111 from :: via fe80::1 dev wlp11s0 proto ra src 2001:db8::5 metric 600 pref medium"), "wlp11s0");
        compare(NetworkSource.routeInterface("RTNETLINK answers: Network is unreachable"), "");
        compare(NetworkSource.routeInterface(""), "");
        compare(NetworkSource.routeInterface("1.1.1.1 dev $(reboot) src 1.2.3.4"), "");
    }

    function test_sourceRoundTrip() {
        compare(NetworkSource.mode("interface:eno1"), "interface");
        compare(NetworkSource.interfaceFromSource("interface:eno1"), "eno1");
        compare(NetworkSource.interfaceSource("eno1"), "interface:eno1");
        compare(NetworkSource.interfaceSource("bad name"), "all");
        compare(NetworkSource.interfaceFromSensorId("network/eno1/download"), "eno1");
        compare(NetworkSource.interfaceFromSensorId("network/all/download"), "");
        compare(NetworkSource.interfaceFromSensorId("network/eno1/upload"), "");
    }

    function test_interfaceKinds() {
        compare(NetworkSource.interfaceKind("wlp11s0"), "wifi");
        compare(NetworkSource.interfaceKind("eno1"), "ethernet");
        compare(NetworkSource.interfaceKind("eth0"), "ethernet");
        compare(NetworkSource.interfaceKind("wg0"), "vpn");
        compare(NetworkSource.interfaceKind("tun0"), "vpn");
        compare(NetworkSource.interfaceKind("virbr0"), "virtual");
        compare(NetworkSource.interfaceKind("enx00e04c"), "ethernet");
        compare(NetworkSource.interfaceKind("usb0"), "other");
    }
}
