import QtQuick
import QtTest
import "../contents/ui/ModuleCatalog.js" as ModuleCatalog

TestCase {
    name: "ModuleCatalog"

    function test_normalizeOrder_data() {
        return [
            { tag: "default", order: "cpu,memory,gpu,disk,network", expected: ["cpu", "memory", "gpu", "disk", "network"] },
            { tag: "custom", order: "network,cpu,disk,memory,gpu", expected: ["network", "cpu", "disk", "memory", "gpu"] },
            { tag: "missing appended", order: "disk,cpu", expected: ["disk", "cpu", "memory", "gpu", "network"] },
            { tag: "duplicates and unknown", order: "gpu,gpu,battery, cpu ,", expected: ["gpu", "cpu", "memory", "disk", "network"] },
            { tag: "empty", order: "", expected: ["cpu", "memory", "gpu", "disk", "network"] },
            { tag: "undefined", order: undefined, expected: ["cpu", "memory", "gpu", "disk", "network"] }
        ];
    }
    function test_normalizeOrder(data) {
        compare(ModuleCatalog.normalizeOrder(data.order), data.expected);
    }

    function test_move() {
        compare(ModuleCatalog.move("cpu,memory,gpu,disk,network", "disk", -1), "cpu,memory,disk,gpu,network");
        compare(ModuleCatalog.move("cpu,memory,gpu,disk,network", "cpu", 1), "memory,cpu,gpu,disk,network");
        // Edges and unknown IDs leave the order unchanged.
        compare(ModuleCatalog.move("cpu,memory,gpu,disk,network", "cpu", -1), "cpu,memory,gpu,disk,network");
        compare(ModuleCatalog.move("cpu,memory,gpu,disk,network", "network", 1), "cpu,memory,gpu,disk,network");
        compare(ModuleCatalog.move("cpu,memory,gpu,disk,network", "battery", 1), "cpu,memory,gpu,disk,network");
        compare(ModuleCatalog.move("gpu,gpu", "gpu", 1), "cpu,gpu,memory,disk,network");
    }

    function test_pagesResolveFromIds() {
        // The popup's page stack has fixed indices, independent of the order.
        compare(ModuleCatalog.pageIndex("cpu"), 0);
        compare(ModuleCatalog.pageIndex("memory"), 1);
        compare(ModuleCatalog.pageIndex("gpu"), 2);
        compare(ModuleCatalog.pageIndex("network"), 3);
        compare(ModuleCatalog.pageIndex("disk"), 4);
        compare(ModuleCatalog.moduleForPage(4), "disk");
        ModuleCatalog.ids.forEach(function(id) {
            compare(ModuleCatalog.moduleForPage(ModuleCatalog.pageIndex(id)), id);
        });
    }
}
