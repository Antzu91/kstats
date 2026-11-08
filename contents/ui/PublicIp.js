.pragma library

// Response handling for the opt-in public IP lookup. Pure, so fixtures can
// cover malformed, oversized and hostile payloads without a network.

var endpoint = "https://api64.ipify.org?format=json";
var maximumPayload = 256;

function isIpv4(value) {
    var octet = "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)";
    return new RegExp("^" + octet + "(\\." + octet + "){3}$").test(value);
}

function isIpv6(value) {
    if (typeof value !== "string" || value.length < 2 || value.length > 45 || !/^[0-9A-Fa-f:.]+$/.test(value)) {
        return false;
    }
    var halves = value.split("::");
    if (halves.length > 2) {
        return false;
    }
    var groups = [];
    var embeddedIpv4 = false;
    for (var h = 0; h < halves.length; ++h) {
        if (halves[h].length === 0) {
            continue;
        }
        var parts = halves[h].split(":");
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var last = h === halves.length - 1 && i === parts.length - 1;
            if (last && part.indexOf(".") >= 0) {
                if (!isIpv4(part)) {
                    return false;
                }
                embeddedIpv4 = true;
                continue;
            }
            if (!/^[0-9A-Fa-f]{1,4}$/.test(part)) {
                return false;
            }
            groups.push(part);
        }
    }
    var width = groups.length + (embeddedIpv4 ? 2 : 0);
    return halves.length === 2 ? width < 8 : width === 8;
}

function isAddress(value) {
    return typeof value === "string" && (isIpv4(value) || isIpv6(value));
}

// Returns { address } on success or { error } with "http", "payload" or "format".
function parseResponse(status, body) {
    if (status !== 200) {
        return { error: "http" };
    }
    var text = typeof body === "string" ? body : "";
    if (text.length === 0 || text.length > maximumPayload) {
        return { error: "payload" };
    }
    var parsed;
    try {
        parsed = JSON.parse(text);
    } catch (error) {
        return { error: "format" };
    }
    var address = parsed && typeof parsed === "object" && typeof parsed.ip === "string" ? parsed.ip.trim() : "";
    return isAddress(address) ? { address: address } : { error: "format" };
}
