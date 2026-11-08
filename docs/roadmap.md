# Roadmap

Updated 2026-11-08. User-facing behavior is documented in the [README](../README.md).

## Done

The monitoring and customization plan from October 2026 is complete:

- Shared sensor states and timestamped history with gaps
- One source per module for panel, popup, tooltip, and history (network,
  disk volume, CPU temperature and fan), with legacy sensor IDs kept as Custom
- Opt-in public IP lookup and SMART drive health
- Panel order, display styles, labels, monochrome, and presets
- Popup scrolling, keyboard access, pinning, and Compact density

## Not done

- Hover values and timestamps on history charts
- Searchable sensor picker for the raw sensor ID fields (only CPU temperature
  and fan have one)
- Public IP: custom providers and separate IPv4/IPv6 lookups
- CPU and memory overhead measured before and after collection changes

## Ideas

- Memory pressure from Linux PSI (`/proc/pressure/`), worded as Linux-specific
- A Sensors view for temperatures, fans, and power, with readings pinnable to
  the panel
- Battery health and charge rate
- Voltage and power sensors

## Verify on a real panel

The test container has no window manager, so these are unconfirmed there:
tooltips appearing above their own module, the pinned popup staying open on
focus loss, Escape closing the popup, and Tab focus reaching panel modules.
