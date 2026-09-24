# 🕰️ Horizon Clock & Weather (`HorizonClockWidget`)

A resizable fork of the built-in Hero Clock & Weather: the greeting, weather, time and date scale together to fit centred in whatever size you drag the card to.

## Features
- **Auto-Fit Layout**: Scales from 160×80 up to wall-sized, keeping every line centred and in proportion.
- **Nerd Font Picker**: Searchable list of every installed Nerd Font, each previewed in its own face.
- **Display Preferences** (same as Hero Clock):
  - 12/24-hour time, optional seconds.
  - Compact or full date format.
  - Greeting message and live weather status toggles.
  - °F/°C temperature scale and a *Refresh Weather* action.
- **Full Theme Palette**: Use all the theme's hues, or accent only.

## Architecture
- `HorizonClockWidget.qml`: Interactive UI inheriting `WidgetCard`.
- Weather comes from the plugin's shared `get-weather.sh`, the same one Hero Clock uses.
