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
