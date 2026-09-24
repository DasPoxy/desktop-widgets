# 📈 System Monitor (`SystemMonitorWidget`)

Live CPU, GPU and RAM meters, network activity, and AI agent usage limits in one card.

## Features
- **Utilization Meters**: CPU, GPU, and RAM percentages.
- **Network**: Live upload/download rates and a network graph, plus session totals with a *Reset Session Counter* action.
- **Agent Usage**: Usage-limit bars from Omarchy's own agent-usage data (the same records the agents bar panel shows), toggled with *Show Agent Usage*.
- **Refresh Rate**: Adjustable polling interval.
- **Header Options**: Rename the title, pick its glyph, or hide either.
- **Full Theme Palette**: Use all the theme's hues, or accent only.

## Architecture
- `SystemMonitorWidget.qml`: Interactive UI inheriting `WidgetCard`.
- `get-sysmon.sh`: CPU/GPU/RAM and network rates as JSON per poll; session counters live in their own file so the script never races the shell's settings writes.
- `get-agents.sh`: Reads Omarchy's agent-usage records and kicks off a background refresh when they're stale.
