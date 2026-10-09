import QtQuick
import org.kde.kirigami as Kirigami
import "ModuleOrder.js" as ModuleOrder

QtObject {
    id: modules

    property string order: "cpu,memory,gpu,disk,network"
    // Tab IDs match the popup stack, regardless of display order.
    readonly property var definitions: [
        { id: "cpu", label: i18nc("@label", "CPU"), tabId: 0, icon: "cpu", color: Kirigami.Theme.positiveTextColor, visibilityKey: "showCpu" },
        { id: "memory", label: i18nc("@label", "RAM"), tabId: 1, icon: "memory", color: Kirigami.Theme.focusColor, visibilityKey: "showMemory" },
        { id: "gpu", label: i18nc("@label", "GPU"), tabId: 2, icon: "video-display", color: Kirigami.Theme.negativeTextColor, visibilityKey: "showGpu" },
        { id: "disk", label: i18nc("@label", "DISK"), tabId: 4, icon: "drive-harddisk", color: Kirigami.Theme.neutralTextColor, visibilityKey: "showDisk" },
        { id: "network", label: i18nc("@label", "NET"), tabId: 3, icon: "network-wired", color: Kirigami.Theme.visitedLinkColor, visibilityKey: "showNetwork" }
    ]
    readonly property var ordered: ModuleOrder.normalize(order, definitions.map(function(module) {
        return module.id;
    })).map(function(id) {
        return modules.definitions.find(function(module) { return module.id === id; });
    })
}
