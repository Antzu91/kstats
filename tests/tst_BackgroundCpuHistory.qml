import QtQuick
import QtTest
import "../contents/ui" as Local
import "../contents/ui/History.js" as History

TestCase {
    id: testCase
    name: "BackgroundCpuHistory"
    when: windowShown
    property real time: 100000
    function i18nc(context, text) { return text; }

    // Match the persistent root's ownership/demand binding. The actual passive
    // CpuBreakdown is created and destroyed as the popup changes pages.
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property bool moduleEnabled: true
            property bool popupOpen: false
            property int selectedTab: 0
            property int windowDuration: 60000
            property var pending: []
            property int requests: 0
            property int counter: 0
            property int viewCreations: 0
            property alias cpuDetailHistory: collector
            readonly property var view: popup.item

            Local.CpuHistory {
                id: collector
                active: fixture.moduleEnabled || (fixture.popupOpen && fixture.selectedTab === 0)
                refreshInterval: 1000
                clock: function() { return testCase.time; }
                provider: function(callback) {
                    fixture.requests++;
                    fixture.pending.push(callback);
                }
            }
            Loader {
                id: popup
                active: fixture.popupOpen && fixture.selectedTab === 0
                sourceComponent: Component {
                    Local.CpuBreakdown {
                        width: 400
                        height: 180
                        detailHistory: fixture.cpuDetailHistory
                        windowDuration: fixture.windowDuration
                        now: testCase.time
                    }
                }
                onLoaded: fixture.viewCreations++
            }
            function deliver() {
                var callback = pending.shift();
                var i = counter++;
                callback({ exitCode: 0, stdout: (i * 10) + " 0 " + (i * 20)
                    + " " + (1000 + i * 70) + " 0 0 0 0", stderr: "" });
            }
        }
    }

    function init() { time = 100000; }
    function make(properties) {
        var fixture = createTemporaryObject(fixtureFactory, testCase, properties || {});
        verify(fixture !== null);
        return fixture;
    }
    function sample(fixture) {
        time += 1000;
        fixture.cpuDetailHistory.refresh();
        compare(fixture.pending.length, 1);
        fixture.deliver();
    }

    function test_collectsBeforeFirstPopupAndSurvivesViewDestruction() {
        var fixture = make();
        var owner = fixture.cpuDetailHistory;
        compare(fixture.view, null);
        compare(fixture.pending.length, 1);
        fixture.deliver(); // Initial counter baseline, before any view exists.
        sample(fixture);
        sample(fixture);
        compare(owner.status, "available");
        compare(owner.userPercent, 10);
        var beforeOpen = owner.userSamples;
        var requests = fixture.requests;

        fixture.popupOpen = true;
        verify(fixture.view !== null);
        compare(fixture.view.detailHistory, owner);
        compare(fixture.view.userPercent, 10);
        compare(fixture.requests, requests); // A view cannot start another collector.
        compare(owner.userSamples, beforeOpen);
        sample(fixture);

        fixture.selectedTab = 1;
        compare(fixture.view, null);
        sample(fixture);
        fixture.popupOpen = false;
        sample(fixture);
        compare(fixture.cpuDetailHistory, owner);
        compare(History.segments(owner.userSamples, 60000, time).length, 1);
        compare(owner.userSamples[owner.userSamples.length - 1].status, "available");

        fixture.selectedTab = 0;
        fixture.popupOpen = true;
        compare(fixture.viewCreations, 2);
        compare(fixture.view.detailHistory, owner);
        compare(fixture.view.systemPercent, 20);
        compare(fixture.view.idlePercent, 70);
    }

    function test_windowOnlyChangesViewAndRevealsEarlierBackgroundSamples() {
        var fixture = make();
        fixture.deliver();
        for (var i = 0; i < 70; ++i) {
            sample(fixture);
        }
        fixture.popupOpen = true;
        var samples = fixture.cpuDetailHistory.userSamples;
        var requests = fixture.requests;
        var minute = History.segments(samples, fixture.view.windowDuration, time)[0];
        fixture.windowDuration = 900000;
        var longer = History.segments(samples, fixture.view.windowDuration, time)[0];
        verify(longer[0].timestamp < minute[0].timestamp);
        compare(fixture.cpuDetailHistory.userSamples, samples);
        compare(fixture.requests, requests);
        compare(fixture.cpuDetailHistory.active, true);
    }

    function test_disabledModuleOnlyCollectsOnItsVisiblePage() {
        var fixture = make({ moduleEnabled: false });
        var owner = fixture.cpuDetailHistory;
        compare(owner.active, false);
        compare(fixture.pending.length, 0);
        fixture.popupOpen = true;
        compare(owner.active, true);
        fixture.deliver();
        sample(fixture);
        time += 100;
        fixture.selectedTab = 1;
        compare(owner.active, false);
        compare(owner.status, "stale");
        var paused = owner.userSamples;
        owner.refresh();
        compare(fixture.pending.length, 0);
        compare(owner.userSamples, paused);
        time += 100;
        fixture.selectedTab = 0;
        compare(owner.active, true);
        fixture.deliver();
        compare(owner.status, "loading");
        sample(fixture);
        compare(History.segments(owner.userSamples, 60000, time).length, 2);
    }
}
