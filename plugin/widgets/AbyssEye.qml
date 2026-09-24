import QtQuick

// ---------------------------------------------------------------------------
// 👁️ Abyss Eye -- one anime-style eye drawn on a Canvas. Pure view: the
// Abyss Warden widget drives gaze/openness/pupil; this only paints them.
// Repaints only when a driven value changes, so a still eye costs nothing.
// ---------------------------------------------------------------------------
Canvas {
  id: eye

  // Gaze direction, -1..1 on each axis (0,0 = straight at the viewer).
  property real gazeX: 0
  property real gazeY: 0
  // 0 = shut, 1 = wide open.
  property real openness: 1
  // Pupil dilation multiplier (~0.7 constricted .. ~1.35 dilated).
  property real pupilScale: 1
  // Glow strength 0..1 (0 while asleep).
  property real glow: 1
  // { sclera, scleraShade, irisDark, iris, irisLight, pupil, highlight, lash, glow, slit }
  property var theme: ({})

  onGazeXChanged: requestPaint()
  onGazeYChanged: requestPaint()
  onOpennessChanged: requestPaint()
  onPupilScaleChanged: requestPaint()
  onGlowChanged: requestPaint()
  onThemeChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function col(key, fallback) {
    var v = theme ? theme[key] : undefined
    return (v === undefined || v === null || v === "") ? fallback : v
  }
  function rgba(c, a) {
    var q = Qt.color(c)
    return "rgba(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255) + "," + Math.round(q.b * 255) + "," + (q.a * a) + ")"
  }
  function lerp(a, b, t) { return a + (b - a) * t }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)

    // Almond footprint, sized so the lashes (which rise ~0.95H above the
    // centre line) and the glow stay inside the item; centred on the whole
    // drawing, not just the almond.
    var W = Math.min(width * 0.84, height * 1.15)
    var H = W * 0.5
    var cx = width / 2
    var cy = height / 2 + H * 0.24
    var o = Math.max(0, Math.min(1, openness))

    // Corners: outer (right) corner tilts up, anime style.
    var Lx = cx - W / 2, Ly = cy + H * 0.06
    var Rx = cx + W / 2, Ry = cy - H * 0.08
    // Shut, both lids meet on a gentle downward arc; open, the upper lid
    // rises high and the lower one drops a little.
    var upY = lerp(cy + H * 0.34, cy - H * 0.98, o)
    var loY = lerp(cy + H * 0.34, cy + H * 0.62, o)

    function almond() {
      ctx.beginPath()
      ctx.moveTo(Lx, Ly)
      ctx.bezierCurveTo(cx - W * 0.28, upY, cx + W * 0.18, upY, Rx, Ry)
      ctx.bezierCurveTo(cx + W * 0.2, loY, cx - W * 0.26, loY, Lx, Ly)
      ctx.closePath()
    }

    var lash = col("lash", "#140a1c")
    var glowCol = col("glow", "#9d4edd")

    // --- Glow + sclera
    ctx.save()
    if (glow > 0.01 && o > 0.05) {
      ctx.shadowColor = rgba(glowCol, 0.85 * glow)
      ctx.shadowBlur = W * 0.12 * glow
    }
    almond()
    var sg = ctx.createRadialGradient(cx, cy, H * 0.1, cx, cy, W * 0.55)
    sg.addColorStop(0, col("sclera", "#f4f1fa"))
    sg.addColorStop(1, col("scleraShade", "#c9c0dc"))
    ctx.fillStyle = sg
    ctx.fill()
    ctx.restore()

    // --- Everything inside the lids
    ctx.save()
    almond()
    ctx.clip()

    var R = W * 0.235
    var ix = cx + Math.max(-1, Math.min(1, gazeX)) * W * 0.25
    var iy = cy + H * 0.02 + Math.max(-1, Math.min(1, gazeY)) * H * 0.26

    // Iris body: dark rim -> main hue -> light core.
    var ig = ctx.createRadialGradient(ix, iy + R * 0.18, R * 0.1, ix, iy, R)
    ig.addColorStop(0, col("irisLight", "#e0aaff"))
    ig.addColorStop(0.45, col("iris", "#7b2ff7"))
    ig.addColorStop(0.88, col("irisDark", "#2a0b4d"))
    ig.addColorStop(1, lash)
    ctx.fillStyle = ig
    ctx.beginPath()
    ctx.arc(ix, iy, R, 0, Math.PI * 2)
    ctx.fill()

    // Fine radial striations.
    ctx.strokeStyle = rgba(col("irisLight", "#e0aaff"), 0.22)
    ctx.lineWidth = Math.max(0.6, R * 0.018)
    for (var s = 0; s < 40; s++) {
      var a = s / 40 * Math.PI * 2
      var r0 = R * (0.42 + (s % 3) * 0.04), r1 = R * (0.8 + (s % 2) * 0.08)
      ctx.beginPath()
      ctx.moveTo(ix + Math.cos(a) * r0, iy + Math.sin(a) * r0)
      ctx.lineTo(ix + Math.cos(a) * r1, iy + Math.sin(a) * r1)
      ctx.stroke()
    }

    // Anime shading: dark upper half, glowing lower crescent.
    var shade = ctx.createLinearGradient(ix, iy - R, ix, iy + R * 0.2)
    shade.addColorStop(0, rgba(col("irisDark", "#2a0b4d"), 0.85))
    shade.addColorStop(1, rgba(col("irisDark", "#2a0b4d"), 0))
    ctx.fillStyle = shade
    ctx.beginPath()
    ctx.arc(ix, iy, R, 0, Math.PI * 2)
    ctx.fill()

    var cres = ctx.createRadialGradient(ix, iy + R * 0.75, R * 0.05, ix, iy + R * 0.75, R * 0.75)
    cres.addColorStop(0, rgba(col("irisLight", "#e0aaff"), 0.75))
    cres.addColorStop(1, rgba(col("irisLight", "#e0aaff"), 0))
    ctx.fillStyle = cres
    ctx.beginPath()
    ctx.arc(ix, iy, R * 0.97, 0, Math.PI * 2)
    ctx.fill()

    // Limbal ring.
    ctx.strokeStyle = rgba(lash, 0.85)
    ctx.lineWidth = R * 0.07
    ctx.beginPath()
    ctx.arc(ix, iy, R * 0.965, 0, Math.PI * 2)
    ctx.stroke()

    // Pupil: round or a vertical slit.
    var ps = Math.max(0.5, Math.min(1.5, pupilScale))
    ctx.fillStyle = col("pupil", "#07020d")
    ctx.beginPath()
    if (col("slit", false)) {
      var pw = R * 0.2 * ps, ph = R * 1.5
      ctx.ellipse(ix - pw / 2, iy - ph / 2, pw, ph)
    } else {
      ctx.arc(ix, iy, R * 0.4 * ps, 0, Math.PI * 2)
    }
    ctx.fill()

    // Highlights ride along with the iris.
    var hl = col("highlight", "#ffffff")
    ctx.fillStyle = rgba(hl, 0.95)
    ctx.beginPath()
    ctx.ellipse(ix - R * 0.62, iy - R * 0.6, R * 0.5, R * 0.36)
    ctx.fill()
    ctx.fillStyle = rgba(hl, 0.85)
    ctx.beginPath()
    ctx.arc(ix + R * 0.36, iy + R * 0.34, R * 0.1, 0, Math.PI * 2)
    ctx.fill()

    // Upper-lid shadow falling across the eye.
    var lidShade = ctx.createLinearGradient(0, upY + H * 0.2, 0, upY + H * 0.62)
    lidShade.addColorStop(0, rgba(lash, 0.5))
    lidShade.addColorStop(1, rgba(lash, 0))
    ctx.fillStyle = lidShade
    ctx.fillRect(Lx, upY, W, H * 1.2)
    ctx.restore()

    // --- Lash line (thick, tapered wing at the outer corner) + lower lid
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = lash
    ctx.lineWidth = Math.max(2, H * lerp(0.05, 0.09, o))
    ctx.beginPath()
    ctx.moveTo(Lx - W * 0.01, Ly)
    ctx.bezierCurveTo(cx - W * 0.28, upY, cx + W * 0.18, upY, Rx, Ry)
    ctx.stroke()

    var wingY = lerp(Ry + H * 0.08, Ry - H * 0.2, o)
    ctx.fillStyle = lash
    ctx.beginPath()
    ctx.moveTo(Rx - W * 0.1, Ry - H * 0.06 * o - H * 0.03)
    ctx.quadraticCurveTo(Rx + W * 0.03, Ry - H * 0.05, Rx + W * 0.08, wingY)
    ctx.quadraticCurveTo(Rx + W * 0.01, Ry + H * 0.04, Rx - W * 0.06, Ry + H * 0.03)
    ctx.closePath()
    ctx.fill()

    // A few lashes flicking off the outer half, following the lid.
    ctx.lineWidth = Math.max(1.5, H * 0.035)
    for (var k = 0; k < 3; k++) {
      var t = 0.62 + k * 0.12
      // Point on the upper-lid bezier at t.
      var u = 1 - t
      var bx = u*u*u*Lx + 3*u*u*t*(cx - W*0.28) + 3*u*t*t*(cx + W*0.18) + t*t*t*Rx
      var by = u*u*u*Ly + 3*u*u*t*upY + 3*u*t*t*upY + t*t*t*Ry
      ctx.beginPath()
      ctx.moveTo(bx, by)
      ctx.quadraticCurveTo(bx + W * 0.03, by - H * 0.1 * o, bx + W * 0.06, by - H * (0.06 + 0.12 * o))
      ctx.stroke()
    }

    if (o > 0.08) {
      ctx.lineWidth = Math.max(1, H * 0.025)
      // Traces the lower lid itself, fading toward the inner corner.
      var lg = ctx.createLinearGradient(Rx, 0, Lx, 0)
      lg.addColorStop(0, rgba(lash, 0.75))
      lg.addColorStop(1, rgba(lash, 0.1))
      ctx.strokeStyle = lg
      ctx.beginPath()
      ctx.moveTo(Rx, Ry)
      ctx.bezierCurveTo(cx + W * 0.2, loY, cx - W * 0.26, loY, Lx, Ly)
      ctx.stroke()
    }
  }
}
