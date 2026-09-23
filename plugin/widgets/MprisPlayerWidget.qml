import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

WidgetCard {
  id: mprisRoot

  widgetId: "mpris_player"
  title: "Karaoke Player"
  icon: ""
  showHeader: false

  defaultX: Style.space(24)
  defaultY: Style.space(120)

  width: 580
  height: 300
  minWidth: 260
  minHeight: 150
  maxWidth: Math.min(1600, screenWidth - 40)
  maxHeight: Math.min(1000, screenHeight - 80)
  resizable: true

  // ---------------------------------------------------------------------------
  // ⚙️ Settings
  // ---------------------------------------------------------------------------
  property string preferredPlayerIdentity: "" // "" = follow whichever is playing
  property bool showVisualizer: true
  property bool showLyrics: true
  property bool spinRecord: true
  property bool showLabelArt: true
  // Lyrics text size multiplier (on top of the card's own uiScale).
  property real lyricsFontScale: 1.0
  readonly property var lyricsFontChoices: [
    { label: "S", scale: 0.85 },
    { label: "M", scale: 1.0 },
    { label: "L", scale: 1.2 },
    { label: "XL", scale: 1.45 },
    { label: "XXL", scale: 1.75 }
  ]
  function setLyricsFontScale(v) {
    lyricsFontScale = v
    saveSetting("lyricsFontScale", v)
  }
  property var lyricsOffsets: ({}) // trackKey -> ms; + = lyrics earlier
  property bool themeColors: true // off = accent-only, like before

  // ---------------------------------------------------------------------------
  // 🎨 Theme Palette -- Color only exposes accent/foreground/background/urgent,
  // so the rest of the theme's colors.toml is read here. Themes name their
  // hues either by role (magenta, cyan...) or as terminal slots (color5...),
  // so each role tries both before falling back to the accent.
  // ---------------------------------------------------------------------------
  property var themePalette: ({})

  function palette(keys, fallback) {
    if (!themeColors) return fallback
    for (var i = 0; i < keys.length; i++) {
      var v = themePalette[keys[i]]
      if (v) return v
    }
    return fallback
  }
  function tint(c, a) { return Qt.alpha(c, a) }
  // Blends around the hue wheel (shorter way) rather than straight through
  // RGB, which turns e.g. cyan -> magenta into a muddy grey midway.
  function mixColor(a, b, t) {
    var ha = a.hsvHue, hb = b.hsvHue
    if (ha < 0 || a.hsvSaturation < 0.08) ha = hb // greys have no real hue
    if (hb < 0 || b.hsvSaturation < 0.08) hb = ha
    if (ha < 0) return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    var d = hb - ha
    if (d > 0.5) d -= 1
    else if (d < -0.5) d += 1
    var h = ha + d * t
    h = h - Math.floor(h)
    return Qt.hsva(h, a.hsvSaturation + (b.hsvSaturation - a.hsvSaturation) * t, a.hsvValue + (b.hsvValue - a.hsvValue) * t, 1)
  }

  readonly property color cPrimary: Color.accent
  readonly property color cSecondary: palette(["magenta", "color5", "bright_magenta", "color13"], Color.accent)
  readonly property color cTertiary: palette(["cyan", "color6", "bright_cyan", "color14"], Color.accent)
  readonly property color cHighlight: palette(["yellow", "color3", "bright_yellow", "color11"], Color.accent)
  readonly property color cLive: palette(["green", "color2", "bright_green", "color10"], Color.accent)
  // Panel fill: the theme's raised-surface colour when it names one, else a
  // faint wash of the secondary hue (selection/color8 are often loud).
  readonly property string surfaceKey: palette(["lighter_background", "lighter_bg"], "")
  readonly property color cSurface: !themeColors ? Qt.rgba(1, 1, 1, 0.04)
    : (surfaceKey !== "" ? Qt.alpha(surfaceKey, 0.45) : Qt.alpha(cSecondary, 0.07))

  function parsePalette(text) {
    var out = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)["']?/)
      if (m) out[m[1]] = m[2]
    }
    themePalette = out
  }

  FileView {
    id: paletteFile
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: mprisRoot.parsePalette(text())
  }

  // A theme swap repoints the current/theme link rather than editing the
  // file, which a watch may miss -- the accent changing is the reliable cue.
  Connections {
    target: Color
    function onAccentChanged() { paletteFile.reload() }
  }

  function applySavedSettings() {
    preferredPlayerIdentity = getSetting("preferredPlayerIdentity", "")
    showVisualizer = getSetting("showVisualizer", true)
    showLyrics = getSetting("showLyrics", true)
    spinRecord = getSetting("spinRecord", true)
    showLabelArt = getSetting("showLabelArt", true)
    lyricsFontScale = getSetting("lyricsFontScale", 1.0)
    themeColors = getSetting("themeColors", true)
    var o = getSetting("lyricsOffsets", {})
    lyricsOffsets = (o && typeof o === "object") ? o : {}
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function toggleSetting(key) {
    mprisRoot[key] = !mprisRoot[key]
    mprisRoot.saveSetting(key, mprisRoot[key])
  }

  // ---------------------------------------------------------------------------
  // 📐 Responsive Scaling -- one factor drives fonts/record/buttons, and whole
  // sections drop out as the card gets too small to hold them.
  // ---------------------------------------------------------------------------
  // Lyrics sit to the right when wide enough, otherwise between the controls
  // and the source chips when tall enough, otherwise they're hidden.
  readonly property string lyricsMode: !showLyrics ? "none" : (width >= 500 ? "side" : (height >= 280 ? "below" : "none"))
  readonly property bool lyricsVisible: lyricsMode !== "none"
  readonly property bool lyricsSide: lyricsMode === "side"
  readonly property bool lyricsBelow: lyricsMode === "below"
  // Width the main column actually gets (card margins + column gap removed,
  // then the 58/42 split). ~360px of it holds record + controls at scale 1.
  readonly property real mainWidth: lyricsSide ? (width - 46) * 0.58 : (width - 32)
  // In "below" mode the lyrics take roughly the lower half of the height.
  readonly property real uiScale: Math.max(0.6, Math.min(2.2, Math.min(mainWidth / 360, (lyricsBelow ? height * 0.55 : height) / 290)))
  readonly property bool visualizerVisible: showVisualizer && (lyricsBelow ? height >= 400 : height >= 170)
  readonly property bool sourcesVisible: height >= 165 && players.length > 0
  readonly property bool albumVisible: uiScale >= 0.8
  function sp(px) { return Math.round(px * mprisRoot.uiScale) }

  // ---------------------------------------------------------------------------
  // 🎵 MPRIS Players
  // ---------------------------------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []

  function playerIdentity(p) {
    return p ? (p.identity || p.desktopEntry || "Media Player") : ""
  }

  readonly property var activePlayer: {
    if (!players || players.length === 0) return null
    if (preferredPlayerIdentity !== "") {
      for (var k = 0; k < players.length; k++) {
        if (playerIdentity(players[k]) === preferredPlayerIdentity) return players[k]
      }
    }
    for (var i = 0; i < players.length; i++) {
      if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
    }
    return players[0]
  }

  function selectPlayer(identity) {
    mprisRoot.preferredPlayerIdentity = identity
    mprisRoot.saveSetting("preferredPlayerIdentity", identity)
  }

  function playerIcon(p) {
    if (!p) return ""
    try {
      var entry = (p.desktopEntry ? DesktopEntries.byId(p.desktopEntry) : null) || DesktopEntries.heuristicLookup(p.identity || "")
      if (entry && entry.icon) return Quickshell.iconPath(entry.icon, true)
    } catch (e) {}
    return ""
  }

  readonly property bool hasPlayer: activePlayer !== null
  readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing
  readonly property string trackTitle: hasPlayer && activePlayer.trackTitle ? activePlayer.trackTitle : (hasPlayer ? "Unknown track" : "Nothing playing")
  readonly property string trackArtist: hasPlayer && activePlayer.trackArtist ? activePlayer.trackArtist : (hasPlayer ? "" : "Start playback in any MPRIS app")
  readonly property string trackAlbum: hasPlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: hasPlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property real lengthSec: hasPlayer && activePlayer.lengthSupported ? activePlayer.length : 0

  // MprisPlayer.position only refreshes when positionChanged() is emitted;
  // poll faster while synced lyrics need line-accurate timing.
  property real positionSec: 0
  property bool seeking: false
  property real seekPreviewFrac: 0

  Timer {
    interval: (mprisRoot.lyricsVisible && mprisRoot.lyricsSynced) ? 250 : 1000
    running: mprisRoot.hasPlayer
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var p = mprisRoot.activePlayer
      if (!p) return
      p.positionChanged()
      mprisRoot.positionSec = p.positionSupported ? p.position : 0
    }
  }

  onActivePlayerChanged: {
    positionSec = (activePlayer && activePlayer.positionSupported) ? activePlayer.position : 0
    refreshMute()
  }

  // Karaoke clock: the polled position is only a sample every 250ms-1s, so
  // interpolate from the last sample every frame while playing. That keeps
  // the line change and the in-line sweep smooth instead of stepping.
  property real posSampleSec: 0
  property double posSampleAt: 0
  onPositionSecChanged: { posSampleSec = positionSec; posSampleAt = Date.now() }
  property real lyricClockMs: 0

  FrameAnimation {
    running: mprisRoot.lyricsVisible && mprisRoot.lyricsSynced
    onTriggered: {
      var rate = (mprisRoot.activePlayer && mprisRoot.activePlayer.rate > 0) ? mprisRoot.activePlayer.rate : 1
      var elapsed = mprisRoot.isPlaying ? (Date.now() - mprisRoot.posSampleAt) / 1000 * rate : 0
      mprisRoot.lyricClockMs = (mprisRoot.posSampleSec + Math.min(elapsed, 2)) * 1000 + mprisRoot.lyricsOffsetMs
    }
  }

  // Per-track timing nudge: music videos often have intros the album-timed
  // LRC doesn't, so let the user shift the lyrics and remember it per track.
  readonly property int lyricsOffsetMs: (trackKey && lyricsOffsets[trackKey] !== undefined) ? lyricsOffsets[trackKey] : 0

  function nudgeLyrics(deltaMs) {
    if (!mprisRoot.trackKey) return
    var o = JSON.parse(JSON.stringify(mprisRoot.lyricsOffsets))
    var v = (deltaMs === 0) ? 0 : (mprisRoot.lyricsOffsetMs + deltaMs)
    if (v === 0) delete o[mprisRoot.trackKey]
    else o[mprisRoot.trackKey] = v
    // Keep the stored map small.
    var keys = Object.keys(o)
    if (keys.length > 150) delete o[keys[0]]
    mprisRoot.lyricsOffsets = o
    mprisRoot.saveSetting("lyricsOffsets", o)
  }

  function escapeHtml(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  // Sung part of the karaoke line, shaded accent -> secondary by character
  // position across the whole line (so the colour doesn't shift as it grows).
  // Grouped into a few runs to keep the markup small.
  function sweepHtml(sung, lineLength) {
    if (!themeColors || sung.length === 0)
      return "<font color=\"" + Color.accent + "\">" + escapeHtml(sung) + "</font>"
    var runs = 8, out = ""
    var step = Math.max(1, Math.ceil(lineLength / runs))
    for (var i = 0; i < sung.length; i += step) {
      var t = lineLength > 1 ? Math.min(1, (i + step / 2) / lineLength) : 0
      out += "<font color=\"" + mixColor(cPrimary, cSecondary, t) + "\">" + escapeHtml(sung.slice(i, i + step)) + "</font>"
    }
    return out
  }

  // Visualizer bars sweep accent -> tertiary -> secondary, left to right.
  function barColor(i) {
    if (!themeColors) return Color.accent
    var t = barCount > 1 ? i / (barCount - 1) : 0
    return t < 0.5 ? mixColor(cPrimary, cTertiary, t * 2) : mixColor(cTertiary, cSecondary, (t - 0.5) * 2)
  }

  // 0..1 progress through the current line: runs from its timestamp to the
  // next line's, but at no slower than a singing pace so a line followed by
  // a long instrumental gap doesn't crawl.
  readonly property real currentLineProgress: {
    var i = currentLyricIndex
    if (i < 0 || !lyricsSynced) return 0
    var start = lyricsLines[i].t
    var next = (i + 1 < lyricsLines.length) ? lyricsLines[i + 1].t : start + 4000
    var dur = Math.min(next - start, Math.max(800, lyricsLines[i].text.length * 110))
    return Math.max(0, Math.min(1, (lyricClockMs - start) / Math.max(1, dur)))
  }

  function seekToFrac(frac) {
    var p = mprisRoot.activePlayer
    if (!p || !p.canSeek || mprisRoot.lengthSec <= 0) return
    var target = Math.max(0, Math.min(mprisRoot.lengthSec, frac * mprisRoot.lengthSec))
    p.position = target
    mprisRoot.positionSec = target
    mprisRoot.posSampleSec = target
    mprisRoot.posSampleAt = Date.now()
  }

  function seekBy(deltaSec) {
    if (mprisRoot.lengthSec <= 0) return
    seekToFrac((mprisRoot.positionSec + deltaSec) / mprisRoot.lengthSec)
  }


  function formatTime(sec) {
    if (!sec || sec <= 0) return "0:00"
    var total = Math.floor(sec)
    var h = Math.floor(total / 3600)
    var m = Math.floor((total % 3600) / 60)
    var s = total % 60
    var mm = (h > 0 && m < 10) ? ("0" + m) : String(m)
    return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : s)
  }

  // ---------------------------------------------------------------------------
  // 📊 Visualizer -- real spectrum from cava (raw ascii, same approach as the
  // cava-visualizer plugin), only while playing; simulated bars as fallback.
  // ---------------------------------------------------------------------------
  readonly property int barCount: 32
  property var bars: []
  property bool cavaAvailable: false
  readonly property bool cavaWanted: visualizerVisible && isPlaying && cavaAvailable

  readonly property string cavaConfPath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dagyr.desktop-widgets/mpris-cava.conf"
  readonly property string cavaConfig:
    "[general]\nframerate = 30\nbars = " + barCount + "\nautosens = 1\n" +
    "[input]\nmethod = pipewire\nsource = auto\n" +
    "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\nchannels = mono\n" +
    "[smoothing]\nnoise_reduction = 0.77\n"

  Process {
    command: ["bash", "-c", "command -v cava >/dev/null && echo yes || echo no"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { mprisRoot.cavaAvailable = String(line).trim() === "yes" }
    }
  }

  Process {
    id: cavaProc
    command: ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && exec cava -p \"$1\"", "_", mprisRoot.cavaConfPath, mprisRoot.cavaConfig]
    running: mprisRoot.cavaWanted
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).split(";")
        var arr = []
        for (var i = 0; i < parts.length; i++) {
          if (parts[i] === "") continue
          var v = parseInt(parts[i], 10)
          arr.push(isNaN(v) ? 0 : v / 100)
        }
        if (arr.length > 0) mprisRoot.bars = arr
      }
    }
    onRunningChanged: if (!running) mprisRoot.bars = []
  }

  property real simPhase: 0
  Timer {
    interval: 70
    running: mprisRoot.visualizerVisible && mprisRoot.isPlaying && !mprisRoot.cavaAvailable
    repeat: true
    onTriggered: {
      mprisRoot.simPhase += 0.25
      var arr = []
      for (var i = 0; i < mprisRoot.barCount; i++) {
        var raw = (Math.sin(mprisRoot.simPhase + i * 0.45) + Math.cos(mprisRoot.simPhase * 1.3 - i * 0.3) + 2) / 4
        arr.push(Math.min(1, Math.max(0.08, raw * 0.8 + Math.random() * 0.15)))
      }
      mprisRoot.bars = arr
    }
    onRunningChanged: if (!running && !cavaProc.running) mprisRoot.bars = []
  }

  // ---------------------------------------------------------------------------
  // 🎤 Lyrics -- get-lyrics.sh: sibling .lrc for local files, else LRCLIB
  // (cached on disk). Synced lines follow playback; plain lyrics just scroll.
  // ---------------------------------------------------------------------------
  property string lyricsStatus: "idle" // idle | loading | ok | none | instrumental | error
  property var lyricsLines: []
  property bool lyricsSynced: false
  property string lyricsSource: ""
  readonly property string trackKey: hasPlayer ? (playerIdentity(activePlayer) + "\n" + (activePlayer.trackArtist || "") + "\n" + (activePlayer.trackTitle || "")) : ""

  readonly property string lyricsScriptPath: {
    var u = Qt.resolvedUrl("../get-lyrics.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  onTrackKeyChanged: {
    mprisRoot.lyricsLines = []
    mprisRoot.lyricsSynced = false
    mprisRoot.lyricsStatus = mprisRoot.trackKey ? "loading" : "idle"
    lyricsDebounce.restart()
  }
  onLyricsVisibleChanged: if (lyricsVisible && lyricsStatus === "loading" && !lyricsProc.running) lyricsDebounce.restart()

  // Players often publish title and artist a beat apart; wait for both.
  Timer {
    id: lyricsDebounce
    interval: 700
    onTriggered: mprisRoot.fetchLyrics()
  }

  function fetchLyrics() {
    if (!mprisRoot.trackKey || !mprisRoot.lyricsVisible) return
    if (lyricsProc.running) { lyricsProc.refetch = true; return }
    var p = mprisRoot.activePlayer
    var url = ""
    try { url = (p.metadata && p.metadata["xesam:url"]) ? String(p.metadata["xesam:url"]) : "" } catch (e) {}
    lyricsProc.requestKey = mprisRoot.trackKey
    lyricsProc.command = [mprisRoot.lyricsScriptPath, p.trackArtist || "", p.trackTitle || "", p.trackAlbum || "", String(mprisRoot.lengthSec || 0), url]
    lyricsProc.running = true
  }

  Process {
    id: lyricsProc
    property string requestKey: ""
    property bool refetch: false
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str || lyricsProc.requestKey !== mprisRoot.trackKey) return
        try {
          var res = JSON.parse(str)
          mprisRoot.lyricsStatus = res.status || "none"
          mprisRoot.lyricsLines = (res.status === "ok" && res.lines) ? res.lines : []
          mprisRoot.lyricsSynced = !!res.synced
          mprisRoot.lyricsSource = res.source || ""
        } catch (e) {
          mprisRoot.lyricsStatus = "error"
          console.warn("[MprisPlayerWidget] lyrics parse error:", e)
        }
      }
    }
    onExited: function(exitCode) {
      if (lyricsProc.refetch || lyricsProc.requestKey !== mprisRoot.trackKey) {
        lyricsProc.refetch = false
        mprisRoot.fetchLyrics()
      }
    }
  }

  // Index of the line being sung (binary search on the karaoke clock, tiny
  // lead so a line lights up as it starts rather than after).
  readonly property int currentLyricIndex: {
    if (!lyricsSynced || lyricsLines.length === 0) return -1
    var t = lyricClockMs + 100
    var lo = 0, hi = lyricsLines.length - 1, ans = -1
    while (lo <= hi) {
      var mid = (lo + hi) >> 1
      if (lyricsLines[mid].t <= t) { ans = mid; lo = mid + 1 } else hi = mid - 1
    }
    return ans
  }

  // ---------------------------------------------------------------------------
  // ⌨️ Hover Hotkeys (Space = play/pause, M = mute) + 🔇 per-app mute
  // ---------------------------------------------------------------------------
  // Same mechanism as the Video Player widget: while the pointer is over the
  // card, request on-demand keyboard focus for the desktop layer (the
  // plugin root promotes it and wires Esc to release it).
  property bool holdsHoverFocus: false

  function updateKeyboardFocusForHover() {
    if (panelHover.hovered && mprisRoot.hasPlayer && !mprisRoot.contextMenuOpen) {
      if (rootRef) rootRef.keyboardFocusRequested = true
      mprisRoot.holdsHoverFocus = true
    } else if (mprisRoot.holdsHoverFocus) {
      mprisRoot.holdsHoverFocus = false
      if (rootRef && rootRef.keyboardFocusRequested) rootRef.keyboardFocusRequested = false
    }
  }
  onHasPlayerChanged: updateKeyboardFocusForHover()
  onContextMenuOpenChanged: updateKeyboardFocusForHover()

  Shortcut {
    sequence: "Space"
    enabled: panelHover.hovered && mprisRoot.hasPlayer && !mprisRoot.contextMenuOpen
    onActivated: if (mprisRoot.activePlayer.canTogglePlaying) mprisRoot.activePlayer.togglePlaying()
  }

  Shortcut {
    sequence: "M"
    enabled: panelHover.hovered && mprisRoot.hasPlayer && !mprisRoot.contextMenuOpen
    onActivated: mprisRoot.toggleMute()
  }

  // Mute works on the player's own PipeWire streams (get-mute.sh), which
  // covers browsers that don't implement MPRIS Volume and leaves the app's
  // volume slider alone. Falls back to MPRIS Volume when no stream matches.
  property bool appMuted: false
  property real volumeBeforeMute: 1

  readonly property string muteScriptPath: {
    var u = Qt.resolvedUrl("../get-mute.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function runMute(action) {
    var p = mprisRoot.activePlayer
    if (!p) { mprisRoot.appMuted = false; return }
    // One at a time; remember the latest request (a toggle wins over a
    // status check) and run it when the current one finishes.
    if (muteProc.running) {
      if (muteProc.pending !== "toggle") muteProc.pending = action
      return
    }
    muteProc.forPlayer = p.dbusName
    muteProc.action = action
    muteProc.command = [mprisRoot.muteScriptPath, action, p.dbusName]
    muteProc.running = true
  }

  function toggleMute() { runMute("toggle") }
  function refreshMute() { runMute("status") }

  Process {
    id: muteProc
    property string forPlayer: ""
    property string action: ""
    property string pending: ""
    running: false
    onExited: {
      var next = muteProc.pending
      muteProc.pending = ""
      // A status reply for a player we've since switched away from is stale.
      if (!next && mprisRoot.activePlayer && mprisRoot.activePlayer.dbusName !== muteProc.forPlayer) next = "status"
      if (next) mprisRoot.runMute(next)
    }
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var res = JSON.parse(str)
          var p = mprisRoot.activePlayer
          if (!p || p.dbusName !== muteProc.forPlayer) return
          if (res.status === "ok") {
            mprisRoot.appMuted = !!res.muted
          } else if (p && p.volumeSupported) {
            if (muteProc.action === "toggle") {
              if (p.volume > 0) { mprisRoot.volumeBeforeMute = p.volume; p.volume = 0 }
              else p.volume = mprisRoot.volumeBeforeMute > 0 ? mprisRoot.volumeBeforeMute : 1
            }
            mprisRoot.appMuted = p.volume === 0
          } else {
            mprisRoot.appMuted = false
          }
        } catch (e) {
          console.warn("[KaraokePlayer] mute parse error:", e)
        }
      }
    }
  }


  // Mute can also change from outside (mixer, the app itself).
  Timer {
    interval: 4000
    running: mprisRoot.hasPlayer
    repeat: true
    onTriggered: mprisRoot.refreshMute()
  }

  // ---------------------------------------------------------------------------
  // 🖱️ Scroll over the source chips to cycle Auto -> each player -> Auto
  // ---------------------------------------------------------------------------
  property real wheelAccum: 0

  function cycleSource(dir) {
    var ids = [""]
    for (var i = 0; i < mprisRoot.players.length; i++) ids.push(mprisRoot.playerIdentity(mprisRoot.players[i]))
    var cur = ids.indexOf(mprisRoot.preferredPlayerIdentity)
    if (cur < 0) cur = 0
    mprisRoot.selectPlayer(ids[(cur + dir + ids.length) % ids.length])
  }

  // ---------------------------------------------------------------------------
  // 📋 Right-Click Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "DISPLAY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Repeater {
        model: [
          { key: "showVisualizer", label: "Audio Spectrum Visualizer", icon: "" },
          { key: "showLyrics", label: "Lyrics Panel (wide sizes)", icon: "" },
          { key: "spinRecord", label: "Spinning Record", icon: String.fromCodePoint(0xf0cb9) },
          { key: "showLabelArt", label: "Album Art on Record Label", icon: "\uf03e" },
          { key: "themeColors", label: "Full Theme Palette", icon: String.fromCodePoint(0xf03d8) }
        ]

        Rectangle {
          id: toggleRow
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool on: mprisRoot[modelData.key]
          color: toggleMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: modelData.icon
              font.family: Style.font.family
              font.pixelSize: 11
              color: toggleRow.on ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
            Text {
              Layout.fillWidth: true
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.foreground
            }
            Text {
              text: toggleRow.on ? "" : ""
              font.family: Style.font.family
              font.pixelSize: 12
              color: toggleRow.on ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            }
          }

          MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mprisRoot.toggleSetting(modelData.key)
          }
        }
      }

      Text {
        text: "LYRICS SIZE"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 6
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: Style.space(4)

        Repeater {
          model: mprisRoot.lyricsFontChoices

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isActive: Math.abs(mprisRoot.lyricsFontScale - modelData.scale) < 0.01
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (sizeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isActive ? Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: Math.round(9 * modelData.scale)
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? Color.accent : Color.foreground
            }

            MouseArea {
              id: sizeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: mprisRoot.setLyricsFontScale(modelData.scale)
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.topMargin: 4
        text: "Switch sources with the chips along the bottom of the panel. Lyrics come from a matching .lrc next to local files, else LRCLIB (lrclib.net), cached. If the highlight runs early/late, use the − / + timing buttons in the lyrics header (saved per track)."
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
      }
    }
  }

  // Reusable pieces for the controls row and the source switcher.
  component CtrlButton: Rectangle {
    // Inline components don't share the document's id scope, so the
    // widget is handed in explicitly.
    property var host
    id: ctrl
    property string glyph: ""
    property bool primary: false
    property bool active: false
    property bool available: true
    signal clicked()
    implicitWidth: host.sp(primary ? 38 : 30)
    implicitHeight: implicitWidth
    radius: width / 2
    opacity: available ? 1 : 0.35
    color: primary
      ? (ctrlMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85))
      : (ctrlMouse.containsMouse && available ? host.tint(host.cTertiary, 0.22) : Qt.rgba(1, 1, 1, 0.06))
    border.color: primary ? Qt.rgba(1, 1, 1, 0.3) : (active ? Color.accent : (ctrlMouse.containsMouse && available ? host.tint(host.cTertiary, 0.6) : Qt.rgba(1, 1, 1, 0.1)))
    border.width: 1
    // Play button blends accent into the secondary hue.
    gradient: primary && host.themeColors ? playGradient : null

    Gradient {
      id: playGradient
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: ctrlMouse.containsMouse ? Qt.lighter(host.cPrimary, 1.15) : host.cPrimary }
      GradientStop { position: 1; color: ctrlMouse.containsMouse ? Qt.lighter(host.cSecondary, 1.15) : host.cSecondary }
    }

    Text {
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: ctrl.primary && !host.isPlaying ? host.sp(1) : 0
      text: ctrl.glyph
      font.family: Style.font.family
      font.pixelSize: host.sp(ctrl.primary ? 15 : 12)
      color: ctrl.primary ? Color.background : (ctrl.active ? Color.accent : (ctrlMouse.containsMouse && ctrl.available ? host.cTertiary : Color.foreground))
    }

    MouseArea {
      id: ctrlMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: ctrl.available ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (ctrl.available) ctrl.clicked()
    }
  }

  component SourceChip: Rectangle {
    // Inline components don't share the document's id scope, so the
    // widget is handed in explicitly.
    property var host
    id: chip
    property string label: ""
    property string iconSource: ""
    property string glyph: ""
    property bool selected: false
    property bool playing: false
    signal clicked()
    implicitHeight: host.sp(24)
    implicitWidth: chipRow.implicitWidth + host.sp(18)
    radius: height / 2
    color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
    border.color: selected ? Color.accent : Qt.rgba(1, 1, 1, 0.1)
    border.width: 1

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: host.sp(5)

      Image {
        visible: chip.iconSource !== ""
        anchors.verticalCenter: parent.verticalCenter
        source: chip.iconSource
        width: host.sp(13)
        height: width
        sourceSize.width: 32
        sourceSize.height: 32
      }
      Text {
        visible: chip.iconSource === "" && chip.glyph !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: chip.glyph
        font.family: Style.font.family
        font.pixelSize: host.sp(10)
        color: chip.selected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: chip.label
        font.family: Style.font.family
        font.pixelSize: host.sp(10)
        font.weight: chip.selected ? Font.Bold : Font.Normal
        color: chip.selected ? Color.accent : Color.foreground
      }
      Rectangle {
        visible: chip.playing
        anchors.verticalCenter: parent.verticalCenter
        width: host.sp(6)
        height: width
        radius: width / 2
        color: host.cLive
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  // Lyrics panel -- one definition, loaded either beside or below the
  // player depending on the card's shape (see lyricsMode).
  Component {
    id: lyricsPanelComp

    Rectangle {
      radius: mprisRoot.sp(12)
      color: mprisRoot.cSurface
      border.color: mprisRoot.themeColors ? mprisRoot.tint(mprisRoot.cSecondary, 0.22) : Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: mprisRoot.sp(10)
        spacing: mprisRoot.sp(6)

        RowLayout {
          Layout.fillWidth: true
          spacing: mprisRoot.sp(6)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(10)
            color: mprisRoot.cSecondary
          }
          Text {
            text: "LYRICS"
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(9)
            font.weight: Font.Bold
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }
          Item { Layout.fillWidth: true }

          // Timing nudge: "+" = lyrics earlier, "−" = later. Click the
          // readout to reset. Saved per track.
          Row {
            visible: mprisRoot.lyricsStatus === "ok" && mprisRoot.lyricsSynced
            spacing: mprisRoot.sp(3)

            Repeater {
              model: [
                { label: "\u2212", delta: -250 },
                { label: "", delta: 0 },
                { label: "+", delta: 250 }
              ]

              Rectangle {
                required property var modelData
                readonly property bool isReadout: modelData.delta === 0
                width: isReadout ? Math.max(mprisRoot.sp(30), nudgeText.implicitWidth + mprisRoot.sp(8)) : mprisRoot.sp(16)
                height: mprisRoot.sp(16)
                radius: height / 2
                color: nudgeMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (isReadout ? "transparent" : Qt.rgba(1, 1, 1, 0.06))
                border.color: !isReadout ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                border.width: 1

                Text {
                  id: nudgeText
                  anchors.centerIn: parent
                  text: parent.isReadout
                    ? ((mprisRoot.lyricsOffsetMs > 0 ? "+" : "") + (mprisRoot.lyricsOffsetMs / 1000).toFixed(2) + "s")
                    : modelData.label
                  font.family: Style.font.family
                  font.pixelSize: mprisRoot.sp(parent.isReadout ? 8 : 10)
                  font.weight: Font.Bold
                  color: (parent.isReadout && mprisRoot.lyricsOffsetMs === 0) ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35) : (parent.isReadout ? mprisRoot.cHighlight : Color.accent)
                }

                MouseArea {
                  id: nudgeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: mprisRoot.nudgeLyrics(modelData.delta)
                }
              }
            }
          }

          Text {
            visible: mprisRoot.lyricsStatus === "ok" && !mprisRoot.lyricsSynced
            text: mprisRoot.lyricsSource
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(8)
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
            elide: Text.ElideRight
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Text {
            anchors.centerIn: parent
            width: parent.width
            visible: mprisRoot.lyricsStatus !== "ok"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
              switch (mprisRoot.lyricsStatus) {
                case "loading": return "Finding lyrics..."
                case "instrumental": return "♪ Instrumental ♪"
                case "none": return "No lyrics found for this track"
                case "error": return "Couldn't reach the lyrics service"
                default: return "Lyrics appear here while something plays"
              }
            }
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(11)
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }

          ListView {
            id: lyricsView
            objectName: "lyricsView"
            anchors.fill: parent
            visible: mprisRoot.lyricsStatus === "ok"
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: mprisRoot.sp(6 * mprisRoot.lyricsFontScale)
            model: mprisRoot.lyricsLines

            // Follow the sung line, but let a manual scroll stick for a bit.
            property bool userScrolled: false
            currentIndex: mprisRoot.currentLyricIndex
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: if (!userScrolled) followLine()
            onModelChanged: { userScrolled = false; positionViewAtBeginning() }
            onMovementStarted: { userScrolled = true; resumeFollow.restart() }
            // Resizing rescales every line; re-centre instead of waiting for
            // the next line change.
            onHeightChanged: if (!userScrolled) Qt.callLater(followLine)
            onContentHeightChanged: if (!userScrolled) Qt.callLater(followLine)

            // Let ListView compute the centred position (its own delegate
            // geometry estimates are only right from the inside), then
            // animate there from where we were.
            function followLine() {
              if (currentIndex < 0) return
              followAnim.stop()
              var from = contentY
              positionViewAtIndex(currentIndex, ListView.Center)
              var to = contentY
              if (Math.abs(to - from) < 1) return
              contentY = from
              followAnim.from = from
              followAnim.to = to
              followAnim.start()
            }

            NumberAnimation {
              id: followAnim
              target: lyricsView
              property: "contentY"
              duration: 380
              easing.type: Easing.OutCubic
            }

            // A font-size change re-lays-out every line over a few passes, so
            // a centre computed mid-way aims at stale positions. Snap again
            // once the new layout has settled.
            Connections {
              target: mprisRoot
              function onLyricsFontScaleChanged() { lyricsView.userScrolled = false; resnap.count = 0; resnap.restart() }
            }

            Timer {
              id: resnap
              property int count: 0
              interval: 150
              onTriggered: {
                followAnim.stop()
                if (lyricsView.currentIndex >= 0) lyricsView.positionViewAtIndex(lyricsView.currentIndex, ListView.Center)
                if (++count < 3) restart()
              }
            }

            Timer {
              id: resumeFollow
              interval: 4000
              onTriggered: { lyricsView.userScrolled = false; lyricsView.followLine() }
            }

            delegate: Text {
              required property var modelData
              required property int index
              readonly property bool current: index === mprisRoot.currentLyricIndex
              readonly property bool past: mprisRoot.lyricsSynced && index < mprisRoot.currentLyricIndex
              width: ListView.view.width
              // Current line sweeps sung characters into the accent colour,
              // shading toward the secondary hue along the line.
              readonly property string lineText: modelData.text === "" ? "♪" : modelData.text
              textFormat: current ? Text.StyledText : Text.PlainText
              text: {
                if (!current) return lineText
                var n = Math.round(lineText.length * mprisRoot.currentLineProgress)
                return mprisRoot.sweepHtml(lineText.slice(0, n), lineText.length)
                  + "<font color=\"" + Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55) + "\">" + mprisRoot.escapeHtml(lineText.slice(n)) + "</font>"
              }
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignLeft
              font.family: Style.font.family
              font.pixelSize: mprisRoot.sp((current ? 13 : 11) * mprisRoot.lyricsFontScale)
              font.weight: current ? Font.Bold : Font.Normal
              color: past && mprisRoot.themeColors ? mprisRoot.cTertiary : Color.foreground
              opacity: !mprisRoot.lyricsSynced ? 0.8 : (current ? 1.0 : (past ? 0.35 : 0.55))
              Behavior on opacity { NumberAnimation { duration: 200 } }

              // Click a synced line to jump there.
              MouseArea {
                anchors.fill: parent
                enabled: mprisRoot.lyricsSynced && modelData.t >= 0 && mprisRoot.lengthSec > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mprisRoot.seekToFrac((modelData.t / 1000) / mprisRoot.lengthSec)
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼️ Layout
  // ---------------------------------------------------------------------------
  RowLayout {
    anchors.fill: parent
    anchors.margins: mprisRoot.sp(16)
    spacing: mprisRoot.sp(14)

    HoverHandler {
      id: panelHover
      onHoveredChanged: mprisRoot.updateKeyboardFocusForHover()
    }

    // ===== Main column: record + info/progress/controls, visualizer, sources
    ColumnLayout {
      // Explicit width (the same mainWidth uiScale is derived from) rather
      // than content-driven sizing, which let long rows push this column
      // under the lyrics panel.
      Layout.fillWidth: !mprisRoot.lyricsSide
      Layout.fillHeight: true
      Layout.preferredWidth: mprisRoot.mainWidth
      Layout.maximumWidth: mprisRoot.lyricsSide ? mprisRoot.mainWidth : Number.POSITIVE_INFINITY
      Layout.minimumWidth: 0
      spacing: mprisRoot.sp(10)

      RowLayout {
        id: topRow
        Layout.fillWidth: true
        spacing: mprisRoot.sp(14)

        // ---- Spinning record
        Item {
          id: recordBox
          readonly property real size: Math.max(48, Math.min(infoColumn.implicitHeight, mprisRoot.mainWidth * 0.36, mprisRoot.height * 0.55))
          Layout.preferredWidth: size
          Layout.preferredHeight: size
          Layout.alignment: Qt.AlignTop

          // Turntable-style spin-up/spin-down instead of a hard start/stop.
          property real speed: (mprisRoot.spinRecord && mprisRoot.isPlaying) ? 120 : 0 // deg/sec (~20 rpm)
          Behavior on speed { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

          FrameAnimation {
            running: recordBox.speed > 0.5
            onTriggered: disc.rotation = (disc.rotation + recordBox.speed * frameTime) % 360
          }

          Item {
            id: disc
            anchors.fill: parent

            // Wireframe vinyl: accent outlines only (rim, grooves, label ring,
            // spindle) plus a few brighter groove arcs so the spin reads.
            Canvas {
              id: vinylCanvas
              anchors.fill: parent
              property color stroke: Color.accent
              property color stroke2: mprisRoot.cSecondary
              property color stroke3: mprisRoot.cTertiary
              onStrokeChanged: requestPaint()
              onStroke2Changed: requestPaint()
              onStroke3Changed: requestPaint()
              onWidthChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                var r = width / 2
                var c = vinylCanvas.stroke
                function rgba(a, col) { var k = col || c; return "rgba(" + Math.round(k.r * 255) + "," + Math.round(k.g * 255) + "," + Math.round(k.b * 255) + "," + a + ")" }
                var c2 = vinylCanvas.stroke2, c3 = vinylCanvas.stroke3
                ctx.reset()
                var lw = Math.max(1, r * 0.018)
                // rim
                ctx.lineWidth = lw * 1.4
                ctx.strokeStyle = rgba(0.95)
                ctx.beginPath(); ctx.arc(r, r, r - lw, 0, Math.PI * 2); ctx.stroke()
                // grooves
                ctx.lineWidth = Math.max(0.6, lw * 0.5)
                var n = 0
                for (var g = r * 0.5; g < r * 0.9; g += r * 0.065, n++) {
                  ctx.strokeStyle = rgba(0.18 + 0.1 * (n % 2))
                  ctx.beginPath(); ctx.arc(r, r, g, 0, Math.PI * 2); ctx.stroke()
                }
                // highlight arcs (rotate with the disc)
                ctx.lineWidth = lw
                ctx.strokeStyle = rgba(0.9, c2)
                ctx.beginPath(); ctx.arc(r, r, r * 0.8, -0.35, 0.45); ctx.stroke()
                ctx.strokeStyle = rgba(0.9, c3)
                ctx.beginPath(); ctx.arc(r, r, r * 0.64, Math.PI - 0.3, Math.PI + 0.5); ctx.stroke()
                ctx.strokeStyle = rgba(0.6, c2)
                ctx.beginPath(); ctx.arc(r, r, r * 0.87, Math.PI * 0.55, Math.PI * 0.8); ctx.stroke()
                // label ring
                ctx.lineWidth = lw * 1.2
                ctx.strokeStyle = rgba(0.95, c2)
                ctx.beginPath(); ctx.arc(r, r, r * 0.42, 0, Math.PI * 2); ctx.stroke()
                // spindle
                ctx.lineWidth = Math.max(1, lw * 0.8)
                ctx.beginPath(); ctx.arc(r, r, Math.max(2, r * 0.05), 0, Math.PI * 2); ctx.stroke()
              }
            }

            // Label: album art inside the ring (optional), else a line-art note.
            ClippingRectangle {
              anchors.centerIn: parent
              // just inside the label ring (ring radius 0.42r = 0.21w)
              width: parent.width * 0.4
              height: width
              radius: width / 2
              color: "transparent"
              visible: mprisRoot.showLabelArt && labelArt.status === Image.Ready && mprisRoot.artUrl !== ""

              Image {
                id: labelArt
                anchors.fill: parent
                source: mprisRoot.showLabelArt ? mprisRoot.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
                opacity: 0.85
              }
            }

            Text {
              anchors.centerIn: parent
              visible: !(mprisRoot.showLabelArt && labelArt.status === Image.Ready && mprisRoot.artUrl !== "")
              text: "\uf001"
              font.family: Style.font.family
              font.pixelSize: parent.width * 0.14
              color: mprisRoot.cSecondary
              opacity: 0.9
            }

            // spindle dot over the art
            Rectangle {
              anchors.centerIn: parent
              width: Math.max(4, parent.width * 0.05)
              height: width
              radius: width / 2
              color: "transparent"
              border.color: Color.accent
              border.width: 1
            }
          }
        }

        // ---- Track info, progress, controls
        ColumnLayout {
          id: infoColumn
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: mprisRoot.sp(4)

          RowLayout {
            Layout.fillWidth: true
            spacing: mprisRoot.sp(6)

            Text {
              Layout.fillWidth: true
              text: mprisRoot.trackTitle
              font.family: Style.font.family
              font.pixelSize: mprisRoot.sp(15)
              font.weight: Font.Bold
              color: Color.foreground
              elide: Text.ElideRight
            }

            // Muted indicator (M while hovering, or click it to unmute)
            Text {
              visible: mprisRoot.appMuted
              text: String.fromCodePoint(0xf0581) // md-volume-off
              font.family: Style.font.family
              font.pixelSize: mprisRoot.sp(13)
              color: Color.urgent

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: mprisRoot.toggleMute()
              }
            }
          }

          Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: mprisRoot.trackArtist
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(12)
            color: mprisRoot.cSecondary
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            visible: mprisRoot.albumVisible && text !== ""
            text: mprisRoot.trackAlbum
            font.family: Style.font.family
            font.pixelSize: mprisRoot.sp(10)
            color: mprisRoot.themeColors ? mprisRoot.tint(mprisRoot.cTertiary, 0.8) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
            elide: Text.ElideRight
          }

          // Progress bar (click/drag to seek, wheel = +/-5s)
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: mprisRoot.sp(4)
            spacing: mprisRoot.sp(8)
            visible: mprisRoot.hasPlayer

            Text {
              text: mprisRoot.formatTime(mprisRoot.seeking ? mprisRoot.seekPreviewFrac * mprisRoot.lengthSec : mprisRoot.positionSec)
              font.family: Style.font.family
              font.pixelSize: mprisRoot.sp(9)
              color: mprisRoot.themeColors ? mprisRoot.tint(mprisRoot.cTertiary, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }

            Rectangle {
              id: seekTrack
              Layout.fillWidth: true
              implicitHeight: Math.max(4, mprisRoot.sp(5))
              radius: height / 2
              color: Qt.rgba(1, 1, 1, 0.12)

              readonly property real frac: mprisRoot.lengthSec > 0
                ? (mprisRoot.seeking ? mprisRoot.seekPreviewFrac : Math.min(1, mprisRoot.positionSec / mprisRoot.lengthSec))
                : 0

              Rectangle {
                height: parent.height
                width: parent.width * seekTrack.frac
                radius: parent.radius
                color: Color.accent
                gradient: mprisRoot.themeColors ? seekGradient : null
                Gradient {
                  id: seekGradient
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: mprisRoot.cPrimary }
                  GradientStop { position: 1; color: mprisRoot.cSecondary }
                }
                Behavior on width {
                  enabled: !mprisRoot.seeking
                  NumberAnimation { duration: 250 }
                }
              }

              Rectangle {
                visible: mprisRoot.lengthSec > 0 && (seekMouse.containsMouse || mprisRoot.seeking)
                x: Math.max(0, Math.min(parent.width - width, parent.width * seekTrack.frac - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(9, mprisRoot.sp(11))
                height: width
                radius: width / 2
                color: mprisRoot.themeColors ? mprisRoot.cHighlight : Color.accent
                border.color: "#ffffff"
                border.width: 1.5
              }

              MouseArea {
                id: seekMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: mprisRoot.hasPlayer && mprisRoot.activePlayer.canSeek && mprisRoot.lengthSec > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function frac(mx) { return Math.max(0, Math.min(1, (mx - 6) / seekTrack.width)) }
                onPressed: function(mouse) { mprisRoot.seeking = true; mprisRoot.seekPreviewFrac = frac(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) mprisRoot.seekPreviewFrac = frac(mouse.x) }
                onReleased: function(mouse) {
                  mprisRoot.seekToFrac(frac(mouse.x))
                  mprisRoot.seeking = false
                }
                onCanceled: mprisRoot.seeking = false
                onWheel: function(wheel) {
                  mprisRoot.seekBy(wheel.angleDelta.y > 0 ? 5 : -5)
                  wheel.accepted = true
                }
              }
            }

            Text {
              // Browsers often publish no length (live/unknown) -- don't claim 0:00.
              text: mprisRoot.lengthSec > 0 ? mprisRoot.formatTime(mprisRoot.lengthSec) : "--:--"
              font.family: Style.font.family
              font.pixelSize: mprisRoot.sp(9)
              color: mprisRoot.themeColors ? mprisRoot.tint(mprisRoot.cTertiary, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }
          }

          // Controls: prev / play-pause / next
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: mprisRoot.sp(2)
            spacing: mprisRoot.sp(10)
            visible: mprisRoot.hasPlayer

            CtrlButton {
              host: mprisRoot
              glyph: ""
              available: mprisRoot.hasPlayer && mprisRoot.activePlayer.canGoPrevious
              onClicked: mprisRoot.activePlayer.previous()
            }
            CtrlButton {
              host: mprisRoot
              primary: true
              glyph: mprisRoot.isPlaying ? "" : ""
              available: mprisRoot.hasPlayer && mprisRoot.activePlayer.canTogglePlaying
              onClicked: mprisRoot.activePlayer.togglePlaying()
            }
            CtrlButton {
              host: mprisRoot
              glyph: ""
              available: mprisRoot.hasPlayer && mprisRoot.activePlayer.canGoNext
              onClicked: mprisRoot.activePlayer.next()
            }
          }
        }
      }

      // ---- Lyrics below the controls (narrow-but-tall sizes)
      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        active: mprisRoot.lyricsBelow
        visible: active
        sourceComponent: lyricsPanelComp
      }

      // ---- Visualizer (fills whatever height is left; a slim strip when
      // the lyrics are taking that space)
      Item {
        id: vizBox
        Layout.fillWidth: true
        Layout.fillHeight: !mprisRoot.lyricsBelow
        Layout.preferredHeight: mprisRoot.lyricsBelow ? mprisRoot.sp(28) : -1
        Layout.minimumHeight: mprisRoot.visualizerVisible ? mprisRoot.sp(18) : 0
        visible: mprisRoot.visualizerVisible

        Row {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          height: parent.height
          readonly property real gap: Math.max(2, mprisRoot.sp(3))
          readonly property real barW: Math.max(2, (vizBox.width - gap * (mprisRoot.barCount - 1)) / mprisRoot.barCount)
          spacing: gap

          Repeater {
            model: mprisRoot.barCount

            Rectangle {
              required property int index
              readonly property real v: mprisRoot.bars.length > index ? mprisRoot.bars[index] : 0
              anchors.bottom: parent.bottom
              width: parent.barW
              height: Math.max(width, v * vizBox.height)
              radius: Math.min(width / 2, mprisRoot.sp(3))
              color: mprisRoot.barColor(index)
              opacity: mprisRoot.isPlaying ? (0.45 + 0.5 * v) : 0.25
              Behavior on height { NumberAnimation { duration: 60 } }
            }
          }
        }
      }

      // Keeps sources pinned to the bottom when the visualizer is hidden.
      Item {
        Layout.fillHeight: true
        visible: !mprisRoot.visualizerVisible && !mprisRoot.lyricsBelow
      }

      // ---- MPRIS source switcher
      Flickable {
        id: sourceFlick
        Layout.fillWidth: true
        Layout.preferredHeight: sourceRow.implicitHeight
        visible: mprisRoot.sourcesVisible
        contentWidth: sourceRow.implicitWidth
        contentHeight: sourceRow.implicitHeight
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // Wheel cycles the selected source (accumulated so smooth-scrolling
        // touchpads step once per notch-equivalent) and keeps it in view.
        MouseArea {
          anchors.fill: sourceRow
          z: 1
          acceptedButtons: Qt.NoButton
          onWheel: function(wheel) {
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            mprisRoot.wheelAccum += d
            while (Math.abs(mprisRoot.wheelAccum) >= 120) {
              var dir = mprisRoot.wheelAccum > 0 ? -1 : 1
              mprisRoot.wheelAccum -= (dir < 0 ? 120 : -120)
              mprisRoot.cycleSource(dir)
            }
            Qt.callLater(sourceFlick.revealSelected)
            wheel.accepted = true
          }
        }

        function revealSelected() {
          for (var i = 0; i < sourceRow.children.length; i++) {
            var c = sourceRow.children[i]
            if (c.selected === true) {
              if (c.x < contentX) contentX = c.x
              else if (c.x + c.width > contentX + width) contentX = Math.min(contentWidth - width, c.x + c.width - width)
              return
            }
          }
        }

        Row {
          id: sourceRow
          spacing: mprisRoot.sp(6)


          SourceChip {
            host: mprisRoot
            label: "Auto"
            glyph: String.fromCodePoint(0xf0bc9)
            selected: mprisRoot.preferredPlayerIdentity === ""
            onClicked: mprisRoot.selectPlayer("")
          }

          Repeater {
            model: mprisRoot.players

            SourceChip {
              host: mprisRoot
              required property var modelData
              label: mprisRoot.playerIdentity(modelData)
              iconSource: mprisRoot.playerIcon(modelData)
              glyph: ""
              selected: mprisRoot.preferredPlayerIdentity === label
              playing: modelData.playbackState === MprisPlaybackState.Playing
              onClicked: mprisRoot.selectPlayer(label)
            }
          }
        }
      }
    }

    // ===== Lyrics on the right (wide sizes)
    Loader {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 0
      Layout.minimumWidth: 0
      active: mprisRoot.lyricsSide
      visible: active
      sourceComponent: lyricsPanelComp
    }
  }

  // ---------------------------------------------------------------------------
  // ✋ Edit-mode chrome (close + move grip), top-right overlay
  // ---------------------------------------------------------------------------
  Row {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(8)
    spacing: Style.space(6)
    visible: rootRef && rootRef.layoutEditMode
    z: 10

    Rectangle {
      width: 22
      height: 22
      radius: 11
      color: closeMprisMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(0, 0, 0, 0.45)
      border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.5)
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: ""
        font.family: Style.font.family
        font.pixelSize: 10
        color: Color.urgent
      }

      MouseArea {
        id: closeMprisMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (rootRef && rootRef.toggleWidgetEnabled) rootRef.toggleWidgetEnabled(mprisRoot.widgetId, false, mprisRoot.monitorName)
        }
      }
    }

    Rectangle {
      width: 22
      height: 22
      radius: 11
      color: gripMprisMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(0, 0, 0, 0.45)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: ""
        font.family: Style.font.family
        font.pixelSize: 10
        color: Color.accent
      }

      MouseArea {
        id: gripMprisMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeAllCursor
        drag.target: mprisRoot.targetItem
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 10
        drag.maximumX: Math.max(10, mprisRoot.screenWidth - mprisRoot.width - 10)
        drag.minimumY: 10
        drag.maximumY: Math.max(10, mprisRoot.screenHeight - mprisRoot.height - 10)

        onPressed: mprisRoot.customGripDragging = true
        onReleased: function() {
          mprisRoot.customGripDragging = false
          var maxX = Math.max(10, mprisRoot.screenWidth - mprisRoot.width - 10)
          var maxY = Math.max(10, mprisRoot.screenHeight - mprisRoot.height - 10)
          var snappedX = Math.max(10, Math.min(maxX, mprisRoot.snapVal(mprisRoot.targetItem.x)))
          var snappedY = Math.max(10, Math.min(maxY, mprisRoot.snapVal(mprisRoot.targetItem.y)))
          mprisRoot.targetItem.x = snappedX
          mprisRoot.targetItem.y = snappedY
          if (rootRef && rootRef.saveWidgetPos) {
            rootRef.saveWidgetPos(mprisRoot.widgetId, snappedX, snappedY, mprisRoot.snapVal(mprisRoot.width), mprisRoot.snapVal(mprisRoot.height), mprisRoot.monitorName)
          }
        }
        onCanceled: mprisRoot.customGripDragging = false
      }
    }
  }
}
