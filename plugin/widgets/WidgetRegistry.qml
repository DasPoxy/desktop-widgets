import QtQuick

QtObject {
  id: registry

  readonly property var builtins: [
    {
      id: "clock",
      name: "Hero Clock & Weather",
      category: "Glance",
      icon: "\uf017",
      badge: "Featured",
      description: "Centerpiece dynamic desktop clock with live weather status and date display.",
      componentUrl: Qt.resolvedUrl("HeroClockWidget.qml")
    },
    {
      id: "horizon_clock",
      name: "Horizon Clock & Weather",
      category: "Glance",
      icon: "\uf017",
      badge: "Resizable",
      description: "Hero Clock & Weather, resizable: the time, date, greeting and weather scale to fit centred in whatever size you drag it to. Pick any installed Nerd Font from the right-click menu.",
      componentUrl: Qt.resolvedUrl("HorizonClockWidget.qml")
    },
    {
      id: "gallery",
      name: "3D Photo Deck Stack",
      category: "Glance",
      icon: "\uf03e",
      badge: "Animated",
      description: "Layered photo deck cycling through wallpapers, camera roll, and custom folders.",
      componentUrl: Qt.resolvedUrl("PhotoGalleryWidget.qml")
    },
    {
      id: "network",
      name: "Live Network Traffic",
      category: "System",
      icon: "\uf0ec",
      badge: "Real-time",
      description: "Real-time upload and download bandwidth sparkline area charts and connection metrics.",
      componentUrl: Qt.resolvedUrl("NetworkTrafficWidget.qml")
    },
    {
      id: "media",
      name: "MPRIS Media Player",
      category: "Media",
      icon: "\uf001",
      badge: "Visualizer",
      description: "Album artwork, track marquee, player controls, and dynamic 24-bar audio frequency spectrum.",
      componentUrl: Qt.resolvedUrl("MediaPlayerWidget.qml")
    },
    {
      id: "system",
      name: "System Resources",
      category: "System",
      icon: "\uf2db",
      badge: "Hardware",
      description: "Live system RAM usage monitor and multi-disk mount storage capacity indicators.",
      componentUrl: Qt.resolvedUrl("SystemResourcesWidget.qml")
    },
    {
      id: "git_activity",
      name: "Git Activity Radar",
      category: "Dev",
      icon: "\uf1d3",
      badge: "84-Day Radar",
      description: "84-day contribution pulse heatmap, commit history, branch tracker, and uncommitted diff status.",
      componentUrl: Qt.resolvedUrl("git-activity/GitActivityWidget.qml")
    },
    {
      id: "hardware_telemetry",
      name: "Hardware Telemetry",
      category: "System",
      icon: "\uf2db",
      badge: "Sensors",
      description: "Real-time CPU and GPU utilization, clock frequencies, thermals, and VRAM monitoring.",
      componentUrl: Qt.resolvedUrl("hardware-telemetry/HardwareTelemetryWidget.qml")
    },
    {
      id: "pomodoro",
      name: "Flow Pomodoro Timer",
      category: "Productivity",
      icon: "\uf252",
      badge: "Focus",
      description: "Flow-state countdown timer with circular progress ring, focus cycles, and audio alerts.",
      componentUrl: Qt.resolvedUrl("pomodoro/PomodoroWidget.qml")
    },
    {
      id: "quick_notes",
      name: "Quick Notes & Todos",
      category: "Productivity",
      icon: "\uf249",
      badge: "Scratchpad",
      description: "Markdown scratchpad and tagged Kanban todo deck with instant local state persistence.",
      componentUrl: Qt.resolvedUrl("quick-notes/QuickNotesWidget.qml")
    },
    {
      id: "weather",
      name: "Weather Forecast",
      category: "Glance",
      icon: "\uf185",
      badge: "Live",
      description: "Current temperature, atmospheric conditions, and 3-day forecast with °F/°C switching.",
      componentUrl: Qt.resolvedUrl("WeatherWidget.qml")
    },
    {
      id: "app_launcher",
      name: "App Launcher Grid",
      category: "Productivity",
      icon: "\uf108",
      badge: "QuickLaunch",
      description: "Fast desktop application launcher with live search, category filters, and system icons.",
      componentUrl: Qt.resolvedUrl("AppLauncherWidget.qml")
    },
    {
      id: "folder_view",
      name: "Folder View Card",
      category: "Productivity",
      icon: "\uf07b",
      badge: "Transparent",
      description: "Transparent desktop portal for any directory with .desktop app launching and subfolder navigation.",
      componentUrl: Qt.resolvedUrl("FolderViewWidget.qml")
    },
    {
      id: "coin_tracker",
      name: "Coin Tracker",
      category: "Finance",
      icon: "\uf51e",
      badge: "Core",
      description: "Live cryptocurrency market tracker with multi-coin watchlist, auto-cycle, interactive sparklines, and fiat switcher.",
      componentUrl: Qt.resolvedUrl("CoinTrackerWidget.qml")
    },
    {
      id: "analog_clock",
      name: "Luxury & Bauhaus Analog Clock",
      category: "Glance",
      icon: "\uf017",
      badge: "Chronograph",
      description: "Precision timepiece with 60 FPS sweep, Swiss chronograph subdials, date complication, and multiple styles.",
      componentUrl: Qt.resolvedUrl("AnalogClockWidget.qml")
    },
    {
      id: "calendar",
      name: "Interactive Calendar & Agenda",
      category: "Productivity",
      icon: "\uf073",
      badge: "Planner",
      description: "Interactive monthly planner grid with day navigation and tagged daily agenda checklist.",
      componentUrl: Qt.resolvedUrl("CalendarWidget.qml")
    },
    {
      id: "rss_feed",
      name: "RSS Feed Radar",
      category: "Glance",
      icon: "\uf09e",
      badge: "Live Feeds",
      description: "News and article reader with customizable RSS/Atom feeds, channel tabs, and browser integration.",
      componentUrl: Qt.resolvedUrl("rss-feed/RssFeedWidget.qml")
    },
    {
      id: "video_player",
      name: "Video Player",
      category: "Media",
      icon: "\uf03d",
      badge: "Looping",
      description: "Browse and select a video to play looping on the desktop, with play/pause, mute, and a volume slider.",
      componentUrl: Qt.resolvedUrl("VideoPlayerWidget.qml")
    },
    {
      id: "mpris_player",
      name: "Karaoke Player",
      category: "Media",
      icon: "\uf130",
      badge: "Karaoke",
      description: "Wireframe spinning-record player for any MPRIS source with karaoke-style synced lyrics (beside or below the controls), seekable progress, shuffle/loop, a live cava spectrum, and a source switcher. Scales from compact to wall-sized.",
      componentUrl: Qt.resolvedUrl("MprisPlayerWidget.qml")
    },
    {
      id: "realm_portal",
      name: "Visit Another Realm",
      category: "Fun",
      icon: "\ueefa",
      badge: "Custom",
      description: "One button: picks a random installed game from Steam, Heroic, or Lutris and launches it.",
      componentUrl: Qt.resolvedUrl("RealmPortalWidget.qml")
    },
    {
      id: "abyss_warden",
      name: "Abyss Warden",
      category: "Fun",
      icon: "󰈈",
      badge: "Watcher",
      badges: ["Watcher", "Custom"],
      description: "An anime eye that only appears while your screen is being recorded (Omarchy recorder, OBS, screen shares). It follows the mouse, glances at windows that change, and blinks. One eye or a pair, 9 eye styles, can float freely around the screen; 10 eye themes or your system theme.",
      componentUrl: Qt.resolvedUrl("AbyssWardenWidget.qml")
    },
    {
      id: "system_about",
      name: "About This System",
      category: "System",
      icon: "\uf05a",
      badge: "fastfetch",
      description: "fastfetch/Omarchy-style system summary (host, CPU, GPU, OS, uptime) plus the active theme's color palette as swatches.",
      componentUrl: Qt.resolvedUrl("SystemAboutWidget.qml")
    },
    {
      id: "system_monitor",
      name: "System Monitor",
      category: "System",
      icon: "\uf200",
      badge: "Live",
      description: "Live CPU, GPU, and RAM utilization meters plus network activity with session-total upload/download counters.",
      componentUrl: Qt.resolvedUrl("SystemMonitorWidget.qml")
    },
    {
      id: "app_grid",
      name: "Quick Launch Grid",
      category: "Productivity",
      icon: "\uf00a",
      badge: "Paged",
      description: "Pin apps into a 3\u00d73, 4\u00d74, or 5\u00d75 quick-launch grid, with extra pages once it fills up.",
      componentUrl: Qt.resolvedUrl("AppGridWidget.qml")
    }
  ]

  property var customWidgets: []

  readonly property var allWidgets: {
    var list = [].concat(builtins)
    for (var i = 0; i < customWidgets.length; i++) {
      var c = customWidgets[i]
      list.push({
        id: c.id,
        name: c.name || "Custom Widget",
        category: "Custom",
        icon: "\uf12e",
        badge: "User QML",
        description: c.path || "Imported custom desktop widget component.",
        componentUrl: (c.path.startsWith("/") || c.path.startsWith("file://")) ? ("file://" + c.path.replace("file://", "")) : Qt.resolvedUrl(c.path)
      })
    }
    return list
  }

  function getWidget(id) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    for (var i = 0; i < allWidgets.length; i++) {
      if (allWidgets[i].id === targetId || allWidgets[i].id === id) return allWidgets[i]
    }
    return null
  }
}
