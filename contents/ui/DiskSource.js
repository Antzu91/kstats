.pragma library

// Pure helpers for choosing which disk sensors the widget measures.
// Sources: "all" (KSysGuard aggregate), "volume:<id>" (one filesystem known to
// KSystemStats, so capacity and activity share its identity) and "custom"
// (the configured capacity/read/write sensor IDs).

var defaults = {
    usage: "disk/all/usedPercent",
    read: "disk/all/read",
    write: "disk/all/write"
};
var volumePrefix = "volume:";

function text(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

// KSystemStats keys volumes by filesystem UUID; IDs reach sensor paths only.
function validVolumeId(id) {
    return typeof id === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(id) && id !== "all";
}

// Earlier versions stored only sensor IDs; any non-default one (including a
// cleared field) was deliberate and survives as an explicit Custom source.
function legacyCustom(usageSensorId, readSensorId, writeSensorId) {
    return text(usageSensorId) !== defaults.usage || text(readSensorId) !== defaults.read
        || text(writeSensorId) !== defaults.write;
}

function effectiveSource(source, usageSensorId, readSensorId, writeSensorId) {
    var value = text(source);
    if (value === "custom") {
        return value;
    }
    if (value.indexOf(volumePrefix) === 0 && validVolumeId(value.slice(volumePrefix.length))) {
        return value;
    }
    return legacyCustom(usageSensorId, readSensorId, writeSensorId) ? "custom" : "all";
}

function mode(effective) {
    return effective.indexOf(volumePrefix) === 0 ? "volume" : effective;
}

function volumeFromSource(effective) {
    return effective.indexOf(volumePrefix) === 0 ? effective.slice(volumePrefix.length) : "";
}

function volumeSource(id) {
    return validVolumeId(id) ? volumePrefix + id : "all";
}

// used/total are only provided where they share the capacity sensor's definition.
function sensorIds(effective, usageSensorId, readSensorId, writeSensorId) {
    var sourceMode = mode(effective);
    if (sourceMode === "custom") {
        return { usage: text(usageSensorId), read: text(readSensorId), write: text(writeSensorId), used: "", total: "" };
    }
    var prefix = sourceMode === "volume" ? "disk/" + volumeFromSource(effective) : "disk/all";
    return { usage: prefix + "/usedPercent", read: prefix + "/read", write: prefix + "/write",
        used: prefix + "/used", total: prefix + "/total" };
}

// Volumes have a capacity sensor; physical block devices only report activity.
function volumeFromSensorId(sensorId) {
    var match = text(sensorId).match(/^disk\/([^\/]+)\/usedPercent$/);
    return match && validVolumeId(match[1]) ? match[1] : "";
}
