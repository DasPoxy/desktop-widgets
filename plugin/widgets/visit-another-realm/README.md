# 🌀 Visit Another Realm (`RealmPortalWidget`)

One button that picks a random installed game and launches it.

## Features
- **Random Game Launch**: Picks from Steam, Heroic, and Lutris libraries.
- **Cover-Art Swatches**: Shuffling cover-art strips behind the portal, with a selectable angle (╲ │ ╱) and shuffle interval.
- **Customisable Text**: Custom or blank title and button text.
- **Icon Picker**: Searchable icon for the portal.
- **Excluded Games**: Searchable per-game exclusion list, so tools and launchers never get picked.
- **Full Theme Palette**: Use all the theme's hues, or accent only.

## Architecture
- `RealmPortalWidget.qml`: Interactive UI inheriting `WidgetCard`.
- `get-random-game.sh`: Python backend that scans the Steam/Heroic/Lutris libraries, skips anything passed in `--exclude`, and launches the pick via `steam://`, `heroic://` or `lutris`.
