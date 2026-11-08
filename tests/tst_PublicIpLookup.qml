import QtQuick
import QtTest
import "../contents/ui" as Local

TestCase {
    id: testCase
    name: "PublicIpLookup"
    when: windowShown
    property var created: []
    property real time: 1000

    // Mirrors the XMLHttpRequest surface the lookup uses; abort() reports
    // DONE with status 0, as Qt does, so late callbacks can be exercised.
    function fakeRequest() {
        var request = {
            readyState: 0, status: 0, responseText: "", url: "", sent: false, aborted: false,
            onreadystatechange: null,
            open: function(method, url) { this.url = method + " " + url; this.readyState = 1; },
            send: function() { this.sent = true; },
            abort: function() {
                this.aborted = true;
                this.readyState = 4;
                this.status = 0;
                if (this.onreadystatechange) {
                    this.onreadystatechange();
                }
            }
        };
        testCase.created.push(request);
        return request;
    }
    function respond(request, status, body) {
        request.status = status;
        request.responseText = body;
        request.readyState = 4;
        request.onreadystatechange();
    }

    Component {
        id: lookupFactory
        Local.PublicIpLookup {
            requestFactory: function() { return testCase.fakeRequest(); }
            clock: function() { return testCase.time; }
        }
    }

    function init() {
        created = [];
        time = 1000;
        failOnWarning(/TypeError|ReferenceError|is not a function|is not defined|Cannot read property|Binding loop/);
    }
    function make(properties) {
        var lookup = createTemporaryObject(lookupFactory, testCase, properties || {});
        verify(lookup !== null);
        return lookup;
    }
    function succeed(lookup, address) {
        respond(created[created.length - 1], 200, '{"ip":"' + address + '"}');
    }

    function test_disabledMakesNoRequests() {
        var lookup = make({ demand: true });
        compare(lookup.refresh(), false);
        lookup.demand = false;
        lookup.demand = true;
        lookup.routeKey = "eno1";
        compare(created.length, 0);
        compare(lookup.status, "disabled");
    }

    function test_eachActivationRequestsOnce() {
        var lookup = make({ lookupEnabled: true });
        compare(created.length, 0);
        lookup.demand = true;
        compare(created.length, 1);
        compare(created[0].url, "GET https://api64.ipify.org?format=json");
        verify(created[0].sent);
        compare(lookup.status, "loading");
        succeed(lookup, "203.0.113.7");
        compare(lookup.status, "ok");
        compare(lookup.address, "203.0.113.7");
        compare(lookup.checkedAt, 1000);
        wait(50);
        compare(created.length, 1);
    }

    function test_enablingWhileVisibleRequestsOnce() {
        var lookup = make({ demand: true });
        lookup.lookupEnabled = true;
        compare(created.length, 1);
    }

    function test_concurrentTriggersCoalesce() {
        var lookup = make({ lookupEnabled: true, demand: true });
        compare(lookup.refresh(), false);
        compare(lookup.refresh(), false);
        compare(created.length, 1);
    }

    function test_reopeningShowsPreviousWhileRefreshing() {
        var lookup = make({ lookupEnabled: true, demand: true });
        succeed(lookup, "203.0.113.7");
        lookup.demand = false;
        time = 5000;
        lookup.demand = true;
        compare(created.length, 2);
        compare(lookup.status, "loading");
        compare(lookup.address, "203.0.113.7");
        succeed(lookup, "198.51.100.4");
        compare(lookup.address, "198.51.100.4");
        compare(lookup.checkedAt, 5000);
    }

    function test_failureKeepsLastResult_data() {
        return [
            { tag: "http", status: 500, body: "{}", error: "http" },
            { tag: "offline or tls", status: 0, body: "", error: "network" },
            { tag: "malformed", status: 200, body: "{nope", error: "format" },
            { tag: "invalid address", status: 200, body: '{"ip":"999.1.1.1"}', error: "format" },
            { tag: "oversized", status: 200, body: new Array(400).join(" "), error: "payload" }
        ];
    }
    function test_failureKeepsLastResult(data) {
        var lookup = make({ lookupEnabled: true, demand: true });
        succeed(lookup, "203.0.113.7");
        verify(lookup.refresh());
        respond(created[1], data.status, data.body);
        compare(lookup.status, "failed");
        compare(lookup.error, data.error);
        compare(lookup.address, "203.0.113.7");
        compare(lookup.checkedAt, 1000);
        // Manual retry works, and no retry loop starts by itself.
        wait(50);
        compare(created.length, 2);
        verify(lookup.refresh());
        succeed(lookup, "198.51.100.4");
        compare(lookup.status, "ok");
        compare(lookup.error, "");
    }

    function test_timeoutAbortsWithoutRetrying() {
        var lookup = make({ lookupEnabled: true, timeout: 30, demand: true });
        tryCompare(lookup, "status", "failed", 1000);
        compare(lookup.error, "timeout");
        verify(created[0].aborted);
        wait(80);
        compare(created.length, 1);
    }

    function test_closingAbortsAndIgnoresLateResponse() {
        var lookup = make({ lookupEnabled: true, demand: true });
        var first = created[0];
        lookup.demand = false;
        verify(first.aborted);
        compare(lookup.status, "idle");
        respond(first, 200, '{"ip":"203.0.113.7"}');
        compare(lookup.address, "");
    }

    function test_supersededResponseCannotOverwriteNewer() {
        var lookup = make({ lookupEnabled: true, demand: true });
        var first = created[0];
        lookup.demand = false;
        lookup.demand = true;
        var second = created[1];
        respond(second, 200, '{"ip":"198.51.100.4"}');
        first.status = 200;
        first.responseText = '{"ip":"203.0.113.7"}';
        first.onreadystatechange();
        compare(lookup.address, "198.51.100.4");
    }

    function test_disablingAbortsAndClears() {
        var lookup = make({ lookupEnabled: true, demand: true });
        succeed(lookup, "203.0.113.7");
        verify(lookup.refresh());
        lookup.lookupEnabled = false;
        verify(created[1].aborted);
        compare(lookup.address, "");
        compare(lookup.checkedAt, null);
        compare(lookup.status, "disabled");
    }

    function test_routeChangeInvalidatesAndCancelsOlderRequest() {
        var lookup = make({ lookupEnabled: true, routeKey: "eno1", demand: true });
        succeed(lookup, "203.0.113.7");
        compare(lookup.resultRouteKey, "eno1");
        lookup.routeKey = "wlp11s0";
        compare(lookup.status, "invalidated");
        compare(created.length, 1);
        verify(lookup.refresh());
        lookup.routeKey = "tun0";
        verify(created[1].aborted);
        compare(lookup.status, "invalidated");
        compare(created.length, 2);
    }

    function test_requestStartedBeforeRouteKnownAdoptsIt() {
        var lookup = make({ lookupEnabled: true, demand: true });
        lookup.routeKey = "eno1";
        verify(!created[0].aborted);
        succeed(lookup, "203.0.113.7");
        compare(lookup.resultRouteKey, "eno1");
        compare(lookup.status, "ok");
    }

    function test_requestCreationFailureIsReported() {
        var lookup = make({ lookupEnabled: true });
        lookup.requestFactory = function() { throw new Error("no network access"); };
        compare(lookup.refresh(), false);
        compare(lookup.status, "failed");
        compare(lookup.error, "network");
    }

    function test_destroyedLookupAbortsAndIgnoresLateReply() {
        var lookup = lookupFactory.createObject(testCase, {
            lookupEnabled: true,
            requestFactory: function() { return testCase.fakeRequest(); }
        });
        lookup.demand = true;
        var request = created[0];
        var handler = request.onreadystatechange;
        lookup.destroy();
        wait(20);
        verify(request.aborted);
        request.status = 200;
        request.responseText = '{"ip":"203.0.113.7"}';
        request.readyState = 4;
        handler();
    }
}
