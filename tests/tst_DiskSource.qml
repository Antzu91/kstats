import QtQuick
import QtTest
import "../contents/ui/DiskSource.js" as DiskSource

TestCase {
    name: "DiskSource"

    readonly property var d: DiskSource.defaults

    function test_upgradeDefaultsToAggregate() {
        compare(DiskSource.effectiveSource("all", d.usage, d.read, d.write), "all");
        compare(DiskSource.effectiveSource("", d.usage, d.read, d.write), "all");
        compare(DiskSource.sensorIds("all", d.usage, d.read, d.write), {
            usage: "disk/all/usedPercent", read: "disk/all/read", write: "disk/all/write",
            used: "disk/all/used", total: "disk/all/total" });
    }

    function test_legacyCustomIdsMigrate_data() {
        return [
            { tag: "custom usage", usage: "disk/abc/usedPercent", read: d.read, write: d.write },
            { tag: "custom read", usage: d.usage, read: "disk/sda/read", write: d.write },
            { tag: "cleared write", usage: d.usage, read: d.read, write: "" }
        ];
    }
    function test_legacyCustomIdsMigrate(data) {
        compare(DiskSource.effectiveSource("all", data.usage, data.read, data.write), "custom");
        var ids = DiskSource.sensorIds("custom", data.usage, data.read, data.write);
        compare(ids.usage, data.usage);
        compare(ids.read, data.read);
        compare(ids.write, data.write);
        // Byte totals are never paired with a custom capacity definition.
        compare(ids.used, "");
        compare(ids.total, "");
    }

    function test_volumeSharesOneIdentity() {
        var source = DiskSource.volumeSource("1792e22e-bc5e-4951-b716-eda210512955");
        compare(DiskSource.effectiveSource(source, d.usage, d.read, d.write), source);
        compare(DiskSource.mode(source), "volume");
        compare(DiskSource.sensorIds(source, "x", "y", "z"), {
            usage: "disk/1792e22e-bc5e-4951-b716-eda210512955/usedPercent",
            read: "disk/1792e22e-bc5e-4951-b716-eda210512955/read",
            write: "disk/1792e22e-bc5e-4951-b716-eda210512955/write",
            used: "disk/1792e22e-bc5e-4951-b716-eda210512955/used",
            total: "disk/1792e22e-bc5e-4951-b716-eda210512955/total" });
    }

    function test_unsafeOrUnknownSourcesAreSanitized_data() {
        return [
            { tag: "unknown", source: "fastest" },
            { tag: "empty volume", source: "volume:" },
            { tag: "path", source: "volume:../x" },
            { tag: "slash", source: "volume:a/b" },
            { tag: "aggregate", source: "volume:all" }
        ];
    }
    function test_unsafeOrUnknownSourcesAreSanitized(data) {
        compare(DiskSource.effectiveSource(data.source, d.usage, d.read, d.write), "all");
    }

    function test_discoveryMatchesVolumesOnly() {
        compare(DiskSource.volumeFromSensorId("disk/8339-7F8B/usedPercent"), "8339-7F8B");
        compare(DiskSource.volumeFromSensorId("disk/all/usedPercent"), "");
        compare(DiskSource.volumeFromSensorId("disk/nvme0n1/read"), "");
        compare(DiskSource.volumeFromSensorId("disk/abc/used"), "");
    }
}
