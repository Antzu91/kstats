.pragma library

// CPU temperature and fan sensor selection. Settings store "auto" (default),
// "off", or a sensor ID. Only Automatic may switch sensors on its own; a
// chosen sensor stays selected and reads N/A while it is missing.

var automatic = "auto";
var disabled = "off";

function text(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

// Template IDs (regex groups or wildcards) describe several sensors, not one.
function isTemplateSensorId(sensorId) {
    return /[\\\[\]()*+]/.test(text(sensorId));
}

function validSensorId(sensorId) {
    var id = text(sensorId);
    return id.length > 0 && id.length <= 256 && id.indexOf("/") > 0 && !/\s/.test(id) && !isTemplateSensorId(id);
}

function selection(setting) {
    var value = text(setting);
    if (value === disabled) {
        return { mode: "off", sensorId: "" };
    }
    if (value.length > 0 && value !== automatic && validSensorId(value)) {
        return { mode: "manual", sensorId: value };
    }
    return { mode: "auto", sensorId: "" };
}

function hasAny(haystack, needles) {
    for (var i = 0; i < needles.length; i++) {
        if (haystack.indexOf(needles[i]) >= 0) {
            return true;
        }
    }
    return false;
}

// Scores how likely a sensor is the CPU's temperature or fan; 0 = not a candidate.
function hardwareScore(sensorId, pathNames, metric) {
    if (!validSensorId(sensorId)) {
        return 0;
    }
    var searchText = (text(sensorId) + " " + (pathNames || []).join(" ")).toLowerCase();
    if (hasAny(searchText, ["gpu", "graphics", "amdgpu", "radeon", "nvidia", "nouveau", "vram", "nvme", "ssd", "hdd", "disk", "drive", "battery"])) {
        return 0;
    }
    if (metric === "temperature") {
        if (hasAny(searchText, ["fan", "rpm", "voltage", "power", "clock", "frequency"])) {
            return 0;
        }
        var temperatureScore = 0;
        if (hasAny(searchText, ["temperature", " temp", "/temp", "temp1", "tctl", "tdie", "package", "package_id", "package id", "cputin", "coretemp", "k10temp", "zenpower", "cpu_thermal", "cpu thermal"])) {
            temperatureScore += 20;
        }
        if (hasAny(searchText, ["cpu", "processor"])) {
            temperatureScore += 25;
        }
        if (hasAny(searchText, ["package", "package_id", "package id", "tctl", "tdie"])) {
            temperatureScore += 40;
        }
        if (hasAny(searchText, ["coretemp", "k10temp", "zenpower"])) {
            temperatureScore += 20;
        }
        return temperatureScore;
    }
    if (metric === "fan") {
        if (!hasAny(searchText, ["fan", "rpm"])) {
            return 0;
        }
        var fanScore = 10;
        if (hasAny(searchText, ["cpu", "processor", "cpu_fan", "cpu fan"])) {
            fanScore += 50;
        }
        if (hasAny(searchText, ["fan1", "fan 1"])) {
            fanScore += 8;
        }
        if (hasAny(searchText, ["pump", "aio"])) {
            fanScore -= 20;
        }
        return fanScore;
    }
    return 0;
}

// entries: [{ sensorId, pathNames }]. Ties keep the first entry, as before.
function bestSensor(entries, metric) {
    var best = "";
    var bestScore = 0;
    for (var i = 0; i < entries.length; i++) {
        var score = hardwareScore(entries[i].sensorId, entries[i].pathNames, metric);
        if (score > bestScore) {
            bestScore = score;
            best = entries[i].sensorId;
        }
    }
    return best;
}

// Automatic keeps its current sensor while it still exists, so readings do not
// hop between equally scored sensors; it recovers when that sensor vanishes.
function automaticSensor(currentSensorId, entries, metric) {
    if (currentSensorId.length > 0 && entries.some(function(entry) { return entry.sensorId === currentSensorId; })) {
        return currentSensorId;
    }
    return bestSensor(entries, metric);
}

function resolvedSensorId(choice, discoveredSensorId) {
    return choice.mode === "manual" ? choice.sensorId : choice.mode === "auto" ? discoveredSensorId : "";
}
