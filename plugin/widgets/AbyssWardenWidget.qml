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

  function applySavedSettings() {
    themeId = getSetting("themeId", "system")
    floating = getSetting("floating", false)
    showCard = getSetting("showCard", false)
    pair = getSetting("pair", false)
    eyeStyle = getSetting("eyeStyle", "classic")
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

  readonly property var systemTheme: ({
    id: "system", name: "System Theme",
    sclera: String(Qt.tint("#f4f2f8", Qt.alpha(pal.secondary, 0.04))),
    scleraShade: String(Qt.tint("#c6c0d4", Qt.alpha(pal.secondary, 0.16))),
    irisDark: String(Qt.darker(Color.accent, 3.0)),
    iris: String(Color.accent),
    irisLight: String(pal.mixColor(Qt.lighter(Color.accent, 1.6), pal.highlight, 0.25)),
    pupil: "#07040c",
    highlight: "#ffffff",
    lash: String(Qt.tint("#0d0911", Qt.alpha(pal.secondary, 0.22))),
    glow: String(Color.accent),
    slit: false
  })

  readonly property var presetThemes: [
    { id: "abyss", name: "Abyssal Violet", sclera: "#f4f1fa", scleraShade: "#c9c0dc", irisDark: "#2a0b4d", iris: "#7b2ff7", irisLight: "#e0aaff", pupil: "#07020d", highlight: "#ffffff", lash: "#140a1c", glow: "#9d4edd", slit: false },
    { id: "crimson", name: "Blood Moon", sclera: "#f3e6e6", scleraShade: "#d6b3b3", irisDark: "#3a0000", iris: "#c1121f", irisLight: "#ff8f8f", pupil: "#0a0000", highlight: "#fff4f4", lash: "#1a0505", glow: "#ff2a2a", slit: false },
    { id: "serpent", name: "Jade Serpent", sclera: "#f1ecc8", scleraShade: "#cfc48a", irisDark: "#0b3d20", iris: "#2dc653", irisLight: "#c7f9cc", pupil: "#021007", highlight: "#fbfff5", lash: "#0d1a10", glow: "#38b000", slit: true },
    { id: "dragon", name: "Gilded Dragon", sclera: "#f6ecd0", scleraShade: "#d9c089", irisDark: "#5a2d00", iris: "#f4a261", irisLight: "#ffe8a3", pupil: "#140800", highlight: "#fffaf0", lash: "#1f1204", glow: "#ffb703", slit: true },
    { id: "frost", name: "Frostbound", sclera: "#eef6fb", scleraShade: "#b8cfdd", irisDark: "#0b3954", iris: "#4cc9f0", irisLight: "#e0fbfc", pupil: "#020c14", highlight: "#ffffff", lash: "#0a1620", glow: "#90e0ef", slit: false },
    { id: "sakura", name: "Sakura Dream", sclera: "#fdf3f7", scleraShade: "#e8c3d3", irisDark: "#6d1b4d", iris: "#ff70a6", irisLight: "#ffd6e8", pupil: "#1a0510", highlight: "#ffffff", lash: "#2a0c1b", glow: "#ff99c8", slit: false },
    { id: "void", name: "Hollow Void", sclera: "#0c0c12", scleraShade: "#000000", irisDark: "#3d3d4a", iris: "#c9c9d6", irisLight: "#ffffff", pupil: "#000000", highlight: "#ffffff", lash: "#000000", glow: "#c8c8ff", slit: false }
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
          var moved = Math.abs(msg.x - warden.cursorX) + Math.abs(msg.y - warden.cursorY)
          warden.cursorX = msg.x
          warden.cursorY = msg.y
          if (moved > 40) warden.lastCursorMove = Date.now()
        } else if (msg.type === "activity") {
          warden.handleActivity(msg.x, msg.y)
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
  // it's drifting to).
  // ---------------------------------------------------------------------------
  property string mode: "wander"
  property real lookX: 0          // global point for window/travel modes
  property real lookY: 0
  property real wanderX: 0        // direction for wander mode, -1..1
  property real wanderY: 0
  property real jitterX: 0
  property real jitterY: 0
  property real lastActivity: 0

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
    var recentMouse = Date.now() - lastCursorMove < 1500
    var r = Math.random()
    var cursorW = recentMouse ? 0.55 : 0.3
    if (r < cursorW) mode = "cursor"
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
    onTriggered: if (warden.awake) warden.pickMode()
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
    if (!awake || mode === "travel") return
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
    } else if (mode === "cursor") {
      var d = directionTo(cursorX, cursorY); tx = d.x; ty = d.y
    } else if (mode === "window" || mode === "travel") {
      var w = directionTo(lookX, lookY); tx = w.x; ty = w.y
    }
    tx += jitterX
    ty += jitterY
    // Following the mouse is smooth pursuit; everything else is a quick
    // saccade.
    var k = 1 - Math.exp(-dt * (mode === "cursor" ? 9 : 22))
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
    var dist = Math.sqrt((nx - floatX) * (nx - floatX) + (ny - floatY) * (ny - floatY))
    floatAnimX.to = nx
    floatAnimY.to = ny
    floatAnimX.duration = floatAnimY.duration = Math.max(1500, dist / 220 * 1000)
    // Look where it's going.
    lookX = monitor.x + reserved[0] + nx + width / 2
    lookY = monitor.y + reserved[1] + ny + height / 2
    mode = "travel"
    pupilTarget = 1.0
    modeTimer.stop()
    floatAnim.restart()
  }

  ParallelAnimation {
    id: floatAnim
    NumberAnimation { id: floatAnimX; target: warden; property: "floatX"; easing.type: Easing.InOutSine }
    NumberAnimation { id: floatAnimY; target: warden; property: "floatY"; easing.type: Easing.InOutSine }
    onFinished: {
      if (!warden.awake) return
      warden.pickMode()
      driftTimer.interval = 5000 + Math.random() * 8000
      driftTimer.restart()
    }
  }

  Timer {
    id: driftTimer
    running: warden.awake && warden.floating
    onTriggered: warden.drift()
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
        theme: warden.theme
        gazeX: warden.gazeX
        gazeY: warden.gazeY
        openness: warden.openness
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
    theme: warden.theme
    gazeX: warden.floating ? 0 : warden.gazeX
    gazeY: warden.floating ? 0 : warden.gazeY
    openness: warden.floating ? 0 : warden.openness
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

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.topMargin: Style.space(4)
        text: "EYE STYLE"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      }

      // Each chip previews its shape in the current theme.
      GridLayout {
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

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.topMargin: Style.space(4)
        text: "EYE THEME"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      }

      GridLayout {
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
