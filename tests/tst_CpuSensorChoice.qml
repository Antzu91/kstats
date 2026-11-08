import QtQuick
import QtTest
import "../contents/ui/CpuSensorChoice.js" as CpuSensorChoice

TestCase {
    name: "CpuSensorChoice"

    readonly property var amdTree: [
        { sensorId: "lmsensors/k10temp-pci-00c3/temp1", pathNames: ["Hardware Sensors", "k10temp-pci-00c3", "Tctl"] },
        { sensorId: "lmsensors/nvme-pci-0100/temp1", pathNames: ["Hardware Sensors", "nvme-pci-0100", "Composite"] },
        { sensorId: "lmsensors/amdgpu-pci-0300/temp1", pathNames: ["Hardware Sensors", "amdgpu-pci-0300", "edge"] },
        { sensorId: "lmsensors/nct6799-isa-0290/fan1", pathNames: ["Hardware Sensors", "nct6799-isa-0290", "CPU Fan"] },
        { sensorId: "lmsensors/nct6799-isa-0290/fan2", pathNames: ["Hardware Sensors", "nct6799-isa-0290", "Pump"] },
        { sensorId: "cpu/all/usage", pathNames: ["CPU", "All", "Usage"] }
    ]

    function test_selection_data() {
        return [
            { tag: "default", setting: "auto", mode: "auto", sensorId: "" },
            { tag: "empty", setting: "", mode: "auto", sensorId: "" },
            { tag: "missing", setting: undefined, mode: "auto", sensorId: "" },
            { tag: "off", setting: "off", mode: "off", sensorId: "" },
            { tag: "manual", setting: "lmsensors/k10temp-pci-00c3/temp1", mode: "manual", sensorId: "lmsensors/k10temp-pci-00c3/temp1" },
            { tag: "template is not a sensor", setting: "cpu/cpu.*/usage", mode: "auto", sensorId: "" },
            { tag: "whitespace", setting: "lmsensors/a b", mode: "auto", sensorId: "" },
            { tag: "no path", setting: "temp1", mode: "auto", sensorId: "" }
        ];
    }
    function test_selection(data) {
        compare(CpuSensorChoice.selection(data.setting), { mode: data.mode, sensorId: data.sensorId });
    }

    function test_automaticPrefersCpuPackageSensors() {
        compare(CpuSensorChoice.bestSensor(amdTree, "temperature"), "lmsensors/k10temp-pci-00c3/temp1");
        compare(CpuSensorChoice.bestSensor(amdTree, "fan"), "lmsensors/nct6799-isa-0290/fan1");
        compare(CpuSensorChoice.bestSensor([amdTree[1], amdTree[2]], "temperature"), "");
    }

    function test_automaticKeepsCurrentWhilePresentAndRecovers() {
        var current = "lmsensors/nct6799-isa-0290/fan2";
        compare(CpuSensorChoice.automaticSensor(current, amdTree, "fan"), current);
        var withoutCurrent = amdTree.filter(function(entry) { return entry.sensorId !== current; });
        compare(CpuSensorChoice.automaticSensor(current, withoutCurrent, "fan"), "lmsensors/nct6799-isa-0290/fan1");
        compare(CpuSensorChoice.automaticSensor("", [], "temperature"), "");
    }

    function test_onlyAutomaticUsesDiscovery() {
        compare(CpuSensorChoice.resolvedSensorId(CpuSensorChoice.selection("auto"), "x/y"), "x/y");
        compare(CpuSensorChoice.resolvedSensorId(CpuSensorChoice.selection("off"), "x/y"), "");
        // A missing manual sensor stays selected; it is never replaced.
        compare(CpuSensorChoice.resolvedSensorId(CpuSensorChoice.selection("gone/sensor"), "x/y"), "gone/sensor");
    }
}
