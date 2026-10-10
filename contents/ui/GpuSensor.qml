import QtQuick

SensorMonitor {
    active: false
    emptyIsUnavailable: true
    // A missing optional GPU metric has always been shown as N/A.
    disabledText: unavailableText
}
