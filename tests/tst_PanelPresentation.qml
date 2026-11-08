import QtQuick
import QtTest
import "../contents/ui/PanelPresentation.js" as PanelPresentation

TestCase {
    name: "PanelPresentation"

    function test_defaultsReproduceOriginalPanel() {
        compare(PanelPresentation.presentation("cpu", undefined), "numberGraph");
        compare(PanelPresentation.presentation("memory", ""), "numberGraph");
        compare(PanelPresentation.presentation("gpu", null), "numberGraph");
        compare(PanelPresentation.presentation("disk", ""), "bar");
        compare(PanelPresentation.presentation("network", ""), "numbers");
    }

    function test_unknownOrMismatchedModesFallBack() {
        compare(PanelPresentation.presentation("cpu", "sparkle"), "numberGraph");
        compare(PanelPresentation.presentation("cpu", "numbers"), "numberGraph");
        compare(PanelPresentation.presentation("network", "bar"), "numbers");
        compare(PanelPresentation.presentation("disk", " graph "), "graph");
    }

    function test_parts() {
        compare(PanelPresentation.parts("number"), { meter: "none", value: true });
        compare(PanelPresentation.parts("graph"), { meter: "sparkline", value: false });
        compare(PanelPresentation.parts("numberGraph"), { meter: "sparkline", value: true });
        compare(PanelPresentation.parts("bar"), { meter: "bar", value: true });
        compare(PanelPresentation.networkParts("numbers"), { numbers: true, graph: false });
        compare(PanelPresentation.networkParts("graph"), { numbers: false, graph: true });
        compare(PanelPresentation.networkParts("numbersGraph"), { numbers: true, graph: true });
    }
}
