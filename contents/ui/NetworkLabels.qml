import QtQml

import "NetworkSource.js" as NetworkSource

// Shared friendly names so settings, popup and tooltips describe interfaces alike.
QtObject {
    function interfaceLabel(name) {
        if (!name || name.length === 0) {
            return i18nc("@info:status", "N/A");
        }
        switch (NetworkSource.interfaceKind(name)) {
        case "wifi":
            return i18nc("@label wifi interface", "Wi-Fi (%1)", name);
        case "ethernet":
            return i18nc("@label wired interface", "Ethernet (%1)", name);
        case "vpn":
            return i18nc("@label vpn interface", "VPN (%1)", name);
        case "virtual":
            return i18nc("@label virtual network interface", "Virtual (%1)", name);
        default:
            return name;
        }
    }

    function sourceLabel(effectiveSource) {
        var mode = NetworkSource.mode(effectiveSource);
        if (mode === "auto") {
            return i18nc("@item:inlistbox network source", "Automatic (default route)");
        }
        if (mode === "interface") {
            return interfaceLabel(NetworkSource.interfaceFromSource(effectiveSource));
        }
        if (mode === "custom") {
            return i18nc("@item:inlistbox network source", "Custom sensor IDs");
        }
        return i18nc("@item:inlistbox network source", "All interfaces (combined)");
    }
}
