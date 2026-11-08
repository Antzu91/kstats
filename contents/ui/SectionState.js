.pragma library

// Remembered expansion of collapsible popup sections, stored as
// "page.section=1,page.section=0". Sections the user never toggled follow
// the density: expanded when comfortable, collapsed when compact.

var keyPattern = /^[a-z]+\.[a-z]+$/;

function parse(text) {
    var states = {};
    String(text === undefined || text === null ? "" : text).split(",").forEach(function(entry) {
        var parts = entry.trim().split("=");
        if (parts.length === 2 && keyPattern.test(parts[0]) && (parts[1] === "0" || parts[1] === "1")) {
            states[parts[0]] = parts[1] === "1";
        }
    });
    return states;
}

function serialize(states) {
    return Object.keys(states).filter(function(key) {
        return keyPattern.test(key);
    }).sort().map(function(key) {
        return key + "=" + (states[key] ? "1" : "0");
    }).join(",");
}

function isExpanded(states, key, compact) {
    return key in states ? states[key] : !compact;
}

function withState(text, key, expanded) {
    if (!keyPattern.test(key)) {
        return serialize(parse(text));
    }
    var states = parse(text);
    states[key] = expanded === true;
    return serialize(states);
}
