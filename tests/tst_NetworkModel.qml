import QtQuick
import QtTest
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "NetworkModel"
    when: windowShown
    visible: true
    property var requests: []
    property var pending: []

    function substitute(text, args) {
        var result = String(text);
        for (var i = 0; i < args.length; ++i) {
            result = result.replace("%" + (i + 1), String(args[i]));
        }
        return result;
    }
    function i18n(text) { return substitute(text, Array.prototype.slice.call(arguments, 1)); }
    function i18nc(context, text) { return substitute(text, Array.prototype.slice.call(arguments, 2)); }
    function i18ncp(context, singular, plural, count) {
        return substitute(count === 1 ? singular : plural, Array.prototype.slice.call(arguments, 3));
    }

    Component {
        id: fakeCommand
        QtObject {
            function exec(command, callback) {
                testCase.requests.push(command);
                testCase.pending.push({ command: command, callback: callback });
            }
        }
    }
    Component {
        id: modelFactory
        Local.NetworkModel {
            commandComponent: fakeCommand
        }
    }
    Component {
        id: pageFixtureFactory
        Item {
            id: fixture
            property bool networkDetailsVisible: true
            property int sensorUpdateRate: 1000
            readonly property int historyWindowDuration: 60000
            readonly property real historyNow: 0
            readonly property var networkUploadSamples: []
            readonly property var networkDownloadSamples: []
            property QtObject networkUploadMonitor: QtObject { property string text: "N/A" }
            property QtObject networkDownloadMonitor: QtObject { property string text: "N/A" }
            property alias networkModel: scope
            property alias page: page
            function historyCoverageText(samples) { return ""; }
            property string initialSource: "interface:eno1"
            Local.NetworkModel {
                id: scope
                source: fixture.initialSource
                active: true
                detailsDemand: fixture.networkDetailsVisible
                commandComponent: fakeCommand
            }
            Local.NetworkPage {
                id: page
                width: 432
                height: 684
                rootItem: fixture
                commandComponent: fakeCommand
            }
        }
    }

    readonly property string routeV4: "1.1.1.1 via 192.168.0.1 dev eno1 src 192.168.0.166 uid 1000 \n    cache \n"
    readonly property string routeWifi: "1.1.1.1 via 10.0.0.1 dev wlp11s0 src 10.0.0.7 uid 1000 \n    cache \n"

    function init() {
        requests = [];
        pending = [];
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }
    function make(properties) {
        var model = createTemporaryObject(modelFactory, testCase, properties || {});
        verify(model !== null);
        return model;
    }
    function deliver(stdout, exitCode) {
        verify(pending.length > 0);
        var request = pending.shift();
        request.callback({ stdout: stdout || "", stderr: "", exitCode: exitCode === undefined ? 0 : exitCode });
        return request.command;
    }
    function routeRequests() {
        return requests.filter(function(command) { return command.indexOf("route get") >= 0; }).length;
    }

    function test_aggregateNeedsNoRouteForMetrics() {
        var model = make({ source: "all", active: true });
        wait(20);
        compare(requests.length, 0);
        compare(model.downloadSensorId, "network/all/download");
        compare(model.uploadSensorId, "network/all/upload");
        compare(model.scopeText, "All interfaces");
    }

    function test_inactiveAutomaticMakesNoRequests() {
        make({ source: "auto" });
        wait(20);
        compare(requests.length, 0);
    }

    function test_automaticFollowsDefaultRoute() {
        var model = make({ source: "auto", active: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        compare(requests.length, 1);
        verify(requests[0].indexOf("ip route get") === 0);
        compare(model.downloadSensorId, "");
        compare(model.scopeText, "Automatic");
        deliver(routeV4);
        compare(model.routeStatus, "resolved");
        compare(model.downloadSensorId, "network/eno1/download");
        compare(model.uploadSensorId, "network/eno1/upload");
        compare(model.scopeText, "Automatic: Ethernet (eno1)");
        compare(model.detailsInterface, "eno1");
    }

    function test_automaticWithoutRouteIsUnavailable_data() {
        return [
            { tag: "unreachable", stdout: "RTNETLINK answers: Network is unreachable", exitCode: 2 },
            { tag: "ip missing", stdout: "", exitCode: 127 },
            { tag: "unparseable", stdout: "something unexpected", exitCode: 0 }
        ];
    }
    function test_automaticWithoutRouteIsUnavailable(data) {
        var model = make({ source: "auto", active: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver(data.stdout, data.exitCode);
        compare(model.routeStatus, "unresolved");
        compare(model.downloadSensorId, "");
        compare(model.uploadSensorId, "");
        compare(model.scopeText, "Automatic: no default route");
    }

    function test_routeChangeSwitchesSensors() {
        var model = make({ source: "auto", active: true, routeRefreshInterval: 1000 });
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver(routeV4);
        compare(model.downloadSensorId, "network/eno1/download");
        tryVerify(function() { return testCase.pending.length === 1; }, 3000);
        deliver(routeWifi);
        compare(model.downloadSensorId, "network/wlp11s0/download");
        compare(model.scopeText, "Automatic: Wi-Fi (wlp11s0)");
    }

    function test_lookupIsSingleFlight() {
        var model = make({ source: "auto", active: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        model.refreshRoute();
        model.refreshRoute();
        compare(requests.length, 1);
    }

    function test_lateResultAfterDemandLossIsIgnored() {
        var model = make({ source: "auto", active: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        model.active = false;
        deliver(routeV4);
        compare(model.routeInterface, "");
        compare(model.routeStatus, "unknown");
        compare(model.downloadSensorId, "");
        wait(20);
        compare(requests.length, 1);
        model.active = true;
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver(routeWifi);
        compare(model.downloadSensorId, "network/wlp11s0/download");
    }

    function test_resultFromPreviousDemandTriggersFreshLookup() {
        var model = make({ source: "auto", active: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        model.active = false;
        model.active = true;
        // The in-flight guard holds until the old request completes.
        compare(requests.length, 1);
        deliver(routeV4);
        compare(model.routeStatus, "unknown");
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver(routeWifi);
        compare(model.downloadSensorId, "network/wlp11s0/download");
    }

    function test_aggregateDetailsDescribeDefaultRoute() {
        var model = make({ source: "all", active: true, detailsDemand: true });
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver(routeV4);
        compare(model.detailsInterface, "eno1");
        compare(model.detailsDescribeRoute, true);
        compare(model.downloadSensorId, "network/all/download");
    }

    function test_fixedInterfaceNeverSwitchesOrLooksUpRoutes() {
        var model = make({ source: "interface:wlp11s0", active: true, detailsDemand: true });
        wait(20);
        compare(routeRequests(), 0);
        compare(model.detailsInterface, "wlp11s0");
        compare(model.downloadSensorId, "network/wlp11s0/download");
        compare(model.scopeText, "Wi-Fi (wlp11s0)");
    }

    function test_legacyCustomIdsKeepWorking() {
        var model = make({ source: "all", active: true,
            customDownloadSensorId: "network/wlan0/download", customUploadSensorId: "network/wlan0/upload" });
        compare(model.mode, "custom");
        compare(model.downloadSensorId, "network/wlan0/download");
        compare(model.uploadSensorId, "network/wlan0/upload");
        compare(model.scopeText, "Custom sensors");
    }

    function test_pageDetailsFollowInterfaceAndIgnoreStaleResults() {
        var fixture = createTemporaryObject(pageFixtureFactory, testCase);
        verify(fixture !== null);
        tryVerify(function() { return testCase.pending.length === 1; });
        compare(pending[0].command, "ip -o addr show dev eno1 scope global");
        deliver("2: eno1    inet 192.168.0.166/24 brd 192.168.0.255 scope global eno1\n");
        compare(pending[0].command, "cat /sys/class/net/eno1/address");
        deliver("4a:7c:e8:05:0e:10\n");
        compare(fixture.page.localIp, "192.168.0.166");
        compare(fixture.page.physicalAddress, "4a:7c:e8:05:0e:10");

        // A periodic refresh is in flight when the interface changes: metadata
        // clears at once and the old completion cannot repopulate it.
        fixture.page.refreshDetails();
        compare(pending.length, 1);
        fixture.networkModel.source = "interface:wlp11s0";
        compare(fixture.page.localIp, "");
        compare(fixture.page.physicalAddress, "");
        var stale = pending.shift();
        stale.callback({ stdout: "inet 192.168.0.166/24", stderr: "", exitCode: 0 });
        compare(fixture.page.localIp, "");
        tryVerify(function() {
            return testCase.pending.some(function(request) { return request.command.indexOf("dev wlp11s0") > 0; });
        });
    }

    function test_pageDetailsStartAsSoonAsTheRouteResolves() {
        // Aggregate source: the page opens before the default route is known.
        var fixture = createTemporaryObject(pageFixtureFactory, testCase, { initialSource: "all" });
        verify(fixture !== null);
        tryVerify(function() { return testCase.pending.length === 1; });
        verify(pending[0].command.indexOf("ip route get") === 0);
        deliver(routeV4);
        // Must not wait for the periodic refresh.
        tryVerify(function() { return testCase.pending.length === 1; }, 1000);
        compare(pending[0].command, "ip -o addr show dev eno1 scope global");
        deliver("2: eno1    inet 192.168.0.166/24 scope global eno1\n");
        deliver("4a:7c:e8:05:0e:10\n");
        compare(fixture.page.localIp, "192.168.0.166");
        compare(fixture.page.physicalAddress, "4a:7c:e8:05:0e:10");
    }

    function test_pageDetailsHandleMissingCommandsAndIpv6Only() {
        var fixture = createTemporaryObject(pageFixtureFactory, testCase);
        tryVerify(function() { return testCase.pending.length === 1; });
        deliver("3: eno1    inet6 2001:db8::5/64 scope global dynamic\n");
        deliver("", 1);
        compare(fixture.page.localIp, "2001:db8::5");
        compare(fixture.page.physicalAddress, "");
        fixture.networkDetailsVisible = false;
        wait(20);
        var count = requests.length;
        fixture.page.refreshDetails();
        compare(requests.length, count);
    }
}
