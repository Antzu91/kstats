import QtQuick
import QtTest
import "../contents/ui/DiskHealth.js" as DiskHealth

TestCase {
    name: "DiskHealth"

    readonly property string nvmePath: "/org/freedesktop/UDisks2/drives/Samsung_SSD_980_1TB_TEST0001"
    readonly property string ataPath: "/org/freedesktop/UDisks2/drives/Samsung_SSD_860_QVO_1TB_TEST0002"

    function prop(type, data) { return { type: type, data: data }; }
    function devicePath(text) {
        var bytes = [];
        for (var i = 0; i < text.length; ++i) {
            bytes.push(text.charCodeAt(i));
        }
        bytes.push(0);
        return prop("ay", bytes);
    }
    // Shape of `busctl --json=short ... GetManagedObjects` from UDisks 2.11.
    function managedObjects(overrides) {
        var o = overrides || {};
        var objects = {};
        objects[nvmePath] = {
            "org.freedesktop.UDisks2.Drive": { Model: prop("s", "Samsung SSD 980 1TB"), Serial: prop("s", "TEST0001"), Size: prop("t", 1000204886016) },
            "org.freedesktop.UDisks2.NVMe.Controller": {
                SmartUpdated: prop("t", o.nvmeUpdated === undefined ? 1794127514 : o.nvmeUpdated),
                SmartCriticalWarning: prop("as", o.criticalWarning || []),
                SmartPowerOnHours: prop("t", 855),
                SmartTemperature: prop("q", 301)
            }
        };
        objects[ataPath] = {
            "org.freedesktop.UDisks2.Drive": { Model: prop("s", "Samsung SSD 860 QVO 1TB"), Serial: prop("s", "TEST0002"), Size: prop("t", 1000204886016) },
            "org.freedesktop.UDisks2.Drive.Ata": {
                SmartSupported: prop("b", o.ataSupported === undefined ? true : o.ataSupported),
                SmartEnabled: prop("b", o.ataEnabled === undefined ? true : o.ataEnabled),
                SmartUpdated: prop("t", 1794127514),
                SmartFailing: prop("b", o.ataFailing === true),
                SmartPowerOnSeconds: prop("t", 21106800),
                SmartTemperature: prop("d", 298),
                SmartNumAttributesFailing: prop("i", o.attributesFailing || 0),
                SmartNumAttributesFailedInThePast: prop("i", 0),
                SmartNumBadSectors: prop("x", o.badSectors || 0)
            }
        };
        objects["/org/freedesktop/UDisks2/drives/USB_Stick"] = {
            "org.freedesktop.UDisks2.Drive": { Model: prop("s", "USB Stick"), Serial: prop("s", ""), Size: prop("t", 8000000000) }
        };
        objects["/org/freedesktop/UDisks2/block_devices/nvme1n1"] = {
            "org.freedesktop.UDisks2.Block": { Device: devicePath("/dev/nvme1n1"), Drive: prop("o", nvmePath) }
        };
        objects["/org/freedesktop/UDisks2/block_devices/nvme1n1p3"] = {
            "org.freedesktop.UDisks2.Block": { Device: devicePath("/dev/nvme1n1p3"), Drive: prop("o", nvmePath) },
            "org.freedesktop.UDisks2.Partition": { Number: prop("u", 3) }
        };
        objects["/org/freedesktop/UDisks2/block_devices/sda"] = {
            "org.freedesktop.UDisks2.Block": { Device: devicePath("/dev/sda"), Drive: prop("o", ataPath) }
        };
        objects["/org/freedesktop/UDisks2/block_devices/sdb"] = {
            "org.freedesktop.UDisks2.Block": { Device: devicePath("/dev/sdb"), Drive: prop("o", "/org/freedesktop/UDisks2/drives/USB_Stick") }
        };
        objects["/org/freedesktop/UDisks2/block_devices/zram0"] = {
            "org.freedesktop.UDisks2.Block": { Device: devicePath("/dev/zram0"), Drive: prop("o", "/") }
        };
        return JSON.stringify({ type: "a{oa{sa{sv}}}", data: [objects] });
    }
    function nvmeAttributes(values) {
        var data = {};
        Object.keys(values).forEach(function(name) { data[name] = prop("t", values[name]); });
        return JSON.stringify({ type: "a{sv}", data: [data] });
    }
    function ataAttributes(wearValue) {
        return JSON.stringify({ type: "a(ysqiiixia{sv})", data: [[
            [5, "reallocated-sector-count", 51, 100, 100, 10, 0, 3, {}],
            [177, "wear-leveling-count", 19, wearValue, wearValue, 0, 21, 1, {}],
            [241, "total-lbas-written", 50, 99, 99, 0, 872683155683, 7, {}]
        ]] });
    }
    function batch(sections) {
        return sections.map(function(section) {
            return DiskHealth.marker + section.path + "\n" + section.body + "\n";
        }).join("");
    }

    function test_parsesDrivesAndWholeDiskMapping() {
        var layout = DiskHealth.parseManagedObjects(managedObjects());
        verify(layout !== null);
        compare(layout.deviceToDrive.nvme1n1, nvmePath);
        compare(layout.deviceToDrive.sda, ataPath);
        verify(!("nvme1n1p3" in layout.deviceToDrive));
        verify(!("zram0" in layout.deviceToDrive));
        compare(layout.drives[nvmePath].kind, "nvme");
        compare(layout.drives[nvmePath].model, "Samsung SSD 980 1TB");
        compare(layout.drives[ataPath].kind, "ata");
        compare(layout.drives["/org/freedesktop/UDisks2/drives/USB_Stick"].kind, "none");
    }

    function test_rejectsUnusableOutput_data() {
        return [
            { tag: "empty", output: "" },
            { tag: "not json", output: "Failed to connect to bus: No such file or directory" },
            { tag: "wrong shape", output: '{"type":"s","data":["x"]}' }
        ];
    }
    function test_rejectsUnusableOutput(data) {
        compare(DiskHealth.parseManagedObjects(data.output), null);
    }

    function test_healthyNvmeWithAttributes() {
        var layout = DiskHealth.parseManagedObjects(managedObjects());
        var attributes = DiskHealth.parseAttributesBatch(batch([{ path: nvmePath, body: nvmeAttributes({
            percent_used: 5, total_data_read: 70499832320000, total_data_written: 45823881216000,
            media_errors: 0, unsafe_shutdowns: 36, avail_spare: 100, spare_thresh: 10 }) }]));
        var summary = DiskHealth.summarize(layout.drives[nvmePath], attributes[nvmePath]);
        compare(summary.status, "good");
        compare(summary.problems, []);
        compare(summary.temperatureC, 27.9);
        compare(summary.powerOnHours, 855);
        compare(summary.wearPercent, 5);
        compare(summary.dataWritten, 45823881216000);
        compare(summary.unsafeShutdowns, 36);
    }

    function test_nvmeWithoutAttributesStillReportsBaseHealth() {
        var layout = DiskHealth.parseManagedObjects(managedObjects());
        var summary = DiskHealth.summarize(layout.drives[nvmePath], null);
        compare(summary.status, "good");
        compare(summary.wearPercent, null);
        compare(summary.dataWritten, null);
    }

    function test_nvmeCriticalWarnings_data() {
        return [
            { tag: "spare", warnings: ["spare"], status: "warning" },
            { tag: "temperature", warnings: ["temperature"], status: "warning" },
            { tag: "read-only", warnings: ["readonly"], status: "failing" },
            { tag: "degraded", warnings: ["degraded", "spare"], status: "failing" }
        ];
    }
    function test_nvmeCriticalWarnings(data) {
        var layout = DiskHealth.parseManagedObjects(managedObjects({ criticalWarning: data.warnings }));
        var summary = DiskHealth.summarize(layout.drives[nvmePath], null);
        compare(summary.status, data.status);
        compare(summary.problems, data.warnings.map(function(warning) { return "nvme-" + warning; }));
    }

    function test_nvmeWearAndMediaErrors() {
        var layout = DiskHealth.parseManagedObjects(managedObjects());
        var attributes = DiskHealth.parseAttributesBatch(batch([{ path: nvmePath,
            body: nvmeAttributes({ percent_used: 104, media_errors: 3 }) }]));
        var summary = DiskHealth.summarize(layout.drives[nvmePath], attributes[nvmePath]);
        compare(summary.status, "warning");
        compare(summary.problems, ["worn-out", "media-errors"]);
    }

    function test_ataHealthAndKnownWearAttribute() {
        var layout = DiskHealth.parseManagedObjects(managedObjects());
        var attributes = DiskHealth.parseAttributesBatch(batch([{ path: ataPath, body: ataAttributes(97) }]));
        var summary = DiskHealth.summarize(layout.drives[ataPath], attributes[ataPath]);
        compare(summary.status, "good");
        compare(summary.temperatureC, 24.9);
        compare(summary.powerOnHours, 5863);
        compare(summary.wearPercent, 3);
        // Raw vendor counters such as total-lbas-written are never interpreted.
        compare(summary.dataWritten, null);
    }

    function test_ataProblems_data() {
        return [
            { tag: "failing", overrides: { ataFailing: true }, status: "failing", problems: ["failing"] },
            { tag: "bad sectors", overrides: { badSectors: 8 }, status: "warning", problems: ["bad-sectors"] },
            { tag: "attributes", overrides: { attributesFailing: 1 }, status: "warning", problems: ["attributes-failing"] },
            { tag: "unsupported", overrides: { ataSupported: false }, status: "unknown", problems: ["unsupported"] },
            { tag: "disabled", overrides: { ataEnabled: false }, status: "unknown", problems: ["disabled"] }
        ];
    }
    function test_ataProblems(data) {
        var layout = DiskHealth.parseManagedObjects(managedObjects(data.overrides));
        var summary = DiskHealth.summarize(layout.drives[ataPath], null);
        compare(summary.status, data.status);
        compare(summary.problems, data.problems);
    }

    function test_missingDataNeverReadsHealthy() {
        var layout = DiskHealth.parseManagedObjects(managedObjects({ nvmeUpdated: 0 }));
        compare(DiskHealth.summarize(layout.drives[nvmePath], null).status, "unknown");
        compare(DiskHealth.summarize(layout.drives[nvmePath], null).problems, ["pending"]);
        compare(DiskHealth.summarize(layout.drives["/org/freedesktop/UDisks2/drives/USB_Stick"], null).problems, ["unsupported"]);
        compare(DiskHealth.summarize(undefined, null).problems, ["missing"]);
    }

    function test_attributesCommandOnlyQuotesValidatedPaths() {
        var layout = DiskHealth.parseManagedObjects(managedObjects({ ataEnabled: false }));
        var drives = Object.keys(layout.drives).map(function(path) { return layout.drives[path]; });
        drives.push({ path: "/org/freedesktop/UDisks2/drives/x'; reboot; '", kind: "nvme", smart: {} });
        var command = DiskHealth.attributesCommand(drives);
        verify(command.indexOf(nvmePath) >= 0);
        // SMART disabled or unsupported drives and invalid paths are skipped.
        verify(command.indexOf(ataPath) < 0);
        verify(command.indexOf("USB_Stick") < 0);
        verify(command.indexOf("reboot") < 0);
        verify(command.indexOf("--allow-interactive-authorization=no") >= 0);
        compare(DiskHealth.attributesCommand([]), "");
    }

    function test_attributeBatchToleratesFailures() {
        var output = batch([
            { path: nvmePath, body: "" },
            { path: ataPath, body: "Call failed: Access denied" },
            { path: "/not/a/drive", body: nvmeAttributes({ percent_used: 1 }) }
        ]);
        compare(DiskHealth.parseAttributesBatch(output), {});
        compare(DiskHealth.parseAttributesBatch(""), {});
    }

    function test_neverPromptsForAuthorization() {
        verify(DiskHealth.managedObjectsCommand.indexOf("--allow-interactive-authorization=no") > 0);
        verify(DiskHealth.managedObjectsCommand.indexOf("--system") > 0);
    }
}
