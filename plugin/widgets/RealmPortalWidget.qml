import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: realmWidgetRoot

  widgetId: "realm_portal"
  title: "Visit Another Realm"
  icon: realmWidgetRoot.iconGlyph
  showHeader: false

  defaultX: 460
  defaultY: 140

  width: 300
  height: 190
  minWidth: 160
  minHeight: 120
  maxWidth: 420
  maxHeight: 260
  resizable: true

  property bool launching: false
  property string statusText: ""
  property bool statusIsError: false

  // ---------------------------------------------------------------------------
  // 🎨 Selectable Icon (right-click menu) -- codepoints verified against the
  // live JetBrainsMono Nerd Font's own cmap (nerd-fonts' glyphnames.json
  // numbering has moved on since older cheat sheets; e.g. fa-dungeon is
  // 0xeefa on this font, not the 0xf6d9 some references still show, which
  // rendered as a missing-glyph box -- that was the original bug here).
  property int iconCodePoint: 0xeefa // fa-dungeon (default)
  readonly property string iconGlyph: String.fromCodePoint(realmWidgetRoot.iconCodePoint)

  readonly property var iconChoices: [
    { name: "Dungeon", code: 0xeefa },
    { name: "Controller", code: 0xf11b },
    { name: "Sword", code: 0xf04e5, leaning: true },
    { name: "Shield", code: 0xf132 },
    { name: "Axe", code: 0xf08c8, leaning: true },
    { name: "Wand", code: 0xf0d0, leaning: true },
    { name: "Tome", code: 0xf02d },
    { name: "Scroll", code: 0xef0d },
    { name: "Dice", code: 0xeef5 }
  ]

  // Axe/sword/wand glyphs are drawn leaning in the font itself; the header
  // shows one on each side of the title, so the left one is mirrored to
  // face outward (\ /) instead of both leaning the same way (/ /).
  readonly property bool iconLeans: {
    for (var i = 0; i < realmWidgetRoot.iconChoices.length; i++) {
      if (realmWidgetRoot.iconChoices[i].code === realmWidgetRoot.iconCodePoint)
        return !!realmWidgetRoot.iconChoices[i].leaning
    }
    return false
  }

  function setIcon(code) {
    realmWidgetRoot.iconCodePoint = code
    realmWidgetRoot.saveSetting("iconCodePoint", code)
  }

  // ---------------------------------------------------------------------------
  // 🖼️ Diagonal Cover-Art Swatches (right-click menu sets the shuffle rate)
  // ---------------------------------------------------------------------------
  property var swatchImages: []
  property int shuffleIntervalMs: 5000 // 0 = off

  readonly property var shuffleIntervalChoices: [
    { label: "Off", ms: 0 },
    { label: "3s", ms: 3000 },
    { label: "5s", ms: 5000 },
    { label: "10s", ms: 10000 },
    { label: "30s", ms: 30000 }
  ]

  // Swatch seam angle: "left" (╲, the original look), "straight" (│) or
  // "right" (╱). Drives the shear on the swatch row below.
  property string swatchSlant: "left"

  readonly property var swatchSlantChoices: [
    { label: "\u2572 Left", value: "left" },
    { label: "\u2502 Straight", value: "straight" },
    { label: "\u2571 Right", value: "right" }
  ]

  function setSwatchSlant(v) {
    realmWidgetRoot.swatchSlant = v
    realmWidgetRoot.saveSetting("swatchSlant", v)
  }

  function setShuffleInterval(ms) {
    realmWidgetRoot.shuffleIntervalMs = ms
    realmWidgetRoot.saveSetting("shuffleIntervalMs", ms)
  }

  function refreshSwatches() {
    if (thumbnailProc.running) return
    thumbnailProc.running = true
  }

  Process {
    id: thumbnailProc
    command: [realmWidgetRoot.scriptPath, "thumbnails", "4", "--exclude", realmWidgetRoot.excludeArg]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok" && data.games) {
            realmWidgetRoot.swatchImages = data.games
          } else {
            realmWidgetRoot.swatchImages = []
          }
        } catch (e) {
          console.warn("[RealmPortalWidget] thumbnails parse error:", e)
        }
      }
    }
  }

  Timer {
    id: shuffleTimer
    interval: Math.max(1000, realmWidgetRoot.shuffleIntervalMs)
    running: realmWidgetRoot.shuffleIntervalMs > 0
    repeat: true
    onTriggered: realmWidgetRoot.refreshSwatches()
  }

  // ---------------------------------------------------------------------------
  // ✏️ Custom Header / Button Text (right-click menu). Empty = default;
  // the "Blank" toggles show no text at all.
  // ---------------------------------------------------------------------------
  readonly property string defaultHeaderText: "Visit Another Realm"
  readonly property string defaultButtonText: "Adventure Awaits!"
  property string headerText: ""
  property string buttonText: ""
  property bool headerBlank: false
  property bool buttonBlank: false
  readonly property string shownHeaderText: headerBlank ? "" : (headerText || defaultHeaderText)
  readonly property string shownButtonText: buttonBlank ? "" : (buttonText || defaultButtonText)

  function setHeaderBlank(b) {
    realmWidgetRoot.headerBlank = b
    realmWidgetRoot.saveSetting("headerBlank", b)
  }

  function setButtonBlank(b) {
    realmWidgetRoot.buttonBlank = b
    realmWidgetRoot.saveSetting("buttonBlank", b)
  }

  function setHeaderText(t) {
    realmWidgetRoot.headerText = t
    realmWidgetRoot.saveSetting("headerText", t)
  }

  function setButtonText(t) {
    realmWidgetRoot.buttonText = t
    realmWidgetRoot.saveSetting("buttonText", t)
  }

  // ---------------------------------------------------------------------------
  // 🚫 Excluded Games (right-click menu). Stored as the script's stable
  // per-game keys (steam:<appid>, heroic:<app_name>, lutris:<id>) and passed
  // back via --exclude, so both the launcher and the cover-art swatches skip
  // them.
  // ---------------------------------------------------------------------------
  property var excludedGames: []
  property var allGames: []
  property bool gameListOpen: false
  property string gameFilter: ""
  readonly property string excludeArg: JSON.stringify(realmWidgetRoot.excludedGames)

  function isExcluded(key) {
    return realmWidgetRoot.excludedGames.indexOf(key) !== -1
  }

  function toggleExcluded(key) {
    var list = realmWidgetRoot.excludedGames.slice()
    var i = list.indexOf(key)
    if (i === -1) list.push(key)
    else list.splice(i, 1)
    realmWidgetRoot.excludedGames = list
    realmWidgetRoot.saveSetting("excludedGames", list)
    realmWidgetRoot.refreshSwatches()
  }

  function clearExcluded() {
    realmWidgetRoot.excludedGames = []
    realmWidgetRoot.saveSetting("excludedGames", [])
    realmWidgetRoot.refreshSwatches()
  }

  readonly property var filteredGames: {
    var q = realmWidgetRoot.gameFilter.trim().toLowerCase()
    if (!q) return realmWidgetRoot.allGames
    return realmWidgetRoot.allGames.filter(function(g) {
      return g.name.toLowerCase().indexOf(q) !== -1 || g.source.toLowerCase().indexOf(q) !== -1
    })
  }

  function openGameList() {
    realmWidgetRoot.gameListOpen = !realmWidgetRoot.gameListOpen
    if (realmWidgetRoot.gameListOpen && !listGamesProc.running) listGamesProc.running = true
  }

  Process {
    id: listGamesProc
    command: [realmWidgetRoot.scriptPath, "list"]
    running: false
    stdout: SplitParser {
      onRead: function(data) {
        try {
          var res = JSON.parse(String(data).trim())
          realmWidgetRoot.allGames = (res.status === "ok" && res.games) ? res.games : []
        } catch (e) {
          console.warn("[RealmPortalWidget] list parse error:", e)
        }
      }
    }
  }

  // Text inputs in the floating menu need the desktop layer to take
  // keyboard focus on demand (same shared flag the Quick Launch picker and
  // Video Player use); hand it back as soon as the menu closes.
  property bool holdsKeyboardFocus: false

  function grabKeyboard(input) {
    if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
    realmWidgetRoot.holdsKeyboardFocus = true
    input.forceActiveFocus()
  }

  function releaseKeyboard() {
    if (!realmWidgetRoot.holdsKeyboardFocus) return
    realmWidgetRoot.holdsKeyboardFocus = false
    if (rootRef && rootRef.keyboardFocusRequested) rootRef.keyboardFocusRequested = false
  }

  onContextMenuOpenChanged: {
    if (!realmWidgetRoot.contextMenuOpen) {
      realmWidgetRoot.releaseKeyboard()
      realmWidgetRoot.gameListOpen = false
      realmWidgetRoot.gameFilter = ""
    }
  }

  // Full Theme Palette: the two header glyphs take the theme's secondary /
  // tertiary hues, the portal gets an accent -> secondary wash and the
  // status line picks up the theme's own green/red. Off = accent-only.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: realmWidgetRoot.themeColors
  }

  function toggleSetting(key) {
    realmWidgetRoot[key] = !realmWidgetRoot[key]
    realmWidgetRoot.saveSetting(key, realmWidgetRoot[key])
  }

  function applySavedSettings() {
    realmWidgetRoot.themeColors = getSetting("themeColors", true)
    realmWidgetRoot.iconCodePoint = getSetting("iconCodePoint", 0xeefa)
    realmWidgetRoot.shuffleIntervalMs = getSetting("shuffleIntervalMs", 5000)
    realmWidgetRoot.swatchSlant = getSetting("swatchSlant", "left")
    realmWidgetRoot.headerText = getSetting("headerText", "")
    realmWidgetRoot.buttonText = getSetting("buttonText", "")
    realmWidgetRoot.headerBlank = getSetting("headerBlank", false)
    realmWidgetRoot.buttonBlank = getSetting("buttonBlank", false)
    var ex = getSetting("excludedGames", [])
    realmWidgetRoot.excludedGames = Array.isArray(ex) ? ex : []
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    realmWidgetRoot.refreshSwatches()
  }

  function visitAnotherRealm() {
    if (realmWidgetRoot.launching) return
    realmWidgetRoot.launching = true
    realmWidgetRoot.statusText = "Opening a portal..."
    realmWidgetRoot.statusIsError = false
    randomGameProc.running = true
  }

  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("../get-random-game.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: randomGameProc
    command: [realmWidgetRoot.scriptPath, "--exclude", realmWidgetRoot.excludeArg]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            realmWidgetRoot.statusText = "Launching " + data.name + " via " + data.source + "..."
            realmWidgetRoot.statusIsError = false
          } else if (data.status === "empty") {
            realmWidgetRoot.statusText = "No installed games found across Steam, Heroic, or Lutris."
            realmWidgetRoot.statusIsError = true
          } else {
            realmWidgetRoot.statusText = "Couldn't launch a game" + (data.message ? (": " + data.message) : ".")
            realmWidgetRoot.statusIsError = true
          }
        } catch (e) {
          realmWidgetRoot.statusText = "Couldn't read the game list."
          realmWidgetRoot.statusIsError = true
          console.warn("[RealmPortalWidget] parse error:", e)
        }
      }
    }
    onExited: function(exitCode) {
      realmWidgetRoot.launching = false
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        text: "PORTAL"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        text: "Picks a random installed game from Steam, Heroic, or Lutris and launches it."
        font.family: Style.font.family
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
      }

      Text {
        text: "TEXT"
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
        spacing: Style.space(6)

        Text {
          Layout.preferredWidth: 44
          text: "Title"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 6
          color: Qt.rgba(1, 1, 1, 0.07)
          border.color: headerTextInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
          border.width: 1

          TextInput {
            id: headerTextInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
            clip: true
            maximumLength: 40
            enabled: !realmWidgetRoot.headerBlank
            opacity: realmWidgetRoot.headerBlank ? 0.35 : 1
            text: realmWidgetRoot.headerText
            onTextEdited: realmWidgetRoot.setHeaderText(text)

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: !headerTextInput.text && !headerTextInput.activeFocus
              text: realmWidgetRoot.headerBlank ? "(blank)" : realmWidgetRoot.defaultHeaderText
              font.family: Style.font.family
              font.pixelSize: 11
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                realmWidgetRoot.grabKeyboard(headerTextInput)
                mouse.accepted = false
              }
            }
          }
        }

        Rectangle {
          implicitWidth: 46
          implicitHeight: 26
          radius: 6
          color: realmWidgetRoot.headerBlank ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (headerBlankMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
          border.color: realmWidgetRoot.headerBlank ? Color.accent : "transparent"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "Blank"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: realmWidgetRoot.headerBlank ? Font.Bold : Font.Normal
            color: realmWidgetRoot.headerBlank ? Color.accent : Color.foreground
          }

          MouseArea {
            id: headerBlankMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              headerTextInput.focus = false
              realmWidgetRoot.setHeaderBlank(!realmWidgetRoot.headerBlank)
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: Style.space(6)

        Text {
          Layout.preferredWidth: 44
          text: "Button"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 6
          color: Qt.rgba(1, 1, 1, 0.07)
          border.color: buttonTextInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
          border.width: 1

          TextInput {
            id: buttonTextInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
            clip: true
            maximumLength: 40
            enabled: !realmWidgetRoot.buttonBlank
            opacity: realmWidgetRoot.buttonBlank ? 0.35 : 1
            text: realmWidgetRoot.buttonText
            onTextEdited: realmWidgetRoot.setButtonText(text)

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: !buttonTextInput.text && !buttonTextInput.activeFocus
              text: realmWidgetRoot.buttonBlank ? "(blank)" : realmWidgetRoot.defaultButtonText
              font.family: Style.font.family
              font.pixelSize: 11
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                realmWidgetRoot.grabKeyboard(buttonTextInput)
                mouse.accepted = false
              }
            }
          }
        }

        Rectangle {
          implicitWidth: 46
          implicitHeight: 26
          radius: 6
          color: realmWidgetRoot.buttonBlank ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (buttonBlankMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
          border.color: realmWidgetRoot.buttonBlank ? Color.accent : "transparent"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "Blank"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: realmWidgetRoot.buttonBlank ? Font.Bold : Font.Normal
            color: realmWidgetRoot.buttonBlank ? Color.accent : Color.foreground
          }

          MouseArea {
            id: buttonBlankMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              buttonTextInput.focus = false
              realmWidgetRoot.setButtonBlank(!realmWidgetRoot.buttonBlank)
            }
          }
        }
      }

      Text {
        text: "ICON"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 6
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Style.space(6)
        rowSpacing: Style.space(6)

        Repeater {
          model: realmWidgetRoot.iconChoices

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 8
            color: modelData.code === realmWidgetRoot.iconCodePoint
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
              : (iconChoiceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.color: modelData.code === realmWidgetRoot.iconCodePoint ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: String.fromCodePoint(modelData.code)
                font.family: Style.font.family
                font.pixelSize: 16
                color: modelData.code === realmWidgetRoot.iconCodePoint ? Color.accent : Color.foreground
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 8
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
              }
            }

            MouseArea {
              id: iconChoiceMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: realmWidgetRoot.setIcon(modelData.code)
            }
          }
        }
      }

      Text {
        text: "SHUFFLE INTERVAL"
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
          model: realmWidgetRoot.shuffleIntervalChoices

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isActive: realmWidgetRoot.shuffleIntervalMs === modelData.ms
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (shuffleRateMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
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
              id: shuffleRateMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: realmWidgetRoot.setShuffleInterval(modelData.ms)
            }
          }
        }
      }

      Text {
        text: "SWATCH ANGLE"
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
          model: realmWidgetRoot.swatchSlantChoices

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isActive: realmWidgetRoot.swatchSlant === modelData.value
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (slantMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
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
              id: slantMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: realmWidgetRoot.setSwatchSlant(modelData.value)
            }
          }
        }
      }

      // Full theme palette toggle
      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
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
            color: realmWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Full Theme Palette"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: realmWidgetRoot.themeColors ? "\uf14a" : "\uf096"
            font.family: Style.font.family
            font.pixelSize: 12
            color: realmWidgetRoot.themeColors ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: themeToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: realmWidgetRoot.toggleSetting("themeColors")
        }
      }

      Text {
        text: "EXCLUDED GAMES"
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

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 6
          color: manageGamesMouse.containsMouse || realmWidgetRoot.gameListOpen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
          border.color: realmWidgetRoot.gameListOpen ? Color.accent : "transparent"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: realmWidgetRoot.gameListOpen ? "\uf078" : "\uf054"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.accent
            }

            Text {
              Layout.fillWidth: true
              text: realmWidgetRoot.excludedGames.length > 0
                ? (realmWidgetRoot.excludedGames.length + " excluded · manage…")
                : "Choose games to exclude..."
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.foreground
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: manageGamesMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: realmWidgetRoot.openGameList()
          }
        }

        Rectangle {
          visible: realmWidgetRoot.excludedGames.length > 0
          implicitWidth: clearExText.implicitWidth + Style.space(14)
          implicitHeight: 26
          radius: 6
          color: clearExMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)

          Text {
            id: clearExText
            anchors.centerIn: parent
            text: "Clear"
            font.family: Style.font.family
            font.pixelSize: 10
            color: clearExMouse.containsMouse ? Color.urgent : Color.foreground
          }

          MouseArea {
            id: clearExMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: realmWidgetRoot.clearExcluded()
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: realmWidgetRoot.gameListOpen
        spacing: Style.space(4)

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 13
          color: Qt.rgba(1, 1, 1, 0.07)
          border.color: gameFilterInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            Text {
              text: "\uf002"
              font.family: Style.font.family
              font.pixelSize: 10
              color: gameFilterInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
            }

            TextInput {
              id: gameFilterInput
              Layout.fillWidth: true
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.foreground
              selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
              clip: true
              text: realmWidgetRoot.gameFilter
              onTextEdited: realmWidgetRoot.gameFilter = text

              Text {
                anchors.fill: parent
                visible: !gameFilterInput.text && !gameFilterInput.activeFocus
                text: "Search " + realmWidgetRoot.allGames.length + " games..."
                font.family: Style.font.family
                font.pixelSize: 10
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: function(mouse) {
                  realmWidgetRoot.grabKeyboard(gameFilterInput)
                  mouse.accepted = false
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: listGamesProc.running || realmWidgetRoot.allGames.length === 0
          text: listGamesProc.running ? "Scanning libraries..." : "No installed games found."
          font.family: Style.font.family
          font.pixelSize: 10
          horizontalAlignment: Text.AlignHCenter
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }

        ListView {
          id: gameListView
          Layout.fillWidth: true
          Layout.preferredHeight: 200
          visible: realmWidgetRoot.allGames.length > 0
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 1
          model: realmWidgetRoot.filteredGames

          delegate: Rectangle {
            id: gameRow
            required property var modelData
            readonly property bool excluded: realmWidgetRoot.isExcluded(modelData.key)
            width: ListView.view.width
            height: 26
            radius: 5
            color: gameRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              // Checked = included in the random pool.
              Rectangle {
                implicitWidth: 14
                implicitHeight: 14
                radius: 3
                color: gameRow.excluded ? "transparent" : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
                border.color: gameRow.excluded ? Qt.rgba(1, 1, 1, 0.3) : Color.accent
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  visible: !gameRow.excluded
                  text: "\uf00c"
                  font.family: Style.font.family
                  font.pixelSize: 8
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 10
                font.strikeout: gameRow.excluded
                color: gameRow.excluded ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4) : Color.foreground
                elide: Text.ElideRight
              }

              Text {
                text: modelData.source.replace("Heroic (", "").replace(")", "")
                font.family: Style.font.family
                font.pixelSize: 8
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
              }
            }

            MouseArea {
              id: gameRowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: realmWidgetRoot.toggleExcluded(modelData.key)
            }
          }
        }
      }
      // Update the whole custom widget suite from its repo.
      SuiteUpdateItem {}
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(14)
    spacing: Style.space(10)

    // Header row: icon + title + edit-mode grip/close
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        id: realmLeftIcon
        text: realmWidgetRoot.iconGlyph
        font.family: Style.font.family
        font.pixelSize: 14
        color: pal.secondary

        transform: Scale {
          origin.x: realmLeftIcon.width / 2
          origin.y: realmLeftIcon.height / 2
          xScale: realmWidgetRoot.iconLeans ? -1 : 1
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: realmWidgetRoot.shownHeaderText
        font.family: Style.font.family
        font.pixelSize: 12
        font.weight: Font.Bold
        color: Color.foreground
        elide: Text.ElideRight
      }

      Text {
        id: realmRightIcon
        text: realmWidgetRoot.iconGlyph
        font.family: Style.font.family
        font.pixelSize: 14
        color: pal.tertiary

        // A bare "on rotation" animation halts mid-loop at whatever angle it
        // was at when launching flips false -- it does not snap back to 0.
        // That leftover rotation shifts each glyph's off-center ink by a
        // different amount, which read as "the right icon sits lower than
        // the left, and by an amount that depends on which icon is picked".
        RotationAnimation {
          id: launchSpinAnim
          target: realmRightIcon
          property: "rotation"
          running: realmWidgetRoot.launching
          from: 0
          to: 360
          loops: Animation.Infinite
          duration: 900
          onRunningChanged: if (!running) realmRightIcon.rotation = 0
        }
      }

      // Close (edit mode only)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 20
        height: 20
        radius: 10
        color: closeRealmMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: Style.font.family
          font.pixelSize: 9
          color: Color.urgent
        }

        MouseArea {
          id: closeRealmMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(realmWidgetRoot.widgetId, false, realmWidgetRoot.monitorName)
            }
          }
        }
      }

      // Move grip (edit mode only)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 20
        height: 20
        radius: 10
        color: gripRealmMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: Style.font.family
          font.pixelSize: 9
          color: Color.accent
        }

        MouseArea {
          id: gripRealmMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: realmWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, realmWidgetRoot.screenWidth - realmWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, realmWidgetRoot.screenHeight - realmWidgetRoot.height - 10)

          onReleased: function() {
            var maxX = Math.max(10, realmWidgetRoot.screenWidth - realmWidgetRoot.width - 10)
            var maxY = Math.max(10, realmWidgetRoot.screenHeight - realmWidgetRoot.height - 10)
            var snappedX = Math.max(10, Math.min(maxX, realmWidgetRoot.snapVal(realmWidgetRoot.targetItem.x)))
            var snappedY = Math.max(10, Math.min(maxY, realmWidgetRoot.snapVal(realmWidgetRoot.targetItem.y)))
            realmWidgetRoot.targetItem.x = snappedX
            realmWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(realmWidgetRoot.widgetId, snappedX, snappedY, realmWidgetRoot.snapVal(realmWidgetRoot.width), realmWidgetRoot.snapVal(realmWidgetRoot.height), realmWidgetRoot.monitorName)
            }
          }
        }
      }
    }

    // Portal Button
    // ClippingRectangle, not Rectangle+clip:true -- plain clip:true only
    // clips to the axis-aligned bounding box and ignores radius, which was
    // squaring off the corners despite radius being set (same fix already
    // used for VideoPlayerWidget's rounded video surface).
    ClippingRectangle {
      id: portalButton
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 16
      color: realmWidgetRoot.swatchImages.length > 0
        ? "transparent"
        : (portalMouse.containsMouse && !realmWidgetRoot.launching ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent")
      border.color: Color.accent

      // Themed hover (no cover art): accent -> secondary wash.
      Rectangle {
        anchors.fill: parent
        visible: realmWidgetRoot.themeColors && realmWidgetRoot.swatchImages.length === 0
          && portalMouse.containsMouse && !realmWidgetRoot.launching
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: pal.tint(pal.primary, 0.2) }
          GradientStop { position: 1; color: pal.tint(pal.secondary, 0.2) }
        }
      }
      border.width: 2
      opacity: realmWidgetRoot.launching ? 0.7 : 1.0

      Behavior on opacity {
        NumberAnimation { duration: 150 }
      }

      // Diagonal photo swatches -- box art of random installed games,
      // reshuffled on realmWidgetRoot.shuffleTimer. The whole strip (not
      // each tile individually) is sheared via Matrix4x4 so the seams
      // between tiles read as one continuous diagonal cut. Oversized/offset
      // so the sheared content always fully covers the button regardless of
      // its aspect ratio -- see the rowX/rowWidth derivation.
      Row {
        id: swatchRow
        // x' = x + shearK*y: positive leans the seams ╲, negative ╱, 0 │.
        // The row is widened by |shearK|*height and shifted so the sheared
        // strip still covers the whole button at both the top and bottom.
        readonly property real shearK: realmWidgetRoot.swatchSlant === "right" ? -0.4 : (realmWidgetRoot.swatchSlant === "straight" ? 0 : 0.4)
        readonly property real skew: portalButton.height * Math.abs(shearK)
        readonly property real margin: portalButton.width * 0.1
        visible: realmWidgetRoot.swatchImages.length > 0
        y: 0
        x: (shearK > 0 ? -skew : 0) - margin
        width: portalButton.width + skew + margin * 2
        height: portalButton.height

        transform: Matrix4x4 {
          matrix: Qt.matrix4x4(
            1, swatchRow.shearK, 0, 0,
            0, 1,                0, 0,
            0, 0,                1, 0,
            0, 0,                0, 1
          )
        }

        Repeater {
          model: realmWidgetRoot.swatchImages

          delegate: Image {
            required property var modelData
            width: swatchRow.width / Math.max(1, realmWidgetRoot.swatchImages.length)
            height: swatchRow.height
            source: modelData.image ? ("file://" + modelData.image) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.height: 220
          }
        }
      }

      // Tint so the border/label stay legible over busy cover art.
      Rectangle {
        anchors.fill: parent
        visible: realmWidgetRoot.swatchImages.length > 0
        color: Qt.rgba(0, 0, 0, 0.5)
      }

      Rectangle {
        anchors.fill: parent
        visible: realmWidgetRoot.themeColors && realmWidgetRoot.swatchImages.length > 0
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: pal.tint(pal.primary, portalMouse.containsMouse ? 0.26 : 0.16) }
          GradientStop { position: 1; color: pal.tint(pal.secondary, portalMouse.containsMouse ? 0.26 : 0.16) }
        }
      }

      Text {
        anchors.centerIn: parent
        text: realmWidgetRoot.launching ? "Opening portal..." : realmWidgetRoot.shownButtonText
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.accent
        style: realmWidgetRoot.swatchImages.length > 0 ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.6)
      }

      MouseArea {
        id: portalMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !realmWidgetRoot.launching
        onClicked: realmWidgetRoot.visitAnotherRealm()
      }
    }

    // Status line
    Text {
      Layout.fillWidth: true
      visible: realmWidgetRoot.statusText.length > 0
      text: realmWidgetRoot.statusText
      font.family: Style.font.family
      font.pixelSize: 10
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      color: realmWidgetRoot.statusIsError ? pal.danger
        : (realmWidgetRoot.themeColors ? pal.tint(pal.live, 0.85) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7))
    }
  }
}
