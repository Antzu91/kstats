.pragma library

// Pure helpers for choosing which network sensors the widget measures.
// Sources: "all" (KSysGuard aggregate), "auto" (default-route interface),
// "interface:<name>" (fixed interface) and "custom" (configured sensor IDs).

var defaultDownloadSensorId = "network/all/download";
var defaultUploadSensorId = "network/all/upload";
var interfacePrefix = "interface:";
// Resolves through a local FIB lookup only; no packets are sent.
var routeCommand = "ip route get 1.1.1.1 2>/dev/null || ip -6 route get 2606:4700:4700::1111";

function text(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

// Interface names reach sensor IDs and shell commands, so accept only the
// conservative character set real interfaces use (Linux allows 15 bytes).
function validInterfaceName(name) {
    return typeof name === "string" && /^[A-Za-z0-9_.-]{1,15}$/.test(name)
        && name !== "." && name !== ".." && name !== "all";
}

// Earlier versions stored only sensor IDs. Any non-default ID (including a
// cleared one) was a deliberate choice, so it survives as an explicit Custom source.
function legacyCustom(downloadSensorId, uploadSensorId) {
    return text(downloadSensorId) !== defaultDownloadSensorId
        || text(uploadSensorId) !== defaultUploadSensorId;
}

function effectiveSource(source, downloadSensorId, uploadSensorId) {
    var value = text(source);
    if (value === "auto" || value === "custom") {
        return value;
    }
    if (value.indexOf(interfacePrefix) === 0 && validInterfaceName(value.slice(interfacePrefix.length))) {
        return value;
    }
    // "all", empty and unknown values: the aggregate unless legacy IDs say otherwise.
    return legacyCustom(downloadSensorId, uploadSensorId) ? "custom" : "all";
}

function mode(effective) {
    return effective.indexOf(interfacePrefix) === 0 ? "interface" : effective;
}

function interfaceFromSource(effective) {
    return effective.indexOf(interfacePrefix) === 0 ? effective.slice(interfacePrefix.length) : "";
}

function interfaceSource(name) {
    return validInterfaceName(name) ? interfacePrefix + name : "all";
}

function sensorIds(sourceMode, interfaceName, downloadSensorId, uploadSensorId) {
    if (sourceMode === "custom") {
        return { download: text(downloadSensorId), upload: text(uploadSensorId) };
    }
    if (sourceMode === "auto" || sourceMode === "interface") {
        // An unresolved or invalid interface yields no sensor, never a fallback.
        return validInterfaceName(interfaceName)
            ? { download: "network/" + interfaceName + "/download", upload: "network/" + interfaceName + "/upload" }
            : { download: "", upload: "" };
    }
    return { download: defaultDownloadSensorId, upload: defaultUploadSensorId };
}

// Parses `ip route get` output ("... dev eno1 src ..."); "" when unresolved.
function routeInterface(output) {
    var match = text(output).match(/\bdev\s+(\S+)/);
    return match && validInterfaceName(match[1]) ? match[1] : "";
}

// Interface names from per-interface download sensors, excluding the aggregate.
function interfaceFromSensorId(sensorId) {
    var match = text(sensorId).match(/^network\/([^\/]+)\/download$/);
    return match && validInterfaceName(match[1]) ? match[1] : "";
}

function interfaceKind(name) {
    var value = text(name);
    if (/^wl/.test(value)) {
        return "wifi";
    }
    if (/^(en|eth)/.test(value)) {
        return "ethernet";
    }
    if (/^(tun|tap|wg|ppp|vpn|ipsec|tailscale|zt|nordlynx|proton)/.test(value)) {
        return "vpn";
    }
    if (/^(lo)$/.test(value)) {
        return "loopback";
    }
    if (/^(br|virbr|docker|veth|vnet|podman|cni|flannel|lxc|lxd)/.test(value)) {
        return "virtual";
    }
    return "other";
}
