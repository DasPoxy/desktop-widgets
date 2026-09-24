import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
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
  minWidth: 40
  minHeight: 28
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
  property string form: "one"   // one | pair | beholder
  property string eyeStyle: "classic"
  property bool examineClicks: true
  // Buddy Mode: stay out all the time instead of only while recording; a
  // recording makes the irises glow instead of summoning the eyes.
  property bool buddyMode: false
  property string irisStyle: "auto"
  // Which menu sections are expanded, e.g. { style: true }. All start folded.
  property var openSections: ({})
  property bool chaseFastMouse: true
  // Reactions (Behaviour section): dance while music plays, jump when a
  // window closes, go and read new notifications, glance at the clock as
  // the minute turns, and now and then lean in and tap on the screen.
  property bool danceToMusic: true
  property bool reactToClosing: true
  property bool watchNotifications: true
  property bool checkClock: true
  property bool tapScreen: true

  function applySavedSettings() {
    themeId = getSetting("themeId", "system")
    floating = getSetting("floating", false)
    showCard = getSetting("showCard", false)
    // "pair" was a bool before the Beholder existed.
    form = getSetting("form", getSetting("pair", false) ? "pair" : "one")
    eyeStyle = getSetting("eyeStyle", "classic")
    examineClicks = getSetting("examineClicks", true)
    buddyMode = getSetting("buddyMode", false)
    irisStyle = getSetting("irisStyle", "auto")
    themeColors = getSetting("themeColors", true)
    openSections = getSetting("openSections", {})
    chaseFastMouse = getSetting("chaseFastMouse", true)
    danceToMusic = getSetting("danceToMusic", true)
    reactToClosing = getSetting("reactToClosing", true)
    watchNotifications = getSetting("watchNotifications", true)
    checkClock = getSetting("checkClock", true)
    tapScreen = getSetting("tapScreen", true)
  }
  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function toggleSetting(key) {
    warden[key] = !warden[key]
    warden.saveSetting(key, warden[key])
  }
  function setForm(v) {
    if (warden.form === v) return
    warden.form = v
    warden.saveSetting("form", v)
    reshapeForForm()
  }
  // Switching form reshapes the widget around it (same height, width to
  // suit), so the eyes stay about the same size.
  readonly property var formAspect: ({ one: 1.65, pair: 2.6, beholder: 1.3, jelly: 0.74, saucer: 1.14, ghost: 0.88, djinn: 0.71, skull: 0.92, squid: 0.74, unicorn: 0.92, robot: 0.8 })

  // Buddy Types, in menu order (drawing: AbyssEyes / AbyssBeholder /
  // AbyssCreature).
  readonly property var buddyTypes: [
    { id: "one", name: "One Eye" },
    { id: "pair", name: "Pair" },
    { id: "beholder", name: "Beholder" },
    { id: "jelly", name: "Jellyfish" },
    { id: "saucer", name: "Saucer" },
    { id: "ghost", name: "Ghost" },
    { id: "djinn", name: "Djinn" },
    { id: "skull", name: "Skull" },
    { id: "squid", name: "Handsome" },
    { id: "unicorn", name: "Smug Unicorn" },
    { id: "robot", name: "Robot" }
  ]
  function reshapeForForm() {
    var a = formAspect[form] || 1.65
    setEyeSize(warden.height * a, 1 / a)
    commitSize()
  }

  // Eye size = the widget's size (also the floating eyes' size), keeping
  // its shape. Saved like a resize-handle drag.
  function setEyeSize(w, aspect) {
    // Clamp the width so the height stays in range too, keeping the shape.
    var lo = Math.max(warden.minWidth, warden.minHeight / aspect)
    var hi = Math.min(warden.maxWidth, warden.maxHeight / aspect)
    w = Math.max(lo, Math.min(Math.max(lo, hi), w))
    warden.width = w
    warden.height = Math.max(warden.minHeight, Math.min(warden.maxHeight, w * aspect))
  }
  // The size slider is logarithmic so the small end has room to aim.
  function sizeFrac(w) {
    return Math.max(0, Math.min(1, Math.log(w / warden.minWidth) / Math.log(warden.maxWidth / warden.minWidth)))
  }
  function sizeAt(f) {
    return warden.minWidth * Math.pow(warden.maxWidth / warden.minWidth, f)
  }
  function commitSize() {
    if (!rootRef || !rootRef.saveWidgetPos) return
    // Snap the width only and keep the shape: snapping both squashes small
    // buddies (46x28 would land on 40x20).
    var aspect = warden.height / Math.max(1, warden.width)
    warden.setEyeSize(Math.max(warden.minWidth, warden.snapVal(warden.width)), aspect)
    var w = Math.round(warden.width), h = Math.round(warden.height)
    warden.width = w
    warden.height = h
    rootRef.saveWidgetPos(warden.widgetId, warden.targetItem.x, warden.targetItem.y, w, h, warden.monitorName)
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
  readonly property string behaviourSummary: {
    var on = []
    if (floating) on.push("Floating")
    if (buddyMode) on.push("Buddy")
    if (showCard) on.push("Card")
    if (examineClicks) on.push("Clicks")
    if (chaseFastMouse) on.push("Chase")
    if (danceToMusic) on.push("Dance")
    if (reactToClosing) on.push("Jumpy")
    if (watchNotifications) on.push("Notifs")
    if (checkClock) on.push("Clock")
    if (tapScreen) on.push("Tap")
    if (!on.length) return "all off"
    return on.length > 3 ? on.slice(0, 2).join(" · ") + " +" + (on.length - 2) : on.join(" · ")
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
    { id: "slit", name: "Slit" },
    { id: "sharingan1", name: "Sharingan I" },
    { id: "sharingan2", name: "Sharingan II" },
    { id: "sharingan3", name: "Sharingan III" },
    { id: "mangekyo", name: "Mangekyō" },
    { id: "scythe", name: "Mangekyō II" },
    { id: "rinnegan", name: "Rinnegan" },
    { id: "byakugan", name: "Byakugan" },
    { id: "heartstar", name: "Heart Star" },
    { id: "starpupil", name: "Star Pupil" },
    { id: "flower", name: "Flower" },
    { id: "sunburst", name: "Sunburst" },
    { id: "compass", name: "Compass" },
    { id: "glass", name: "Glass" },
    { id: "arcs", name: "Arcs" },
    { id: "eclipse", name: "Eclipse" },
    { id: "streaks", name: "Streaks" },
    { id: "infinity", name: "Infinity" },
    // Evil / manic set.
    { id: "bloodmoon", name: "Blood Moon" },
    { id: "void", name: "Void" },
    { id: "twitch", name: "Twitch" },
    { id: "cracked", name: "Cracked" },
    { id: "goat", name: "Goat" },
    { id: "hellfire", name: "Hellfire" },
    { id: "blackout", name: "Blackout" },
    { id: "madness", name: "Madness" }
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
    { id: "angular", name: "Angular" },
    { id: "triangle", name: "Triangle" },
    { id: "box", name: "Boxy" },
    { id: "drowsy", name: "Drowsy" },
    { id: "toon", name: "Toon" },
    { id: "fox", name: "Fox" },
    { id: "dome", name: "Dome" },
    { id: "doll", name: "Doll" },
    { id: "sixeyes", name: "Six Eyes" },
    // Evil / manic set.
    { id: "sinister", name: "Sinister" },
    { id: "manic", name: "Manic" },
    { id: "yandere", name: "Yandere" },
    { id: "demon", name: "Demon" },
    { id: "berserk", name: "Berserk" }
  ]

  function setTheme(id) {
    warden.themeId = id
    warden.saveSetting("themeId", id)
  }

  // ---------------------------------------------------------------------------
  // 🎨 Themes -- "system" follows the Omarchy theme; the rest are fixed.
  // ---------------------------------------------------------------------------
  // Full Theme Palette (Eye Theme section): the System Theme draws on all of
  // the theme's hues -- secondary tints the iris shadow and ink, tertiary the
  // cel shadows and print offset, highlight the iris crescent. Off: every
  // role falls back to the accent (ThemePalette's inactive mode), same as
  // the other widgets' toggle.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: warden.themeColors
  }

  // Flat riso-print palettes: sclera = paper, scleraShade = the cel shadow
  // tone, lash = coloured ink (never pure black), glow = the offset print
  // colour (usually a contrasting ink).
  readonly property var systemTheme: ({
    id: "system", name: "System Theme",
    sclera: String(Qt.tint("#f3ead9", Qt.alpha(pal.secondary, 0.05))),
    scleraShade: String(Qt.tint("#aebccb", Qt.alpha(pal.tertiary, 0.35))),
    irisDark: String(pal.mixColor(Qt.darker(Color.accent, 2.4), Qt.darker(pal.secondary, 2.2), 0.4)),
    iris: String(Color.accent),
    irisLight: String(pal.mixColor(Qt.lighter(Color.accent, 1.5), pal.highlight, 0.45)),
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
  readonly property bool awake: recording || previewing || buddyMode

  // Buddy Mode recording glow: fades in when a recording starts (or during
  // a preview), with a slow pulse; glowPhase advances in tick().
  readonly property bool glowing: buddyMode && (recording || previewing)
  property real irisGlowLevel: glowing ? 1 : 0
  Behavior on irisGlowLevel { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
  property real glowPhase: 0
  readonly property real shownIrisGlow: irisGlowLevel * (0.86 + 0.14 * Math.sin(glowPhase * 2.6))

  // A recording starting while the buddy's already out: a startled blink
  // and a pupil twitch as the glow comes on.
  onRecordingChanged: {
    if (buddyMode && recording && openness > 0.5) {
      pupil = 0.6
      blink()
    }
  }
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
        } else if (msg.type === "closed") {
          warden.handleClosed(msg.x, msg.y)
        } else if (msg.type === "notify") {
          warden.handleNotify()
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
  // the edge of a window or check the bar, then comes back to the mouse),
  // surprised (a window closed: jump, pupils pinned on where it was),
  // notify (read a new notification; floating flies over), clock (glance at
  // a desktop clock or the bar as the minute turns), dance (music playing;
  // floating dances beside the music widget), tap (lean in to the glass and
  // knock on it).
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
  property real gazeVX: 0
  property real gazeVY: 0
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
      haltFloat()
      driftTimer.stop()
      rushDelay.stop()
      examineLook.stop()
      hopAnim.stop()
      tapAnim.stop()
      bodyScale = 1
      bodyY = 0
      bodyRot = 0
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
    if (danceToMusic && musicPlaying && Math.random() < 0.3) { startDance(); return }
    if (tapScreen && Math.random() < 0.05) { startTap(); return }
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
      var wasBusy = warden.holdsPosition()
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
    if (!awake || mode === "travel" || holdsPosition()) return
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
    settleBody()
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
    moveEyeTo(cx - ox - width / 2, cy - oy - height / 2, 950, "examine")
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
    settleBody()
    mode = "hurry"
    squint = 0
    pupil = 0.62
    pupilTarget = 0.82
    blinkAnim.stop()
    openness = 1
    modeTimer.stop()
    examineLook.stop()
    if (floating) {
      stopFloat()           // brake to a stop...
      driftTimer.stop()
      rushDelay.restart()   // ...look for a beat, then hurry over
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
    moveEyeTo(tx - ox - width / 2, ty - oy - height / 2, 1500, "hurry")
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
      moveEyeTo(p[0] - ox - width / 2, ny, scanIdx === 0 ? 800 : 420, "scan")
    } else if (scanIdx === 0) {
      moveEyeTo(p[0] - ox - width / 2, p[1] - oy + 40, 800, "scan")
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

  // --- Reactions -----------------------------------------------------------
  // Body motion shared by the reactions, applied to the card and floating
  // eyes alike: bodyY (fraction of height, negative = up), bodyRot (deg),
  // bodyScale (1 = resting; > 1 = leaning toward the viewer).
  property real bodyY: 0
  property real bodyRot: 0
  property real bodyScale: 1
  property real rippleT: 1        // knock ripple, 0..1 (1 = gone)

  // Modes that keep the eyes where they are (no drifting off, no glancing
  // at every window event).
  function holdsPosition() {
    return mode === "examine" || mode === "hurry" || mode === "scan" || mode === "surprised"
      || mode === "notify" || mode === "clock" || mode === "dance" || mode === "tap"
  }
  // Only a click or a flick of the mouse cuts these short.
  function reactionBusy() {
    return mode === "examine" || mode === "hurry" || mode === "tap" || mode === "surprised"
  }
  function settleBody() {
    if (tapAnim.running) tapAnim.stop()
    if (bodyScale !== 1) settleAnim.restart()
  }
  NumberAnimation { id: settleAnim; target: warden; property: "bodyScale"; to: 1; duration: 260; easing.type: Easing.OutCubic }

  function beginReaction(newMode, holdMs) {
    settleBody()
    mode = newMode
    blinkAnim.stop()
    examineLook.stop()
    modeTimer.interval = holdMs
    modeTimer.restart()
    if (floating) {
      driftTimer.stop()
      if (floatMoving && moveReason === "travel") stopFloat()
    }
  }

  // A rect of another desktop widget on this monitor, in monitor-local
  // coordinates, or null if it isn't showing here.
  function widgetRect(id) {
    if (!rootRef || !rootRef.isWidgetActiveOnMonitor || !rootRef.isWidgetActiveOnMonitor(id, monitorName)) return null
    var mp = rootRef.monitorPositions
    var p = (mp && mp[monitorName] && mp[monitorName][id]) || (rootRef.widgetPositions || {})[id]
    if (!p) return null
    return { x: p.x, y: p.y, w: p.w || 200, h: p.h || 120 }
  }
  // Floating: sit beside a monitor-local rect, on whichever side has room.
  function moveBeside(r, speed, reason) {
    var ox = reserved[0], oy = reserved[1]
    var roomRight = (monitor.w || screenWidth) - reserved[2] - (r.x + r.w)
    var nx = roomRight > width + 40 ? r.x + r.w + 24 : r.x - width - 24
    var ny = r.y + r.h / 2 - height / 2
    moveEyeTo(nx - ox, ny - oy, speed, reason)
  }

  // Window closed: jump, then stare at the spot it vanished from.
  SequentialAnimation {
    id: hopAnim
    ParallelAnimation {
      NumberAnimation { target: warden; property: "bodyY"; to: -0.16; duration: 110; easing.type: Easing.OutQuad }
      NumberAnimation { target: warden; property: "bodyScale"; to: 1.07; duration: 110 }
    }
    ParallelAnimation {
      NumberAnimation { target: warden; property: "bodyY"; to: 0; duration: 420; easing.type: Easing.OutBounce }
      NumberAnimation { target: warden; property: "bodyScale"; to: 1; duration: 300 }
    }
  }
  function handleClosed(x, y) {
    if (!awake || !reactToClosing || reactionBusy() || Math.random() > 0.7) return
    beginReaction("surprised", 1500 + Math.random() * 900)
    lookX = x
    lookY = y
    squint = 0
    openness = 1
    pupil = 0.5
    pupilTarget = 0.75
    hopAnim.restart()
  }

  // Notification: go and read it (Omarchy's popups sit top-right, under
  // the bar), eyes skimming across the card like lines of text.
  property real notifyX: 0
  property real notifyY: 0
  function handleNotify() {
    if (!awake || !watchNotifications || reactionBusy()) return
    notifyX = monitor.x + (monitor.w || screenWidth) - reserved[2] - 210
    notifyY = monitor.y + reserved[1] + 60
    beginReaction("notify", 3000 + Math.random() * 1500)
    lookX = notifyX
    lookY = notifyY
    squint = 0.3
    pupil = 0.8
    pupilTarget = 1.15
    if (floating) moveBeside({ x: notifyX - monitor.x - 200, y: notifyY - monitor.y - 40, w: 400, h: 80 }, 900, "notify")
  }
  Timer {
    running: warden.awake && warden.mode === "notify"
    interval: 420
    repeat: true
    onTriggered: {
      interval = 260 + Math.random() * 280
      warden.lookX = warden.notifyX - 150 + Math.random() * 300
      warden.lookY = warden.notifyY - 20 + Math.random() * 40
    }
  }

  // Clock: as the minute turns, now and then (always on the hour) glance
  // at a desktop clock on this monitor, or the middle of the bar.
  property int lastMinute: -1
  Timer {
    running: warden.awake && warden.checkClock
    interval: 1000
    repeat: true
    onTriggered: {
      var m = new Date().getMinutes()
      if (warden.lastMinute < 0 || m === warden.lastMinute) { warden.lastMinute = m; return }
      warden.lastMinute = m
      if (m === 0 || Math.random() < 0.25) warden.glanceAtClock(m === 0)
    }
  }
  function glanceAtClock(onHour) {
    if (reactionBusy() || mode === "notify") return
    var ids = ["horizon_clock", "clock", "analog_clock"], r = null
    for (var i = 0; i < ids.length && !r; i++) r = widgetRect(ids[i])
    var cx, cy
    if (r) {
      cx = monitor.x + r.x + r.w / 2
      cy = monitor.y + r.y + r.h / 2
    } else {
      var bar = barLine()
      if (!bar) return
      cx = (bar.x0 + bar.x1) / 2
      cy = bar.y
    }
    beginReaction("clock", onHour ? 3600 : 2000 + Math.random() * 1200)
    lookX = cx
    lookY = cy
    squint = 0.2
    pupilTarget = onHour ? 1.3 : 1.1
    if (onHour) {
      blinkAnim.twice = true
      blinkAnim.restart()
      hopAnim.restart()
    }
    if (floating && r) moveBeside(r, 700, "clock")
  }

  // Music: dance while it plays -- floating dances beside the music widget
  // (Karaoke Player, else the Media Player) if one is on this monitor.
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property bool musicPlaying: {
    for (var i = 0; i < mprisPlayers.length; i++)
      if (mprisPlayers[i].playbackState === MprisPlaybackState.Playing) return true
    return false
  }
  property real danceT: 0
  readonly property real danceBeat: 2    // beats per second (~120 bpm)
  onMusicPlayingChanged: {
    if (musicPlaying) Qt.callLater(startDance)
    else if (mode === "dance") stopDance()
  }
  function startDance() {
    if (!awake || !danceToMusic || !musicPlaying || reactionBusy() || mode === "dance") return
    beginReaction("dance", 7000 + Math.random() * 6000)
    danceT = 0
    squint = 0.35      // happy squint
    pupilTarget = 1.15
    if (floating) {
      var r = widgetRect("mpris_player") || widgetRect("media")
      if (r) moveBeside(r, 700, "dance")
    }
  }
  // Music stopped mid-dance: a disappointed droop, then carry on.
  function stopDance() {
    mode = "stare"
    pupilTarget = 1.3
    squint = 0.5
    modeTimer.interval = 900
    modeTimer.restart()
  }

  // Tap: lean in toward the viewer and knock on the glass a few times.
  SequentialAnimation {
    id: tapAnim
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.24; duration: 380; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 260 }
    ScriptAction { script: warden.knock() }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.3; duration: 55; easing.type: Easing.OutQuad }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.24; duration: 110; easing.type: Easing.InQuad }
    PauseAnimation { duration: 150 }
    ScriptAction { script: warden.knock() }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.3; duration: 55; easing.type: Easing.OutQuad }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.24; duration: 110; easing.type: Easing.InQuad }
    PauseAnimation { duration: 150 }
    ScriptAction { script: if (Math.random() < 0.6) warden.knock() }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.3; duration: 55; easing.type: Easing.OutQuad }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1.24; duration: 110; easing.type: Easing.InQuad }
    PauseAnimation { duration: 550 }
    NumberAnimation { target: warden; property: "bodyScale"; to: 1; duration: 450; easing.type: Easing.InOutCubic }
    ScriptAction { script: warden.endTap() }
  }
  NumberAnimation { id: rippleAnim; target: warden; property: "rippleT"; from: 0; to: 1; duration: 560; easing.type: Easing.OutCubic }
  function startTap() {
    beginReaction("tap", 60000)   // tapAnim ends it
    modeTimer.stop()
    squint = 0
    pupilTarget = 1.3
    if (floating) stopFloat()
    tapAnim.restart()
  }
  function knock() {
    rippleAnim.restart()
    pupil = 0.92
  }
  function endTap() {
    if (!awake) return
    pickMode()
    resumeDrift()
  }

  // Knock ripple on the glass, over the eyes.
  component KnockRipple: Item {
    anchors.fill: parent
    visible: warden.rippleT < 1
    Repeater {
      model: 2
      Rectangle {
        required property int index
        readonly property real t: Math.max(0, Math.min(1, warden.rippleT * 1.25 - index * 0.25))
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * (0.35 + 0.9 * t)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, 3 * (1 - t))
        border.color: warden.theme.highlight || "#ffffff"
        opacity: (1 - t) * (index === 0 ? 0.75 : 0.45)
      }
    }
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
    } else if (mode === "window" || mode === "travel" || mode === "examine" || mode === "scan"
               || mode === "surprised" || mode === "notify" || mode === "clock") {
      var w = directionTo(lookX, lookY); tx = w.x; ty = w.y
    } else if (mode === "dance") {
      // Sway side to side on the beat, bounce on every one.
      danceT += dt
      var beat = Math.sin(Math.PI * danceBeat * danceT)
      tx = beat * 0.45
      ty = -0.12 + Math.abs(beat) * 0.12
      bodyRot = beat * 8
      bodyY = -Math.abs(beat) * 0.07
    }
    if (mode !== "dance" && !hopAnim.running) {
      var k = Math.exp(-dt * 10)
      bodyRot *= k
      bodyY *= k
    }
    tx += jitterX
    ty += jitterY
    // Critically damped spring: velocity carries over when the target moves,
    // so quick looks ease out and in instead of snapping, and the 20Hz cursor
    // samples blur into one glide. Stiffness per mode: following the mouse
    // is smooth pursuit, a slow trace when scanning, brisk for glances.
    var w = mode === "cursor" ? 9 : (mode === "hurry" ? 13 : (mode === "scan" ? 6 : 15))
    var steps = Math.max(1, Math.ceil(dt / 0.016))
    var h = dt / steps
    for (var i = 0; i < steps; i++) {
      gazeVX += (w * w * (tx - gazeX) - 2 * w * gazeVX) * h
      gazeVY += (w * w * (ty - gazeY) - 2 * w * gazeVY) * h
      gazeX += gazeVX * h
      gazeY += gazeVY * h
    }
    pupil += (pupilTarget - pupil) * (1 - Math.exp(-dt * 5))
    if (irisGlowLevel > 0) glowPhase += dt
    if (floating) stepFloat(dt)
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

  // Floating motion is a spring too (see stepFloat): a target, a velocity,
  // and per-move limits on speed and acceleration, so the eyes ease off,
  // glide, and settle -- and when the target changes mid-flight (chasing the
  // mouse, sweeping the bar) they curve toward the new one instead of
  // restarting from a standstill.
  property real floatVX: 0
  property real floatVY: 0
  property real floatTX: 0
  property real floatTY: 0
  property bool floatMoving: false
  property real floatOmega: 1
  property real floatMaxSpeed: 250
  property real floatMaxAccel: 300
  readonly property var moveProfiles: ({
    travel: { omega: 1.1, accel: 260 },   // lazy drift
    scan: { omega: 2.2, accel: 1400 },
    examine: { omega: 2.6, accel: 2200 },
    hurry: { omega: 3.6, accel: 3600 },   // rushing over
    notify: { omega: 2.6, accel: 2200 },
    clock: { omega: 2.2, accel: 1400 },
    dance: { omega: 2.0, accel: 1200 },
    stop: { omega: 4.5, accel: 3000 }     // braking to a halt
  })

  function stopFloat() {
    // Coast to a halt rather than freezing mid-air.
    floatVX = floatVX || 0
    floatVY = floatVY || 0
    var maxX = Math.max(0, floatAreaW - width), maxY = Math.max(0, floatAreaH - height)
    floatTX = Math.max(0, Math.min(maxX, floatX + floatVX * 0.22))
    floatTY = Math.max(0, Math.min(maxY, floatY + floatVY * 0.22))
    floatOmega = moveProfiles.stop.omega
    floatMaxAccel = moveProfiles.stop.accel
    moveReason = "stop"
    floatMoving = true
  }

  function haltFloat() {
    floatMoving = false
    floatVX = 0
    floatVY = 0
  }

  function stepFloat(dt) {
    if (!floatMoving) return
    var maxX = Math.max(0, floatAreaW - width), maxY = Math.max(0, floatAreaH - height)
    var steps = Math.max(1, Math.ceil(dt / 0.016))
    var h = dt / steps
    var w = floatOmega
    for (var i = 0; i < steps; i++) {
      var ax = w * w * (floatTX - floatX) - 2 * w * floatVX
      var ay = w * w * (floatTY - floatY) - 2 * w * floatVY
      var am = Math.sqrt(ax * ax + ay * ay)
      if (am > floatMaxAccel) { ax *= floatMaxAccel / am; ay *= floatMaxAccel / am }
      floatVX += ax * h
      floatVY += ay * h
      var vm = Math.sqrt(floatVX * floatVX + floatVY * floatVY)
      if (vm > floatMaxSpeed) { floatVX *= floatMaxSpeed / vm; floatVY *= floatMaxSpeed / vm }
      floatX = Math.max(0, Math.min(maxX, floatX + floatVX * h))
      floatY = Math.max(0, Math.min(maxY, floatY + floatVY * h))
    }
    var dx = floatTX - floatX, dy = floatTY - floatY
    if (dx * dx + dy * dy < 2.25 && floatVX * floatVX + floatVY * floatVY < 64) {
      floatX = floatTX
      floatY = floatTY
      haltFloat()
      floatArrived()
    }
  }

  function floatArrived() {
    if (!awake) return
    if (moveReason === "examine" && mode === "examine") {
      startExamining()
    } else if (moveReason === "travel") {
      pickMode()
      driftTimer.interval = 5000 + Math.random() * 8000
      driftTimer.restart()
    }
    // "hurry"/"scan"/"stop": their own timers decide what happens next.
  }

  function placeFloatRandomly() {
    haltFloat()
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
    moveEyeTo(nx, ny, 230, "travel")
  }

  // Shared mover for the floating eye(s): x/y are float-area coordinates of
  // the top-left corner, maxSpeed in px/s; the reason picks the spring.
  property string moveReason: ""
  function moveEyeTo(nx, ny, maxSpeed, reason) {
    var maxX = Math.max(0, floatAreaW - width), maxY = Math.max(0, floatAreaH - height)
    var prof = moveProfiles[reason] || moveProfiles.travel
    floatTX = Math.max(0, Math.min(maxX, nx))
    floatTY = Math.max(0, Math.min(maxY, ny))
    floatOmega = prof.omega
    floatMaxAccel = prof.accel
    floatMaxSpeed = maxSpeed
    moveReason = reason
    floatMoving = true
  }

  function resumeDrift() {
    if (!floating || !awake) return
    driftTimer.interval = 2500 + Math.random() * 5000
    driftTimer.restart()
  }

  Timer {
    id: driftTimer
    onTriggered: if (warden.awake && warden.floating && !warden.holdsPosition()) warden.drift()
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
        id: floatEyes
        x: warden.floatX
        y: warden.floatY
        width: warden.width
        height: warden.height
        transform: [
          Scale { origin.x: floatEyes.width / 2; origin.y: floatEyes.height / 2; xScale: warden.bodyScale; yScale: warden.bodyScale },
          Rotation { origin.x: floatEyes.width / 2; origin.y: floatEyes.height * 0.8; angle: warden.bodyRot },
          Translate { y: warden.bodyY * floatEyes.height }
        ]

        KnockRipple {}
        form: warden.form
        styleId: warden.eyeStyle
        irisStyle: warden.irisStyle
        theme: warden.theme
        gazeX: warden.gazeX
        gazeY: warden.gazeY
        openness: warden.shownOpenness
        pupilScale: warden.pupil
        glow: warden.glowLevel
        irisGlow: warden.shownIrisGlow
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
    form: warden.form
    styleId: warden.eyeStyle
    irisStyle: warden.irisStyle
    theme: warden.theme
    transform: [
      Scale { origin.x: cardEye.width / 2; origin.y: cardEye.height / 2; xScale: warden.floating ? 1 : warden.bodyScale; yScale: warden.floating ? 1 : warden.bodyScale },
      Rotation { origin.x: cardEye.width / 2; origin.y: cardEye.height * 0.8; angle: warden.floating ? 0 : warden.bodyRot },
      Translate { y: warden.floating ? 0 : warden.bodyY * cardEye.height }
    ]
    gazeX: warden.floating ? 0 : warden.gazeX
    gazeY: warden.floating ? 0 : warden.gazeY
    openness: warden.floating ? 0 : warden.shownOpenness
    pupilScale: warden.pupil
    glow: warden.floating ? 0 : warden.glowLevel
    irisGlow: warden.floating ? 0 : warden.shownIrisGlow

    KnockRipple { visible: !warden.floating && warden.rippleT < 1 }

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
          ? "󰑊  Watching · " + warden.recSources.join(", ") + (warden.buddyMode ? " · irises glowing" : "")
          : (warden.buddyMode
            ? (warden.previewing ? "\uf004  Buddy · previewing the recording glow" : "\uf004  Buddy · hanging out; irises glow while recording")
            : (warden.previewing ? "󰈈  Preview · wide awake for 15s" : "󰒲  Asleep · appears only while the screen is recorded"))
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
            text: warden.buddyMode
              ? (warden.previewing ? "Stop Glow Preview" : "Preview Recording Glow (15s)")
              : (warden.previewing ? "Put It Back to Sleep" : "Wake It Up (15s preview)")
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

      // Behaviour toggles fold like the other sections; anything added to
      // this column folds with them.
      SectionHeader {
        label: "BEHAVIOUR"
        value: warden.behaviourSummary
        open: !!warden.openSections.behaviour
        onToggled: warden.toggleSection("behaviour")
      }

      ColumnLayout {
        visible: !!warden.openSections.behaviour
        Layout.fillWidth: true
        spacing: Style.space(4)

        MenuToggle {
          glyph: "󰁌"
          label: "Free-Floating Mode"
          checked: warden.floating
          onToggled: warden.toggleSetting("floating")
        }

        MenuToggle {
          glyph: "\uf004"
          label: "Buddy Mode (always out)"
          checked: warden.buddyMode
          onToggled: warden.toggleSetting("buddyMode")
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

        MenuToggle {
          glyph: String.fromCodePoint(0xf075a) // md-music
          label: "Dance to Music"
          checked: warden.danceToMusic
          onToggled: warden.toggleSetting("danceToMusic")
        }

        MenuToggle {
          glyph: String.fromCodePoint(0xf0156) // md-close
          label: "Jump When Windows Close"
          checked: warden.reactToClosing
          onToggled: warden.toggleSetting("reactToClosing")
        }

        MenuToggle {
          glyph: String.fromCodePoint(0xf009a) // md-bell
          label: "Read Notifications"
          checked: warden.watchNotifications
          onToggled: warden.toggleSetting("watchNotifications")
        }

        MenuToggle {
          glyph: String.fromCodePoint(0xf0954) // md-clock
          label: "Check the Clock"
          checked: warden.checkClock
          onToggled: warden.toggleSetting("checkClock")
        }

        MenuToggle {
          glyph: String.fromCodePoint(0xf0741) // md-gesture_tap
          label: "Tap on the Screen"
          checked: warden.tapScreen
          onToggled: warden.toggleSetting("tapScreen")
        }
      }

      SectionHeader {
        label: "BUDDY TYPE"
        value: warden.nameOf(warden.buddyTypes, warden.form)
        open: !!warden.openSections.buddy
        onToggled: warden.toggleSection("buddy")
      }

      // Each chip previews the buddy in the current eye style, iris and theme.
      GridLayout {
        visible: !!warden.openSections.buddy
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        columns: 4
        columnSpacing: Style.space(4)
        rowSpacing: Style.space(4)

        Repeater {
          model: warden.buddyTypes

          Rectangle {
            required property var modelData
            readonly property bool selected: warden.form === modelData.id
            Layout.fillWidth: true
            implicitHeight: 62
            radius: 6
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : (buddyMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: selected ? Color.accent : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            AbyssEyes {
              anchors.top: parent.top
              anchors.topMargin: 3
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 6
              height: 40
              animate: false
              form: modelData.id
              styleId: warden.eyeStyle
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
              id: buddyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: warden.setForm(modelData.id)
            }
          }
        }
      }

      // Buddy size: drags the widget's size (= the floating eyes' size),
      // keeping its shape; saved on release like a resize-handle drag.
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(2)
        Layout.leftMargin: Style.space(8)
        Layout.rightMargin: Style.space(8)
        spacing: Style.space(8)

        Text {
          text: "Buddy Size"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        Item {
          id: sizeTrack
          Layout.fillWidth: true
          implicitHeight: 20
          readonly property real frac: warden.sizeFrac(warden.width)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.12)
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * sizeTrack.frac
            height: 4
            radius: 2
            color: Color.accent
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * sizeTrack.frac - width / 2
            width: 14
            height: 14
            radius: 7
            color: sizeMouse.pressed ? Color.foreground : Color.accent
            border.color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
          }

          MouseArea {
            id: sizeMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            property real aspect: 1
            function apply(mx) {
              var f = Math.max(0, Math.min(1, mx / width))
              warden.setEyeSize(warden.sizeAt(f), aspect)
            }
            onPressed: function(mouse) {
              aspect = warden.height / Math.max(1, warden.width)
              apply(mouse.x)
            }
            onPositionChanged: function(mouse) { if (pressed) apply(mouse.x) }
            onReleased: warden.commitSize()
          }
        }

        Text {
          Layout.preferredWidth: 42
          horizontalAlignment: Text.AlignRight
          text: Math.round(warden.width) + "px"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.accent
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

      // Full Theme Palette -- shapes the System Theme, so turning it either
      // way while a preset is picked switches to the System Theme.
      MenuToggle {
        visible: !!warden.openSections.theme
        glyph: String.fromCodePoint(0xf03d8) // md-palette
        label: "Full Theme Palette"
        checked: warden.themeColors
        onToggled: {
          warden.toggleSetting("themeColors")
          if (warden.themeId !== "system") warden.setTheme("system")
        }
      }
      Text {
        visible: !!warden.openSections.theme
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.rightMargin: Style.space(8)
        Layout.bottomMargin: Style.space(2)
        wrapMode: Text.WordWrap
        text: warden.themeColors ? "System Theme uses every hue in your Omarchy theme." : "System Theme uses your accent colour only."
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
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
      // Update the whole custom widget suite from its repo.
      SuiteUpdateItem {}
    }
  }
}
