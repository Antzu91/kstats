import QtQuick
import QtTest
import "../contents/ui/PublicIp.js" as PublicIp

TestCase {
    name: "PublicIp"

    function test_addresses_data() {
        return [
            { tag: "ipv4", value: "203.0.113.7", valid: true },
            { tag: "ipv4 zeros", value: "0.0.0.0", valid: true },
            { tag: "ipv4 max", value: "255.255.255.255", valid: true },
            { tag: "ipv4 octet too big", value: "256.1.1.1", valid: false },
            { tag: "ipv4 leading zero", value: "01.2.3.4", valid: false },
            { tag: "ipv4 short", value: "1.2.3", valid: false },
            { tag: "ipv6 full", value: "2001:0db8:0000:0000:0000:ff00:0042:8329", valid: true },
            { tag: "ipv6 compressed", value: "2001:db8::ff00:42:8329", valid: true },
            { tag: "ipv6 loopback", value: "::1", valid: true },
            { tag: "ipv6 mapped ipv4", value: "::ffff:192.0.2.128", valid: true },
            { tag: "ipv6 two gaps", value: "2001::db8::1", valid: false },
            { tag: "ipv6 too many groups", value: "1:2:3:4:5:6:7:8:9", valid: false },
            { tag: "ipv6 bad group", value: "2001:db8::g", valid: false },
            { tag: "ipv6 short", value: "1:2:3", valid: false },
            { tag: "markup", value: "<b>1.2.3.4</b>", valid: false },
            { tag: "empty", value: "", valid: false }
        ];
    }
    function test_addresses(data) {
        compare(PublicIp.isAddress(data.value), data.valid);
    }

    function test_acceptsOnlyValidSuccessfulResponses() {
        compare(PublicIp.parseResponse(200, '{"ip":"203.0.113.7"}'), { address: "203.0.113.7" });
        compare(PublicIp.parseResponse(200, '{"ip":" 2001:db8::1 "}'), { address: "2001:db8::1" });
    }

    function test_rejectsFailures_data() {
        return [
            { tag: "http error", status: 503, body: '{"ip":"203.0.113.7"}', error: "http" },
            { tag: "network", status: 0, body: "", error: "http" },
            { tag: "empty", status: 200, body: "", error: "payload" },
            { tag: "oversized", status: 200, body: '{"ip":"203.0.113.7","pad":"' + new Array(300).join("x") + '"}', error: "payload" },
            { tag: "malformed json", status: 200, body: "{ip:", error: "format" },
            { tag: "plain text", status: 200, body: "203.0.113.7", error: "format" },
            { tag: "missing field", status: 200, body: '{"address":"203.0.113.7"}', error: "format" },
            { tag: "wrong type", status: 200, body: '{"ip":12345}', error: "format" },
            { tag: "invalid address", status: 200, body: '{"ip":"not-an-ip"}', error: "format" },
            { tag: "array", status: 200, body: '["203.0.113.7"]', error: "format" },
            { tag: "null", status: 200, body: "null", error: "format" }
        ];
    }
    function test_rejectsFailures(data) {
        compare(PublicIp.parseResponse(data.status, data.body), { error: data.error });
    }

    function test_endpointIsFixedHttps() {
        compare(PublicIp.endpoint, "https://api64.ipify.org?format=json");
    }
}
