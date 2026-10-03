#!/bin/sh

# Match KSystemStats' Linux PCI enumeration, not DRM card numbering.
export LC_ALL=C
command -v udevadm >/dev/null 2>&1 || exit 1

for device in /sys/bus/pci/devices/*; do
    readlink -f "$device" || exit 1
done | sort | while IFS= read -r device; do
    class=$(cat "$device/class") || exit 1
    case "$class" in
        0x030000|0x030200|0x038000) ;;
        *) continue ;;
    esac
    vendor=$(cat "$device/vendor") || exit 1
    case "$vendor" in
        0x1002|0x10de|0x8086) ;;
        *) continue ;;
    esac

    # Xe enumeration depends on how KSystemStats was built.
    driver=$(readlink "$device/driver")
    case "$driver" in
        */xe) exit 1 ;;
    esac

    properties=$(udevadm info --query=property --path="$device") || exit 1
    name=$(printf '%s\n' "$properties" | sed -n 's/^ID_MODEL_FROM_DATABASE=//p')
    if [ -z "$name" ]; then
        name=$(printf '%s\n' "$properties" | sed -n 's/^ID_MODEL=//p')
    fi
    printf '%s\t%s\n' "${device##*/}" "$name"
done
