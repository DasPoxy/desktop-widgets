import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// ---------------------------------------------------------------------------
// 👁️ Abyss Warden -- an anime eye that only shows itself while the screen is
// being recorded (Omarchy's recorder, other CLI recorders, or any portal
// screen capture: OBS, Discord, browser screen share). Awake, it glances
// between the mouse, windows whose contents change, random spots, and
// staring straight out at the viewer, and blinks now and then.
// Lives in its card by default; Free-Floating mode lets it drift around the
// screen instead (click-through overlay, sized like the card). One eye or a
// pair, in any of the AbyssEye styles.
// ---------------------------------------------------------------------------
WidgetCard {
  id: warden

  widgetId: "abyss_warden"
  title: "Abyss Warden"
  icon: "󰈈"
  showHeader: false

  width: 280
  height: 170
  minWidth: 140
  minHeight: 90
  maxWidth: Math.min(900, screenWidth - 40)
  maxHeight: Math.min(600, screenHeight - 80)
  resizable: true
  frameless: !showCard
  menuWidth: 300

  // ---------------------------------------------------------------------------
  // ⚙️ Settings
  // ---------------------------------------------------------------------------
  property string themeId: "system"
  property bool floating: false
  property bool showCard: false
  property bool pair: false
  property string eyeStyle: "classic"
  property bool examineClicks: true
  property string irisStyle: "auto"
  // Which menu sections are expanded, e.g. { style: true }. All start folded.
  property var openSections: ({})
  property bool chaseFastMouse: true

  function applySavedSettings() {
    themeId = getSetting("themeId", "system")
    floating = getSetting("floating", false)
    showCard = getSetting("showCard", false)
    pair = getSetting("pair", false)
    eyeStyle = getSetting("eyeStyle", "classic")
    examineClicks = getSetting("examineClicks", true)
    irisStyle = getSetting("irisStyle", "auto")
    openSections = getSetting("openSections", {})
    chaseFastMouse = getSetting("chaseFastMouse", true)
  }
  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function toggleSetting(key) {
    warden[key] = !warden[key]
    warden.saveSetting(key, warden[key])
  }
  function setPair(v) {
    warden.pair = v
    warden.saveSetting("pair", v)
  }
  function setIrisStyle(id) {
    warden.irisStyle = id
    warden.saveSetting("irisStyle", id)
  }
  function toggleSection(key) {
    var next = Object.assign({}, warden.openSections)
    next[key] = !next[key]
    warden.openSections = next
    warden.saveSetting("openSections", next)
  }
  function nameOf(list, id) {
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i].name
    return ""
  }

  // Patterns live in AbyssEye.qml; these are the menu names, in menu order.
  readonly property var irisStyles: [
    { id: "auto", name: "Match Eye" },
    { id: "cel", name: "Cel" },
    { id: "sparkle", name: "Sparkle" },
    { id: "star", name: "Starlight" },
    { id: "rings", name: "Rings" },
    { id: "blossom", name: "Blossom" },
    { id: "spiral", name: "Spiral" },
    { id: "hollow", name: "Hollow" },
    { id: "crosshair", name: "Crosshair" },
    { id: "heart", name: "Heart" },
    { id: "pinpoint", name: "Pinpoint" },
    { id: "slit", name: "Slit" }
  ]

  function setEyeStyle(id) {
    warden.eyeStyle = id
    warden.saveSetting("eyeStyle", id)
  }

  // Shapes live in AbyssEye.qml; these are the menu names, in menu order.
  readonly property var eyeStyles: [
    { id: "classic", name: "Classic" },
    { id: "sparkle", name: "Sparkle" },
    { id: "starry", name: "Starry" },
    { id: "sharp", name: "Sharp" },
    { id: "glare", name: "Glare" },
    { id: "shocked", name: "Shocked" },
    { id: "hypnotic", name: "Hypnotic" },
    { id: "shoujo", name: "Shoujo" },
    { id: "angular", name: "Angular" }
  ]

  function setTheme(id) {
    warden.themeId = id
    warden.saveSetting("themeId", id)
  }

  // ---------------------------------------------------------------------------
  // 🎨 Themes -- "system" follows the Omarchy theme; the rest are fixed.
  // ---------------------------------------------------------------------------
  ThemePalette {
    id: pal
    active: true
  }

  // Flat riso-print palettes: sclera = paper, scleraShade = the cel shadow
  // tone, lash = coloured ink (never pure black), glow = the offset print
  // colour (usually a contrasting ink).
  readonly property var systemTheme: ({
    id: "system", name: "System Theme",
    sclera: String(Qt.tint("#f3ead9", Qt.alpha(pal.secondary, 0.05))),
    scleraShade: String(Qt.tint("#aebccb", Qt.alpha(pal.tertiary, 0.35))),
    irisDark: String(Qt.darker(Color.accent, 2.4)),
    iris: String(Color.accent),
    irisLight: String(pal.mixColor(Qt.lighter(Color.accent, 1.5), pal.highlight, 0.3)),
    pupil: String(Qt.tint("#16152b", Qt.alpha(pal.secondary, 0.2))),
    highlight: "#fff7ea",
    lash: String(Qt.tint("#16152b", Qt.alpha(pal.secondary, 0.25))),
    glow: String(pal.tertiary),
    slit: false
  })

  readonly property var presetThemes: [
    // From the reference art: teal room / hot-pink desk / navy ink.
    { id: "riso", name: "Riso Room", sclera: "#f2e6d0", scleraShade: "#8fc5b8", irisDark: "#8c1f3f", iris: "#e8456b", irisLight: "#ffb3a7", pupil: "#1c1f3f", highlight: "#fff7ea", lash: "#1c1f3f", glow: "#2a9d8f", slit: false },
    // Magenta canopy over a teal sky.
    { id: "petal", name: "Petal Dusk", sclera: "#efe3e6", scleraShade: "#c79bb5", irisDark: "#7a1f4b", iris: "#ff5f8f", irisLight: "#ffc2d1", pupil: "#2b1433", highlight: "#fffafc", lash: "#2b1433", glow: "#1f8a78", slit: false },
    // Teal sky, orange field, red pinwheel.
    { id: "pinwheel", name: "Pinwheel Summer", sclera: "#f4ead8", scleraShade: "#8fb8b8", irisDark: "#7d1d3f", iris: "#e84a5f", irisLight: "#ffb38a", pupil: "#23204a", highlight: "#fffaf0", lash: "#23204a", glow: "#f29e4c", slit: false },
    { id: "abyss", name: "Abyssal Violet", sclera: "#efe8f3", scleraShade: "#b7a8d6", irisDark: "#2a0b4d", iris: "#7b2ff7", irisLight: "#e0aaff", pupil: "#150826", highlight: "#ffffff", lash: "#241046", glow: "#ff6fa3", slit: false },
    { id: "crimson", name: "Blood Moon", sclera: "#f3e6e0", scleraShade: "#d9a3a3", irisDark: "#4a0610", iris: "#c1121f", irisLight: "#ff8f8f", pupil: "#1a0508", highlight: "#fff4f0", lash: "#2a0d1a", glow: "#2a9d8f", slit: false },
    { id: "serpent", name: "Jade Serpent", sclera: "#f1ecc8", scleraShade: "#c9bf7e", irisDark: "#0b3d20", iris: "#2dc653", irisLight: "#c7f9cc", pupil: "#08170d", highlight: "#fbfff5", lash: "#10281a", glow: "#f2c14e", slit: true },
    { id: "dragon", name: "Gilded Dragon", sclera: "#f6ecd0", scleraShade: "#e0b870", irisDark: "#6a3300", iris: "#f4a261", irisLight: "#ffe8a3", pupil: "#1f0f03", highlight: "#fffaf0", lash: "#2d1606", glow: "#e84a5f", slit: true },
    { id: "frost", name: "Frostbound", sclera: "#eef4f6", scleraShade: "#9fc3d6", irisDark: "#0b3954", iris: "#4cc9f0", irisLight: "#e0fbfc", pupil: "#0a1a2a", highlight: "#ffffff", lash: "#0f2438", glow: "#ff8fab", slit: false },
    { id: "sakura", name: "Sakura Dream", sclera: "#fbf0f3", scleraShade: "#e5a9c4", irisDark: "#6d1b4d", iris: "#ff70a6", irisLight: "#ffd6e8", pupil: "#2a0c1b", highlight: "#ffffff", lash: "#3a1230", glow: "#2ec4b6", slit: false },
    { id: "void", name: "Hollow Void", sclera: "#16161d", scleraShade: "#2c2c38", irisDark: "#4a4a58", iris: "#c9c9d6", irisLight: "#ffffff", pupil: "#000000", highlight: "#ffffff", lash: "#000000", glow: "#c8c8ff", slit: false }
  ]

  readonly property var allThemes: [systemTheme].concat(presetThemes)
  readonly property var theme: {
    for (var i = 0; i < allThemes.length; i++) {
      if (allThemes[i].id === themeId) return allThemes[i]
    }
    return systemTheme
  }

  // ---------------------------------------------------------------------------
  // 🎥 Recording watch (get-abyss-watch.sh)
  // ---------------------------------------------------------------------------
  property bool recording: false
  property var recSources: []
  property bool previewing: false
  readonly property bool awake: recording || previewing
  readonly property bool editing: !!(rootRef && rootRef.layoutEditMode)

  property var monitorsMap: ({})
  property real cursorX: 0
  property real cursorY: 0
  property real lastCursorMove: 0

  readonly property string watchScriptPath: {
    var u = Qt.resolvedUrl("../get-abyss-watch.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function sendActive() {
    if (watchProc.running) watchProc.write("active " + (warden.awake ? "1" : "0") + "\n")
  }

  Process {
    id: watchProc
    command: [warden.watchScriptPath]
    running: true
    stdinEnabled: true
    onStarted: warden.sendActive()
    onExited: watchRestart.restart()
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        var msg
        try { msg = JSON.parse(str) } catch (e) { return }
        if (msg.type === "rec") {
          warden.recording = !!msg.recording
          warden.recSources = msg.sources || []
        } else if (msg.type === "monitors") {
          warden.monitorsMap = msg.list || {}
        } else if (msg.type === "cursor") {
          warden.handleCursor(msg.x, msg.y)
        } else if (msg.type === "activity") {
          warden.handleActivity(msg.x, msg.y)
        } else if (msg.type === "windows") {
          warden.windowsList = msg.list || []
        } else if (msg.type === "click") {
          warden.handleClick(msg.x, msg.y, msg.win || null)
        }
      }
    }
  }

  // Watcher died (shouldn't happen) -- bring it back.
  Timer {
    id: watchRestart
    interval: 3000
    onTriggered: watchProc.running = true
  }

  Timer {
    id: previewTimer
    interval: 15000
    onTriggered: warden.previewing = false
  }

  function startPreview() {
    warden.previewing = true
    previewTimer.restart()
  }

  // ---------------------------------------------------------------------------
  // 🧠 Behaviour -- modes: cursor (track the mouse), window (look at a window
  // that just changed), wander (quick saccades to random spots), stare
  // (straight at the viewer, pupils dilated), travel (floating: look where
  // it's drifting to), examine (a click: narrow in on the spot, then scan
  // the clicked window; floating flies over first), hurry (rapid mouse
  // movement: freeze and stare, pupils snap small; floating rushes over),
  // scan (instead of following the mouse it sometimes wanders off to trace
  // the edge of a window or check the bar, then comes back to the mouse).
  // ---------------------------------------------------------------------------
  property string mode: "wander"
  property real lookX: 0          // global point for window/travel modes
  property real lookY: 0
  property real wanderX: 0        // direction for wander mode, -1..1
  property real wanderY: 0
  property real jitterX: 0
  property real jitterY: 0
  property real lastActivity: 0
  // Scrutinising squint (0..1), narrows the eye while examining.
  property real squint: 0
  Behavior on squint { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  readonly property real shownOpenness: openness * (1 - 0.22 * squint)

  property real gazeX: 0
  property real gazeY: 0
  property real openness: 0
  property real pupil: 1
  property real pupilTarget: 1
  property real glowLevel: 0

  onAwakeChanged: {
    sendActive()
    blinkAnim.stop()
    if (awake) {
      if (floating) placeFloatRandomly()
      sleepAnim.stop()
      wakeAnim.restart()
      pickMode()
      blinkTimer.restart()
    } else {
      wakeAnim.stop()
      modeTimer.stop()
      blinkTimer.stop()
      floatAnim.stop()
      driftTimer.stop()
      rushDelay.stop()
      examineLook.stop()
      squint = 0
      mode = "wander"
      sleepAnim.restart()
    }
  }

  // Slow, creepy open: crack, pause, then wide.
  SequentialAnimation {
    id: wakeAnim
    ParallelAnimation {
      NumberAnimation { target: warden; property: "openness"; to: 0.3; duration: 450; easing.type: Easing.OutCubic }
      NumberAnimation { target: warden; property: "glowLevel"; to: 0.5; duration: 450 }
    }
    PauseAnimation { duration: 280 }
    ParallelAnimation {
      NumberAnimation { target: warden; property: "openness"; to: 1; duration: 520; easing.type: Easing.OutBack }
      NumberAnimation { target: warden; property: "glowLevel"; to: 1; duration: 520 }
    }
  }

  ParallelAnimation {
    id: sleepAnim
    NumberAnimation { target: warden; property: "openness"; to: 0; duration: 450; easing.type: Easing.InCubic }
    NumberAnimation { target: warden; property: "glowLevel"; to: 0; duration: 450 }
  }

  SequentialAnimation {
    id: blinkAnim
    property bool twice: false
    NumberAnimation { target: warden; property: "openness"; to: 0; duration: 70; easing.type: Easing.InQuad }
    NumberAnimation { target: warden; property: "openness"; to: 1; duration: 130; easing.type: Easing.OutQuad }
    ScriptAction {
      script: {
        if (blinkAnim.twice) { blinkAnim.twice = false; blinkAnim.restart() }
      }
    }
  }

  function blink() {
    if (!awake || wakeAnim.running || sleepAnim.running) return
    blinkAnim.twice = Math.random() < 0.18
    blinkAnim.restart()
  }

  Timer {
    id: blinkTimer
    interval: 3000
    onTriggered: {
      if (!warden.awake) return
      warden.blink()
      interval = 2200 + Math.random() * 5000
      restart()
    }
  }

  function pickMode() {
    squint = 0
    var recentMouse = Date.now() - lastCursorMove < 1500
    var r = Math.random()
    var cursorW = recentMouse ? 0.55 : 0.3
    if (r < cursorW) {
      // Now and then, get distracted before going back to the mouse.
      if (Math.random() < 0.3 && startSurvey()) return
      mode = "cursor"
    }
    else if (r < cursorW + 0.3) { mode = "wander"; saccade() }
    else mode = "stare"
    pupilTarget = mode === "stare" ? 1.28 : 1.0
    modeTimer.interval = 2400 + Math.random() * 3800
    modeTimer.restart()
  }

  function saccade() {
    var a = Math.random() * Math.PI * 2
    var m = 0.35 + Math.random() * 0.65
    wanderX = Math.cos(a) * m
    wanderY = Math.sin(a) * m
  }

  Timer {
    id: modeTimer
    interval: 3000
    onTriggered: {
      if (!warden.awake) return
      var wasBusy = warden.mode === "examine"
      warden.pickMode()
      if (wasBusy) warden.resumeDrift()
    }
  }

  Timer {
    running: warden.awake && warden.mode === "wander"
    interval: 900
    repeat: true
    onTriggered: {
      warden.saccade()
      interval = 600 + Math.random() * 1200
    }
  }

  // Tiny drift so a fixed gaze still looks alive.
  Timer {
    running: warden.awake
    interval: 350
    repeat: true
    onTriggered: {
      warden.jitterX = (Math.random() - 0.5) * 0.04
      warden.jitterY = (Math.random() - 0.5) * 0.04
    }
  }

  function handleActivity(x, y) {
    if (!awake || mode === "travel" || mode === "examine" || mode === "hurry" || mode === "scan") return
    var now = Date.now()
    if (now - lastActivity < 2500 || Math.random() > 0.8) return
    lastActivity = now
    lookX = x
    lookY = y
    mode = "window"
    // Startled: pupil snaps small, then relaxes.
    pupil = 0.72
    pupilTarget = 1.0
    modeTimer.interval = 2000 + Math.random() * 1600
    modeTimer.restart()
  }

  // --- Clicks: take an interest in what was clicked
  property real examineX: 0
  property real examineY: 0
  property var examineWin: null
  property bool examineSettled: false
  property real lastClick: 0

  function handleClick(x, y, win) {
    if (!awake || !examineClicks) return
    var now = Date.now()
    // A double-click (or clicks right next to each other) is one event.
    if (now - lastClick < 450 && Math.abs(x - examineX) + Math.abs(y - examineY) < 60) return
    lastClick = now
    examineX = x
    examineY = y
    examineWin = win
    lookX = x
    lookY = y
    mode = "examine"
    squint = 1
    pupil = 0.8            // quick focus...
    pupilTarget = 1.18     // ...then widen with interest
    blinkAnim.stop()
    modeTimer.stop()
    if (floating) {
      examineSettled = false
      driftTimer.stop()
      travelToExamine()
    } else {
      startExamining()
    }
  }

  function startExamining() {
    examineSettled = false
    examineLook.restart()   // hold on the click point first
    modeTimer.interval = 3200 + Math.random() * 2600
    modeTimer.restart()
  }

  // After a beat on the click point, scan around the clicked window.
  Timer {
    id: examineLook
    interval: 700
    onTriggered: if (warden.mode === "examine") warden.examineSettled = true
  }

  Timer {
    running: warden.awake && warden.mode === "examine" && warden.examineSettled
    interval: 700
    repeat: true
    onTriggered: {
      interval = 450 + Math.random() * 650
      var w = warden.examineWin
      if (Math.random() < 0.35) {
        warden.lookX = warden.examineX
        warden.lookY = warden.examineY
      } else if (w && w.w > 0) {
        warden.lookX = w.x + w.w * (0.1 + Math.random() * 0.8)
        warden.lookY = w.y + w.h * (0.1 + Math.random() * 0.8)
      } else {
        warden.lookX = warden.examineX + (Math.random() - 0.5) * 320
        warden.lookY = warden.examineY + (Math.random() - 0.5) * 220
      }
    }
  }

  // Floating: go and sit beside the click (on whichever side has room, a
  // little above), not on top of it.
  function travelToExamine() {
    var ox = monitor.x + reserved[0], oy = monitor.y + reserved[1]
    var side = (examineX - ox) > floatAreaW / 2 ? -1 : 1
    var cx = examineX + side * (width * 0.5 + 70)
    var cy = examineY - height * 0.45
    moveEyeTo(cx - ox - width / 2, cy - oy - height / 2, 950, Easing.OutCubic, "examine")
  }

  // --- Rapid mouse movement: stop, look, (floating) hurry over
  property real lastCursorT: 0
  property real cursorSpeed: 0
  property real lastRapid: 0
  readonly property real rapidSpeed: 4200   // px/s, smoothed -- a real flick, not normal use

  function handleCursor(x, y) {
    var dx = x - cursorX, dy = y - cursorY
    var dist = Math.sqrt(dx * dx + dy * dy)
    var now = Date.now()
    var dt = (now - lastCursorT) / 1000
    lastCursorT = now
    cursorX = x
    cursorY = y
    if (dist > 40) lastCursorMove = now
    if (dt <= 0 || dt > 0.4) { cursorSpeed = 0; return }
    cursorSpeed = cursorSpeed * 0.55 + (dist / dt) * 0.45
    if (awake && chaseFastMouse && cursorSpeed > rapidSpeed) handleRapidMovement()
  }

  function handleRapidMovement() {
    lastRapid = Date.now()
    if (mode === "hurry") return
    // Freeze and stare: whatever it was doing stops.
    mode = "hurry"
    squint = 0
    pupil = 0.62
    pupilTarget = 0.82
    blinkAnim.stop()
    openness = 1
    modeTimer.stop()
    examineLook.stop()
    if (floating) {
      floatAnim.stop()
      driftTimer.stop()
      rushDelay.restart()   // the "stop and look" beat, then hurry over
    }
  }

  Timer {
    id: rushDelay
    interval: 280
    onTriggered: if (warden.mode === "hurry") warden.rushToCursor()
  }

  // Stop short of the cursor, on the side the eye is coming from.
  function rushToCursor() {
    var c = eyeCenter()
    var dx = c.x - cursorX, dy = c.y - cursorY
    var d = Math.sqrt(dx * dx + dy * dy)
    if (d < 1) { dx = 1; dy = 0; d = 1 }
    var stand = Math.max(width, height) * 0.5 + 90
    if (d < stand + 40) return
    var tx = cursorX + dx / d * stand, ty = cursorY + dy / d * stand
    var ox = monitor.x + reserved[0], oy = monitor.y + reserved[1]
    moveEyeTo(tx - ox - width / 2, ty - oy - height / 2, 1500, Easing.OutQuad, "hurry")
  }

  // While the flurry lasts keep up with the cursor; once it has been calm
  // for a couple of seconds, go back to normal.
  Timer {
    running: warden.awake && warden.mode === "hurry"
    interval: 350
    repeat: true
    onTriggered: {
      var calm = Date.now() - warden.lastRapid
      if (calm > 2200) {
        warden.pickMode()
        warden.resumeDrift()
      } else if (warden.floating && !rushDelay.running && calm < 900) {
        warden.rushToCursor()
      }
    }
  }

  // --- Surveys: trace a window's edge or sweep along the bar
  property var windowsList: []
  property var scanPts: []
  property int scanIdx: 0
  property string scanKind: ""

  // Returns false when there's nothing to survey (caller falls back).
  function startSurvey() {
    var bar = barLine()
    var canEdge = windowsList.length > 0
    if (!canEdge && !bar) return false
    var pts = []
    if (canEdge && (!bar || Math.random() < 0.6)) {
      scanKind = "edge"
      var w = windowsList[Math.floor(Math.random() * windowsList.length)]
      var inset = 8
      var corners = [[w.x + inset, w.y + inset], [w.x + w.w - inset, w.y + inset],
                     [w.x + w.w - inset, w.y + w.h - inset], [w.x + inset, w.y + w.h - inset]]
      // Two adjacent edges, clockwise or back the other way.
      var start = Math.floor(Math.random() * 4), dir = Math.random() < 0.5 ? 1 : 3
      for (var e = 0; e < 2; e++) {
        var a = corners[(start + e * dir) % 4], b = corners[(start + (e + 1) * dir) % 4]
        for (var k = (e === 0 ? 0 : 1); k <= 5; k++) pts.push([a[0] + (b[0] - a[0]) * k / 5, a[1] + (b[1] - a[1]) * k / 5])
      }
    } else {
      scanKind = "bar"
      // Sweep part of the bar, left-to-right or back.
      var from = Math.random() * 0.4, to = 0.6 + Math.random() * 0.4
      if (Math.random() < 0.5) { var t = from; from = to; to = t }
      for (var i = 0; i <= 7; i++) pts.push([bar.x0 + (bar.x1 - bar.x0) * (from + (to - from) * i / 7), bar.y])
    }
    scanPts = pts
    scanIdx = 0
    lookX = pts[0][0]
    lookY = pts[0][1]
    mode = "scan"
    squint = 0.45
    pupilTarget = 1.05
    modeTimer.stop()
    if (floating) {
      driftTimer.stop()
      approachScan()
    }
    return true
  }

  // Middle line of the bar: whichever screen edge has a reserved strip.
  function barLine() {
    var m = monitor, r = reserved
    if (r[1] > 0) return { x0: m.x + 20, x1: m.x + m.w - 20, y: m.y + r[1] / 2 }
    if (r[3] > 0) return { x0: m.x + 20, x1: m.x + m.w - 20, y: m.y + m.h - r[3] / 2 }
    return null
  }

  // Floating: go and have a look -- right under the bar, or just beside the
  // first point of the window edge.
  function approachScan() {
    var ox = monitor.x + reserved[0], oy = monitor.y + reserved[1]
    var p = scanPts[scanIdx]
    if (scanKind === "bar") {
      var ny = reserved[1] > 0 ? 8 : floatAreaH - height - 8
      moveEyeTo(p[0] - ox - width / 2, ny, scanIdx === 0 ? 800 : 320, Easing.InOutSine, "scan")
    } else if (scanIdx === 0) {
      moveEyeTo(p[0] - ox - width / 2, p[1] - oy + 40, 800, Easing.OutCubic, "scan")
    }
  }

  Timer {
    running: warden.awake && warden.mode === "scan"
    interval: 500
    repeat: true
    onTriggered: {
      interval = 380 + Math.random() * 260
      warden.scanIdx++
      if (warden.scanIdx >= warden.scanPts.length) {
        warden.endSurvey()
        return
      }
      warden.lookX = warden.scanPts[warden.scanIdx][0]
      warden.lookY = warden.scanPts[warden.scanIdx][1]
      // Glide along under the bar while sweeping it.
      if (warden.floating && warden.scanKind === "bar") warden.approachScan()
    }
  }

  // Back to the mouse.
  function endSurvey() {
    mode = "cursor"
    squint = 0
    pupilTarget = 1.0
    modeTimer.interval = 2500 + Math.random() * 2000
    modeTimer.restart()
    resumeDrift()
  }

  // --- Geometry: where the eye is, in global (Hyprland) coordinates
  readonly property var monitor: {
    var m = monitorsMap[monitorName]
    if (m) return m
    for (var k in monitorsMap) return monitorsMap[k]
    return { x: 0, y: 0, w: screenWidth, h: screenHeight, reserved: [0, 0, 0, 0] }
  }
  readonly property var reserved: (monitor && monitor.reserved) ? monitor.reserved : [0, 0, 0, 0]
  readonly property real floatAreaW: Math.max(width, (monitor.w || screenWidth) - reserved[0] - reserved[2])
  readonly property real floatAreaH: Math.max(height, (monitor.h || screenHeight) - reserved[1] - reserved[3])

  function eyeCenter() {
    if (floating) {
      return {
        x: monitor.x + reserved[0] + floatX + width / 2,
        y: monitor.y + reserved[1] + floatY + height / 2
      }
    }
    var p = cardEye.mapToItem(null, cardEye.width / 2, cardEye.height / 2)
    return { x: monitor.x + p.x, y: monitor.y + p.y }
  }

  function directionTo(px, py) {
    var c = eyeCenter()
    var dx = px - c.x, dy = py - c.y
    var dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < 1) return { x: 0, y: 0 }
    var mag = dist / (dist + 220)
    return { x: dx / dist * mag, y: dy / dist * mag }
  }

  function tick(dt) {
    dt = Math.min(dt, 0.1)
    var tx = 0, ty = 0
    if (mode === "wander") {
      tx = wanderX; ty = wanderY
    } else if (mode === "cursor" || mode === "hurry") {
      var d = directionTo(cursorX, cursorY); tx = d.x; ty = d.y
    } else if (mode === "window" || mode === "travel" || mode === "examine" || mode === "scan") {
      var w = directionTo(lookX, lookY); tx = w.x; ty = w.y
    }
    tx += jitterX
    ty += jitterY
    // Following the mouse is smooth pursuit; everything else is a quick
    // saccade.
    // Scanning an edge is a slow, smooth trace.
    var k = 1 - Math.exp(-dt * (mode === "cursor" ? 9 : (mode === "hurry" ? 18 : (mode === "scan" ? 7 : 22))))
    gazeX += (tx - gazeX) * k
    gazeY += (ty - gazeY) * k
    pupil += (pupilTarget - pupil) * (1 - Math.exp(-dt * 5))
  }

  FrameAnimation {
    running: warden.awake || warden.openness > 0.001
    onTriggered: warden.tick(frameTime)
  }

  // ---------------------------------------------------------------------------
  // 🌫️ Free-floating drift
  // ---------------------------------------------------------------------------
  property real floatX: 0
  property real floatY: 0

  function placeFloatRandomly() {
    floatAnim.stop()
    floatX = Math.random() * Math.max(0, floatAreaW - width)
    floatY = Math.random() * Math.max(0, floatAreaH - height)
    driftTimer.interval = 3000 + Math.random() * 4000
    driftTimer.restart()
  }

  function drift() {
    var maxX = Math.max(0, floatAreaW - width), maxY = Math.max(0, floatAreaH - height)
    var nx, ny
    if (Math.random() < 0.3) {
      // Creep toward (not onto) the mouse.
      var a = Math.random() * Math.PI * 2
      nx = cursorX - monitor.x - reserved[0] - width / 2 + Math.cos(a) * 320
      ny = cursorY - monitor.y - reserved[1] - height / 2 + Math.sin(a) * 240
    } else {
      nx = Math.random() * maxX
      ny = Math.random() * maxY
    }
    nx = Math.max(0, Math.min(maxX, nx))
    ny = Math.max(0, Math.min(maxY, ny))
    // Look where it's going.
    lookX = monitor.x + reserved[0] + nx + width / 2
    lookY = monitor.y + reserved[1] + ny + height / 2
    mode = "travel"
    pupilTarget = 1.0
    modeTimer.stop()
    moveEyeTo(nx, ny, 220, Easing.InOutSine, "travel")
  }

  // Shared mover for the floating eye(s): x/y are float-area coordinates of
  // the top-left corner, speed in px/s.
  property string moveReason: ""
  function moveEyeTo(nx, ny, speed, easing, reason) {
    var maxX = Math.max(0, floatAreaW - width), maxY = Math.max(0, floatAreaH - height)
    nx = Math.max(0, Math.min(maxX, nx))
    ny = Math.max(0, Math.min(maxY, ny))
    var dist = Math.sqrt((nx - floatX) * (nx - floatX) + (ny - floatY) * (ny - floatY))
    floatAnim.stop()
    floatAnimX.to = nx
    floatAnimY.to = ny
    floatAnimX.easing.type = floatAnimY.easing.type = easing
    floatAnimX.duration = floatAnimY.duration = Math.max(reason === "travel" ? 1500 : 320, dist / speed * 1000)
    moveReason = reason
    floatAnim.restart()
  }

  function resumeDrift() {
    if (!floating || !awake) return
    driftTimer.interval = 2500 + Math.random() * 5000
    driftTimer.restart()
  }

  ParallelAnimation {
    id: floatAnim
    NumberAnimation { id: floatAnimX; target: warden; property: "floatX"; easing.type: Easing.InOutSine }
    NumberAnimation { id: floatAnimY; target: warden; property: "floatY"; easing.type: Easing.InOutSine }
    onFinished: {
      if (!warden.awake) return
      if (warden.moveReason === "examine" && warden.mode === "examine") {
        warden.startExamining()
      } else if (warden.moveReason === "travel") {
        warden.pickMode()
        driftTimer.interval = 5000 + Math.random() * 8000
        driftTimer.restart()
      }
      // "hurry": the hurry timer decides what happens next.
    }
  }

  Timer {
    id: driftTimer
    onTriggered: if (warden.awake && warden.floating && warden.mode !== "examine" && warden.mode !== "hurry" && warden.mode !== "scan") warden.drift()
  }

  onFloatingChanged: if (floating && awake) placeFloatRandomly()

  readonly property var floatScreen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === monitorName) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  LazyLoader {
    active: warden.floating && (warden.awake || warden.openness > 0.001)

    PanelWindow {
      screen: warden.floatScreen
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      // Same recipe as other full-screen overlays here: Top layer (above
      // apps, below other plugins' popups), no exclusive zone, keep out of
      // the bar's reserved strip, and click-through.
      margins {
        left: warden.reserved[0]
        top: warden.reserved[1]
        right: warden.reserved[2]
        bottom: warden.reserved[3]
      }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-abyss-warden"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      AbyssEyes {
        x: warden.floatX
        y: warden.floatY
        width: warden.width
        height: warden.height
        pair: warden.pair
        styleId: warden.eyeStyle
        irisStyle: warden.irisStyle
        theme: warden.theme
        gazeX: warden.gazeX
        gazeY: warden.gazeY
        openness: warden.shownOpenness
        pupilScale: warden.pupil
        glow: warden.glowLevel
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼️ Card
  // ---------------------------------------------------------------------------
  // Only seen while recording (in card mode), in layout edit mode (asleep, so
  // it can be placed/resized), or with its menu open.
  readonly property bool cardShown: (awake && !floating) || editing || contextMenuOpen
  opacity: cardShown ? 1.0 : 0.0
  Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

  AbyssEyes {
    id: cardEye
    anchors.fill: parent
    anchors.margins: 4
    pair: warden.pair
    styleId: warden.eyeStyle
    irisStyle: warden.irisStyle
    theme: warden.theme
    gazeX: warden.floating ? 0 : warden.gazeX
    gazeY: warden.floating ? 0 : warden.gazeY
    openness: warden.floating ? 0 : warden.shownOpenness
    pupilScale: warden.pupil
    glow: warden.floating ? 0 : warden.glowLevel

    // Poke it: it flinches.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: warden.awake && !warden.floating && !warden.editing
      onClicked: {
        warden.pupil = 0.6
        warden.blink()
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 6
    visible: warden.editing && !warden.awake
    text: warden.floating ? "Asleep · floats free while recording" : "Asleep · wakes while recording"
    font.family: Style.font.family
    font.pixelSize: 10
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
  }

  // ---------------------------------------------------------------------------
  // 📋 Right-click menu
  // ---------------------------------------------------------------------------
  component MenuToggle: Rectangle {
    id: toggleRow
    property string glyph: ""
    property string label: ""
    property bool checked: false
    signal toggled()
    Layout.fillWidth: true
    implicitHeight: 28
    radius: 6
    color: toggleMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: toggleRow.glyph
        font.family: Style.font.family
        font.pixelSize: 11
        color: toggleRow.checked ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
      }
      Text {
        Layout.fillWidth: true
        text: toggleRow.label
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.foreground
      }
      Text {
        text: toggleRow.checked ? "" : ""
        font.family: Style.font.family
        font.pixelSize: 12
        color: toggleRow.checked ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
      }
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggleRow.toggled()
    }
  }

  // Foldable section title: shows the current pick and a chevron.
  component SectionHeader: Rectangle {
    id: sectionRow
    property string label: ""
    property string value: ""
    property bool open: false
    signal toggled()
    Layout.fillWidth: true
    Layout.topMargin: Style.space(2)
    implicitHeight: 24
    radius: 6
    color: sectionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(6)

      Text {
        text: sectionRow.label
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      }
      Text {
        Layout.fillWidth: true
        text: sectionRow.value
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: 9
        color: Color.accent
      }
      Text {
        text: sectionRow.open ? "\uf077" : "\uf078"
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
      }
    }

    MouseArea {
      id: sectionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: sectionRow.toggled()
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.rightMargin: Style.space(8)
        wrapMode: Text.WordWrap
        text: warden.recording
          ? "󰑊  Watching · " + warden.recSources.join(", ")
          : (warden.previewing ? "󰈈  Preview · wide awake for 15s" : "󰒲  Asleep · appears only while the screen is recorded")
        font.family: Style.font.family
        font.pixelSize: 10
        color: warden.recording ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        visible: !warden.recording
        color: previewMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)
          Text {
            text: "󰈈"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: warden.previewing ? "Put It Back to Sleep" : "Wake It Up (15s preview)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: previewMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (warden.previewing) {
              previewTimer.stop()
              warden.previewing = false
            } else {
              warden.startPreview()
            }
            warden.contextMenuOpen = false
          }
        }
      }

      MenuToggle {
        glyph: "󰁌"
        label: "Free-Floating Mode"
        checked: warden.floating
        onToggled: warden.toggleSetting("floating")
      }

      MenuToggle {
        glyph: "󰆞"
        label: "Card Background"
        checked: warden.showCard
        onToggled: warden.toggleSetting("showCard")
      }

      MenuToggle {
        glyph: "󰍽"
        label: "Examine Clicks"
        checked: warden.examineClicks
        onToggled: warden.toggleSetting("examineClicks")
      }

      MenuToggle {
        glyph: "󰁔"
        label: "Chase Fast Mouse"
        checked: warden.chaseFastMouse
        onToggled: warden.toggleSetting("chaseFastMouse")
      }

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.topMargin: Style.space(4)
        text: "EYES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      }

      // One eye | a pair.
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        spacing: Style.space(4)

        Repeater {
          model: [{ label: "One Eye", glyph: "󰈈", pair: false }, { label: "Pair", glyph: "󰈈󰈈", pair: true }]

          Rectangle {
            required property var modelData
            readonly property bool selected: warden.pair === modelData.pair
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 6
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : (countMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: selected ? Color.accent : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.glyph + "  " + modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              color: parent.selected ? Color.accent : Color.foreground
            }

            MouseArea {
              id: countMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: warden.setPair(modelData.pair)
            }
          }
        }
      }

      SectionHeader {
        label: "EYE STYLE"
        value: warden.nameOf(warden.eyeStyles, warden.eyeStyle)
        open: !!warden.openSections.style
        onToggled: warden.toggleSection("style")
      }

      // Each chip previews its shape in the current theme and iris.
      GridLayout {
        visible: !!warden.openSections.style
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        columns: 3
        columnSpacing: Style.space(4)
        rowSpacing: Style.space(4)

        Repeater {
          model: warden.eyeStyles

          Rectangle {
            required property var modelData
            readonly property bool selected: warden.eyeStyle === modelData.id
            Layout.fillWidth: true
            implicitHeight: 50
            radius: 6
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : (styleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: selected ? Color.accent : "transparent"
            border.width: 1

            AbyssEye {
              anchors.top: parent.top
              anchors.topMargin: 3
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 8
              height: 30
              styleId: modelData.id
              irisStyle: warden.irisStyle
              theme: warden.theme
              glow: 0
            }
            Text {
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 3
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.name
              font.family: Style.font.family
              font.pixelSize: 9
              color: parent.selected ? Color.accent : Color.foreground
            }

            MouseArea {
              id: styleMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: warden.setEyeStyle(modelData.id)
            }
          }
        }
      }

      SectionHeader {
        label: "IRIS STYLE"
        value: warden.nameOf(warden.irisStyles, warden.irisStyle)
        open: !!warden.openSections.iris
        onToggled: warden.toggleSection("iris")
      }

      // Each chip previews the iris in the current eye style and theme.
      GridLayout {
        visible: !!warden.openSections.iris
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        columns: 3
        columnSpacing: Style.space(4)
        rowSpacing: Style.space(4)

        Repeater {
          model: warden.irisStyles

          Rectangle {
            required property var modelData
            readonly property bool selected: warden.irisStyle === modelData.id
            Layout.fillWidth: true
            implicitHeight: 50
            radius: 6
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : (irisMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: selected ? Color.accent : "transparent"
            border.width: 1

            AbyssEye {
              anchors.top: parent.top
              anchors.topMargin: 3
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 8
              height: 30
              styleId: warden.eyeStyle
              irisStyle: modelData.id
              theme: warden.theme
              glow: 0
            }
            Text {
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 3
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.name
              font.family: Style.font.family
              font.pixelSize: 9
              color: parent.selected ? Color.accent : Color.foreground
            }

            MouseArea {
              id: irisMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: warden.setIrisStyle(modelData.id)
            }
          }
        }
      }

      SectionHeader {
        label: "EYE THEME"
        value: warden.theme.name
        open: !!warden.openSections.theme
        onToggled: warden.toggleSection("theme")
      }

      GridLayout {
        visible: !!warden.openSections.theme
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        columns: 2
        columnSpacing: Style.space(4)
        rowSpacing: Style.space(4)

        Repeater {
          model: warden.allThemes

          Rectangle {
            required property var modelData
            readonly property bool selected: warden.themeId === modelData.id
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 6
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : (themeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: selected ? Color.accent : "transparent"
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              // Mini iris swatch.
              Rectangle {
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: modelData.iris
                border.color: modelData.irisDark
                border.width: 2
                Rectangle {
                  anchors.centerIn: parent
                  width: modelData.slit ? 3 : 6
                  height: modelData.slit ? 10 : 6
                  radius: width / 2
                  color: modelData.pupil
                }
              }
              Text {
                Layout.fillWidth: true
                text: modelData.name
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.foreground
              }
            }

            MouseArea {
              id: themeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: warden.setTheme(modelData.id)
            }
          }
        }
      }
    }
  }
}
