.pragma library

// /proc/stat's guest counters are already included in user/nice. Keep the first
// eight counters separately so a rollback cannot be hidden by another increase.
function parse(text) {
    if (typeof text !== "string" || text.trim().length === 0) {
        return null;
    }
    var fields = text.trim().split(/\s+/);
    if (fields.length < 7 || fields.length > 10) {
        return null;
    }
    var counters = [];
    var total = 0;
    for (var i = 0; i < fields.length; i++) {
        var value = Number(fields[i]);
        if (!/^\d+$/.test(fields[i]) || !Number.isSafeInteger(value) || value < 0) {
            return null;
        }
        if (i < 8) {
            counters.push(value);
            total += value;
        }
    }
    if (!Number.isSafeInteger(total)) {
        return null;
    }
    if (counters.length === 7) {
        counters.push(0);
    }
    return counters;
}

function intervalOrDefault(interval) {
    return typeof interval === "number" && isFinite(interval) && interval > 0 ? interval : 1500;
}

function discontinuity(before, after, previousInterval, interval) {
    return after < before || after - before > Math.max(intervalOrDefault(previousInterval), intervalOrDefault(interval)) * 2.5;
}

function empty(status, baseline, errorCode) {
    return { status: status, baseline: baseline, errorCode: errorCode || "",
        user: null, system: null, idle: null };
}

// Baseline and clock are supplied by the owner. Invalid input discards the
// baseline; a reset/suspend starts with a missing observation before new deltas.
function observe(previous, text, timestamp, interval) {
    var counters = parse(text);
    if (!counters || typeof timestamp !== "number" || !isFinite(timestamp) || timestamp < 0) {
        return empty("unavailable", null, "format");
    }
    var baseline = { counters: counters, timestamp: timestamp, interval: intervalOrDefault(interval) };
    if (!previous || discontinuity(previous.timestamp, timestamp, previous.interval, interval)) {
        return empty("loading", baseline);
    }
    var deltas = [];
    var total = 0;
    for (var i = 0; i < counters.length; i++) {
        var delta = counters[i] - previous.counters[i];
        if (delta < 0) {
            return empty("unavailable", baseline);
        }
        deltas.push(delta);
        total += delta;
    }
    if (total === 0 || timestamp === previous.timestamp) {
        return empty("unavailable", baseline);
    }
    return { status: "available", baseline: baseline, errorCode: "",
        user: (deltas[0] + deltas[1]) / total * 100,
        system: (deltas[2] + deltas[5] + deltas[6]) / total * 100,
        idle: (deltas[3] + deltas[4]) / total * 100 };
}
