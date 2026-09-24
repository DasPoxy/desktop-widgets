import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons

// The HEADER section of a widget's right-click menu: custom title and glyph
// (picked from every icon glyph in the system font), or hide either.
//
// The host widget provides: titleText, glyphText, titleHidden, glyphHidden,
// defaultTitle, defaultGlyph, setHeaderSetting(key, value) and
// grabKeyboard(textInput). Empty text means "use the default".
ColumnLayout {
  id: editor
  required property var host
  Layout.fillWidth: true
  spacing: Style.space(4)

  readonly property string shownGlyph: host.glyphText || host.defaultGlyph

  // Glyph picker: every icon glyph in the system font (get-glyphs.sh reads
  // them, with their Nerd Font names, straight from the font file). Loaded
  // the first time the dropdown opens.
  property bool glyphPickerOpen: false
  property var glyphList: []            // [[codepoint, name], ...]
  property string glyphStatus: "idle"   // idle | loading | ok | error
  property string glyphQuery: ""
  property string glyphHoverName: ""
  readonly property var filteredGlyphs: {
    var q = glyphQuery.trim().toLowerCase()
    if (!q) return glyphList
    var terms = q.split(/\s+/)
    return glyphList.filter(function(g) {
      var n = g[1].toLowerCase()
      for (var i = 0; i < terms.length; i++) if (n.indexOf(terms[i]) < 0) return false
      return true
    })
  }
  readonly property int shownGlyphCode: shownGlyph ? shownGlyph.codePointAt(0) : 0
  readonly property string shownGlyphName: {
    for (var i = 0; i < glyphList.length; i++) if (glyphList[i][0] === shownGlyphCode) return glyphList[i][1]
    return editor.host.glyphText ? "custom" : "default"
  }

  readonly property string glyphsScriptPath: {
    var u = Qt.resolvedUrl("../get-glyphs.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }
  function toggleGlyphPicker() {
    glyphPickerOpen = !glyphPickerOpen
    if (glyphPickerOpen && glyphStatus !== "ok" && !glyphProc.running) {
      glyphStatus = "loading"
      glyphProc.command = [glyphsScriptPath, Style.font.family]
      glyphProc.running = true
    }
  }
  function pickGlyph(cp) {
    editor.host.setHeaderSetting("glyphText", cp ? String.fromCodePoint(cp) : "")
    if (editor.host.glyphHidden) editor.host.setHeaderSetting("glyphHidden", false)
  }

  Process {
    id: glyphProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var res = JSON.parse(text)
          editor.glyphList = res.glyphs || []
          editor.glyphStatus = res.status === "ok" ? "ok" : "error"
        } catch (e) {
          editor.glyphStatus = "error"
        }
      }
    }
  }

  Connections {
    target: editor.host
    function onContextMenuOpenChanged() {
      if (editor.host.contextMenuOpen) return
      editor.glyphPickerOpen = false
      editor.glyphQuery = ""
    }
  }

  // One "label [text field] [Hide]" row of the menu's HEADER section.
  component HeaderField: RowLayout {
    id: field
    property var host
    property string label: ""
    property string value: ""
    property string placeholder: ""
    property bool hidden: false
    property int maxLength: 40
    signal edited(string text)
    signal hideToggled()
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: Style.space(6)

    Text {
      Layout.preferredWidth: 38
      text: field.label
      font.family: Style.font.family
      font.pixelSize: 10
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 26
      radius: 6
      color: Qt.rgba(1, 1, 1, 0.07)
      border.color: fieldInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
      border.width: 1

      TextInput {
        id: fieldInput
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        verticalAlignment: TextInput.AlignVCenter
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.foreground
        selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        clip: true
        maximumLength: field.maxLength
        enabled: !field.hidden
        opacity: field.hidden ? 0.35 : 1
        text: field.value
        onTextEdited: field.edited(text)

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          visible: !fieldInput.text && !fieldInput.activeFocus
          text: field.hidden ? "(hidden)" : field.placeholder
          font.family: Style.font.family
          font.pixelSize: 11
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
          elide: Text.ElideRight
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          onPressed: function(mouse) {
            field.host.grabKeyboard(fieldInput)
            mouse.accepted = false
          }
        }
      }
    }

    Rectangle {
      implicitWidth: 46
      implicitHeight: 26
      radius: 6
      color: field.hidden ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (hideMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
      border.color: field.hidden ? Color.accent : "transparent"
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: "Hide"
        font.family: Style.font.family
        font.pixelSize: 10
        font.weight: field.hidden ? Font.Bold : Font.Normal
        color: field.hidden ? Color.accent : Color.foreground
      }

      MouseArea {
        id: hideMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          fieldInput.focus = false
          field.hideToggled()
        }
      }
    }
  }

  Text {
    text: "HEADER"
    font.family: Style.font.family
    font.pixelSize: 9
    font.weight: Font.Bold
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
    Layout.leftMargin: 4
    Layout.topMargin: 2
  }

  HeaderField {
    host: editor.host
    label: "Title"
    value: editor.host.titleText
    placeholder: editor.host.defaultTitle
    hidden: editor.host.titleHidden
    onEdited: function(text) { editor.host.setHeaderSetting("titleText", text) }
    onHideToggled: editor.host.setHeaderSetting("titleHidden", !editor.host.titleHidden)
  }

  // Glyph: a dropdown of every icon glyph in the system font.
  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: Style.space(6)

    Text {
      Layout.preferredWidth: 38
      text: "Glyph"
      font.family: Style.font.family
      font.pixelSize: 10
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 26
      radius: 6
      color: glyphButtonMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.07)
      border.color: editor.glyphPickerOpen ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
      border.width: 1
      opacity: editor.host.glyphHidden ? 0.45 : 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(8)

        Text {
          text: editor.shownGlyph
          font.family: Style.font.family
          font.pixelSize: 14
          color: Color.accent
        }
        Text {
          Layout.fillWidth: true
          text: editor.host.glyphHidden ? "(hidden)" : editor.shownGlyphName
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }
        Text {
          text: editor.glyphPickerOpen ? "\uf077" : "\uf078"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        }
      }

      MouseArea {
        id: glyphButtonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: editor.toggleGlyphPicker()
      }
    }

    Rectangle {
      implicitWidth: 46
      implicitHeight: 26
      radius: 6
      color: editor.host.glyphHidden ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (glyphHideMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
      border.color: editor.host.glyphHidden ? Color.accent : "transparent"
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: "Hide"
        font.family: Style.font.family
        font.pixelSize: 10
        font.weight: editor.host.glyphHidden ? Font.Bold : Font.Normal
        color: editor.host.glyphHidden ? Color.accent : Color.foreground
      }

      MouseArea {
        id: glyphHideMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: editor.host.setHeaderSetting("glyphHidden", !editor.host.glyphHidden)
      }
    }
  }

  // The dropdown itself: search + a scrolling grid of glyphs.
  ColumnLayout {
    visible: editor.glyphPickerOpen
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: Style.space(4)

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 26
      radius: 6
      color: Qt.rgba(1, 1, 1, 0.07)
      border.color: glyphSearch.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
      border.width: 1

      TextInput {
        id: glyphSearch
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        verticalAlignment: TextInput.AlignVCenter
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.foreground
        selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        clip: true
        text: editor.glyphQuery
        onTextEdited: editor.glyphQuery = text

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          visible: !glyphSearch.text && !glyphSearch.activeFocus
          text: editor.glyphStatus === "ok"
            ? "Search " + editor.glyphList.length + " glyphs (rocket, home, fa-...)"
            : (editor.glyphStatus === "error" ? "Couldn't read the font's glyphs" : "Loading glyphs...")
          font.family: Style.font.family
          font.pixelSize: 11
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
          elide: Text.ElideRight
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          onPressed: function(mouse) {
            editor.host.grabKeyboard(glyphSearch)
            mouse.accepted = false
          }
        }
      }
    }

    GridView {
      id: glyphGrid
      Layout.fillWidth: true
      Layout.preferredHeight: 6 * cellHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: Math.floor(width / 8)
      cellHeight: 34
      model: editor.filteredGlyphs

      delegate: Rectangle {
        required property var modelData
        readonly property bool current: modelData[0] === editor.shownGlyphCode && !editor.host.glyphHidden
        width: glyphGrid.cellWidth - 2
        height: glyphGrid.cellHeight - 2
        radius: 6
        color: current ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
          : (cellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
        border.color: current ? Color.accent : "transparent"
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: String.fromCodePoint(modelData[0])
          font.family: Style.font.family
          font.pixelSize: 16
          color: parent.current ? Color.accent : Color.foreground
        }

        MouseArea {
          id: cellMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: if (containsMouse) editor.glyphHoverName = modelData[1]
          onClicked: editor.pickGlyph(modelData[0])
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        Layout.fillWidth: true
        text: editor.glyphHoverName || (editor.glyphStatus === "ok" ? editor.filteredGlyphs.length + " shown" : "")
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
      }

      Rectangle {
        implicitWidth: defaultText.implicitWidth + 16
        implicitHeight: 22
        radius: 6
        color: defaultMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

        Text {
          id: defaultText
          anchors.centerIn: parent
          text: "Default " + editor.host.defaultGlyph
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.foreground
        }

        MouseArea {
          id: defaultMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: editor.pickGlyph(0)
        }
      }
    }
  }
}
