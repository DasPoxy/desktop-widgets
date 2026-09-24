import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

import "../../shared"
import ".."

WidgetCard {
  id: aboutWidgetRoot

  widgetId: "system_about"
  title: "About This System"
  icon: ""
  showHeader: false

  width: 320
  height: 380
  minWidth: 260
  minHeight: 200
  maxWidth: Math.min(900, screenWidth - 40)
  maxHeight: Math.min(1200, screenHeight - 80)
  resizable: true

  // ---------------------------------------------------------------------------
  // 🖥️ fastfetch/Omarchy "About" Snapshot + Theme Palette State
  // ---------------------------------------------------------------------------
  property var info: ({})
  property var swatches: []
  property int pollIntervalMs: 30000
  readonly property bool hasData: Object.keys(info).length > 0

  // Full Theme Palette: each section's icons and heading take their own
  // theme hue (hardware cyan, software magenta, uptime green).
  // Off = accent-only.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: aboutWidgetRoot.themeColors
  }

  function toggleSetting(key) {
    aboutWidgetRoot[key] = !aboutWidgetRoot[key]
    aboutWidgetRoot.saveSetting(key, aboutWidgetRoot[key])
  }

  // Grid Mode: the header divider carries on down the middle and between
  // the rows and sections, like a table. Line positions are measured from
  // the laid-out cells (updateGridLines), so they follow resizes and data.
  property bool gridMode: false
  property var gridLineYs: []
  property real gridLineX: 0

  function applySavedSettings() {
    pollIntervalMs = getSetting("pollIntervalMs", 30000)
    themeColors = getSetting("themeColors", true)
    gridMode = getSetting("gridMode", false)
  }

  onGridModeChanged: gridLinesTimer.restart()
  onInfoChanged: gridLinesTimer.restart()
  Timer {
    id: gridLinesTimer
    interval: 30
    onTriggered: aboutWidgetRoot.updateGridLines()
  }
  function updateGridLines() {
    if (!gridMode) return
    var ys = [], first = true, x = 0
    var secs = [[hardwareSection, hardwareGrid], [softwareSection, softwareGrid], [uptimeSection, uptimeGrid]]
    for (var k = 0; k < secs.length; k++) {
      var sec = secs[k][0], grid = secs[k][1]
      if (!sec.visible) continue
      if (!first) ys.push(sec.y - aboutColumn.spacing / 2)
      first = false
      var cells = []
      for (var c = 0; c < grid.children.length; c++)
        if (grid.children[c].modelData !== undefined && grid.children[c].visible) cells.push(grid.children[c])
      if (!x && cells.length > 1) x = grid.x + (cells[0].x + cells[0].width + cells[1].x) / 2
      for (var i = 2; i < cells.length; i += 2)
        ys.push(sec.y + grid.y + (cells[i - 2].y + cells[i - 2].height + cells[i].y) / 2)
    }
    gridLineYs = ys
    gridLineX = x || aboutColumn.width / 2
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function buildRows(pairs) {
    var out = []
    for (var i = 0; i < pairs.length; i++) {
      var value = pairs[i][2]
      if (value !== undefined && value !== null && value !== "") {
        out.push({ icon: pairs[i][0], label: pairs[i][1], value: value })
      }
    }
    return out
  }

  readonly property var hardwareRows: buildRows([
    ["", "Host", info.host],
    ["", "CPU", info.cpu],
    ["", "Cores", info.cpu_cores],
    ["", "GPU", info.gpu],
    ["", "Display", info.display],
    ["", "Disk", (info.disk_used && info.disk_total) ? (info.disk_used + " / " + info.disk_total) : ""],
    ["", "Memory", (info.memory_used && info.memory_total) ? (info.memory_used + " / " + info.memory_total) : ""],
    ["", "Swap", (info.swap_used && info.swap_total) ? (info.swap_used + " / " + info.swap_total) : ""]
  ])

  readonly property var softwareRows: buildRows([
    ["", "OS", info.os],
    ["", "Kernel", info.kernel],
    ["", "WM", info.wm],
    ["", "Desktop", info.de],
    ["", "Channel", info.channel],
    ["", "Branch", info.branch],
    ["", "Packages", info.packages],
    ["", "Theme", info.theme]
  ])

  readonly property var uptimeRows: buildRows([
    ["", "Uptime", info.uptime],
    ["", "Age", info.os_age],
    ["", "Updated", info.last_update]
  ])

  readonly property string aboutScriptPath: {
    var u = Qt.resolvedUrl("get-about.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function refreshNow() {
    if (!aboutProc.running) aboutProc.running = true
  }

  Process {
    id: aboutProc
    command: [aboutWidgetRoot.aboutScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          aboutWidgetRoot.info = data
          aboutWidgetRoot.swatches = Array.isArray(data.swatches) ? data.swatches : []
        } catch (e) {
          console.warn("[SystemAboutWidget] parse error:", e)
        }
      }
    }
  }

  Timer {
    interval: aboutWidgetRoot.pollIntervalMs
    running: true
    repeat: true
    onTriggered: aboutWidgetRoot.refreshNow()
  }

  // Shared compact "icon + label / value" grid-cell delegate, reused by the
  // Hardware/Software/Uptime GridLayouts below (2 columns instead of the
  // original one-full-width-row-per-fact layout, roughly halving their
  // height) so all three sections stay in sync visually with one definition.
  Component {
    id: infoCellDelegate

    ColumnLayout {
      required property var modelData
      // Section hue, from the enclosing GridLayout (see sectionHue below).
      readonly property color hue: parent && parent.sectionHue !== undefined ? parent.sectionHue : Color.accent
      Layout.fillWidth: true
      // Grid Mode: equal columns, so the middle line runs straight down.
      Layout.preferredWidth: aboutWidgetRoot.gridMode ? 1 : -1
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
          text: modelData.icon
          font.family: Style.font.family
          font.pixelSize: 9
          color: hue
        }

        Text {
          Layout.fillWidth: true
          text: modelData.label
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
          elide: Text.ElideRight
        }
      }

      Text {
        Layout.fillWidth: true
        text: modelData.value
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Color.foreground
        elide: Text.ElideRight
      }
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refreshMenuMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Refresh Now"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: refreshMenuMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            aboutWidgetRoot.refreshNow()
            aboutWidgetRoot.contextMenuOpen = false
          }
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
            color: aboutWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Full Theme Palette"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: aboutWidgetRoot.themeColors ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: aboutWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: themeToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: aboutWidgetRoot.toggleSetting("themeColors")
        }
      }
      // Grid Mode toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: gridModeMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: String.fromCodePoint(0xf02c1) // md-grid
            font.family: Style.font.family
            font.pixelSize: 11
            color: aboutWidgetRoot.gridMode ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Grid Mode"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: aboutWidgetRoot.gridMode ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: aboutWidgetRoot.gridMode ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: gridModeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: aboutWidgetRoot.toggleSetting("gridMode")
        }
      }
      // Update the whole custom widget suite from its repo.
      SuiteUpdateItem {}
    }
  }

  ColumnLayout {
    id: aboutCardLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(14)
    anchors.bottomMargin: Style.space(14)
    anchors.leftMargin: Style.space(16)
    anchors.rightMargin: Style.space(16)
    spacing: Style.space(8)

    // Header Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        text: ""
        font.family: Style.font.family
        font.pixelSize: 13
        color: Color.accent
      }

      ColumnLayout {
        spacing: 0
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: aboutWidgetRoot.info.os || "About This System"
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.Bold
          color: Color.foreground
          elide: Text.ElideRight
        }

        Text {
          visible: !!aboutWidgetRoot.info.theme
          text: (aboutWidgetRoot.info.theme || "") + " theme"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }
      }

      Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

      // Theme Palette — compact swatch strip, wraps to a few rows if the
      // theme has a lot of colors, no hex captions at this size.
      Flow {
        visible: aboutWidgetRoot.swatches.length > 0
        Layout.preferredWidth: Math.min(110, aboutWidgetRoot.swatches.length * 13)
        Layout.maximumWidth: 110
        Layout.alignment: Qt.AlignTop
        spacing: 3

        Repeater {
          model: aboutWidgetRoot.swatches

          Rectangle {
            required property var modelData
            width: 10
            height: 10
            radius: 3
            color: modelData.hex
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 1
          }
        }
      }

      // Close / Hide Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeAboutMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeAboutMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(aboutWidgetRoot.widgetId, false, aboutWidgetRoot.monitorName)
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
        color: aboutGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: aboutGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: aboutWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, aboutWidgetRoot.screenWidth - aboutWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, aboutWidgetRoot.screenHeight - aboutWidgetRoot.height - 10)

          onPressed: aboutWidgetRoot.customGripDragging = true
          onReleased: function() {
            aboutWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, aboutWidgetRoot.screenWidth - aboutWidgetRoot.width - 10)
            var maxY = Math.max(10, aboutWidgetRoot.screenHeight - aboutWidgetRoot.height - 10)
            var snappedX = Math.round(aboutWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(aboutWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            aboutWidgetRoot.targetItem.x = snappedX
            aboutWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(aboutWidgetRoot.widgetId, snappedX, snappedY, aboutWidgetRoot.snapVal(aboutWidgetRoot.width), aboutWidgetRoot.snapVal(aboutWidgetRoot.height), aboutWidgetRoot.monitorName)
            }
          }
          onCanceled: aboutGripArea.customGripDragging = false
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: pal.line
    }

    Text {
      visible: !aboutWidgetRoot.hasData
      Layout.fillWidth: true
      Layout.topMargin: Style.space(20)
      horizontalAlignment: Text.AlignHCenter
      text: "Gathering system info..."
      font.family: Style.font.family
      font.pixelSize: 12
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
    }

    Flickable {
      id: aboutFlick
      Layout.fillWidth: true
      Layout.fillHeight: true
      // Grid Mode: reach up into the layout gap (topMargin puts the content
      // back) so the middle line meets the header divider.
      Layout.topMargin: aboutWidgetRoot.gridMode ? -aboutCardLayout.spacing : 0
      topMargin: aboutWidgetRoot.gridMode ? aboutCardLayout.spacing : 0
      visible: aboutWidgetRoot.hasData
      clip: true
      contentWidth: width
      contentHeight: aboutColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      GridLines {
        visible: aboutWidgetRoot.gridMode
        xs: [aboutWidgetRoot.gridLineX]
        ys: aboutWidgetRoot.gridLineYs
        vTop: -aboutFlick.topMargin
        vBottom: aboutColumn.implicitHeight
        hLeft: 0
        hRight: aboutColumn.width
        color: pal.line
      }

      ColumnLayout {
        id: aboutColumn
        width: aboutFlick.width
        spacing: Style.space(10)
        onImplicitHeightChanged: gridLinesTimer.restart()
        onWidthChanged: gridLinesTimer.restart()

        // Hardware Section
        ColumnLayout {
          id: hardwareSection
          Layout.fillWidth: true
          spacing: Style.space(3)
          visible: aboutWidgetRoot.hardwareRows.length > 0

          Text {
            text: "HARDWARE"
            font.family: Style.font.family
            font.pixelSize: 8
            font.weight: Font.Bold
            color: aboutWidgetRoot.themeColors ? pal.tint(pal.tertiary, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }

          GridLayout {
            id: hardwareGrid
            readonly property color sectionHue: pal.tertiary
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(14)
            rowSpacing: Style.space(5)

            Repeater {
              model: aboutWidgetRoot.hardwareRows
              delegate: infoCellDelegate
            }
          }
        }

        // Software Section
        ColumnLayout {
          id: softwareSection
          Layout.fillWidth: true
          spacing: Style.space(3)
          visible: aboutWidgetRoot.softwareRows.length > 0

          Text {
            text: "SOFTWARE"
            font.family: Style.font.family
            font.pixelSize: 8
            font.weight: Font.Bold
            color: aboutWidgetRoot.themeColors ? pal.tint(pal.secondary, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }

          GridLayout {
            id: softwareGrid
            readonly property color sectionHue: pal.secondary
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(14)
            rowSpacing: Style.space(5)

            Repeater {
              model: aboutWidgetRoot.softwareRows
              delegate: infoCellDelegate
            }
          }
        }

        // Uptime Section
        ColumnLayout {
          id: uptimeSection
          Layout.fillWidth: true
          spacing: Style.space(3)
          visible: aboutWidgetRoot.uptimeRows.length > 0

          Text {
            text: "AGE / UPTIME / UPDATE"
            font.family: Style.font.family
            font.pixelSize: 8
            font.weight: Font.Bold
            color: aboutWidgetRoot.themeColors ? pal.tint(pal.live, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }

          GridLayout {
            id: uptimeGrid
            readonly property color sectionHue: pal.live
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(14)
            rowSpacing: Style.space(5)

            Repeater {
              model: aboutWidgetRoot.uptimeRows
              delegate: infoCellDelegate
            }
          }
        }

      }
    }
  }
}
