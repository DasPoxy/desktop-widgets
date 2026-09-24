import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: monWidgetRoot

  widgetId: "system_monitor"
  title: "System Monitor"
  icon: ""
  showHeader: false

  width: 340
  height: monCardLayout.implicitHeight + Style.space(36)
  minWidth: 280
  minHeight: 220
  maxWidth: Math.min(700, screenWidth - 40)
  maxHeight: Math.min(900, screenHeight - 80)
  resizable: true

  // ---------------------------------------------------------------------------
  // 📊 CPU / GPU / RAM Utilization + Network Activity State
  // ---------------------------------------------------------------------------
  property real cpuPct: 0
  property var ram: null
  property var gpus: []
  property var network: null
  property int pollIntervalMs: 2000

  // ---------------------------------------------------------------------------
  // 🤖 Agent Rate-Limit Usage (Claude Code / Codex / ...), read from the
  // records Omarchy's omarchy-agent-usage-update keeps -- see get-agents.sh.
  // ---------------------------------------------------------------------------
  property var agents: []
  property bool showAgents: true
  readonly property bool agentsVisible: monWidgetRoot.showAgents && monWidgetRoot.agents.length > 0

  function setShowAgents(on) {
    monWidgetRoot.showAgents = on
    monWidgetRoot.saveSetting("showAgents", on)
    if (on) monWidgetRoot.refreshAgents()
  }

  function refreshAgents() {
    if (monWidgetRoot.showAgents && !agentsProc.running) agentsProc.running = true
  }

  // "Session (5-hour)" -> "5h", "Weekly (7-day)" -> "7d"; otherwise first word.
  function shortLimitLabel(label) {
    var m = /(\d+)[- ]?(hour|day|week|month)/i.exec(label || "")
    if (m) return m[1] + m[2].charAt(0).toLowerCase()
    var w = String(label || "").split(/[\s(]/)[0]
    return w.length > 6 ? w.slice(0, 6) : w
  }

  function formatResetIn(sec) {
    if (sec < 0) return ""
    var d = Math.floor(sec / 86400)
    var h = Math.floor((sec % 86400) / 3600)
    var m = Math.floor((sec % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  readonly property string agentsScriptPath: {
    var u = Qt.resolvedUrl("../get-agents.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: agentsProc
    command: [monWidgetRoot.agentsScriptPath, "--refresh-if-stale"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          monWidgetRoot.agents = Array.isArray(data.agents) ? data.agents : []
        } catch (e) {
          console.warn("[SystemMonitorWidget] agents parse error:", e)
        }
      }
    }
  }

  // Usage moves on the scale of minutes; no need to follow the CPU poll rate.
  Timer {
    interval: 60000
    running: monWidgetRoot.showAgents
    repeat: true
    triggeredOnStart: true
    onTriggered: monWidgetRoot.refreshAgents()
  }

  // Full Theme Palette: each meter gets its own theme hue (CPU tertiary,
  // RAM secondary, GPU green) with an accent -> hue fill, and the
  // 70%/90% warnings use the theme's yellow/red. Off = accent-only.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: monWidgetRoot.themeColors
  }

  function toggleSetting(key) {
    monWidgetRoot[key] = !monWidgetRoot[key]
    monWidgetRoot.saveSetting(key, monWidgetRoot[key])
  }

  // Header: custom title / glyph, or hide either (HeaderEditor in the menu).
  // Empty text = the default.
  readonly property string defaultTitle: "System Monitor"
  readonly property string defaultGlyph: ""
  property string titleText: ""
  property string glyphText: ""
  property bool titleHidden: false
  property bool glyphHidden: false
  readonly property string shownTitle: titleText || defaultTitle
  readonly property string shownGlyph: glyphText || defaultGlyph

  function setHeaderSetting(key, val) {
    monWidgetRoot[key] = val
    monWidgetRoot.saveSetting(key, val)
  }

  // Menu text fields need keyboard focus on the desktop layer.
  property bool holdsKeyboardFocus: false
  function grabKeyboard(input) {
    if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
    monWidgetRoot.holdsKeyboardFocus = true
    input.forceActiveFocus()
  }
  function releaseKeyboard() {
    if (!monWidgetRoot.holdsKeyboardFocus) return
    monWidgetRoot.holdsKeyboardFocus = false
    if (rootRef && rootRef.keyboardFocusRequested) rootRef.keyboardFocusRequested = false
  }
  onContextMenuOpenChanged: if (!contextMenuOpen) releaseKeyboard()

  function applySavedSettings() {
    titleText = getSetting("titleText", "")
    glyphText = getSetting("glyphText", "")
    titleHidden = getSetting("titleHidden", false)
    glyphHidden = getSetting("glyphHidden", false)
    pollIntervalMs = getSetting("pollIntervalMs", 2000)
    showAgents = getSetting("showAgents", true)
    themeColors = getSetting("themeColors", true)
  }

  function setPollInterval(ms) {
    monWidgetRoot.pollIntervalMs = ms
    monWidgetRoot.saveSetting("pollIntervalMs", ms)
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function barColor(pct, hue) {
    if (pct >= 90) return pal.danger
    if (pct >= 70) return monWidgetRoot.themeColors ? pal.highlight : "#f59e0b"
    return hue !== undefined ? hue : Color.accent
  }
  // Below the warning band a themed bar blends accent -> the meter's hue.
  function barGradient(pct) {
    return monWidgetRoot.themeColors && pct < 70
  }

  readonly property string sysmonScriptPath: {
    var u = Qt.resolvedUrl("../get-sysmon.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: sysmonProc
    command: [monWidgetRoot.sysmonScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (typeof data.cpu_pct === "number") monWidgetRoot.cpuPct = data.cpu_pct
          monWidgetRoot.ram = data.ram || null
          monWidgetRoot.gpus = Array.isArray(data.gpus) ? data.gpus : []
          monWidgetRoot.network = data.network || null
        } catch (e) {
          console.warn("[SystemMonitorWidget] parse error:", e)
        }
      }
    }
  }

  Timer {
    interval: monWidgetRoot.pollIntervalMs
    running: true
    repeat: true
    onTriggered: if (!sysmonProc.running) sysmonProc.running = true
  }

  function resetSession() {
    resetProc.running = true
  }

  Process {
    id: resetProc
    command: [monWidgetRoot.sysmonScriptPath, "reset_session"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (typeof data.cpu_pct === "number") monWidgetRoot.cpuPct = data.cpu_pct
          monWidgetRoot.ram = data.ram || null
          monWidgetRoot.gpus = Array.isArray(data.gpus) ? data.gpus : []
          monWidgetRoot.network = data.network || null
        } catch (e) {}
      }
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      HeaderEditor {
        host: monWidgetRoot
      }

      Text {
        text: "REFRESH RATE"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.bottomMargin: 4
        spacing: Style.space(6)

        Repeater {
          model: [
            { label: "1s", ms: 1000 },
            { label: "2s", ms: 2000 },
            { label: "5s", ms: 5000 },
            { label: "10s", ms: 10000 }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isActive: monWidgetRoot.pollIntervalMs === modelData.ms
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (rateMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isActive ? Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? Color.accent : Color.foreground
            }

            MouseArea {
              id: rateMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: monWidgetRoot.setPollInterval(modelData.ms)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: resetMenuMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Reset Session Counter"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: resetMenuMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            monWidgetRoot.resetSession()
            monWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Agent usage toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: agentsToggleMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: String.fromCodePoint(0xf06a9) // md-robot
            font.family: Style.font.family
            font.pixelSize: 11
            color: monWidgetRoot.showAgents ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Show Agent Usage"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: monWidgetRoot.showAgents ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: monWidgetRoot.showAgents ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: agentsToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: monWidgetRoot.setShowAgents(!monWidgetRoot.showAgents)
        }
      }

      // Full theme palette toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: themeToggleMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: String.fromCodePoint(0xf03d8) // md-palette
            font.family: Style.font.family
            font.pixelSize: 11
            color: monWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Full Theme Palette"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: monWidgetRoot.themeColors ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: monWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: themeToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: monWidgetRoot.toggleSetting("themeColors")
        }
      }
      // Update the whole custom widget suite from its repo.
      SuiteUpdateItem {}
    }
  }

  ColumnLayout {
    id: monCardLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(18)
    anchors.bottomMargin: Style.space(18)
    anchors.leftMargin: Style.space(20)
    anchors.rightMargin: Style.space(20)
    spacing: Style.space(12)

    // Header Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        visible: !monWidgetRoot.glyphHidden
        text: monWidgetRoot.shownGlyph
        font.family: Style.font.family
        font.pixelSize: 15
        color: Color.accent
      }

      Text {
        visible: !monWidgetRoot.titleHidden
        text: monWidgetRoot.shownTitle
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.foreground
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        width: 7
        height: 7
        radius: 3.5
        color: pal.live
      }

      Text {
        text: "Live"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }

      // Close / Hide Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeMonMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeMonMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(monWidgetRoot.widgetId, false, monWidgetRoot.monitorName)
            }
          }
        }
      }

      // Drag Grip Button
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: monGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: monGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: monWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, monWidgetRoot.screenWidth - monWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, monWidgetRoot.screenHeight - monWidgetRoot.height - 10)

          onPressed: monWidgetRoot.customGripDragging = true
          onReleased: function() {
            monWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, monWidgetRoot.screenWidth - monWidgetRoot.width - 10)
            var maxY = Math.max(10, monWidgetRoot.screenHeight - monWidgetRoot.height - 10)
            var snappedX = Math.round(monWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(monWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            monWidgetRoot.targetItem.x = snappedX
            monWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(monWidgetRoot.widgetId, snappedX, snappedY, monWidgetRoot.snapVal(monWidgetRoot.width), monWidgetRoot.snapVal(monWidgetRoot.height), monWidgetRoot.monitorName)
            }
          }
          onCanceled: monWidgetRoot.customGripDragging = false
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: pal.line
    }

    // CPU Meter
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 11
          color: pal.tertiary
          Layout.preferredWidth: 16
        }
        Text {
          text: "CPU"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }
        Item { Layout.fillWidth: true }
        Text {
          text: Math.round(monWidgetRoot.cpuPct) + "%"
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.Bold
          color: Color.foreground
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 7
        radius: 3.5
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
          height: parent.height
          width: Math.max(0, Math.min(parent.width, parent.width * monWidgetRoot.cpuPct / 100))
          radius: 3.5
          color: monWidgetRoot.barColor(monWidgetRoot.cpuPct, pal.tertiary)
          gradient: monWidgetRoot.barGradient(monWidgetRoot.cpuPct) ? cpuFillGradient : null
          Gradient {
            id: cpuFillGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: pal.primary }
            GradientStop { position: 1; color: pal.tertiary }
          }
          Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
      }
    }

    // RAM Meter
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)
      visible: monWidgetRoot.ram !== null

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: String.fromCodePoint(0xf035b) // md-memory (fa-memory is absent from this font)
          font.family: Style.font.family
          font.pixelSize: 11
          color: pal.secondary
          Layout.preferredWidth: 16
        }
        Text {
          text: "RAM"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }
        Item { Layout.fillWidth: true }
        Text {
          text: monWidgetRoot.ram ? (monWidgetRoot.ram.used + " / " + monWidgetRoot.ram.total) : ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        }
        Text {
          text: monWidgetRoot.ram ? Math.round(monWidgetRoot.ram.pct) + "%" : "0%"
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.Bold
          color: Color.foreground
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 7
        radius: 3.5
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
          readonly property real pct: monWidgetRoot.ram ? monWidgetRoot.ram.pct : 0
          height: parent.height
          width: Math.max(0, Math.min(parent.width, parent.width * pct / 100))
          radius: 3.5
          color: monWidgetRoot.barColor(pct, pal.secondary)
          gradient: monWidgetRoot.barGradient(pct) ? ramFillGradient : null
          Gradient {
            id: ramFillGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: pal.primary }
            GradientStop { position: 1; color: pal.secondary }
          }
          Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
      }
    }

    // GPU Meters (one per detected GPU)
    Repeater {
      model: monWidgetRoot.gpus

      ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.space(3)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 11
            color: pal.live
            Layout.preferredWidth: 16
          }
          Text {
            Layout.fillWidth: true
            text: modelData.name || "GPU"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
            elide: Text.ElideRight
          }
          Text {
            visible: !!modelData.mem_used
            text: modelData.mem_used ? (modelData.mem_used + " / " + modelData.mem_total) : ""
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
          }
          Text {
            text: Math.round(modelData.pct) + "%"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Color.foreground
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 7
          radius: 3.5
          color: Qt.rgba(1, 1, 1, 0.12)

          Rectangle {
            height: parent.height
            width: Math.max(0, Math.min(parent.width, parent.width * modelData.pct / 100))
            radius: 3.5
            color: monWidgetRoot.barColor(modelData.pct, pal.live)
            gradient: monWidgetRoot.barGradient(modelData.pct) ? gpuFillGradient : null
            Gradient {
              id: gpuFillGradient
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: pal.primary }
              GradientStop { position: 1; color: pal.live }
            }
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
          }
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: pal.line
    }

    // Bottom row: network readings, with agent usage bars to their right
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

    // Network Section
    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: Style.space(6)
      visible: monWidgetRoot.network !== null

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 11
          color: pal.tertiary
        }
        Text {
          text: "NETWORK"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        }
        Item { Layout.fillWidth: true }
        Text {
          text: monWidgetRoot.network ? monWidgetRoot.network.iface : ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(16)

        RowLayout {
          spacing: Style.space(5)
          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 10
            color: monWidgetRoot.themeColors ? pal.live : "#10b981"
          }
          Text {
            text: monWidgetRoot.network ? monWidgetRoot.network.down_rate : "0 B/s"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }

        RowLayout {
          spacing: Style.space(5)
          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 10
            color: monWidgetRoot.themeColors ? pal.highlight : "#f59e0b"
          }
          Text {
            text: monWidgetRoot.network ? monWidgetRoot.network.up_rate : "0 B/s"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }

        Item { Layout.fillWidth: true }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Session:"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
        Text {
          Layout.fillWidth: true
          text: monWidgetRoot.network ? (" " + monWidgetRoot.network.session_down + "   " + monWidgetRoot.network.session_up) : ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
          elide: Text.ElideRight
        }
        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: resetIconMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)

          MouseArea {
            id: resetIconMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: monWidgetRoot.resetSession()
          }
        }
      }
    }

    Rectangle {
      visible: monWidgetRoot.agentsVisible && monWidgetRoot.network !== null
      Layout.fillHeight: true
      implicitWidth: 1
      color: pal.line
    }

    // Agent Usage Section
    ColumnLayout {
      visible: monWidgetRoot.agentsVisible
      Layout.alignment: Qt.AlignTop
      Layout.fillWidth: monWidgetRoot.network === null
      Layout.preferredWidth: 90
      spacing: Style.space(5)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: String.fromCodePoint(0xf06a9) // md-robot
          font.family: Style.font.family
          font.pixelSize: 11
          color: pal.secondary
        }
        Text {
          text: "AGENTS"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        }
      }

      Repeater {
        model: monWidgetRoot.agents

        ColumnLayout {
          id: agentBlock
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.space(3)

          // Name only when several agents report limits.
          Text {
            visible: monWidgetRoot.agents.length > 1
            Layout.fillWidth: true
            text: agentBlock.modelData.name
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            elide: Text.ElideRight
          }

          Repeater {
            model: agentBlock.modelData.limits

            // Hover a row to swap the percentage for the reset countdown.
            RowLayout {
              id: limitRow
              required property var modelData
              readonly property real pct: Math.max(0, Math.min(100, modelData.percent * 100))
              Layout.fillWidth: true
              spacing: Style.space(5)

              HoverHandler { id: limitHover }

              Text {
                Layout.preferredWidth: 14
                text: monWidgetRoot.shortLimitLabel(limitRow.modelData.label)
                font.family: Style.font.family
                font.pixelSize: 9
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                  height: parent.height
                  width: Math.max(0, Math.min(parent.width, parent.width * limitRow.pct / 100))
                  radius: 2.5
                  color: monWidgetRoot.barColor(limitRow.pct, pal.secondary)
                  gradient: monWidgetRoot.barGradient(limitRow.pct) ? agentFillGradient : null
                  Gradient {
                    id: agentFillGradient
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: pal.primary }
                    GradientStop { position: 1; color: pal.secondary }
                  }
                  Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
              }

              Text {
                Layout.preferredWidth: 26
                horizontalAlignment: Text.AlignRight
                text: limitHover.hovered && limitRow.modelData.resetsInSec >= 0
                  ? monWidgetRoot.formatResetIn(limitRow.modelData.resetsInSec)
                  : Math.round(limitRow.pct) + "%"
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Color.foreground
              }
            }
          }
        }
      }
    }
    }
  }
}
