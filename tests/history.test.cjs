const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

function load(name) {
    const context = {};
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../contents/ui/", name), "utf8"), context);
    return context;
}

const history = load("TimedHistory.js");
const order = load("ModuleOrder.js");
const plain = value => JSON.parse(JSON.stringify(value));

test("constant readings advance across a complete 60-second window at each cadence", () => {
    for (const interval of [500, 1000, 2500, 10000]) {
        let samples = [];
        for (let now = 0; now <= 120000; now += interval) {
            samples = history.append(samples, 42, true, now, interval, 60000);
        }
        assert.equal(samples.length, 60000 / interval + 1);
        assert.ok(samples.every(sample => sample.value === 42));
        const segments = history.segments(samples, 120000, 60000);
        assert.equal(segments.length, 1);
        assert.equal(segments[0][0].x, 0);
        assert.equal(segments[0].at(-1).x, 1);
    }
});

test("interval changes retain timestamps and preserve elapsed-time spacing", () => {
    let samples = [];
    for (let now = 0; now <= 20000; now += 1000) {
        samples = history.append(samples, 10, true, now, 1000, 60000);
    }
    samples = history.append(samples, 10, true, 20000, 10000, 60000);
    samples = history.append(samples, 20, true, 30000, 10000, 60000);
    const points = history.segments(samples, 30000, 60000)[0];
    assert.equal(points[0].x, 0.5);
    assert.equal(points.at(-1).x, 1);
    assert.ok(Math.abs(points.at(-1).x - points.at(-2).x - 1 / 6) < 1e-10);
});

test("unavailable and invalid readings break paths rather than showing zero", () => {
    let samples = history.append([], 25, true, 0, 1000, 60000);
    samples = history.append(samples, 25, true, 1000, 1000, 60000);
    for (const [index, value] of [null, undefined, "", NaN].entries()) {
        samples = history.append(samples, value, true, 2000 + index * 1000, 1000, 60000);
        assert.equal(samples.at(-1).value, null);
    }
    samples = history.append(samples, 0, false, 6000, 1000, 60000);
    samples = history.append(samples, 0, true, 7000, 1000, 60000);
    samples = history.append(samples, 0, true, 8000, 1000, 60000);
    const segments = history.segments(samples, 8000, 60000);
    assert.equal(segments.length, 2);
    assert.equal(segments[1][0].value, 0);
});

test("delayed callbacks and suspension do not join disconnected readings", () => {
    let samples = history.append([], 25, true, 0, 1000, 60000);
    samples = history.append(samples, 25, true, 1000, 1000, 60000);
    samples = history.append(samples, 75, true, 10000, 1000, 60000);
    assert.equal(history.segments(samples, 10000, 60000).length, 2);
    samples = history.append(samples, 50, true, 100000, 1000, 60000);
    assert.equal(samples.length, 1);
    assert.equal(samples[0].time, 100000);
});

test("clock rollback clears future history, same-time samples replace instead of accumulating", () => {
    let samples = history.append([], 25, true, 5000, 1000, 60000);
    samples = history.append(samples, 75, true, 5000, 1000, 60000);
    assert.equal(samples.length, 1);
    assert.equal(samples[0].value, 75);
    samples = history.append(samples, 50, true, 1000, 1000, 60000);
    assert.equal(samples.length, 1);
    assert.equal(samples[0].time, 1000);
});

test("malformed order never duplicates, drops, or invents popup modules", () => {
    const ids = ["cpu", "memory", "gpu", "disk", "network"];
    assert.deepEqual(plain(order.normalize("disk,disk,unknown,cpu", ids)), ["disk", "cpu", "memory", "gpu", "network"]);
    assert.deepEqual(plain(order.normalize("", ids)), ids);
    assert.deepEqual(plain(order.normalize("network,disk,gpu,memory,cpu", ids)), [...ids].reverse());
});
