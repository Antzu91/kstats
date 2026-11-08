import QtQuick
import QtTest
import "../contents/ui/SectionState.js" as SectionState

TestCase {
    name: "SectionState"

    function test_defaultsFollowDensity() {
        var states = SectionState.parse("");
        compare(SectionState.isExpanded(states, "ram.details", false), true);
        compare(SectionState.isExpanded(states, "ram.details", true), false);
    }

    function test_explicitChoicesWin() {
        var states = SectionState.parse("ram.details=0,cpu.apps=1");
        compare(SectionState.isExpanded(states, "ram.details", false), false);
        compare(SectionState.isExpanded(states, "cpu.apps", true), true);
    }

    function test_roundTripAndSanitize() {
        compare(SectionState.withState("", "net.apps", false), "net.apps=0");
        compare(SectionState.withState("net.apps=0", "cpu.apps", true), "cpu.apps=1,net.apps=0");
        compare(SectionState.withState("net.apps=0", "net.apps", true), "net.apps=1");
        // Malformed entries and keys are dropped, never stored.
        compare(SectionState.serialize(SectionState.parse("bad,x=2,ram.details=1,=1,a.b.c=0")), "ram.details=1");
        compare(SectionState.withState("ram.details=1", "Bad Key", false), "ram.details=1");
    }
}
