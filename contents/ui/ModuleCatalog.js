.pragma library

// Stable module IDs. Settings store IDs, never tab positions; the popup's
// page stack keeps its own fixed indices, resolved through pageIndex.

var ids = ["cpu", "memory", "gpu", "disk", "network"];
var defaultOrder = ids.join(",");
var pageIndexes = { cpu: 0, memory: 1, gpu: 2, network: 3, disk: 4 };

// Keeps known IDs once, in stored order, then appends any missing ones, so
// unknown, duplicate or missing entries can never hide a module.
function normalizeOrder(order) {
    var result = [];
    String(order === undefined || order === null ? "" : order).split(",").forEach(function(raw) {
        var id = raw.trim();
        if (ids.indexOf(id) >= 0 && result.indexOf(id) < 0) {
            result.push(id);
        }
    });
    return result.concat(ids.filter(function(id) { return result.indexOf(id) < 0; }));
}

function serialize(order) {
    return normalizeOrder(order.join(",")).join(",");
}

// Returns the order string with the module moved by delta (-1 up, +1 down).
function move(order, id, delta) {
    var list = normalizeOrder(order);
    var from = list.indexOf(id);
    var to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) {
        return list.join(",");
    }
    list.splice(from, 1);
    list.splice(to, 0, id);
    return list.join(",");
}

function pageIndex(id) {
    return id in pageIndexes ? pageIndexes[id] : 0;
}

function moduleForPage(index) {
    for (var i = 0; i < ids.length; ++i) {
        if (pageIndexes[ids[i]] === index) {
            return ids[i];
        }
    }
    return "cpu";
}
