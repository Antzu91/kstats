import QtQuick

import "ModuleCatalog.js" as Catalog

// Display data per module ID. Views resolve colors from their own Kirigami
// theme context (panel and popup can differ) through colorRole.
Item {
    id: catalog

    readonly property var modules: ({
        cpu: { id: "cpu", name: i18nc("@label module name", "CPU"), tabLabel: i18nc("@title:tab", "CPU"),
            panelLabel: i18nc("@label", "CPU"), icon: "cpu", colorRole: "positiveTextColor" },
        memory: { id: "memory", name: i18nc("@label module name", "Memory"), tabLabel: i18nc("@title:tab", "RAM"),
            panelLabel: i18nc("@label", "MEM"), icon: "memory", colorRole: "focusColor" },
        gpu: { id: "gpu", name: i18nc("@label module name", "GPU"), tabLabel: i18nc("@title:tab", "GPU"),
            panelLabel: i18nc("@label", "GPU"), icon: "video-display", colorRole: "negativeTextColor" },
        disk: { id: "disk", name: i18nc("@label module name", "Disk"), tabLabel: i18nc("@title:tab", "DISK"),
            panelLabel: i18nc("@label", "DSK"), icon: "drive-harddisk", colorRole: "neutralTextColor" },
        network: { id: "network", name: i18nc("@label module name", "Network"), tabLabel: i18nc("@title:tab", "NET"),
            panelLabel: i18nc("@label", "NET"), icon: "network-wired", colorRole: "visitedLinkColor" }
    })

    visible: false

    function module(id) {
        return modules[id] || modules.cpu;
    }
}
