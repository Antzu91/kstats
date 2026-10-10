.pragma library

// All times are milliseconds. These helpers never read the clock or a provider.
var retentionDuration = 15 * 60 * 1000;
var maximumSamples = 1802; // 500 ms readings plus an edge sample / gap marker.
var maximumSeries = 64;
var windowDurations = [60000, 300000, 900000];

function validTime(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

function validValue(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

function normalizeStatus(status, value) {
    if (status === "available") {
        return validValue(value) ? status : "unavailable";
    }
    return ["loading", "unavailable", "stale", "disabled"].indexOf(status) >= 0
        ? status : "unavailable";
}

function sample(value, status, timestamp, sourceKey) {
    var state = normalizeStatus(status, value);
    return { timestamp: timestamp, value: state === "available" ? value : null,
        status: state, sourceKey: sourceKey };
}

function createState() {
    return { series: [], now: 0 };
}

function boundedOption(value, fallback, minimum) {
    return validValue(value) ? Math.max(minimum, Math.min(fallback, Math.floor(value))) : fallback;
}

function optionsOrDefault(options) {
    var settings = options || {};
    return {
        retention: boundedOption(settings.retentionDuration, retentionDuration, 1),
        maxSamples: boundedOption(settings.maxSamples, maximumSamples, 2),
        maxSeries: boundedOption(settings.maxSeries, maximumSeries, 1),
        interval: validValue(settings.sampleInterval) && settings.sampleInterval > 0
            ? settings.sampleInterval : 1000
    };
}

function trimSamples(samples, cutoff, limit) {
    var first = 0;
    while (first < samples.length && samples[first].timestamp < cutoff) {
        first++;
    }
    if (first === samples.length) {
        return [];
    }
    // Keep one predecessor for clipping a continuous line at the window edge.
    var offset = Math.max(0, first - 1, samples.length - limit);
    return offset === 0 ? samples : samples.slice(offset);
}

function prune(state, timestamp, options) {
    if (!validTime(timestamp)) {
        return state;
    }
    if (timestamp < state.now) {
        // A wall-clock rollback invalidates the epoch of every retained series,
        // including inactive sources that will not be sampled again this tick.
        return { series: [], now: timestamp };
    }
    var settings = optionsOrDefault(options);
    var retained = [];
    for (var i = 0; i < state.series.length; i++) {
        var entry = state.series[i];
        var samples = trimSamples(entry.samples, timestamp - settings.retention, settings.maxSamples);
        if (samples.length > 0) {
            retained.push({ metricId: entry.metricId, sourceKey: entry.sourceKey,
                samples: samples, interval: entry.interval, active: entry.active });
        }
    }
    // Entries are ordered by last append; evict the least recently sampled first.
    return { series: retained.slice(-settings.maxSeries), now: timestamp };
}

function append(state, metricId, sourceKey, value, status, timestamp, options) {
    if (!validTime(timestamp) || typeof metricId !== "string" || metricId.length === 0
            || typeof sourceKey !== "string") {
        return state;
    }
    var settings = optionsOrDefault(options);
    var retained = prune(state, timestamp, options).series;
    var next = [];
    var previous = null;
    for (var i = 0; i < retained.length; i++) {
        var entry = retained[i];
        if (entry.metricId === metricId && entry.sourceKey === sourceKey) {
            previous = entry;
        } else {
            next.push({ metricId: entry.metricId, sourceKey: entry.sourceKey,
                samples: entry.samples, interval: entry.interval,
                active: entry.metricId === metricId ? false : entry.active });
        }
    }

    var samples = previous ? previous.samples.slice(0) : [];
    var last = samples.length > 0 ? samples[samples.length - 1] : null;
    if (last && timestamp === last.timestamp) {
        // One observation per timestamp; repeated notifications must not grow memory.
        samples.pop();
    } else if (last && (!previous.active
            || timestamp - last.timestamp > Math.max(previous.interval, settings.interval) * 2.5)) {
        // No invented readings during suspension, disabled demand, or source switches.
        samples.push(sample(null, "stale", last.timestamp + Math.min(
            previous.interval, settings.interval, (timestamp - last.timestamp) / 2), sourceKey));
    }
    samples.push(sample(value, status, timestamp, sourceKey));
    samples = trimSamples(samples, timestamp - settings.retention, settings.maxSamples);
    next.push({ metricId: metricId, sourceKey: sourceKey, samples: samples,
        interval: settings.interval, active: true });
    return { series: next.slice(-settings.maxSeries), now: timestamp };
}

function samplesFor(state, metricId, sourceKey) {
    for (var i = 0; i < state.series.length; i++) {
        var entry = state.series[i];
        if (entry.metricId === metricId && entry.sourceKey === sourceKey) {
            return entry.samples;
        }
    }
    return [];
}

function durationOrDefault(duration) {
    return validValue(duration) && duration > 0 ? Math.min(duration, retentionDuration) : 60000;
}

function xPosition(timestamp, duration, now) {
    return (timestamp - (now - durationOrDefault(duration))) / durationOrDefault(duration);
}

function interpolate(left, right, timestamp) {
    return { timestamp: timestamp,
        value: left.value + (right.value - left.value) * (timestamp - left.timestamp)
            / (right.timestamp - left.timestamp),
        status: "available", sourceKey: left.sourceKey };
}

function clipSegment(segment, start, end) {
    var clipped = [];
    for (var i = 0; i < segment.length; i++) {
        var point = segment[i];
        if (i > 0 && segment[i - 1].timestamp < start && point.timestamp > start) {
            clipped.push(interpolate(segment[i - 1], point, start));
        }
        if (point.timestamp >= start && point.timestamp <= end) {
            clipped.push(point);
        }
        if (i > 0 && segment[i - 1].timestamp < end && point.timestamp > end) {
            clipped.push(interpolate(segment[i - 1], point, end));
        }
        if (point.timestamp > end) {
            break;
        }
    }
    return clipped;
}

// Each returned segment can be stroked and filled independently. A null/status
// gap, invalid point, time reversal, or source change always breaks both paths.
function segments(samples, duration, now) {
    if (!validTime(now)) {
        return [];
    }
    var result = [];
    var current = [];
    var start = now - durationOrDefault(duration);
    for (var i = 0; i <= samples.length; i++) {
        var point = i < samples.length ? samples[i] : null;
        var usable = point && validTime(point.timestamp) && point.status === "available"
            && validValue(point.value) && typeof point.sourceKey === "string";
        var last = current.length > 0 ? current[current.length - 1] : null;
        if (!usable || (last && (last.sourceKey !== point.sourceKey || last.timestamp >= point.timestamp))) {
            var clipped = clipSegment(current, start, now);
            if (clipped.length > 0) {
                result.push(clipped);
            }
            current = [];
        }
        if (usable) {
            current.push(point);
        }
    }
    return result;
}

// Returns actual observations (including missing states), never fabricated values.
function nearestSample(samples, timestamp, duration, now) {
    var nearest = null;
    var distance = Infinity;
    var start = now - durationOrDefault(duration);
    if (!validTime(now) || !validTime(timestamp) || timestamp < start || timestamp > now) {
        return null;
    }
    for (var i = 0; i < samples.length; i++) {
        var point = samples[i];
        if (point && validTime(point.timestamp) && point.timestamp >= start && point.timestamp <= now
                && Math.abs(point.timestamp - timestamp) < distance) {
            nearest = point;
            distance = Math.abs(point.timestamp - timestamp);
        }
    }
    return nearest;
}

// Retained span inside the selected window; trailing inactivity is not coverage.
function coverageDuration(samples, duration, now) {
    var first = null;
    var last = null;
    for (var i = 0; i < samples.length; ++i) {
        var point = samples[i];
        if (point.status === "available" && validValue(point.value) && validTime(point.timestamp)) {
            first = first === null ? point.timestamp : Math.min(first, point.timestamp);
            last = last === null ? point.timestamp : Math.max(last, point.timestamp);
        }
    }
    return first === null || !validTime(now) ? 0
        : Math.max(0, Math.min(now, last) - Math.max(now - durationOrDefault(duration), first));
}
