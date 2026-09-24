import QtQuick

// ---------------------------------------------------------------------------
// 👁️ Abyss Eye -- one anime-style eye drawn on a Canvas. Pure view: the
// Abyss Warden widget drives gaze/openness/pupil; this only paints them.
// Repaints only when a driven value changes, so a still eye costs nothing.
//
// Drawn in "eye units": the almond is 1 unit wide, centred on the origin,
// y down, inner corner on the left / outer corner (wing) on the right. The
// style picks the shape, iris, highlights, lashes and brow; `mirrored` flips
// the drawing for the left eye of a pair (highlights stay on the same side,
// as if lit by one light).
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
  property string styleId: "classic"
  property bool mirrored: false

  onGazeXChanged: requestPaint()
  onGazeYChanged: requestPaint()
  onOpennessChanged: requestPaint()
  onPupilScaleChanged: requestPaint()
  onGlowChanged: requestPaint()
  onThemeChanged: requestPaint()
  onStyleIdChanged: requestPaint()
  onMirroredChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  // ---------------------------------------------------------------------------
  // Styles (after the usual anime eye sheet). Fields, all in eye units:
  //   inner/outer   corner y            upY/loY     lid control-point y, fully open
  //   up1/up2       upper control x     lo1/lo2     lower control x
  //   closedY       where the lids meet when shut
  //   angular       straight-edged lids instead of curves
  //   iris          radius; irisRy vertical stretch; irisY resting offset
  //   pupil         round | tall | pin (tiny) ; pupilR (fraction of iris)
  //   rings         concentric iris rings (hypnotic)
  //   highlight     classic | big | star | soft
  //   lashW         lid line weight; wing = outer flick length
  //   lashes        [[t along lid, length]]; lower = count of lower lashes
  //   crease        double-lid line; brow: none | arc | angled | flat, browY
  //   top/bot       drawing extents (lashes, brow, glow) for fitting
  // ---------------------------------------------------------------------------
  readonly property var styles: ({
    classic: { inner: 0.03, outer: -0.04, upY: -0.49, up1: -0.28, up2: 0.18, loY: 0.31, lo1: 0.2, lo2: -0.26, closedY: 0.17,
      iris: 0.235, irisRy: 1.0, irisY: 0.01, pupil: "round", pupilR: 0.4, highlight: "classic",
      lashW: 0.045, wing: 0.08, lashes: [[0.62, 0.09], [0.74, 0.09], [0.86, 0.09]], lower: 0, brow: "none", top: -0.52, bot: 0.3 },
    sparkle: { inner: 0.06, outer: -0.02, upY: -0.64, up1: -0.3, up2: 0.2, loY: 0.44, lo1: 0.24, lo2: -0.28, closedY: 0.2,
      iris: 0.28, irisRy: 1.32, irisY: 0.06, pupil: "tall", pupilR: 0.46, highlight: "big",
      lashW: 0.085, wing: 0, lashes: [[0.86, 0.06]], lower: 2, brow: "none", top: -0.58, bot: 0.42 },
    starry: { inner: 0.05, outer: -0.02, upY: -0.6, up1: -0.3, up2: 0.2, loY: 0.42, lo1: 0.22, lo2: -0.28, closedY: 0.2,
      iris: 0.24, irisRy: 1.3, irisY: 0.04, pupil: "tall", pupilR: 0.55, highlight: "star",
      lashW: 0.05, wing: 0.06, lashes: [[0.7, 0.08], [0.82, 0.09], [0.92, 0.08]], lower: 0, brow: "arc", browY: -0.6, top: -0.72, bot: 0.4 },
    sharp: { inner: 0.05, outer: -0.08, upY: -0.3, up1: -0.2, up2: 0.26, loY: 0.24, lo1: 0.2, lo2: -0.24, closedY: 0.14,
      iris: 0.23, irisRy: 1.0, irisY: 0.07, pupil: "round", pupilR: 0.38, highlight: "soft",
      lashW: 0.06, wing: 0.11, lashes: [[0.88, 0.07]], lower: 0, crease: true, brow: "none", top: -0.42, bot: 0.26 },
    glare: { inner: 0.1, outer: -0.1, upY: -0.26, up1: -0.08, up2: 0.3, loY: 0.17, lo1: 0.22, lo2: -0.2, closedY: 0.1,
      iris: 0.17, irisRy: 1.05, irisY: 0.03, pupil: "pin", pupilR: 0.3, highlight: "soft",
      lashW: 0.07, wing: 0.07, lashes: [], lower: 0, brow: "angled", browY: -0.34, top: -0.5, bot: 0.22 },
    shocked: { inner: 0.0, outer: -0.02, upY: -0.62, up1: -0.3, up2: 0.26, loY: 0.52, lo1: 0.26, lo2: -0.3, closedY: 0.22,
      iris: 0.15, irisRy: 1.05, irisY: 0.0, pupil: "pin", pupilR: 0.32, highlight: "soft",
      lashW: 0.036, wing: 0.04, lashes: [[0.78, 0.07], [0.9, 0.07]], lower: 3, brow: "arc", browY: -0.66, top: -0.76, bot: 0.5 },
    hypnotic: { inner: 0.04, outer: -0.03, upY: -0.54, up1: -0.28, up2: 0.2, loY: 0.4, lo1: 0.22, lo2: -0.27, closedY: 0.19,
      iris: 0.25, irisRy: 1.0, irisY: 0.02, pupil: "round", pupilR: 0.28, rings: 3, highlight: "classic",
      lashW: 0.045, wing: 0.07, lashes: [[0.6, 0.07], [0.7, 0.08], [0.8, 0.09], [0.9, 0.08]], lower: 4, brow: "none", top: -0.52, bot: 0.42 },
    shoujo: { inner: 0.06, outer: -0.04, upY: -0.66, up1: -0.3, up2: 0.2, loY: 0.46, lo1: 0.24, lo2: -0.28, closedY: 0.21,
      iris: 0.27, irisRy: 1.28, irisY: 0.05, pupil: "tall", pupilR: 0.4, highlight: "big",
      lashW: 0.055, wing: 0.13, lashes: [[0.5, 0.08], [0.62, 0.11], [0.73, 0.13], [0.83, 0.14], [0.92, 0.12]], lower: 3, brow: "none", top: -0.7, bot: 0.46 },
    angular: { inner: 0.05, outer: -0.05, upY: -0.4, up1: -0.3, up2: 0.26, loY: 0.3, lo1: 0.3, lo2: -0.3, closedY: 0.14, angular: true,
      iris: 0.22, irisRy: 1.15, irisY: 0.02, pupil: "round", pupilR: 0.45, highlight: "classic",
      lashW: 0.07, wing: 0.07, lashes: [], lower: 0, brow: "flat", browY: -0.5, top: -0.58, bot: 0.34 }
  })

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

    var st = styles[styleId] || styles.classic
    var o = Math.max(0, Math.min(1, openness))

    // Fit the whole drawing (almond + wing, lashes, brow, glow) in the item.
    var span = st.bot - st.top
    var s = Math.min(width * 0.8 / (1 + st.wing), height * 0.92 / span)
    if (s <= 0) return
    ctx.save()
    ctx.translate(width / 2, height / 2 - s * (st.top + st.bot) / 2)
    ctx.scale(s, s)
    if (mirrored) ctx.scale(-1, 1)
    var hs = mirrored ? -1 : 1   // keeps highlights on the same screen side

    var Lx = -0.5, Ly = st.inner
    var Rx = 0.5, Ry = st.outer
    var upY = lerp(st.closedY, st.upY, o)
    var loY = lerp(st.closedY, st.loY, o)
    var up = [[Lx, Ly], [st.up1, upY], [st.up2, upY], [Rx, Ry]]
    var lo = [[Rx, Ry], [st.lo1, loY], [st.lo2, loY], [Lx, Ly]]

    function trace(p, first) {
      if (first) ctx.moveTo(p[0][0], p[0][1])
      if (st.angular) {
        ctx.lineTo(p[1][0], p[1][1]); ctx.lineTo(p[2][0], p[2][1]); ctx.lineTo(p[3][0], p[3][1])
      } else {
        ctx.bezierCurveTo(p[1][0], p[1][1], p[2][0], p[2][1], p[3][0], p[3][1])
      }
    }
    function pointAt(p, t) {
      if (st.angular) {
        var seg = Math.min(2, Math.floor(t * 3)), f = t * 3 - seg
        return [lerp(p[seg][0], p[seg + 1][0], f), lerp(p[seg][1], p[seg + 1][1], f)]
      }
      var u = 1 - t
      return [u*u*u*p[0][0] + 3*u*u*t*p[1][0] + 3*u*t*t*p[2][0] + t*t*t*p[3][0],
              u*u*u*p[0][1] + 3*u*u*t*p[1][1] + 3*u*t*t*p[2][1] + t*t*t*p[3][1]]
    }
    function almond() {
      ctx.beginPath()
      trace(up, true)
      trace(lo, false)
      ctx.closePath()
    }

    var lash = col("lash", "#140a1c")
    var glowCol = col("glow", "#9d4edd")

    // --- Glow + sclera
    ctx.save()
    if (glow > 0.01 && o > 0.05) {
      ctx.shadowColor = rgba(glowCol, 0.85 * glow)
      ctx.shadowBlur = s * 0.12 * glow
    }
    almond()
    var sg = ctx.createRadialGradient(0, 0, 0.05, 0, 0, 0.55)
    sg.addColorStop(0, col("sclera", "#f4f1fa"))
    sg.addColorStop(1, col("scleraShade", "#c9c0dc"))
    ctx.fillStyle = sg
    ctx.fill()
    ctx.restore()

    // --- Everything inside the lids
    ctx.save()
    almond()
    ctx.clip()

    var R = st.iris, ry = st.irisRy
    var gx = Math.max(-1, Math.min(1, gazeX)) * (mirrored ? -1 : 1)
    var ix = gx * Math.max(0.12, 0.5 - R - 0.02)
    var iy = st.irisY + Math.max(-1, Math.min(1, gazeY)) * 0.12

    // Iris (drawn in a vertically stretched frame for oval irises).
    ctx.save()
    ctx.translate(ix, iy)
    ctx.scale(1, ry)

    var ig = ctx.createRadialGradient(0, R * 0.18, R * 0.1, 0, 0, R)
    ig.addColorStop(0, col("irisLight", "#e0aaff"))
    ig.addColorStop(0.45, col("iris", "#7b2ff7"))
    ig.addColorStop(0.88, col("irisDark", "#2a0b4d"))
    ig.addColorStop(1, lash)
    ctx.fillStyle = ig
    ctx.beginPath()
    ctx.arc(0, 0, R, 0, Math.PI * 2)
    ctx.fill()

    // Fine radial striations.
    ctx.strokeStyle = rgba(col("irisLight", "#e0aaff"), 0.22)
    ctx.lineWidth = R * 0.018
    for (var k = 0; k < 40; k++) {
      var a = k / 40 * Math.PI * 2
      var r0 = R * (0.42 + (k % 3) * 0.04), r1 = R * (0.8 + (k % 2) * 0.08)
      ctx.beginPath()
      ctx.moveTo(Math.cos(a) * r0, Math.sin(a) * r0)
      ctx.lineTo(Math.cos(a) * r1, Math.sin(a) * r1)
      ctx.stroke()
    }

    // Anime shading: dark upper half, glowing lower crescent.
    var shade = ctx.createLinearGradient(0, -R, 0, R * 0.2)
    shade.addColorStop(0, rgba(col("irisDark", "#2a0b4d"), 0.85))
    shade.addColorStop(1, rgba(col("irisDark", "#2a0b4d"), 0))
    ctx.fillStyle = shade
    ctx.beginPath()
    ctx.arc(0, 0, R, 0, Math.PI * 2)
    ctx.fill()

    var cres = ctx.createRadialGradient(0, R * 0.75, R * 0.05, 0, R * 0.75, R * 0.75)
    cres.addColorStop(0, rgba(col("irisLight", "#e0aaff"), 0.75))
    cres.addColorStop(1, rgba(col("irisLight", "#e0aaff"), 0))
    ctx.fillStyle = cres
    ctx.beginPath()
    ctx.arc(0, 0, R * 0.97, 0, Math.PI * 2)
    ctx.fill()

    // Hypnotic rings.
    if (st.rings) {
      ctx.strokeStyle = rgba(lash, 0.55)
      ctx.lineWidth = R * 0.035
      for (var ri = 1; ri <= st.rings; ri++) {
        ctx.beginPath()
        ctx.arc(0, 0, R * (0.3 + 0.6 * ri / (st.rings + 1)), 0, Math.PI * 2)
        ctx.stroke()
      }
    }

    // Limbal ring.
    ctx.strokeStyle = rgba(lash, 0.85)
    ctx.lineWidth = R * 0.07
    ctx.beginPath()
    ctx.arc(0, 0, R * 0.965, 0, Math.PI * 2)
    ctx.stroke()

    // Pupil: theme slit wins, else the style's shape.
    var ps = Math.max(0.5, Math.min(1.5, pupilScale))
    ctx.fillStyle = col("pupil", "#07020d")
    ctx.beginPath()
    if (col("slit", false)) {
      var pw = R * 0.2 * ps, ph = R * 1.5
      ctx.ellipse(-pw / 2, -ph / 2, pw, ph)
    } else if (st.pupil === "tall") {
      var tw = R * st.pupilR * 1.6 * ps, th = R * st.pupilR * 2.3 * ps
      ctx.ellipse(-tw / 2, -th / 2, tw, th)
    } else {
      ctx.arc(0, 0, R * st.pupilR * ps, 0, Math.PI * 2)
    }
    ctx.fill()
    ctx.restore()

    // Highlights ride along with the iris.
    var hl = col("highlight", "#ffffff")
    var Rv = R * ry
    function oval(x, y, w, h, a) {
      ctx.fillStyle = rgba(hl, a)
      ctx.beginPath()
      ctx.ellipse(x - w / 2, y - h / 2, w, h)
      ctx.fill()
    }
    function dot(x, y, r, a) {
      ctx.fillStyle = rgba(hl, a)
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fill()
    }
    if (st.highlight === "big") {
      oval(ix - hs * R * 0.35, iy - Rv * 0.4, R * 0.7, Rv * 0.55, 0.95)
      oval(ix + hs * R * 0.38, iy + Rv * 0.42, R * 0.34, Rv * 0.26, 0.85)
      dot(ix + hs * R * 0.05, iy + Rv * 0.12, R * 0.07, 0.8)
    } else if (st.highlight === "star") {
      // Four-point sparkle over the pupil + a small dot.
      var sx = ix - hs * R * 0.12, sy = iy - Rv * 0.15, sr = R * 0.42, sn = sr * 0.18
      ctx.fillStyle = rgba(hl, 0.97)
      ctx.beginPath()
      ctx.moveTo(sx, sy - sr)
      ctx.quadraticCurveTo(sx + sn, sy - sn, sx + sr * 0.75, sy)
      ctx.quadraticCurveTo(sx + sn, sy + sn, sx, sy + sr)
      ctx.quadraticCurveTo(sx - sn, sy + sn, sx - sr * 0.75, sy)
      ctx.quadraticCurveTo(sx - sn, sy - sn, sx, sy - sr)
      ctx.fill()
      dot(ix + hs * R * 0.4, iy + Rv * 0.45, R * 0.09, 0.85)
    } else if (st.highlight === "soft") {
      oval(ix - hs * R * 0.4, iy - Rv * 0.35, R * 0.4, Rv * 0.3, 0.85)
    } else {
      oval(ix - hs * R * 0.37, iy - Rv * 0.42, R * 0.5, Rv * 0.36, 0.95)
      dot(ix + hs * R * 0.36, iy + Rv * 0.34, R * 0.1, 0.85)
    }

    // Upper-lid shadow falling across the eye.
    var shadeTop = Math.min(Ly, Ry, upY * 0.75)
    var lidShade = ctx.createLinearGradient(0, shadeTop + 0.03, 0, shadeTop + 0.2)
    lidShade.addColorStop(0, rgba(lash, 0.5))
    lidShade.addColorStop(1, rgba(lash, 0))
    ctx.fillStyle = lidShade
    ctx.fillRect(-0.6, shadeTop - 0.1, 1.2, 0.8)
    ctx.restore()

    // --- Lid line, wing, lashes
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = lash
    ctx.lineWidth = lerp(st.lashW * 0.6, st.lashW, o)
    ctx.beginPath()
    trace(up, true)
    ctx.stroke()

    if (st.wing > 0) {
      var wingY = lerp(Ry + 0.04, Ry - 0.1, o)
      ctx.fillStyle = lash
      ctx.beginPath()
      ctx.moveTo(Rx - 0.1, Ry - 0.03 * o - 0.015)
      ctx.quadraticCurveTo(Rx + st.wing * 0.4, Ry - 0.025, Rx + st.wing, wingY)
      ctx.quadraticCurveTo(Rx + 0.01, Ry + 0.02, Rx - 0.06, Ry + 0.015)
      ctx.closePath()
      ctx.fill()
    }

    ctx.lineWidth = Math.max(0.012, st.lashW * 0.4)
    for (var li = 0; li < st.lashes.length; li++) {
      var bp = pointAt(up, st.lashes[li][0])
      var len = st.lashes[li][1]
      ctx.beginPath()
      ctx.moveTo(bp[0], bp[1])
      ctx.quadraticCurveTo(bp[0] + len * 0.3, bp[1] - len * 0.6 * o, bp[0] + len * 0.65, bp[1] - len * (0.35 + 0.65 * o))
      ctx.stroke()
    }

    // Double-lid crease.
    if (st.crease) {
      ctx.strokeStyle = rgba(lash, 0.6 * Math.max(0.3, o))
      ctx.lineWidth = 0.014
      ctx.beginPath()
      for (var ci = 0; ci <= 20; ci++) {
        var ct = 0.12 + ci * 0.041
        var cp = pointAt(up, ct)
        var lift = 0.07 + 0.03 * Math.sin(ct * Math.PI)
        if (ci === 0) ctx.moveTo(cp[0], cp[1] - lift)
        else ctx.lineTo(cp[0], cp[1] - lift)
      }
      ctx.stroke()
    }

    // Lower lid: traced, fading toward the inner corner, + lower lashes.
    if (o > 0.08) {
      var lg = ctx.createLinearGradient(Rx, 0, Lx, 0)
      lg.addColorStop(0, rgba(lash, 0.75))
      lg.addColorStop(1, rgba(lash, 0.1))
      ctx.strokeStyle = lg
      ctx.lineWidth = Math.max(0.01, st.lashW * 0.28)
      ctx.beginPath()
      trace(lo, true)
      ctx.stroke()

      ctx.strokeStyle = rgba(lash, 0.7)
      ctx.lineWidth = 0.015
      for (var lw = 0; lw < st.lower; lw++) {
        var lp = pointAt(lo, 0.18 + lw * 0.13)
        ctx.beginPath()
        ctx.moveTo(lp[0], lp[1])
        ctx.lineTo(lp[0] + 0.018, lp[1] + 0.065 * o)
        ctx.stroke()
      }
    }

    // Brow.
    if (st.brow !== "none") {
      var by = st.browY
      ctx.strokeStyle = lash
      ctx.lineWidth = 0.032
      ctx.beginPath()
      if (st.brow === "arc") {
        ctx.moveTo(-0.4, by + 0.06)
        ctx.quadraticCurveTo(0.02, by - 0.07, 0.46, by + 0.02)
      } else if (st.brow === "angled") {
        // Scowl: dips toward the nose.
        ctx.moveTo(-0.42, by + 0.1)
        ctx.quadraticCurveTo(0.05, by - 0.02, 0.48, by - 0.09)
      } else {
        ctx.moveTo(-0.42, by + 0.02)
        ctx.lineTo(0.48, by - 0.03)
      }
      ctx.stroke()
    }

    ctx.restore()
  }
}
