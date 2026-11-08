import QtQml

import org.kde.kirigami as Kirigami

// Popup spacing and chart sizes per density. Comfortable reproduces the
// original popup; Compact tightens spacing and charts and hides chart titles.
QtObject {
    property bool compact: false

    readonly property real padding: compact ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
    readonly property real headerSpacing: compact ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
    readonly property real pageSpacing: compact ? Kirigami.Units.smallSpacing / 2 : Kirigami.Units.smallSpacing
    readonly property real preferredHeight: Kirigami.Units.gridUnit * (compact ? 32 : 38)
    readonly property real memoryChartHeight: Kirigami.Units.gridUnit * (compact ? 3.8 : 4.7)
    readonly property real networkChartHeight: Kirigami.Units.gridUnit * (compact ? 4.2 : 5.2)
    readonly property real cpuCoresHeight: Kirigami.Units.gridUnit * (compact ? 3.8 : 4.6)
    readonly property real cpuHistoryHeight: Kirigami.Units.gridUnit * (compact ? 4.8 : 5.8)
    readonly property bool chartTitles: !compact
}
