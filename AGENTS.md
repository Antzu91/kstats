# Repository Guidelines

## Project Structure & Module Organization

KStats is a KDE Plasma 6 widget using QML, Kirigami, and KSysGuard sensors. No compilation step is required.

- `contents/ui/main.qml` wires sensors, shared state, and compact/expanded representations. Pages read shared state only through its `rootItem` interface.
- `contents/ui/` contains metric pages (`CpuPage.qml`, `GpuPage.qml`) and reusable components (`Sparkline.qml`, `Card.qml`). Testable logic lives in `.pragma library` JS files (`History.js`, `NetworkSource.js`, `DiskHealth.js`, …); they cannot call `i18n`, so user-visible strings stay in QML.
- Module IDs (`cpu`, `memory`, `gpu`, `disk`, `network`) come from `ModuleCatalog.js`. Settings store IDs; popup pages keep fixed indices resolved with `pageIndex()`.
- `contents/config/main.xml` defines settings and defaults; `contents/config/config.qml` registers the settings page implemented in `contents/ui/configGeneral.qml`.
- `metadata.json` defines the widget identity and version. `screenshots/` holds README images; `.github/workflows/` contains validation and release workflows.

## Build, Test, and Development Commands

Run commands from the repository root with Plasma 6 and the required KDE QML modules installed. See `.github/workflows/ci.yml` for CI dependencies; CI runs in `archlinux:base-devel`, so reproduce it there with podman if Qt tools are missing locally.

- `plasmoidviewer --applet .` previews the widget without installation. Set `QT_FORCE_STDERR_LOGGING=1`, or QML errors go to the journal.
- `kpackagetool6 --type Plasma/Applet --install .` installs for the current user; then add KStats through Plasma’s widget picker.
- `/usr/lib/qt6/bin/qmllint --unqualified disable contents/ui/*.qml contents/config/config.qml` runs CI’s QML checks. Adjust the executable path for your distribution. `Member … not found on type "KConfigPropertyMap"` warnings are expected; treat other new warnings as regressions.
- `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests` runs the Qt Quick tests.
- `xmllint --noout contents/config/main.xml` checks configuration XML.
- `kpackagetool6 --type Plasma/Applet --appstream-metainfo . > /tmp/kstats.metainfo.xml` generates metadata; validate it with `appstreamcli validate --no-net --explain /tmp/kstats.metainfo.xml`.
- `kpackagetool6 --type Plasma/Applet --packageroot /tmp/kstats-plasmoid-check --install .` checks installation in a temporary location.

## Coding Style & Naming Conventions

Use four-space indentation, same-line opening braces, double-quoted strings, and semicolons in JavaScript statements. Use PascalCase for reusable QML filenames and camelCase for properties, IDs, and functions. Follow existing import aliases such as `Kirigami`, `Sensors`, and `Local`.

Use `i18n`/`i18nc` for user-visible text and Kirigami theme values for styling. Keep configuration keys synchronized with `cfg_` bindings. New settings must default to the previous behavior, and stored values must be sanitized. No formatter is configured; match surrounding code and run `qmllint`.

## Testing Guidelines

Tests are Qt Quick Test files in `tests/tst_*.qml`. Inject fakes rather than touching hardware or the network (`commandComponent`, `sensorComponent`, `requestFactory`, `clock`). Define `i18n`/`i18nc` in the `TestCase` and call `failOnWarning(/TypeError|ReferenceError|Binding loop/)` in `init()` so runtime errors fail. When a page uses a new `rootItem` property, add it to the fake roots, e.g. `tests/tst_PopupSmoke.qml`.

Missing sensors, daemons, UDisks, or network access must show `N/A`, not script errors. Also exercise affected tabs, compact/expanded layouts, settings persistence, panel sizes, and themes manually.

## Pitfalls

- Async work (`RunCommand`, `XMLHttpRequest`) needs one request in flight, a generation counter to drop stale replies, and an `if (!id) return;` guard in callbacks. XHRs outlive QML objects, so abort them in `Component.onDestruction`.
- `busctl` calls must pass `--allow-interactive-authorization=no` to avoid polkit prompts.
- Change handlers can run before derived bindings update. Read the source property, or defer with `Qt.callLater`.
- Never put a `Repeater` directly inside a `Kirigami.FormLayout`; wrap it in one static item. A `Kirigami.Dialog` held in a property needs an explicit `parent`.
- Panel widths must not depend on the current reading.

## Commit & Pull Request Guidelines

Commit and push directly to `master`. Use concise, scoped summaries (`feat:`, `fix:`, `perf:`, `refactor:`, `docs:`), one focused change per commit, and describe behavior and validation in the body. Release tags use `vX.Y.Z` and must match `KPlugin.Version` in `metadata.json`.
