import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: gridWidgetRoot

  widgetId: "app_grid"
  title: "Quick Launch"
  icon: ""
  showHeader: false

  width: 340
  height: 380
  minWidth: 240
  minHeight: 220
  maxWidth: Math.min(700, screenWidth - 40)
  maxHeight: Math.min(900, screenHeight - 80)
  resizable: true

  // ---------------------------------------------------------------------------
  // 🔳 Pinned Apps, Grid Size, Pagination & Picker State
  // ---------------------------------------------------------------------------
  property var pinnedApps: []
  property int gridCols: 4
  property int currentPage: 0
  property var allApps: []
  property bool isLoading: false
  property bool pickerOpen: false
  property string pickerQuery: ""
  property int tileMenuIndex: -1
  property real tileMenuX: 0
  property real tileMenuY: 0

  // Full Theme Palette: tiles sweep accent -> cyan -> magenta across the
  // grid (hover wash, border, name), like the Karaoke visualizer bars.
  // Off = accent-only.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: gridWidgetRoot.themeColors
  }

  function toggleSetting(key) {
    gridWidgetRoot[key] = !gridWidgetRoot[key]
    gridWidgetRoot.saveSetting(key, gridWidgetRoot[key])
  }

  // Hue for the tile at grid position i (row-major, diagonal sweep).
  function tileHue(i) {
    if (!gridWidgetRoot.themeColors) return Color.accent
    var n = gridWidgetRoot.gridCols
    var t = n > 1 ? ((i % n) + Math.floor(i / n)) / (2 * (n - 1)) : 0
    return t < 0.5 ? pal.mixColor(pal.primary, pal.tertiary, t * 2) : pal.mixColor(pal.tertiary, pal.secondary, (t - 0.5) * 2)
  }

  function applySavedSettings() {
    themeColors = getSetting("themeColors", true)
    var pinned = getSetting("pinnedApps", undefined)
    if (Array.isArray(pinned)) gridWidgetRoot.pinnedApps = pinned
    var cols = getSetting("gridCols", 4)
    if (cols === 3 || cols === 4 || cols === 5) gridWidgetRoot.gridCols = cols
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  readonly property string appsScriptPath: {
    var u = Qt.resolvedUrl("../get-apps.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function loadApps() {
    if (appsProc.running) return
    gridWidgetRoot.isLoading = true
    appsProc.running = true
  }

  function launchApp(execCommand) {
    if (!execCommand) return
    Quickshell.execDetached([gridWidgetRoot.appsScriptPath, "launch", execCommand])
  }

  function getCategoryIcon(cat) {
    switch (cat) {
      case "Internet": return ""
      case "Dev": return ""
      case "Media": return ""
      case "System": return ""
      case "Utilities": return ""
      case "Games": return ""
      default: return ""
    }
  }

  Process {
    id: appsProc
    command: [gridWidgetRoot.appsScriptPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (Array.isArray(data)) gridWidgetRoot.allApps = data
        } catch (e) {
          console.warn("[AppGridWidget] parse error:", e)
        }
        gridWidgetRoot.isLoading = false
      }
    }
    onExited: function(exitCode) {
      gridWidgetRoot.isLoading = false
    }
  }

  function isPinned(app) {
    for (var i = 0; i < gridWidgetRoot.pinnedApps.length; i++) {
      var p = gridWidgetRoot.pinnedApps[i]
      if (p.exec === app.exec && p.name === app.name) return true
    }
    return false
  }

  function togglePin(app) {
    var arr = gridWidgetRoot.pinnedApps.slice()
    var idx = -1
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].exec === app.exec && arr[i].name === app.name) { idx = i; break }
    }
    if (idx >= 0) arr.splice(idx, 1)
    else arr.push({ name: app.name, icon: app.icon, exec: app.exec, category: app.category })
    gridWidgetRoot.pinnedApps = arr
    gridWidgetRoot.saveSetting("pinnedApps", arr)
  }

  function removeAppAt(idx) {
    if (idx < 0 || idx >= gridWidgetRoot.pinnedApps.length) return
    var arr = gridWidgetRoot.pinnedApps.slice()
    arr.splice(idx, 1)
    gridWidgetRoot.pinnedApps = arr
    gridWidgetRoot.saveSetting("pinnedApps", arr)
    var cap = gridWidgetRoot.gridCols * gridWidgetRoot.gridCols
    var maxPage = Math.max(0, Math.ceil((arr.length + 1) / cap) - 1)
    if (gridWidgetRoot.currentPage > maxPage) gridWidgetRoot.currentPage = maxPage
  }

  function setGridCols(n) {
    gridWidgetRoot.gridCols = n
    gridWidgetRoot.saveSetting("gridCols", n)
    gridWidgetRoot.currentPage = 0
  }

  function openPicker() {
    gridWidgetRoot.tileMenuIndex = -1
    gridWidgetRoot.pickerOpen = true
    gridWidgetRoot.pickerQuery = ""
    if (rootRef) rootRef.keyboardFocusRequested = true
    if (gridWidgetRoot.allApps.length === 0) gridWidgetRoot.loadApps()
  }

  function closePicker() {
    gridWidgetRoot.pickerOpen = false
    if (rootRef && rootRef.keyboardFocusRequested) rootRef.keyboardFocusRequested = false
  }

  // Same reuse as the Video Player widget's fullscreen (see that file): the
  // plugin's own root already wires a real Escape Shortcut to this shared
  // flag whenever it's set, so closing on Esc comes for free.
  Connections {
    target: rootRef || null
    function onKeyboardFocusRequestedChanged() {
      if (gridWidgetRoot.pickerOpen && rootRef && !rootRef.keyboardFocusRequested) {
        gridWidgetRoot.pickerOpen = false
      }
    }
  }

  readonly property var displayItems: gridWidgetRoot.pinnedApps.concat([{ __add: true }])
  readonly property int capacity: Math.max(1, gridWidgetRoot.gridCols * gridWidgetRoot.gridCols)
  readonly property int totalPages: Math.max(1, Math.ceil(gridWidgetRoot.displayItems.length / gridWidgetRoot.capacity))
  readonly property var currentPageItems: gridWidgetRoot.displayItems.slice(gridWidgetRoot.currentPage * gridWidgetRoot.capacity, gridWidgetRoot.currentPage * gridWidgetRoot.capacity + gridWidgetRoot.capacity)

  function nextPage() { if (gridWidgetRoot.currentPage < gridWidgetRoot.totalPages - 1) gridWidgetRoot.currentPage++ }
  function prevPage() { if (gridWidgetRoot.currentPage > 0) gridWidgetRoot.currentPage-- }

  onGridColsChanged: {
    if (gridWidgetRoot.currentPage > gridWidgetRoot.totalPages - 1) gridWidgetRoot.currentPage = Math.max(0, gridWidgetRoot.totalPages - 1)
  }

  property bool pickerSortByAdded: false

  readonly property var filteredPickerApps: {
    var q = gridWidgetRoot.pickerQuery.trim().toLowerCase()
    var out = []
    for (var i = 0; i < gridWidgetRoot.allApps.length; i++) {
      var a = gridWidgetRoot.allApps[i]
      if (q === "" || (a.name || "").toLowerCase().indexOf(q) !== -1) out.push(a)
    }
    if (gridWidgetRoot.pickerSortByAdded) {
      out = out.slice().sort(function(a, b) {
        var pa = gridWidgetRoot.isPinned(a) ? 0 : 1
        var pb = gridWidgetRoot.isPinned(b) ? 0 : 1
        if (pa !== pb) return pa - pb
        return (a.name || "").localeCompare(b.name || "")
      })
    }
    return out
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      Text {
        text: "GRID SIZE"
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
        spacing: Style.space(6)

        Repeater {
          model: [3, 4, 5]

          Rectangle {
            required property int modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isActive: gridWidgetRoot.gridCols === modelData
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (colsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isActive ? Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData + "×" + modelData
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? Color.accent : Color.foreground
            }

            MouseArea {
              id: colsMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: gridWidgetRoot.setGridCols(modelData)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 28
        radius: 6
        color: addMenuMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Add App..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: addMenuMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            gridWidgetRoot.openPicker()
            gridWidgetRoot.contextMenuOpen = false
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
            color: gridWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Full Theme Palette"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: gridWidgetRoot.themeColors ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: gridWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: themeToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gridWidgetRoot.toggleSetting("themeColors")
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        text: "Unlock Widgets Layout to remove pinned apps."
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      }
    }
  }

  ColumnLayout {
    id: gridCardLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(16)
    anchors.bottomMargin: Style.space(16)
    anchors.leftMargin: Style.space(16)
    anchors.rightMargin: Style.space(16)
    spacing: Style.space(8)

    // Header Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: gridWidgetRoot.pickerOpen ? "" : ""
        font.family: Style.font.family
        font.pixelSize: 14
        color: Color.accent
      }

      Text {
        Layout.fillWidth: true
        text: gridWidgetRoot.pickerOpen ? "Add App to Quick Launch" : "Quick Launch"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.foreground
        elide: Text.ElideRight
      }

      // Back / Done button while the picker is open
      Rectangle {
        visible: gridWidgetRoot.pickerOpen
        implicitWidth: doneRow.implicitWidth + Style.space(16)
        implicitHeight: 24
        radius: 12
        color: doneMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)

        RowLayout {
          id: doneRow
          anchors.centerIn: parent
          spacing: Style.space(4)
          Text {
            text: "Done"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Color.background
          }
        }

        MouseArea {
          id: doneMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gridWidgetRoot.closePicker()
        }
      }

      // Close / Hide Button (when in edit mode, normal view only)
      Rectangle {
        visible: !gridWidgetRoot.pickerOpen && rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeGridMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeGridMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(gridWidgetRoot.widgetId, false, gridWidgetRoot.monitorName)
            }
          }
        }
      }

      // Drag Grip Button (normal view only)
      Rectangle {
        visible: !gridWidgetRoot.pickerOpen && rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: gridGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: gridGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: gridWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, gridWidgetRoot.screenWidth - gridWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, gridWidgetRoot.screenHeight - gridWidgetRoot.height - 10)

          onPressed: gridWidgetRoot.customGripDragging = true
          onReleased: function() {
            gridWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, gridWidgetRoot.screenWidth - gridWidgetRoot.width - 10)
            var maxY = Math.max(10, gridWidgetRoot.screenHeight - gridWidgetRoot.height - 10)
            var snappedX = Math.round(gridWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(gridWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            gridWidgetRoot.targetItem.x = snappedX
            gridWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(gridWidgetRoot.widgetId, snappedX, snappedY, gridWidgetRoot.snapVal(gridWidgetRoot.width), gridWidgetRoot.snapVal(gridWidgetRoot.height), gridWidgetRoot.monitorName)
            }
          }
          onCanceled: gridWidgetRoot.customGripDragging = false
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: pal.line
    }

    // ---------------------------------------------------------------------
    // Normal Grid View
    // ---------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: !gridWidgetRoot.pickerOpen
      spacing: Style.space(6)

      GridView {
        id: appGridView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        cellWidth: Math.floor(width / gridWidgetRoot.gridCols)
        cellHeight: cellWidth

        model: gridWidgetRoot.currentPageItems

        delegate: Item {
          id: tileRoot
          required property var modelData
          required property int index
          readonly property color hue: gridWidgetRoot.tileHue(index)
          width: appGridView.cellWidth
          height: appGridView.cellHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 12
            color: modelData.__add
              ? (addTileMouse.containsMouse ? pal.tint(tileRoot.hue, 0.18) : Qt.rgba(1, 1, 1, 0.03))
              : (tileMouse.containsMouse ? (gridWidgetRoot.themeColors ? pal.tint(tileRoot.hue, 0.16) : Qt.rgba(1, 1, 1, 0.12)) : Qt.rgba(1, 1, 1, 0.03))
            border.color: modelData.__add ? pal.tint(tileRoot.hue, 0.4)
              : (gridWidgetRoot.themeColors && tileMouse.containsMouse ? pal.tint(tileRoot.hue, 0.45) : "transparent")
            border.width: modelData.__add || (gridWidgetRoot.themeColors && tileMouse.containsMouse) ? 1 : 0

            scale: (modelData.__add ? addTileMouse.pressed : tileMouse.pressed) ? 0.94
              : ((modelData.__add ? addTileMouse.containsMouse : tileMouse.containsMouse) ? 1.03 : 1.0)

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            // Add Tile
            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2
              visible: !!modelData.__add

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: ""
                font.family: Style.font.family
                font.pixelSize: 20
                color: tileRoot.hue
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Add"
                font.family: Style.font.family
                font.pixelSize: 9
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
              }
            }

            // App Tile
            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 6
              spacing: 3
              visible: !modelData.__add

              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(36, tileRoot.width * 0.42)
                Layout.preferredHeight: Layout.preferredWidth

                Image {
                  id: tileIconImage
                  anchors.fill: parent
                  source: modelData.__add ? "" : ((modelData.icon && modelData.icon.startsWith("/")) ? ("file://" + modelData.icon) : (modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""))
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  smooth: true
                }

                Text {
                  visible: tileIconImage.status !== Image.Ready
                  anchors.centerIn: parent
                  text: gridWidgetRoot.getCategoryIcon(modelData.category)
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: tileRoot.hue
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: modelData.name || ""
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: tileMouse.containsMouse ? tileRoot.hue : Color.foreground
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
              }
            }

            // Remove Badge (edit mode only, app tiles only)
            Rectangle {
              visible: !modelData.__add && rootRef && rootRef.layoutEditMode
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: 2
              width: 16
              height: 16
              radius: 8
              color: removeMouse.containsMouse ? Color.urgent : Qt.rgba(0, 0, 0, 0.6)
              border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.6)
              border.width: 1
              z: 5

              Text {
                anchors.centerIn: parent
                text: ""
                font.family: Style.font.family
                font.pixelSize: 8
                color: "#ffffff"
              }

              MouseArea {
                id: removeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: gridWidgetRoot.removeAppAt(gridWidgetRoot.currentPage * gridWidgetRoot.capacity + tileRoot.index)
              }
            }

            MouseArea {
              id: tileMouse
              anchors.fill: parent
              visible: !modelData.__add
              enabled: !modelData.__add
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                  var pos = tileMouse.mapToItem(gridWidgetRoot, mouse.x, mouse.y)
                  gridWidgetRoot.tileMenuIndex = gridWidgetRoot.currentPage * gridWidgetRoot.capacity + tileRoot.index
                  gridWidgetRoot.tileMenuX = pos.x
                  gridWidgetRoot.tileMenuY = pos.y
                } else {
                  gridWidgetRoot.launchApp(modelData.exec)
                }
              }
            }

            MouseArea {
              id: addTileMouse
              anchors.fill: parent
              visible: !!modelData.__add
              enabled: !!modelData.__add
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: gridWidgetRoot.openPicker()
            }
          }
        }
      }

      // Pagination Row
      RowLayout {
        Layout.fillWidth: true
        visible: gridWidgetRoot.totalPages > 1
        spacing: Style.space(10)

        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 12
          color: gridWidgetRoot.currentPage > 0 ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.25)

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            enabled: gridWidgetRoot.currentPage > 0
            onClicked: gridWidgetRoot.prevPage()
          }
        }

        Item { Layout.fillWidth: true }

        Text {
          text: (gridWidgetRoot.currentPage + 1) + " / " + gridWidgetRoot.totalPages
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }

        Item { Layout.fillWidth: true }

        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 12
          color: gridWidgetRoot.currentPage < gridWidgetRoot.totalPages - 1 ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.25)

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            enabled: gridWidgetRoot.currentPage < gridWidgetRoot.totalPages - 1
            onClicked: gridWidgetRoot.nextPage()
          }
        }
      }
    }

    // ---------------------------------------------------------------------
    // Add-App Picker
    // ---------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: gridWidgetRoot.pickerOpen
      spacing: Style.space(8)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Rectangle {
        Layout.fillWidth: true
        height: 32
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.07)
        border.color: pickerSearchInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: 11
            color: pickerSearchInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }

          TextInput {
            id: pickerSearchInput
            Layout.fillWidth: true
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            clip: true
            text: gridWidgetRoot.pickerQuery
            onTextChanged: gridWidgetRoot.pickerQuery = text

            Text {
              anchors.fill: parent
              visible: !pickerSearchInput.text && !pickerSearchInput.activeFocus
              text: "Search applications..."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
            }
          }
        }
        }

        // Sort toggle: alphabetical (default) vs already-pinned apps first
        Rectangle {
          implicitWidth: sortToggleRow.implicitWidth + Style.space(14)
          implicitHeight: 32
          radius: 16
          color: gridWidgetRoot.pickerSortByAdded ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.07)
          border.color: gridWidgetRoot.pickerSortByAdded ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
          border.width: 1

          RowLayout {
            id: sortToggleRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: 10
              color: gridWidgetRoot.pickerSortByAdded ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }
            Text {
              text: gridWidgetRoot.pickerSortByAdded ? "Added" : "A-Z"
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: gridWidgetRoot.pickerSortByAdded ? Color.accent : Color.foreground
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gridWidgetRoot.pickerSortByAdded = !gridWidgetRoot.pickerSortByAdded
          }
        }
      }

      Text {
        visible: gridWidgetRoot.isLoading
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Loading applications..."
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
      }

      ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !gridWidgetRoot.isLoading
        spacing: 2
        model: gridWidgetRoot.filteredPickerApps

        delegate: Rectangle {
          id: pickerRow
          required property var modelData
          width: ListView.view.width
          height: 34
          radius: 8
          readonly property bool pinned: gridWidgetRoot.isPinned(modelData)
          color: pickerRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Item {
              Layout.preferredWidth: 20
              Layout.preferredHeight: 20

              Image {
                id: pickerIconImage
                anchors.fill: parent
                source: (pickerRow.modelData.icon && pickerRow.modelData.icon.startsWith("/")) ? ("file://" + pickerRow.modelData.icon) : (pickerRow.modelData.icon ? Quickshell.iconPath(pickerRow.modelData.icon, true) : "")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
              }

              Text {
                visible: pickerIconImage.status !== Image.Ready
                anchors.centerIn: parent
                text: gridWidgetRoot.getCategoryIcon(pickerRow.modelData.category)
                font.family: Style.font.family
                font.pixelSize: 12
                color: Color.accent
              }
            }

            Text {
              Layout.fillWidth: true
              text: pickerRow.modelData.name || ""
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.foreground
              elide: Text.ElideRight
            }

            Text {
              text: pickerRow.pinned ? "" : ""
              font.family: Style.font.family
              font.pixelSize: 11
              color: pickerRow.pinned ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            }
          }

          MouseArea {
            id: pickerRowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gridWidgetRoot.togglePin(pickerRow.modelData)
          }
        }
      }
    }
  }

  // Click-outside backdrop to dismiss the per-tile right-click menu
  MouseArea {
    anchors.fill: parent
    visible: gridWidgetRoot.tileMenuIndex >= 0
    z: 49
    onClicked: gridWidgetRoot.tileMenuIndex = -1
  }

  // Per-tile right-click menu (Remove from Quick Launch)
  Rectangle {
    id: tileContextMenu
    visible: gridWidgetRoot.tileMenuIndex >= 0
    x: Math.max(4, Math.min(gridWidgetRoot.tileMenuX, gridWidgetRoot.width - width - 6))
    y: Math.max(4, Math.min(gridWidgetRoot.tileMenuY, gridWidgetRoot.height - height - 6))
    z: 50
    implicitWidth: tileMenuRow.implicitWidth + Style.space(20)
    implicitHeight: 30
    radius: 8
    color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    RowLayout {
      id: tileMenuRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        text: ""
        font.family: Style.font.family
        font.pixelSize: 10
        color: Color.urgent
      }
      Text {
        text: "Remove from Quick Launch"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Color.foreground
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        gridWidgetRoot.removeAppAt(gridWidgetRoot.tileMenuIndex)
        gridWidgetRoot.tileMenuIndex = -1
      }
    }
  }
}
