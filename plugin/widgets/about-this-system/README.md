# ℹ️ About This System (`SystemAboutWidget`)

A fastfetch / Omarchy-style system summary with the active theme's colour palette.

## Features
- **Hardware**: Host, CPU (cores/threads), GPU, display resolution and refresh rate, disk, memory, and swap.
- **Software**: Omarchy version, channel and branch, kernel, WM, DE, package counts, and the active theme.
- **Age / Uptime / Update**: Install age, uptime, and time since the last update.
- **Theme Palette**: The active theme's colours as swatches.
- **Grid Mode** and *Refresh Now*.
- **Full Theme Palette**: Use all the theme's hues, or accent only.

## Architecture
- `SystemAboutWidget.qml`: Interactive UI inheriting `WidgetCard`.
- `get-about.sh`: Collects fastfetch facts, Omarchy branding info, and the theme palette as one JSON object.
