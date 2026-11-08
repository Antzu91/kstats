import QtQuick

import "PublicIp.js" as PublicIp

// Opt-in lookup of the address the internet sees for the current route.
// Requests only when demand starts (the Network page becomes visible) or on
// refresh(); never periodically and never while disabled. One request at a
// time; aborted, timed-out or superseded responses cannot overwrite state.
Item {
    id: lookup

    property bool lookupEnabled: false
    property bool demand: false
    // Default-route interface when known; a change invalidates older results.
    property string routeKey: ""
    property int timeout: 8000
    property string endpoint: PublicIp.endpoint
    // Replace in fixtures; must return an object with the XMLHttpRequest surface used here.
    property var requestFactory: function() { return new XMLHttpRequest(); }
    property var clock: function() { return Date.now(); }

    // The last accepted result stays available while refreshing or after failures.
    property string address: ""
    property var checkedAt: null
    property string resultRouteKey: ""
    // "", or why the latest attempt failed: timeout, network, http, payload, format.
    property string error: ""
    readonly property bool loading: requestPending
    readonly property bool invalidated: address.length > 0 && resultRouteKey.length > 0
        && routeKey.length > 0 && routeKey !== resultRouteKey
    readonly property string status: !lookupEnabled ? "disabled"
        : loading ? "loading"
        : error.length > 0 ? "failed"
        : invalidated ? "invalidated"
        : address.length > 0 ? "ok" : "idle"

    property bool requestPending: false
    property var _request: null
    property string _requestRouteKey: ""
    property int _generation: 0

    visible: false

    function refresh() {
        if (!lookupEnabled || requestPending) {
            return false;
        }
        var request;
        try {
            request = requestFactory();
        } catch (failure) {
            error = "network";
            return false;
        }
        var generation = ++_generation;
        _request = request;
        _requestRouteKey = routeKey;
        requestPending = true;
        error = "";
        request.onreadystatechange = function() {
            if (request.readyState === 4 && generation === lookup._generation) {
                lookup.finish(request.status, request.responseText);
            }
        };
        try {
            request.open("GET", endpoint);
            request.send();
        } catch (failure) {
            _generation++;
            _request = null;
            requestPending = false;
            error = "network";
            return false;
        }
        timeoutTimer.restart();
        return true;
    }

    function finish(status, body) {
        timeoutTimer.stop();
        _request = null;
        requestPending = false;
        var result = PublicIp.parseResponse(status, body);
        if (result.address === undefined) {
            // Status 0 covers offline, DNS and TLS failures in QML's XMLHttpRequest.
            error = status === 0 ? "network" : result.error;
            return;
        }
        address = result.address;
        checkedAt = clock();
        resultRouteKey = _requestRouteKey.length > 0 ? _requestRouteKey : routeKey;
        error = "";
    }

    function abort(reason) {
        if (!requestPending) {
            return;
        }
        var request = _request;
        _generation++;
        _request = null;
        requestPending = false;
        timeoutTimer.stop();
        try {
            request.abort();
        } catch (failure) {
            // Already finished; the generation guard ignores any late callback.
        }
        error = reason || "";
    }

    function clear() {
        abort("");
        address = "";
        checkedAt = null;
        resultRouteKey = "";
        error = "";
    }

    Component.onCompleted: {
        if (demand && lookupEnabled) {
            refresh();
        }
    }
    onDemandChanged: {
        if (demand) {
            refresh();
        } else {
            abort("");
        }
    }
    onLookupEnabledChanged: {
        if (!lookupEnabled) {
            clear();
        } else if (demand) {
            refresh();
        }
    }
    onRouteKeyChanged: {
        if (!requestPending || routeKey.length === 0) {
            return;
        }
        if (_requestRouteKey.length === 0) {
            // Started before the route was known; it uses the route now resolved.
            _requestRouteKey = routeKey;
        } else if (routeKey !== _requestRouteKey) {
            // Started on a route that no longer applies; refresh or reopen to retry.
            abort("");
        }
    }

    Timer {
        id: timeoutTimer
        interval: Math.max(1, lookup.timeout)
        onTriggered: lookup.abort("timeout")
    }
}
