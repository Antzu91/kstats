.pragma library

// Panel presentations per module. Stored values are sanitized: anything
// unknown falls back to the module's default, which reproduces the
// original panel appearance.

var percentModes = ["number", "graph", "numberGraph", "bar"];
var networkModes = ["numbers", "graph", "numbersGraph"];
var defaults = { cpu: "numberGraph", memory: "numberGraph", gpu: "numberGraph", disk: "bar", network: "numbers" };

function modesFor(moduleId) {
    return moduleId === "network" ? networkModes : percentModes;
}

function presentation(moduleId, stored) {
    var value = stored === undefined || stored === null ? "" : String(stored).trim();
    return modesFor(moduleId).indexOf(value) >= 0 ? value : (defaults[moduleId] || "numberGraph");
}

// Which parts a percentage module draws: a meter (graph or bar) and/or its value.
function parts(mode) {
    switch (mode) {
    case "number":
        return { meter: "none", value: true };
    case "graph":
        return { meter: "sparkline", value: false };
    case "bar":
        return { meter: "bar", value: true };
    default:
        return { meter: "sparkline", value: true };
    }
}

function networkParts(mode) {
    return { numbers: mode !== "graph", graph: mode === "graph" || mode === "numbersGraph" };
}

// Presets change only presentations and labels; visibility, order, fonts,
// sources and monochrome stay as configured. "current" is the original look.
var presets = {
    current: {
        presentation: { cpu: "numberGraph", memory: "numberGraph", gpu: "numberGraph", disk: "bar", network: "numbers" },
        labels: true
    },
    compact: {
        presentation: { cpu: "number", memory: "number", gpu: "number", disk: "number", network: "numbers" },
        labels: true
    },
    graphs: {
        presentation: { cpu: "graph", memory: "graph", gpu: "graph", disk: "graph", network: "graph" },
        labels: true
    }
};
var presetNames = ["current", "compact", "graphs"];
var moduleIds = ["cpu", "memory", "gpu", "disk", "network"];

// settings: { cpu: { presentation, label }, ... } -> matching preset name or "".
function matchingPreset(settings) {
    for (var p = 0; p < presetNames.length; ++p) {
        var preset = presets[presetNames[p]];
        var matches = moduleIds.every(function(id) {
            var module = settings[id] || {};
            return presentation(id, module.presentation) === preset.presentation[id] && (module.label !== false) === preset.labels;
        });
        if (matches) {
            return presetNames[p];
        }
    }
    return "";
}
