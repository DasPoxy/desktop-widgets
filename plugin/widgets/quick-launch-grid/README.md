# 🚀 Quick Launch Grid (`AppGridWidget`)

Pin your favourite apps into a paged quick-launch grid, unlike the search-based App Launcher.

## Features
- **Grid Sizes**: 3×3, 4×4, or 5×5, with extra pages once it fills up.
- **Pinning**: *Add App...* opens a searchable list of installed applications; right-click a tile for *Remove from Quick Launch* (only while the widget layout is unlocked).
- **Header Options**: Rename the title, pick its glyph from a searchable dropdown of every icon in your system font, or hide either. Hide both and the apps take the whole card.
- **Grid Mode** and a *Full Theme Palette* toggle.

## Architecture
- `AppGridWidget.qml`: Interactive UI inheriting `WidgetCard`.
- App list comes from the plugin's shared `get-apps.sh`, the same one the App Launcher uses.
