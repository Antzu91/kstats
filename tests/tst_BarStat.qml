import QtQuick
import QtTest
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "BarStat"
    when: windowShown
    visible: true
    width: 400
    height: 60
    function i18nc(context, text) { return text; }

    Component {
        id: statFactory
        Local.BarStat {
            height: 24
            label: "CPU"
            value: "23.4%"
            percent: 23.4
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }
    function make(properties) {
        var stat = createTemporaryObject(statFactory, testCase, properties || {});
        verify(stat !== null);
        return stat;
    }
    function unavailableLabel(stat) {
        return findChild(stat, "meterUnavailable");
    }

    function test_widthNeverDependsOnTheReading_data() {
        return [
            { tag: "number", meterMode: "none", showValue: true },
            { tag: "graph", meterMode: "sparkline", showValue: false },
            { tag: "number and graph", meterMode: "sparkline", showValue: true },
            { tag: "bar", meterMode: "bar", showValue: true }
        ];
    }
    function test_widthNeverDependsOnTheReading(data) {
        var stat = make({ meterMode: data.meterMode, showValue: data.showValue });
        var width = stat.fixedWidth;
        verify(width > 0);
        stat.value = "100.0%";
        compare(stat.fixedWidth, width);
        stat.value = "N/A";
        stat.dataAvailable = false;
        compare(stat.fixedWidth, width);
        stat.value = "3%";
        stat.dataAvailable = true;
        compare(stat.fixedWidth, width);
    }

    function test_partsAddUp() {
        var full = make({ meterMode: "sparkline", showValue: true });
        var noLabel = make({ meterMode: "sparkline", showValue: true, showLabel: false });
        var numberOnly = make({ meterMode: "none", showValue: true });
        verify(noLabel.fixedWidth < full.fixedWidth);
        verify(numberOnly.fixedWidth < full.fixedWidth);
        compare(noLabel.partCount, 2);
        compare(numberOnly.partCount, 2);
        compare(make({ meterMode: "none", showValue: false, showLabel: false }).fixedWidth, 0);
    }

    function test_graphOnlyStillSaysWhenDataIsMissing() {
        var stat = make({ meterMode: "sparkline", showValue: false, dataAvailable: false });
        verify(unavailableLabel(stat).visible);
        stat.dataAvailable = true;
        verify(!unavailableLabel(stat).visible);
        // With the value shown, the value carries N/A instead.
        var withValue = make({ meterMode: "bar", showValue: true, dataAvailable: false });
        verify(!unavailableLabel(withValue).visible);
    }

    function test_customFontSizes() {
        var stat = make({ labelFontSize: 20, valueFontSize: 22 });
        var wide = stat.fixedWidth;
        var normal = make();
        verify(wide > normal.fixedWidth);
    }
}
