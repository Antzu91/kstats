// Null values mark gaps between valid readings.
function append(samples, value, available, now, interval, duration) {
    var previous = samples.length ? samples[samples.length - 1] : null;
    var next = previous && now < previous.time ? [] : samples.filter(function(sample) {
        return sample.time >= now - duration;
    });
    if (previous && now >= previous.time && now - previous.time > previous.interval * 1.5) {
        var gapAt = previous.time + previous.interval;
        if (gapAt >= now - duration) {
            next.push({ time: gapAt, value: null, interval: interval });
        }
    }
    var valid = available && value !== null && value !== undefined && value !== "" && isFinite(Number(value));
    var point = { time: now, value: valid ? Math.max(0, Math.min(100, Number(value))) : null, interval: interval };
    if (next.length && next[next.length - 1].time === now) {
        next[next.length - 1] = point;
    } else {
        next.push(point);
    }
    return next;
}

function segments(samples, now, duration) {
    var result = [];
    var segment = [];
    samples.forEach(function(sample) {
        if (sample.value === null || sample.time < now - duration || sample.time > now) {
            if (segment.length) {
                result.push(segment);
            }
            segment = [];
        } else {
            segment.push({ x: 1 - (now - sample.time) / duration, value: sample.value });
        }
    });
    if (segment.length) {
        result.push(segment);
    }
    return result;
}
