import QtQuick

// ---------------------------------------------------------------------------
// 🐙 Abyss Beholder -- the "Beholder" form: a round little monster with one
// big central eye (the chosen eye/iris style), a toothy grin, and a crown of
// swaying eyestalks, each tipped with a small eye that follows the main gaze
// but wanders a little on its own. Same flat riso look as AbyssEye: flat
// fills, ink outline, halftone shadow. Body = the theme's print colour.
// ---------------------------------------------------------------------------
Item {
  id: beholder

  property string styleId: "classic"
  property string irisStyle: "auto"
  property var theme: ({})
  property real gazeX: 0
  property real gazeY: 0
  property real openness: 1
  property real pupilScale: 1
  property real glow: 1
  property real irisGlow: 0

  // Seconds of animation time: drives the stalk sway and the little eyes'
  // own wandering. Only ticks while awake.
  property real t: 0
  FrameAnimation {
    running: beholder.visible && beholder.openness > 0.05
    onTriggered: beholder.t += frameTime
  }

  // Layout in item pixels: the body sits low, stalks fan out above it.
  // Sized so the whole creature fits: it spans ~3.6 body radii tall
  // (body + stalks + tip eyes) and ~4.5 wide.
  readonly property real bodyR: Math.max(4, Math.min(width / 4.5, height / 3.6))
  readonly property real cx: width / 2
  readonly property real cy: height / 2 + bodyR * 0.75

  readonly property int stalkCount: 7
  function stalkBaseAngle(i) {
    // Spread over the top of the body, from upper-left to upper-right.
    return Math.PI * (1.12 + 0.76 * i / (stalkCount - 1))
  }
  function stalkBase(i) {
    var a = stalkBaseAngle(i)
    return { x: cx + Math.cos(a) * bodyR * 0.92, y: cy + Math.sin(a) * bodyR * 0.92 }
  }
  function stalkTip(i) {
    var a = stalkBaseAngle(i)
    var len = bodyR * (0.62 + 0.2 * ((i * 37) % 5) / 4)
    var sway = Math.sin(t * (0.9 + 0.17 * i) + i * 1.7) * 0.22
    var aa = a + sway * 0.5
    return { x: cx + Math.cos(aa) * (bodyR + len), y: cy + Math.sin(aa) * (bodyR + len) - len * 0.25 }
  }

  function col(key, fallback) {
    var v = theme ? theme[key] : undefined
    return (v === undefined || v === null || v === "") ? fallback : v
  }

  Canvas {
    id: body
    anchors.fill: parent

    Connections {
      target: beholder
      function onTChanged() { body.requestPaint() }
      function onThemeChanged() { body.requestPaint() }
      function onOpennessChanged() { body.requestPaint() }
      function onWidthChanged() { body.requestPaint() }
      function onHeightChanged() { body.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var lash = beholder.col("lash", "#1c1f3f")
      var flesh = beholder.col("glow", "#2a9d8f")
      var shade = Qt.darker(flesh, 1.45)
      var R = beholder.bodyR, cx = beholder.cx, cy = beholder.cy
      var lw = Math.max(1.5, R * 0.06)

      // Stalks: tapered ink-outlined tentacles from the body to each tip.
      for (var i = 0; i < beholder.stalkCount; i++) {
        var b = beholder.stalkBase(i), tp = beholder.stalkTip(i)
        var mx = (b.x + tp.x) / 2 + Math.sin(beholder.t * 1.3 + i) * R * 0.12, my = (b.y + tp.y) / 2
        ctx.lineCap = "round"
        ctx.strokeStyle = lash
        ctx.lineWidth = R * 0.16 + lw * 2
        ctx.beginPath()
        ctx.moveTo(b.x, b.y)
        ctx.quadraticCurveTo(mx, my, tp.x, tp.y)
        ctx.stroke()
        ctx.strokeStyle = flesh
        ctx.lineWidth = R * 0.16
        ctx.stroke()
      }

      // Body: flat fill, hard cel shadow on the lower right + halftone edge.
      ctx.save()
      ctx.beginPath()
      ctx.arc(cx, cy, R, 0, Math.PI * 2)
      ctx.clip()
      // Shadow tone everywhere, then the lit disc offset up-left on top:
      // what's left is a hard crescent of shadow on the lower right.
      ctx.fillStyle = shade
      ctx.fillRect(cx - R, cy - R, R * 2, R * 2)
      ctx.fillStyle = flesh
      ctx.beginPath()
      ctx.arc(cx - R * 0.35, cy - R * 0.4, R * 1.25, 0, Math.PI * 2)
      ctx.fill()
      ctx.fillStyle = shade
      ctx.beginPath()
      for (var row = 0; row < 3; row++) {
        for (var k = 0; k < 18; k++) {
          var ang = -0.25 + k * 0.1 + (row % 2) * 0.05
          var rad = R * (1.25 - 0.08 - row * 0.07)
          var dx = cx - R * 0.35 + Math.cos(ang) * rad, dy = cy - R * 0.4 + Math.sin(ang) * rad
          var dr = R * 0.03 * (1 - row / 3.4)
          ctx.moveTo(dx + dr, dy)
          ctx.arc(dx, dy, dr, 0, Math.PI * 2)
        }
      }
      ctx.fill()
      ctx.restore()
      ctx.strokeStyle = lash
      ctx.lineWidth = lw
      ctx.beginPath()
      ctx.arc(cx, cy, R, 0, Math.PI * 2)
      ctx.stroke()

      // Toothy grin under the eye.
      var my2 = cy + R * 0.52, mw = R * 0.62
      ctx.fillStyle = lash
      ctx.beginPath()
      ctx.moveTo(cx - mw, my2 - R * 0.06)
      ctx.quadraticCurveTo(cx, my2 + R * 0.36, cx + mw, my2 - R * 0.06)
      ctx.quadraticCurveTo(cx, my2 + R * 0.08, cx - mw, my2 - R * 0.06)
      ctx.fill()
      ctx.fillStyle = beholder.col("sclera", "#f2e6d0")
      for (var tt = 0; tt < 6; tt++) {
        var f = (tt + 0.5) / 6
        var tx = cx - mw + f * 2 * mw
        var top = my2 - R * 0.06 + Math.sin(f * Math.PI) * R * 0.12
        ctx.beginPath()
        ctx.moveTo(tx - R * 0.07, top)
        ctx.lineTo(tx + R * 0.07, top)
        ctx.lineTo(tx, top + R * (tt % 2 ? 0.1 : 0.14))
        ctx.closePath()
        ctx.fill()
      }
    }
  }

  // Big central eye.
  AbyssEye {
    x: beholder.cx - width / 2
    y: beholder.cy - beholder.bodyR * 0.2 - height / 2
    width: beholder.bodyR * 1.75
    height: beholder.bodyR * 1.15
    styleId: beholder.styleId
    irisStyle: beholder.irisStyle
    theme: beholder.theme
    gazeX: beholder.gazeX
    gazeY: beholder.gazeY
    openness: beholder.openness
    pupilScale: beholder.pupilScale
    irisGlow: beholder.irisGlow
    glow: beholder.glow
  }

  // Little eyes on the stalk tips.
  Repeater {
    model: beholder.stalkCount

    AbyssEye {
      required property int index
      readonly property var tip: beholder.stalkTip(index)
      width: beholder.bodyR * 0.62
      height: beholder.bodyR * 0.42
      x: tip.x - width / 2
      y: tip.y - height / 2
      mirrored: index < beholder.stalkCount / 2
      styleId: "shocked"
      irisStyle: beholder.irisStyle
      theme: beholder.theme
      gazeX: Math.max(-1, Math.min(1, beholder.gazeX + Math.sin(beholder.t * 0.8 + index * 2.1) * 0.35))
      gazeY: Math.max(-1, Math.min(1, beholder.gazeY + Math.cos(beholder.t * 0.7 + index * 1.3) * 0.3))
      openness: beholder.openness
      pupilScale: beholder.pupilScale
      irisGlow: beholder.irisGlow
      glow: 0
    }
  }
}
