function normalize(order, ids) {
    var result = [];
    String(order || "").split(",").forEach(function(id) {
        if (ids.indexOf(id) >= 0 && result.indexOf(id) < 0) {
            result.push(id);
        }
    });
    return result.concat(ids.filter(function(id) { return result.indexOf(id) < 0; }));
}
