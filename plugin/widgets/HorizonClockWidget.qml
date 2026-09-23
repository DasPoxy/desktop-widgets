import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Horizon Clock & Weather -- a fork of HeroClockWidget.qml that sits on
// WidgetCard (so it can be resized like the other widgets) and scales all of
// its text to fit, centred, inside whatever box it's given. Font family is
// selectable from the installed Nerd Fonts.
WidgetCard {
  id: horizonRoot

  widgetId: "horizon_clock"
  title: "Horizon Clock & Weather"
  icon: ""
  showHeader: false
  frameless: true // floating text like Hero; the card outline shows in edit mode only

  width: 560
  height: 300
  minWidth: 160
  minHeight: 80
  resizable: true
  defaultX: Math.round((screenWidth - width) / 2)
  defaultY: Math.round((screenHeight - height) / 2)

  // ---------------------------------------------------------------------------
  // ⏰ Clock, Date, Greeting
  // ---------------------------------------------------------------------------
  property var currentDate: new Date()
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: horizonRoot.currentDate = new Date()
  }

  property bool is24Hour: true
  property bool showSeconds: false
  property bool showWeather: true
  property bool showGreeting: true
  property bool compactDate: false
  property bool useCelsius: false
  property string fontFamily: "" // "" = theme font

  // Full Theme Palette: greeting magenta, weather icon yellow, date cyan,
  // and the time itself shaded accent -> magenta digit by digit.
  // Off = accent-only.
  property bool themeColors: true

  ThemePalette {
    id: pal
    active: horizonRoot.themeColors
  }

  function escapeHtml(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
  // Per-character accent -> secondary sweep (colour-only markup, so the
  // hidden plain-text measuring copies still give the same width).
  function sweepHtml(str) {
    var out = ""
    for (var i = 0; i < str.length; i++) {
      var t = str.length > 1 ? i / (str.length - 1) : 0
      out += "<font color=\"" + pal.mixColor(pal.primary, pal.secondary, t) + "\">" + escapeHtml(str.charAt(i)) + "</font>"
    }
    return out
  }

  function applySavedSettings() {
    is24Hour = getSetting("is24Hour", true)
    showSeconds = getSetting("showSeconds", false)
    showWeather = getSetting("showWeather", true)
    showGreeting = getSetting("showGreeting", true)
    compactDate = getSetting("compactDate", false)
    useCelsius = getSetting("useCelsius", false)
    fontFamily = getSetting("fontFamily", "")
    themeColors = getSetting("themeColors", true)
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function toggleSetting(key) {
    horizonRoot[key] = !horizonRoot[key]
    horizonRoot.saveSetting(key, horizonRoot[key])
  }

  function setFontFamily(f) {
    horizonRoot.fontFamily = f
    horizonRoot.saveSetting("fontFamily", f)
  }

  readonly property string activeFont: fontFamily !== "" ? fontFamily : Style.font.family

  readonly property string timeString: {
    var fmt = is24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatTime(horizonRoot.currentDate, fmt)
  }
  readonly property string dateString: compactDate ? Qt.formatDate(horizonRoot.currentDate, "ddd, MMM d") : Qt.formatDate(horizonRoot.currentDate, "dddd, MMMM d, yyyy")

  readonly property string greetingString: {
    var h = horizonRoot.currentDate.getHours()
    if (h >= 5 && h < 12) return "Good morning"
    if (h >= 12 && h < 17) return "Good afternoon"
    if (h >= 17 && h < 22) return "Good evening"
    return "Late night vibes"
  }

  // ---------------------------------------------------------------------------
  // ⛅ Weather (same get-weather.sh as Hero Clock)
  // ---------------------------------------------------------------------------
  property string weatherTempF: ""
  property string weatherTempC: ""
  readonly property string weatherTemp: useCelsius ? (weatherTempC ? weatherTempC : weatherTempF) : (weatherTempF ? weatherTempF : weatherTempC)
  property string weatherDesc: ""
  property string weatherIcon: ""
  readonly property string weatherText: weatherTemp ? (weatherTemp + (weatherDesc ? ("  ·  " + weatherDesc) : "")) : weatherDesc
  readonly property bool weatherShown: showWeather && (weatherTemp !== "" || weatherDesc !== "")

  readonly property string weatherScriptPath: {
    var u = Qt.resolvedUrl("../get-weather.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: weatherProc
    command: [horizonRoot.weatherScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.temp) horizonRoot.weatherTempF = data.temp
          if (data.tempC) horizonRoot.weatherTempC = data.tempC
          if (data.desc) horizonRoot.weatherDesc = data.desc
          if (data.icon) horizonRoot.weatherIcon = data.icon
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 600000 // every 10 min
    running: true
    repeat: true
    onTriggered: if (!weatherProc.running) weatherProc.running = true
  }

  // ---------------------------------------------------------------------------
  // 📐 Auto-fit: measure the text block at base sizes (hidden), then scale
  // every font by one factor so the block fills the card, centred. Digits are
  // measured as "0" so the fit doesn't twitch as the seconds tick over.
  // ---------------------------------------------------------------------------
  readonly property real baseGreeting: 20
  readonly property real baseWeatherIcon: 16
  readonly property real baseWeather: 15
  readonly property real baseTime: 96
  readonly property real baseDate: 20
  readonly property real baseSpacing: 4
  readonly property real baseWeatherGap: 8

  Text { id: mGreeting; visible: false; text: horizonRoot.greetingString; font.family: horizonRoot.activeFont; font.pixelSize: horizonRoot.baseGreeting; font.weight: Font.DemiBold }
  Text { id: mWeatherIcon; visible: false; text: horizonRoot.weatherIcon; font.family: horizonRoot.activeFont; font.pixelSize: horizonRoot.baseWeatherIcon }
  Text { id: mWeather; visible: false; text: horizonRoot.weatherText.replace(/[0-9]/g, "0"); font.family: horizonRoot.activeFont; font.pixelSize: horizonRoot.baseWeather }
  Text { id: mTime; visible: false; text: horizonRoot.timeString.replace(/[0-9]/g, "0"); font.family: horizonRoot.activeFont; font.pixelSize: horizonRoot.baseTime; font.weight: Font.Bold; font.letterSpacing: 2 }
  Text { id: mDate; visible: false; text: horizonRoot.dateString; font.family: horizonRoot.activeFont; font.pixelSize: horizonRoot.baseDate; font.weight: Font.Medium }

  readonly property real naturalWidth: Math.max(
    showGreeting ? mGreeting.implicitWidth : 0,
    weatherShown ? (mWeatherIcon.implicitWidth + baseWeatherGap + mWeather.implicitWidth + 16) : 0,
    mTime.implicitWidth,
    mDate.implicitWidth)
  readonly property real naturalHeight: {
    var h = mTime.implicitHeight + mDate.implicitHeight
    var n = 2
    if (showGreeting) { h += mGreeting.implicitHeight; n++ }
    if (weatherShown) { h += Math.max(mWeatherIcon.implicitHeight, mWeather.implicitHeight) + 6; n++ }
    return h + baseSpacing * (n - 1)
  }

  readonly property real fitScale: {
    if (naturalWidth <= 0 || naturalHeight <= 0) return 1
    var availW = width * 0.9
    var availH = height * 0.88
    return Math.max(0.1, Math.min(10, availW / naturalWidth, availH / naturalHeight))
  }
  function px(base) { return Math.max(1, Math.floor(base * horizonRoot.fitScale)) }

  // ---------------------------------------------------------------------------
  // 🔤 Nerd Font picker -- canonical families only (the NF/NFM/NFP aliases
  // and per-weight families are the same fonts under other names).
  // ---------------------------------------------------------------------------
  readonly property var nerdFonts: {
    var out = []
    var all = Qt.fontFamilies()
    for (var i = 0; i < all.length; i++) {
      if (/Nerd Font( Mono| Propo)?$/.test(all[i]) && out.indexOf(all[i]) === -1) out.push(all[i])
    }
    out.sort(function(a, b) { return a.toLowerCase() < b.toLowerCase() ? -1 : 1 })
    return out
  }
  property bool fontListOpen: false
  property string fontFilter: ""
  readonly property var filteredFonts: {
    var q = fontFilter.trim().toLowerCase()
    var list = [""].concat(nerdFonts) // "" = theme default
    if (!q) return list
    return list.filter(function(f) { return (f === "" ? "theme default" : f.toLowerCase()).indexOf(q) !== -1 })
  }

  // The search box needs on-demand keyboard focus on the desktop layer;
  // hand it back when the menu closes.
  property bool holdsKeyboardFocus: false
  function grabKeyboard(input) {
    if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
    horizonRoot.holdsKeyboardFocus = true
    input.forceActiveFocus()
  }
  onContextMenuOpenChanged: {
    if (!contextMenuOpen) {
      fontListOpen = false
      fontFilter = ""
      if (holdsKeyboardFocus) {
        holdsKeyboardFocus = false
        if (rootRef && rootRef.keyboardFocusRequested) rootRef.keyboardFocusRequested = false
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📋 Right-click menu
  // ---------------------------------------------------------------------------
  component ToggleRow: Rectangle {
    id: toggleRowRoot
    property var host
    property string glyph: ""
    property string label: ""
    property bool checked: false
    property string pill: "" // shows a value pill instead of a checkbox
    property bool isAction: false // plain action row: no checkbox or pill
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 28
    radius: 6
    color: rowMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: toggleRowRoot.glyph
        font.family: Style.font.family
        font.pixelSize: 11
        color: (toggleRowRoot.checked || toggleRowRoot.pill !== "" || toggleRowRoot.isAction) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
      }
      Text {
        Layout.fillWidth: true
        text: toggleRowRoot.label
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.foreground
      }
      Rectangle {
        visible: toggleRowRoot.pill !== ""
        implicitWidth: pillText.implicitWidth + 12
        implicitHeight: 18
        radius: 9
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
        Text {
          id: pillText
          anchors.centerIn: parent
          text: toggleRowRoot.pill
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Color.accent
        }
      }
      Text {
        visible: toggleRowRoot.pill === "" && !toggleRowRoot.isAction
        text: toggleRowRoot.checked ? "" : ""
        font.family: Style.font.family
        font.pixelSize: 12
        color: toggleRowRoot.checked ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggleRowRoot.clicked()
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "DISPLAY PREFERENCES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      ToggleRow { host: horizonRoot; glyph: ""; label: "Time Format"; pill: horizonRoot.is24Hour ? "24-Hour" : "12-Hour"; onClicked: horizonRoot.toggleSetting("is24Hour") }
      ToggleRow { host: horizonRoot; glyph: ""; label: "Show Seconds (:SS)"; checked: horizonRoot.showSeconds; onClicked: horizonRoot.toggleSetting("showSeconds") }
      ToggleRow { host: horizonRoot; glyph: ""; label: "Compact Date Format"; checked: horizonRoot.compactDate; onClicked: horizonRoot.toggleSetting("compactDate") }
      ToggleRow { host: horizonRoot; glyph: ""; label: "Show Weather Status"; checked: horizonRoot.showWeather; onClicked: horizonRoot.toggleSetting("showWeather") }
      ToggleRow {
        host: horizonRoot
        visible: horizonRoot.showWeather
        glyph: horizonRoot.useCelsius ? "" : ""
        label: "Temperature Scale"
        pill: horizonRoot.useCelsius ? "Celsius (°C)" : "Fahrenheit (°F)"
        onClicked: horizonRoot.toggleSetting("useCelsius")
      }
      ToggleRow { host: horizonRoot; glyph: ""; label: "Show Greeting Message"; checked: horizonRoot.showGreeting; onClicked: horizonRoot.toggleSetting("showGreeting") }
      ToggleRow { host: horizonRoot; glyph: String.fromCodePoint(0xf03d8); label: "Full Theme Palette"; checked: horizonRoot.themeColors; onClicked: horizonRoot.toggleSetting("themeColors") }
      ToggleRow {
        host: horizonRoot
        glyph: ""
        label: "Refresh Weather"
        isAction: true
        onClicked: if (!weatherProc.running) weatherProc.running = true
      }

      Text {
        text: "FONT"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 6
      }

      // Current font; click to expand the picker.
      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitHeight: 30
        radius: 6
        color: fontBtnMouse.containsMouse || horizonRoot.fontListOpen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
        border.color: horizonRoot.fontListOpen ? Color.accent : "transparent"
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: horizonRoot.fontListOpen ? "" : ""
            font.family: Style.font.family
            font.pixelSize: 9
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: horizonRoot.fontFamily !== "" ? horizonRoot.fontFamily : "Theme default (" + Style.font.family + ")"
            font.family: horizonRoot.activeFont
            font.pixelSize: 12
            color: Color.foreground
            elide: Text.ElideRight
          }
          Text {
            text: horizonRoot.nerdFonts.length + " installed"
            font.family: Style.font.family
            font.pixelSize: 8
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: fontBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: horizonRoot.fontListOpen = !horizonRoot.fontListOpen
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: horizonRoot.fontListOpen
        spacing: Style.space(4)

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 13
          color: Qt.rgba(1, 1, 1, 0.07)
          border.color: fontFilterInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: 10
              color: fontFilterInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
            }

            TextInput {
              id: fontFilterInput
              Layout.fillWidth: true
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.foreground
              selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
              clip: true
              text: horizonRoot.fontFilter
              onTextEdited: horizonRoot.fontFilter = text

              Text {
                anchors.fill: parent
                visible: !fontFilterInput.text && !fontFilterInput.activeFocus
                text: "Search Nerd Fonts..."
                font.family: Style.font.family
                font.pixelSize: 10
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: function(mouse) {
                  horizonRoot.grabKeyboard(fontFilterInput)
                  mouse.accepted = false
                }
              }
            }
          }
        }

        ListView {
          Layout.fillWidth: true
          Layout.preferredHeight: 200
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 1
          model: horizonRoot.filteredFonts

          delegate: Rectangle {
            id: fontRow
            required property var modelData
            readonly property bool selected: horizonRoot.fontFamily === modelData
            width: ListView.view.width
            height: 26
            radius: 5
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (fontRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              // Preview each family in itself.
              Text {
                Layout.fillWidth: true
                text: fontRow.modelData === "" ? "Theme default" : fontRow.modelData
                font.family: fontRow.modelData === "" ? Style.font.family : fontRow.modelData
                font.pixelSize: 12
                color: fontRow.selected ? Color.accent : Color.foreground
                elide: Text.ElideRight
              }
              Text {
                visible: fontRow.selected
                text: ""
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.accent
              }
            }

            MouseArea {
              id: fontRowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: horizonRoot.setFontFamily(fontRow.modelData)
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🌫️ Soft radial backdrop (fills the card, fades out before the edges so
  // nothing is visibly clipped)
  // ---------------------------------------------------------------------------
  Canvas {
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var rx = width / 2, ry = height / 2
      if (rx <= 0 || ry <= 0) return
      ctx.save()
      ctx.translate(rx, ry)
      ctx.scale(1.0, ry / rx)
      var grad = ctx.createRadialGradient(0, 0, 0, 0, 0, rx)
      grad.addColorStop(0.0, "rgba(0, 0, 0, 0.20)")
      grad.addColorStop(0.35, "rgba(0, 0, 0, 0.12)")
      grad.addColorStop(0.70, "rgba(0, 0, 0, 0.05)")
      grad.addColorStop(1.0, "rgba(0, 0, 0, 0.0)")
      ctx.fillStyle = grad
      ctx.beginPath()
      ctx.arc(0, 0, rx, 0, 2 * Math.PI)
      ctx.fill()
      ctx.restore()
    }
  }

  // ---------------------------------------------------------------------------
  // 🕰️ The clock block, scaled to fit and centred
  // ---------------------------------------------------------------------------
  ColumnLayout {
    id: clockColumn
    objectName: "horizonClockColumn"
    anchors.centerIn: parent
    spacing: horizonRoot.baseSpacing * horizonRoot.fitScale

    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: horizonRoot.showGreeting
      text: horizonRoot.greetingString
      font.family: horizonRoot.activeFont
      font.pixelSize: horizonRoot.px(horizonRoot.baseGreeting)
      font.weight: Font.DemiBold
      color: pal.secondary
      opacity: 0.95
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.75)
    }

    // Weather (click to toggle °F / °C)
    Item {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: weatherRow.implicitWidth + 16 * horizonRoot.fitScale
      implicitHeight: weatherRow.implicitHeight + 6 * horizonRoot.fitScale
      visible: horizonRoot.weatherShown

      Rectangle {
        anchors.fill: parent
        radius: 8 * horizonRoot.fitScale
        color: weatherHover.containsMouse ? pal.tint(pal.highlight, 0.22) : "transparent"
        border.color: weatherHover.containsMouse ? pal.tint(pal.highlight, 0.45) : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
      }

      RowLayout {
        id: weatherRow
        anchors.centerIn: parent
        spacing: horizonRoot.baseWeatherGap * horizonRoot.fitScale

        Text {
          text: horizonRoot.weatherIcon
          font.family: horizonRoot.activeFont
          font.pixelSize: horizonRoot.px(horizonRoot.baseWeatherIcon)
          color: pal.highlight
          opacity: 0.9
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.75)
        }
        Text {
          text: horizonRoot.weatherText
          font.family: horizonRoot.activeFont
          font.pixelSize: horizonRoot.px(horizonRoot.baseWeather)
          color: Color.foreground
          opacity: 0.85
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.75)
        }
      }

      MouseArea {
        id: weatherHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !(rootRef && rootRef.layoutEditMode)
        onClicked: horizonRoot.toggleSetting("useCelsius")
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      textFormat: horizonRoot.themeColors ? Text.StyledText : Text.PlainText
      text: horizonRoot.themeColors ? horizonRoot.sweepHtml(horizonRoot.timeString) : horizonRoot.timeString
      font.family: horizonRoot.activeFont
      font.pixelSize: horizonRoot.px(horizonRoot.baseTime)
      font.weight: Font.Bold
      font.letterSpacing: 2 * horizonRoot.fitScale
      color: Color.foreground
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.85)
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: horizonRoot.dateString
      font.family: horizonRoot.activeFont
      font.pixelSize: horizonRoot.px(horizonRoot.baseDate)
      font.weight: Font.Medium
      color: horizonRoot.themeColors ? pal.tint(pal.tertiary, 0.9) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.75)
    }
  }

  // ---------------------------------------------------------------------------
  // ✋ Edit-mode chrome (close + move grip), top-right
  // ---------------------------------------------------------------------------
  Row {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(6)
    spacing: Style.space(6)
    visible: rootRef && rootRef.layoutEditMode
    z: 10

    Rectangle {
      width: 22
      height: 22
      radius: 11
      color: closeHorizonMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(14/255, 14/255, 20/255, 0.6)
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
        id: closeHorizonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (rootRef && rootRef.toggleWidgetEnabled) rootRef.toggleWidgetEnabled(horizonRoot.widgetId, false, horizonRoot.monitorName)
      }
    }

    Rectangle {
      width: 22
      height: 22
      radius: 11
      color: gripHorizonMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(14/255, 14/255, 20/255, 0.6)
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
        id: gripHorizonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeAllCursor
        drag.target: horizonRoot.targetItem
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 10
        drag.maximumX: Math.max(10, horizonRoot.screenWidth - horizonRoot.width - 10)
        drag.minimumY: 10
        drag.maximumY: Math.max(10, horizonRoot.screenHeight - horizonRoot.height - 10)

        onPressed: horizonRoot.customGripDragging = true
        onReleased: function() {
          horizonRoot.customGripDragging = false
          var maxX = Math.max(10, horizonRoot.screenWidth - horizonRoot.width - 10)
          var maxY = Math.max(10, horizonRoot.screenHeight - horizonRoot.height - 10)
          var snappedX = Math.max(10, Math.min(maxX, horizonRoot.snapVal(horizonRoot.targetItem.x)))
          var snappedY = Math.max(10, Math.min(maxY, horizonRoot.snapVal(horizonRoot.targetItem.y)))
          horizonRoot.targetItem.x = snappedX
          horizonRoot.targetItem.y = snappedY
          if (rootRef && rootRef.saveWidgetPos) {
            rootRef.saveWidgetPos(horizonRoot.widgetId, snappedX, snappedY, horizonRoot.snapVal(horizonRoot.width), horizonRoot.snapVal(horizonRoot.height), horizonRoot.monitorName)
          }
        }
        onCanceled: horizonRoot.customGripDragging = false
      }
    }
  }
}
