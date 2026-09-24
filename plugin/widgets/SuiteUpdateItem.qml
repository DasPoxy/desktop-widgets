import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons

// ---------------------------------------------------------------------------
// ⬇️ Suite Update -- the "Check for Updates" row at the bottom of every
// custom widget's right-click menu. Checks the desktop-widgets repo against
// what's installed and, on a second click, pulls and installs the whole
// suite, then the shell reloads (see get-suite-update.sh).
// ---------------------------------------------------------------------------
ColumnLayout {
  id: suiteUpdate

  // idle | checking | current | available | applying | updated | error
  property string phase: "idle"
  property var result: ({})

  Layout.fillWidth: true
  Layout.topMargin: Style.space(2)
  spacing: Style.space(2)

  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("../get-suite-update.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function run(mode) {
    if (updateProc.running) return
    suiteUpdate.phase = mode === "apply" ? "applying" : "checking"
    updateProc.command = [suiteUpdate.scriptPath, mode]
    updateProc.running = true
  }

  function short(sha) { return sha ? String(sha).slice(0, 7) : "?" }

  readonly property string label: {
    switch (phase) {
      case "checking": return "Checking for updates…"
      case "current": return "Up to date · " + short(result.local)
      case "available":
        return (result.count ? result.count + (result.count === 1 ? " update" : " updates") : "Update")
          + " available · Install"
      case "applying": return "Updating widget suite…"
      case "updated": return "Updated to " + short(result.remote) + " · reloading…"
      case "error": return "Update check failed · Retry"
      default: return "Check for Updates"
    }
  }

  readonly property string detail: {
    if (phase === "available") {
      if (result.commits && result.commits.length) return "• " + result.commits.join("\n• ")
      return result.local ? "" : "Installed version unknown -- installing brings it in line with the repo."
    }
    if (phase === "error") return result.message || ""
    return ""
  }

  Process {
    id: updateProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var res = JSON.parse(str)
          suiteUpdate.result = res
          suiteUpdate.phase = res.status || "error"
        } catch (e) {
          suiteUpdate.result = { message: "Unexpected output from the updater" }
          suiteUpdate.phase = "error"
        }
      }
    }
    onExited: function(exitCode) {
      if (suiteUpdate.phase === "checking" || suiteUpdate.phase === "applying") {
        suiteUpdate.result = { message: "Updater exited (" + exitCode + ")" }
        suiteUpdate.phase = "error"
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 28
    radius: 6
    readonly property bool busy: suiteUpdate.phase === "checking" || suiteUpdate.phase === "applying" || suiteUpdate.phase === "updated"
    color: !busy && updateMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
      : (suiteUpdate.phase === "available" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        id: updateIcon
        text: suiteUpdate.phase === "current" ? ""
          : (suiteUpdate.phase === "error" ? "" : "")
        font.family: Style.font.family
        font.pixelSize: 11
        color: suiteUpdate.phase === "error" ? Color.urgent : Color.accent
        RotationAnimation on rotation {
          running: suiteUpdate.phase === "checking" || suiteUpdate.phase === "applying"
          from: 0; to: 360
          duration: 1100
          loops: Animation.Infinite
          onRunningChanged: if (!running) updateIcon.rotation = 0
        }
      }

      Text {
        Layout.fillWidth: true
        text: suiteUpdate.label
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: suiteUpdate.phase === "available" ? Font.Bold : Font.Normal
        color: Color.foreground
      }
    }

    MouseArea {
      id: updateMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !parent.busy
      cursorShape: Qt.PointingHandCursor
      onClicked: suiteUpdate.run(suiteUpdate.phase === "available" ? "apply" : "check")
    }
  }

  Text {
    Layout.fillWidth: true
    Layout.leftMargin: Style.space(8)
    Layout.rightMargin: Style.space(8)
    visible: suiteUpdate.detail !== ""
    text: suiteUpdate.detail
    wrapMode: Text.WordWrap
    maximumLineCount: 7
    elide: Text.ElideRight
    font.family: Style.font.family
    font.pixelSize: 9
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
  }
}
