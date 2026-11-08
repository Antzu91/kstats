.pragma library

// SMART health from UDisks2 over the system bus, read with busctl. Reading
// cached properties needs no privileges; busctl must never prompt for
// authorization, and nothing here asks UDisks to wake drives or run tests.

var busctl = "busctl --system --json=short --allow-interactive-authorization=no --timeout=5";
var managedObjectsCommand = busctl
    + " call org.freedesktop.UDisks2 /org/freedesktop/UDisks2 org.freedesktop.DBus.ObjectManager GetManagedObjects";
var drivePathPattern = /^\/org\/freedesktop\/UDisks2\/drives\/[A-Za-z0-9_]+$/;
var marker = "@@KSTATS-DRIVE ";
var ataWearAttributes = ["wear-leveling-count", "ssd-life-left", "media-wearout-indicator", "percent-lifetime-remain"];

function value(properties, name) {
    var property = properties ? properties[name] : undefined;
    return property && typeof property === "object" && "data" in property ? property.data : undefined;
}

function number(raw) {
    var parsed = Number(raw);
    return raw !== undefined && raw !== null && raw !== "" && isFinite(parsed) ? parsed : null;
}

function text(raw) {
    return typeof raw === "string" ? raw.trim() : "";
}

// Block device paths arrive as NUL-terminated byte arrays.
function bytesToString(bytes) {
    if (!Array.isArray(bytes)) {
        return "";
    }
    var result = "";
    for (var i = 0; i < bytes.length && bytes[i] !== 0; ++i) {
        result += String.fromCharCode(bytes[i]);
    }
    return result;
}

function parseJson(output) {
    try {
        return JSON.parse(output);
    } catch (error) {
        return null;
    }
}

// Returns { drives: { path: drive }, deviceToDrive: { kernelName: path } } or null.
function parseManagedObjects(output) {
    var parsed = parseJson(output);
    var objects = parsed && Array.isArray(parsed.data) ? parsed.data[0] : null;
    if (!objects || typeof objects !== "object") {
        return null;
    }
    var drives = {};
    var deviceToDrive = {};
    Object.keys(objects).forEach(function(path) {
        var interfaces = objects[path] || {};
        var drive = interfaces["org.freedesktop.UDisks2.Drive"];
        if (drive && drivePathPattern.test(path)) {
            var ata = interfaces["org.freedesktop.UDisks2.Drive.Ata"];
            var nvme = interfaces["org.freedesktop.UDisks2.NVMe.Controller"];
            var smart = null;
            if (nvme) {
                var warnings = value(nvme, "SmartCriticalWarning");
                smart = {
                    updated: number(value(nvme, "SmartUpdated")) || 0,
                    criticalWarning: Array.isArray(warnings) ? warnings.filter(function(item) {
                        return typeof item === "string";
                    }) : [],
                    temperatureK: number(value(nvme, "SmartTemperature")),
                    powerOnHours: number(value(nvme, "SmartPowerOnHours"))
                };
            } else if (ata) {
                smart = {
                    supported: value(ata, "SmartSupported") === true,
                    enabled: value(ata, "SmartEnabled") === true,
                    updated: number(value(ata, "SmartUpdated")) || 0,
                    failing: value(ata, "SmartFailing") === true,
                    temperatureK: number(value(ata, "SmartTemperature")),
                    powerOnSeconds: number(value(ata, "SmartPowerOnSeconds")),
                    badSectors: number(value(ata, "SmartNumBadSectors")),
                    attributesFailing: number(value(ata, "SmartNumAttributesFailing")),
                    attributesFailedInPast: number(value(ata, "SmartNumAttributesFailedInThePast"))
                };
            }
            drives[path] = {
                path: path,
                model: text(value(drive, "Model")),
                serial: text(value(drive, "Serial")),
                size: number(value(drive, "Size")),
                kind: nvme ? "nvme" : ata ? "ata" : "none",
                smart: smart
            };
        }
        var block = interfaces["org.freedesktop.UDisks2.Block"];
        if (block && !interfaces["org.freedesktop.UDisks2.Partition"]) {
            var device = bytesToString(value(block, "Device")).match(/^\/dev\/([A-Za-z0-9_.-]+)$/);
            var drivePath = text(value(block, "Drive"));
            if (device && drivePathPattern.test(drivePath)) {
                deviceToDrive[device[1]] = drivePath;
            }
        }
    });
    return { drives: drives, deviceToDrive: deviceToDrive };
}

// One shell command reading extended attributes for every SMART-capable drive.
// Paths are validated object paths, so single quotes cannot be escaped.
function attributesCommand(drives) {
    return drives.filter(function(drive) {
        return drive && drivePathPattern.test(drive.path) && drive.smart
            && (drive.kind === "nvme" || (drive.kind === "ata" && drive.smart.supported && drive.smart.enabled));
    }).map(function(drive) {
        var iface = drive.kind === "nvme" ? "org.freedesktop.UDisks2.NVMe.Controller" : "org.freedesktop.UDisks2.Drive.Ata";
        return "echo '" + marker + drive.path + "'; " + busctl + " call org.freedesktop.UDisks2 '"
            + drive.path + "' " + iface + " SmartGetAttributes 'a{sv}' 0 2>/dev/null; echo";
    }).join("; ");
}

// Returns { path: { kind, values } }: NVMe values map names to numbers;
// ATA values map attribute names to { value, worst, threshold, pretty, unit }.
function parseAttributesBatch(output) {
    var result = {};
    var sections = String(output || "").split(marker);
    for (var i = 1; i < sections.length; ++i) {
        var newline = sections[i].indexOf("\n");
        var path = (newline < 0 ? sections[i] : sections[i].slice(0, newline)).trim();
        var parsed = newline < 0 ? null : parseJson(sections[i].slice(newline + 1).trim());
        if (!drivePathPattern.test(path) || !parsed || !Array.isArray(parsed.data)) {
            continue;
        }
        var data = parsed.data[0];
        if (parsed.type === "a{sv}" && data && typeof data === "object" && !Array.isArray(data)) {
            var values = {};
            Object.keys(data).forEach(function(name) {
                var raw = data[name] && data[name].data;
                if (typeof raw === "number") {
                    values[name] = raw;
                }
            });
            result[path] = { kind: "nvme", values: values };
        } else if (Array.isArray(data)) {
            var rows = {};
            data.forEach(function(row) {
                if (Array.isArray(row) && row.length >= 8 && typeof row[1] === "string") {
                    rows[row[1]] = { value: number(row[3]), worst: number(row[4]), threshold: number(row[5]),
                        pretty: number(row[6]), unit: number(row[7]) };
                }
            });
            result[path] = { kind: "ata", values: rows };
        }
    }
    return result;
}

function temperatureCelsius(kelvin) {
    return kelvin !== null && kelvin > 0 ? Math.round((kelvin - 273.15) * 10) / 10 : null;
}

// status: "good", "warning", "failing" or "unknown"; problems are codes the
// view translates. Missing data never reads as healthy.
function summarize(drive, attributes) {
    var summary = { status: "unknown", problems: [], temperatureC: null, powerOnHours: null,
        wearPercent: null, dataRead: null, dataWritten: null, mediaErrors: null,
        unsafeShutdowns: null, badSectors: null, updated: 0 };
    if (!drive) {
        summary.problems = ["missing"];
        return summary;
    }
    var smart = drive.smart;
    if (!smart) {
        summary.problems = ["unsupported"];
        return summary;
    }
    if (drive.kind === "ata" && !smart.supported) {
        summary.problems = ["unsupported"];
        return summary;
    }
    if (drive.kind === "ata" && !smart.enabled) {
        summary.problems = ["disabled"];
        return summary;
    }
    summary.updated = smart.updated;
    if (!smart.updated) {
        summary.problems = ["pending"];
        return summary;
    }
    summary.temperatureC = temperatureCelsius(smart.temperatureK);
    var failing = false;
    var values = attributes && attributes.values ? attributes.values : {};

    if (drive.kind === "nvme") {
        summary.powerOnHours = smart.powerOnHours;
        smart.criticalWarning.forEach(function(warning) {
            summary.problems.push("nvme-" + warning);
            failing = failing || warning === "readonly" || warning === "degraded";
        });
        if (attributes && attributes.kind === "nvme") {
            summary.wearPercent = number(values.percent_used);
            summary.dataRead = number(values.total_data_read);
            summary.dataWritten = number(values.total_data_written);
            summary.mediaErrors = number(values.media_errors);
            summary.unsafeShutdowns = number(values.unsafe_shutdowns);
            if (summary.wearPercent !== null && summary.wearPercent >= 100) {
                summary.problems.push("worn-out");
            }
            if (summary.mediaErrors !== null && summary.mediaErrors > 0) {
                summary.problems.push("media-errors");
            }
        }
    } else {
        summary.powerOnHours = smart.powerOnSeconds !== null ? Math.floor(smart.powerOnSeconds / 3600) : null;
        summary.badSectors = smart.badSectors;
        if (smart.failing) {
            summary.problems.push("failing");
            failing = true;
        }
        if (smart.attributesFailing !== null && smart.attributesFailing > 0) {
            summary.problems.push("attributes-failing");
        }
        if (smart.badSectors !== null && smart.badSectors > 0) {
            summary.problems.push("bad-sectors");
        }
        if (attributes && attributes.kind === "ata") {
            // Vendor-normalized remaining life; only well-known names, never raw counters.
            for (var i = 0; i < ataWearAttributes.length; ++i) {
                var row = values[ataWearAttributes[i]];
                if (row && row.value !== null && row.value >= 0 && row.value <= 100) {
                    summary.wearPercent = 100 - row.value;
                    break;
                }
            }
        }
    }
    summary.status = failing ? "failing" : summary.problems.length > 0 ? "warning" : "good";
    return summary;
}
