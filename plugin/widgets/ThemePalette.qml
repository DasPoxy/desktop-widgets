import QtQuick
import Quickshell.Io
import qs.Commons

// ---------------------------------------------------------------------------
// 🎨 Theme Palette -- the "Full Theme Palette" colours, shared by widgets
// that offer that toggle. Color only exposes accent/foreground/background/
// urgent, so the rest of the theme's colors.toml is read here. Themes name
// their hues either by role (magenta, cyan...) or as terminal slots
// (color5...), so each role tries both before falling back.
// With active off, every role returns its fallback (accent-only look).
// Same logic as MprisPlayerWidget's inline copy.
// ---------------------------------------------------------------------------
Item {
  id: paletteRoot
  visible: false
  width: 0
  height: 0

  property bool active: true
  property var values: ({})

  function pick(keys, fallback) {
    if (!active) return fallback
    for (var i = 0; i < keys.length; i++) {
      var v = values[keys[i]]
      if (v) return v
    }
    return fallback
  }
  function tint(c, a) { return Qt.alpha(c, a) }
  // Blends around the hue wheel (shorter way) rather than straight through
  // RGB, which turns e.g. cyan -> magenta into a muddy grey midway.
  function mixColor(a, b, t) {
    var ha = a.hsvHue, hb = b.hsvHue
    if (ha < 0 || a.hsvSaturation < 0.08) ha = hb // greys have no real hue
    if (hb < 0 || b.hsvSaturation < 0.08) hb = ha
    if (ha < 0) return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    var d = hb - ha
    if (d > 0.5) d -= 1
    else if (d < -0.5) d += 1
    var h = ha + d * t
    h = h - Math.floor(h)
    return Qt.hsva(h, a.hsvSaturation + (b.hsvSaturation - a.hsvSaturation) * t, a.hsvValue + (b.hsvValue - a.hsvValue) * t, 1)
  }

  readonly property color primary: Color.accent
  readonly property color secondary: pick(["magenta", "color5", "bright_magenta", "color13"], Color.accent)
  readonly property color tertiary: pick(["cyan", "color6", "bright_cyan", "color14"], Color.accent)
  readonly property color highlight: pick(["yellow", "color3", "bright_yellow", "color11"], Color.accent)
  readonly property color live: pick(["green", "color2", "bright_green", "color10"], Color.accent)
  readonly property color danger: pick(["red", "color1", "bright_red", "color9"], Color.urgent)
  // Panel fill: the theme's raised-surface colour when it names one, else a
  // faint wash of the secondary hue (selection/color8 are often loud).
  readonly property string surfaceKey: pick(["lighter_background", "lighter_bg"], "")
  readonly property color surface: !active ? Qt.rgba(1, 1, 1, 0.04)
    : (surfaceKey !== "" ? Qt.alpha(surfaceKey, 0.45) : Qt.alpha(secondary, 0.07))
  // Hairline dividers/borders: a faint secondary wash instead of white.
  readonly property color line: active ? Qt.alpha(secondary, 0.22) : Qt.rgba(1, 1, 1, 0.08)

  function parse(text) {
    var out = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)["']?/)
      if (m) out[m[1]] = m[2]
    }
    values = out
  }

  FileView {
    id: paletteFile
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: paletteRoot.parse(text())
  }

  // A theme swap repoints the current/theme link rather than editing the
  // file, which a watch may miss -- the accent changing is the reliable cue.
  Connections {
    target: Color
    function onAccentChanged() { paletteFile.reload() }
  }
}
