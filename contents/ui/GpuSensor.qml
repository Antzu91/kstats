import QtQuick

SensorMonitor {
    active: false
    // A missing optional GPU metric has always been shown as N/A.
    disabledText: unavailableText
}
