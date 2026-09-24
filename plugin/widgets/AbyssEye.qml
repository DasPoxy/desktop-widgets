import QtQuick

// ---------------------------------------------------------------------------
// 👁️ Abyss Eye -- one anime-style eye drawn on a Canvas. Pure view: the
// Abyss Warden widget drives gaze/openness/pupil; this only paints them.
// Repaints only when a driven value changes, so a still eye costs nothing.
// Look: flat cel shading in the risograph-print anime style -- solid fills,
// hard-edged shadows fading through halftone dots, coloured ink lines,
// paper grain, and an offset second "ink pass" in place of a glow.
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
  // Print-offset strength 0..1 (0 while asleep).
  property real glow: 1
  // Iris glow 0..1 (Buddy Mode: the irises light up while recording).
  property real irisGlow: 0
  // { sclera, scleraShade, irisDark, iris, irisLight, pupil, highlight, lash, glow, slit }
  property var theme: ({})
  property string styleId: "classic"
  property bool mirrored: false
  // "auto" = the eye style's own iris; otherwise a key of irisStyles.
  property string irisStyle: "auto"

  onGazeXChanged: requestPaint()
  onGazeYChanged: requestPaint()
  onOpennessChanged: requestPaint()
  onPupilScaleChanged: requestPaint()
  onGlowChanged: requestPaint()
  onIrisGlowChanged: requestPaint()
  onThemeChanged: requestPaint()
  onStyleIdChanged: requestPaint()
  onIrisStyleChanged: requestPaint()

  // Slow rotation for the spinning irises (Sharingan/Mangekyō); only ticks
  // while one is shown and the eye is open.
  property real spinAngle: 0
  readonly property real spinSpeed: (irisStyles[irisStyle] && irisStyles[irisStyle].spin) || 0
  FrameAnimation {
    running: eye.spinSpeed > 0 && eye.visible && eye.openness > 0.05
    onTriggered: {
      eye.spinAngle = (eye.spinAngle + frameTime * eye.spinSpeed) % (Math.PI * 2)
      eye.requestPaint()
    }
  }
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

  // Iris styles: pattern (cel | rings | petal | spiral | hollow | crosshair |
  // pinpoint), pupil (round | tall | slit | heart | none) with pupilR as a
  // fraction of the iris radius, and highlight (classic | big | star | soft
  // | tiny | none). Everything scales with the iris, whose size the eye
  // style sets.
  readonly property var irisStyles: ({
    cel: { pattern: "cel", pupil: "round", pupilR: 0.4, highlight: "classic" },
    sparkle: { pattern: "cel", pupil: "tall", pupilR: 0.46, highlight: "big" },
    star: { pattern: "cel", pupil: "tall", pupilR: 0.55, highlight: "star" },
    rings: { pattern: "rings", pupil: "round", pupilR: 0.28, highlight: "classic", rings: 3 },
    blossom: { pattern: "petal", pupil: "round", pupilR: 0.3, highlight: "classic" },
    spiral: { pattern: "spiral", pupil: "round", pupilR: 0.14, highlight: "soft" },
    hollow: { pattern: "hollow", pupil: "none", pupilR: 0, highlight: "tiny" },
    crosshair: { pattern: "crosshair", pupil: "round", pupilR: 0.16, highlight: "soft" },
    heart: { pattern: "cel", pupil: "heart", pupilR: 0.5, highlight: "classic" },
    pinpoint: { pattern: "pinpoint", pupil: "round", pupilR: 0.17, highlight: "soft" },
    slit: { pattern: "cel", pupil: "slit", pupilR: 0.2, highlight: "classic" },
    // Naruto dojutsu. These keep their signature colours whatever the theme
    // (`colors` overrides the theme's iris/irisDark/irisLight/pupil); `spin`
    // is a slow rotation in rad/s.
    sharingan1: { pattern: "tomoe", tomoe: 1, pupil: "round", pupilR: 0.17, highlight: "soft", spin: 0.7, colors: { iris: "#d1172e", irisDark: "#5e0612", irisLight: "#ff6b6b", pupil: "#0d0406" } },
    sharingan2: { pattern: "tomoe", tomoe: 2, pupil: "round", pupilR: 0.17, highlight: "soft", spin: 0.7, colors: { iris: "#d1172e", irisDark: "#5e0612", irisLight: "#ff6b6b", pupil: "#0d0406" } },
    sharingan3: { pattern: "tomoe", tomoe: 3, pupil: "round", pupilR: 0.17, highlight: "soft", spin: 0.7, colors: { iris: "#d1172e", irisDark: "#5e0612", irisLight: "#ff6b6b", pupil: "#0d0406" } },
    mangekyo: { pattern: "pinwheel", pupil: "none", pupilR: 0.22, highlight: "soft", spin: 0.35, colors: { iris: "#cc1530", irisDark: "#5e0612", irisLight: "#ff6b6b", pupil: "#0d0406" } },
    scythe: { pattern: "scythe", pupil: "round", pupilR: 0.14, highlight: "soft", spin: 0.35, colors: { iris: "#cc1530", irisDark: "#5e0612", irisLight: "#ff6b6b", pupil: "#0d0406" } },
    rinnegan: { pattern: "rinnegan", pupil: "round", pupilR: 0.08, highlight: "tiny", colors: { iris: "#b7a3dd", irisDark: "#3f2f66", irisLight: "#e3d8f7", pupil: "#2a1f47" } },
    byakugan: { pattern: "byakugan", pupil: "none", pupilR: 0, highlight: "none", veins: true, colors: { iris: "#ece9f6", irisDark: "#aaa3cc", irisLight: "#ffffff", pupil: "#ece9f6" } }
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

    var lash = col("lash", "#1c1f3f")
    var printCol = col("glow", "#2a9d8f")
    var shadeCol = col("scleraShade", "#9fc9bf")

    // Seeded so grain and halftone don't crawl between repaints.
    var seed = mirrored ? 7331 : 1337
    function rand() {
      seed = (seed * 16807) % 2147483647
      return (seed - 1) / 2147483646
    }
    // Many dots, one path, one fill.
    function dots(list, color) {
      if (list.length === 0) return
      ctx.fillStyle = color
      ctx.beginPath()
      for (var d = 0; d < list.length; d++) {
        ctx.moveTo(list[d][0] + list[d][2], list[d][1])
        ctx.arc(list[d][0], list[d][1], list[d][2], 0, Math.PI * 2)
      }
      ctx.fill()
    }

    // --- Riso misregistration: a flat, offset second "ink pass" of the
    // eye shape in the theme's print colour (stands in for a glow).
    if (glow > 0.01 && o > 0.05) {
      ctx.save()
      ctx.translate(0.03, 0.035)
      almond()
      ctx.fillStyle = rgba(printCol, 0.9 * glow)
      ctx.fill()
      ctx.restore()
    }

    // --- Everything inside the lids: flat paper white + cel shading
    ctx.save()
    almond()
    ctx.fillStyle = col("sclera", "#f2e6d0")
    ctx.fill()
    ctx.clip()

    // Shadow cast by the upper lid: one hard-edged flat shape...
    var sd = 0.07 + 0.05 * o
    function lidEdge(t) {
      var p = pointAt(up, t)
      return [p[0], p[1] + sd * Math.sin(Math.PI * (0.12 + 0.76 * t))]
    }
    ctx.fillStyle = shadeCol
    ctx.beginPath()
    ctx.moveTo(-0.7, -1.2)
    ctx.lineTo(0.7, -1.2)
    for (var si = 24; si >= 0; si--) {
      var e = lidEdge(si / 24)
      ctx.lineTo(e[0], e[1])
    }
    ctx.closePath()
    ctx.fill()

    // ...fading out through a halftone band.
    var tone = []
    for (var row = 0; row < 4; row++) {
      for (var hx = 0; hx <= 34; hx++) {
        var t = (hx + (row % 2) * 0.5) / 34
        var he = lidEdge(t)
        tone.push([he[0], he[1] + 0.018 + row * 0.024, 0.0115 * (1 - row / 4.2)])
      }
    }
    dots(tone, shadeCol)

    // Paper grain.
    var grain = []
    for (var g = 0; g < 110; g++) grain.push([rand() - 0.5, rand() * 0.9 - 0.5, 0.003 + rand() * 0.004])
    dots(grain, rgba(lash, 0.12))

    // Size and resting spot come from the eye style (so any iris fits any
    // eye); the pattern, pupil and highlights come from the iris style, or
    // from the eye style's own defaults when set to "auto".
    var R = st.iris, ry = st.irisRy
    var irs = irisStyles[irisStyle]
    var autoIris = !irs
    // A chosen iris grows to what this eye's opening can hold (never below
    // the eye style's own size), so a detailed pattern still reads in a
    // small-iris style like Shocked. The auto iris keeps the style's size.
    if (!autoIris) {
      var opening = (st.loY - st.upY) * 0.75
      R = Math.max(R, Math.min(0.26, 0.42 * opening / ry))
    }
    if (autoIris) irs = { pattern: st.rings ? "rings" : "cel", pupil: st.pupil, pupilR: st.pupilR, highlight: st.highlight, rings: st.rings }
    // Themes with slit pupils (serpent, dragon) keep them on the auto iris.
    var pupilShape = (autoIris && col("slit", false)) ? "slit" : irs.pupil

    var gx = Math.max(-1, Math.min(1, gazeX)) * (mirrored ? -1 : 1)
    var ix = gx * Math.max(0.12, 0.5 - R - 0.02)
    var iy = st.irisY + Math.max(-1, Math.min(1, gazeY)) * 0.12

    // --- Iris (drawn in a vertically stretched frame for oval irises)
    ctx.save()
    ctx.translate(ix, iy)
    ctx.scale(1, ry)

    ctx.beginPath()
    ctx.arc(0, 0, R, 0, Math.PI * 2)
    var ic = irs.colors || {}
    ctx.fillStyle = ic.iris || col("iris", "#e8456b")
    ctx.fill()

    // Shading shapes are built to stay inside the iris circle rather than
    // clipped to it: Canvas clip() replaces the current clip instead of
    // intersecting, and restoring a nested clip drops the eye-shape clip.
    var irisDark = ic.irisDark || col("irisDark", "#8c1f3f")
    var irisLight = ic.irisLight || col("irisLight", "#ffb3a7")
    function ring(r, w, color) {
      ctx.strokeStyle = color
      ctx.lineWidth = w
      ctx.beginPath()
      ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.stroke()
    }
    // Flat shadow cap: the top of the circle down to a sagging edge.
    function cap(withTone) {
      var capY = -R * 0.1, capA = Math.asin(-capY / R)
      ctx.fillStyle = irisDark
      ctx.beginPath()
      ctx.arc(0, 0, R, Math.PI + capA, 2 * Math.PI - capA, false)
      ctx.quadraticCurveTo(0, capY + R * 0.28, -Math.cos(capA) * R, capY)
      ctx.closePath()
      ctx.fill()
      if (!withTone) return
      var itone = []
      for (var ir = 0; ir < 3; ir++) {
        for (var ixg = -6; ixg <= 6; ixg++) {
          var tx = (ixg + (ir % 2) * 0.5) * R * 0.16, ty = capY + R * 0.14 + ir * R * 0.14
          if (tx * tx + ty * ty < R * R * 0.8) itone.push([tx, ty, R * 0.045 * (1 - ir / 3.2)])
        }
      }
      dots(itone, irisDark)
    }
    // Light crescent: the bottom of the circle up to a bulging edge.
    function crescent(alpha) {
      var creY = R * 0.4, creA = Math.asin(creY / R)
      ctx.fillStyle = rgba(irisLight, alpha)
      ctx.beginPath()
      ctx.arc(0, 0, R, creA, Math.PI - creA, false)
      ctx.quadraticCurveTo(0, creY - R * 0.3, Math.cos(creA) * R, creY)
      ctx.closePath()
      ctx.fill()
    }
    function flecks() {
      ctx.strokeStyle = irisDark
      ctx.lineWidth = R * 0.035
      ctx.lineCap = "round"
      for (var f = 0; f < 7; f++) {
        var fa = Math.PI * (0.18 + f * 0.105)
        ctx.beginPath()
        ctx.moveTo(Math.cos(fa) * R * 0.55, Math.sin(fa) * R * 0.55)
        ctx.lineTo(Math.cos(fa) * R * 0.82, Math.sin(fa) * R * 0.82)
        ctx.stroke()
      }
    }

    function polar(r, a) { return [Math.cos(a) * r, Math.sin(a) * r] }
    var pat = irs.pattern
    if (pat === "cel") {
      cap(true); crescent(1); flecks()
      ring(R * 0.64, R * 0.045, rgba(lash, 0.85))
    } else if (pat === "rings") {
      cap(true); crescent(1)
      var n = irs.rings || 3
      for (var ri = 1; ri <= n; ri++) ring(R * (0.3 + 0.6 * ri / (n + 1)), R * 0.04, lash)
    } else if (pat === "petal") {
      // Blossom: petals of light fanned around the pupil.
      cap(false)
      ctx.fillStyle = irisLight
      for (var pk = 0; pk < 8; pk++) {
        ctx.save()
        ctx.rotate(pk * Math.PI / 4 + Math.PI / 8)
        ctx.beginPath()
        ctx.ellipse(-R * 0.14, -R * 0.86, R * 0.28, R * 0.46)
        ctx.fill()
        ctx.restore()
      }
      ring(R * 0.42, R * 0.05, lash)
    } else if (pat === "spiral") {
      crescent(1)
      ctx.strokeStyle = irisDark
      ctx.lineWidth = R * 0.06
      ctx.lineCap = "round"
      ctx.beginPath()
      for (var sp = 0; sp <= 90; sp++) {
        var st2 = sp / 90, sr0 = R * (0.12 + 0.78 * st2), sa = st2 * Math.PI * 4.4
        if (sp === 0) ctx.moveTo(Math.cos(sa) * sr0, Math.sin(sa) * sr0)
        else ctx.lineTo(Math.cos(sa) * sr0, Math.sin(sa) * sr0)
      }
      ctx.stroke()
    } else if (pat === "hollow") {
      // Empty, dead-eyed stare: one flat dark disc and a faint ring.
      ctx.fillStyle = irisDark
      ctx.beginPath()
      ctx.arc(0, 0, R, 0, Math.PI * 2)
      ctx.fill()
      crescent(0.35)
      ring(R * 0.72, R * 0.05, rgba(irisLight, 0.55))
    } else if (pat === "crosshair") {
      cap(false); crescent(1)
      ring(R * 0.56, R * 0.05, lash)
      ctx.strokeStyle = lash
      ctx.lineWidth = R * 0.045
      ctx.lineCap = "butt"
      for (var ch = 0; ch < 4; ch++) {
        var ca = ch * Math.PI / 2
        ctx.beginPath()
        ctx.moveTo(Math.cos(ca) * R * 0.24, Math.sin(ca) * R * 0.24)
        ctx.lineTo(Math.cos(ca) * R * 0.9, Math.sin(ca) * R * 0.9)
        ctx.stroke()
      }
    } else if (pat === "pinpoint") {
      crescent(1)
      ring(R * 0.45, R * 0.06, lash)
      ring(R * 0.78, R * 0.025, rgba(lash, 0.7))
    } else if (pat === "tomoe") {
      // Sharingan: a thin ring with 1-3 comma-shaped tomoe riding on it.
      crescent(0.35)
      var rr = R * 0.56, hr = R * 0.13
      ring(rr, R * 0.035, rgba(irisDark, 0.9))
      ctx.fillStyle = ic.pupil || lash
      for (var tk = 0; tk < irs.tomoe; tk++) {
        var ta = spinAngle + tk * Math.PI * 2 / irs.tomoe - Math.PI / 2
        var hx = Math.cos(ta) * rr, hy = Math.sin(ta) * rr
        ctx.beginPath()
        ctx.arc(hx, hy, hr, 0, Math.PI * 2)
        ctx.fill()
        // Tail sweeps back along the ring, tapering to a point.
        var tipA = ta - 0.62, midA = ta - 0.3
        ctx.beginPath()
        ctx.moveTo(hx + Math.cos(ta) * hr, hy + Math.sin(ta) * hr)
        ctx.quadraticCurveTo(Math.cos(midA) * rr * 1.2, Math.sin(midA) * rr * 1.2, Math.cos(tipA) * rr * 1.04, Math.sin(tipA) * rr * 1.04)
        ctx.quadraticCurveTo(Math.cos(midA) * rr * 0.98, Math.sin(midA) * rr * 0.98, hx - Math.cos(ta) * hr * 0.35, hy - Math.sin(ta) * hr * 0.35)
        ctx.closePath()
        ctx.fill()
      }
    } else if (pat === "pinwheel") {
      // Mangekyō: a black core with three broad curved blades.
      crescent(0.35)
      ctx.fillStyle = ic.pupil || lash
      ctx.beginPath()
      ctx.arc(0, 0, R * 0.24, 0, Math.PI * 2)
      ctx.fill()
      for (var pw2 = 0; pw2 < 3; pw2++) {
        var pa = spinAngle + pw2 * Math.PI * 2 / 3
        var p0 = polar(R * 0.2, pa - 0.55), c1 = polar(R * 0.78, pa - 0.25), tip = polar(R * 0.9, pa + 0.42), c2 = polar(R * 0.46, pa + 0.62), p1 = polar(R * 0.2, pa + 0.75)
        ctx.beginPath()
        ctx.moveTo(p0[0], p0[1])
        ctx.quadraticCurveTo(c1[0], c1[1], tip[0], tip[1])
        ctx.quadraticCurveTo(c2[0], c2[1], p1[0], p1[1])
        ctx.closePath()
        ctx.fill()
      }
    } else if (pat === "scythe") {
      // Mangekyō: three thin scythes sweeping out from a ring.
      crescent(0.35)
      ring(R * 0.3, R * 0.05, ic.pupil || lash)
      ctx.fillStyle = ic.pupil || lash
      for (var sc = 0; sc < 3; sc++) {
        var sa = spinAngle + sc * Math.PI * 2 / 3
        var s0 = polar(R * 0.28, sa - 0.18), sc1 = polar(R * 0.75, sa + 0.15), stip = polar(R * 0.93, sa + 1.05), sc2 = polar(R * 0.62, sa + 0.3), s1 = polar(R * 0.28, sa + 0.22)
        ctx.beginPath()
        ctx.moveTo(s0[0], s0[1])
        ctx.quadraticCurveTo(sc1[0], sc1[1], stip[0], stip[1])
        ctx.quadraticCurveTo(sc2[0], sc2[1], s1[0], s1[1])
        ctx.closePath()
        ctx.fill()
      }
    } else if (pat === "rinnegan") {
      // Rippled rings, evenly spaced out from a small pupil.
      for (var rg = 1; rg <= 4; rg++) ring(R * (0.18 + 0.19 * rg), R * 0.04, irisDark)
    } else if (pat === "byakugan") {
      // Near-white and pupil-less: just faint rings.
      ring(R * 0.62, R * 0.03, rgba(irisDark, 0.45))
      ring(R * 0.9, R * 0.02, rgba(irisDark, 0.35))
    }

    // Buddy Mode recording glow, part one: the iris lights up from within in
    // its own hue (drawn before the pupil so the pupil stays dark) and its
    // inner ring burns bright.
    var ig2 = Math.max(0, Math.min(1, irisGlow))
    var irisBase = ic.iris || col("iris", "#e8456b")
    if (ig2 > 0.01) {
      ctx.save()
      ctx.globalCompositeOperation = "lighter"
      ctx.fillStyle = rgba(Qt.lighter(irisBase, 1.3), 0.6 * ig2)
      ctx.beginPath()
      ctx.arc(0, 0, R, 0, Math.PI * 2)
      ctx.fill()
      ctx.restore()
      ring(R * 0.62, R * 0.08, rgba(irisLight, 0.75 * ig2))
      ring(R * 0.62, R * 0.03, rgba(col("highlight", "#fff7ea"), 0.9 * ig2))
    }

    // Pupil.
    var ps = Math.max(0.5, Math.min(1.5, pupilScale))
    var pr = R * (irs.pupilR || 0.4) * ps
    ctx.fillStyle = ic.pupil || col("pupil", "#1c1f3f")
    ctx.beginPath()
    if (pupilShape === "slit") {
      var pw = R * 0.2 * ps, ph = R * 1.5
      ctx.ellipse(-pw / 2, -ph / 2, pw, ph)
      ctx.fill()
    } else if (pupilShape === "tall") {
      ctx.ellipse(-pr * 0.8, -pr * 1.15, pr * 1.6, pr * 2.3)
      ctx.fill()
    } else if (pupilShape === "heart") {
      ctx.moveTo(0, pr * 0.85)
      ctx.bezierCurveTo(-pr * 1.25, 0, -pr * 0.65, -pr * 1.0, 0, -pr * 0.42)
      ctx.bezierCurveTo(pr * 0.65, -pr * 1.0, pr * 1.25, 0, 0, pr * 0.85)
      ctx.fill()
    } else if (pupilShape !== "none") {
      ctx.arc(0, 0, pr, 0, Math.PI * 2)
      ctx.fill()
    }

    // Glow, part two: coloured light spilling off the rim onto the white,
    // as flat bands that fade outward (the riso take on a glow; Canvas
    // shadowBlur doesn't render on these strokes anyway).
    if (ig2 > 0.01) {
      for (var gb = 1; gb <= 5; gb++)
        ring(R * (0.98 + 0.15 * gb), R * 0.16, rgba(irisBase, 0.62 * (1 - gb / 6) * ig2))
    }

    // Iris outline (softened while glowing).
    ring(R * 0.97, R * 0.085, ig2 > 0.01 ? rgba(lash, 1 - 0.5 * ig2) : lash)
    ctx.restore()

    // Highlights: flat, hard-edged, riding along with the iris.
    var hl = col("highlight", "#fff7ea")
    var Rv = R * ry
    function oval(x, y, w, h) {
      ctx.fillStyle = hl
      ctx.beginPath()
      ctx.ellipse(x - w / 2, y - h / 2, w, h)
      ctx.fill()
    }
    function dot(x, y, r) {
      ctx.fillStyle = hl
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fill()
    }
    var hlType = irs.highlight
    if (hlType === "big") {
      oval(ix - hs * R * 0.35, iy - Rv * 0.4, R * 0.7, Rv * 0.55)
      oval(ix + hs * R * 0.38, iy + Rv * 0.42, R * 0.34, Rv * 0.26)
      dot(ix + hs * R * 0.05, iy + Rv * 0.12, R * 0.07)
    } else if (hlType === "star") {
      // Four-point sparkle over the pupil + a small dot.
      var sx = ix - hs * R * 0.12, sy = iy - Rv * 0.15, sr = R * 0.42, sn = sr * 0.18
      ctx.fillStyle = hl
      ctx.beginPath()
      ctx.moveTo(sx, sy - sr)
      ctx.quadraticCurveTo(sx + sn, sy - sn, sx + sr * 0.75, sy)
      ctx.quadraticCurveTo(sx + sn, sy + sn, sx, sy + sr)
      ctx.quadraticCurveTo(sx - sn, sy + sn, sx - sr * 0.75, sy)
      ctx.quadraticCurveTo(sx - sn, sy - sn, sx, sy - sr)
      ctx.fill()
      dot(ix + hs * R * 0.4, iy + Rv * 0.45, R * 0.09)
    } else if (hlType === "soft") {
      oval(ix - hs * R * 0.4, iy - Rv * 0.35, R * 0.4, Rv * 0.3)
    } else if (hlType === "tiny") {
      dot(ix - hs * R * 0.38, iy - Rv * 0.4, R * 0.08)
    } else if (hlType !== "none") {
      oval(ix - hs * R * 0.37, iy - Rv * 0.42, R * 0.5, Rv * 0.36)
      dot(ix + hs * R * 0.36, iy + Rv * 0.34, R * 0.1)
    }
    ctx.restore()

    // --- Ink: lid line (brush-thick toward the outer corner), wing, lashes
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = lash
    ctx.lineWidth = lerp(st.lashW * 0.5, st.lashW * 0.8, o)
    ctx.beginPath()
    trace(up, true)
    ctx.stroke()
    ctx.lineWidth = lerp(st.lashW * 0.7, st.lashW * 1.3, o)
    ctx.beginPath()
    for (var bi = 0; bi <= 16; bi++) {
      var bpt = pointAt(up, 0.38 + 0.62 * bi / 16)
      if (bi === 0) ctx.moveTo(bpt[0], bpt[1])
      else ctx.lineTo(bpt[0], bpt[1])
    }
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

    // Lashes as pointed brush flicks.
    ctx.fillStyle = lash
    var lb = Math.max(0.01, st.lashW * 0.32)
    for (var li = 0; li < st.lashes.length; li++) {
      var bp = pointAt(up, st.lashes[li][0])
      var len = st.lashes[li][1]
      var tipX = bp[0] + len * 0.65, tipY = bp[1] - len * (0.35 + 0.65 * o)
      ctx.beginPath()
      ctx.moveTo(bp[0] - lb, bp[1] + lb * 0.4)
      ctx.quadraticCurveTo(bp[0] + len * 0.2, bp[1] - len * 0.55 * o, tipX, tipY)
      ctx.quadraticCurveTo(bp[0] + len * 0.4, bp[1] - len * 0.45 * o, bp[0] + lb, bp[1] + lb * 0.4)
      ctx.closePath()
      ctx.fill()
    }

    // Double-lid crease.
    if (st.crease) {
      ctx.strokeStyle = rgba(lash, 0.8 * Math.max(0.3, o))
      ctx.lineWidth = 0.016
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

    // Lower lid: inked along the outer two thirds only, + lower lashes.
    if (o > 0.08) {
      ctx.strokeStyle = lash
      ctx.lineWidth = Math.max(0.01, st.lashW * 0.3)
      ctx.beginPath()
      for (var lt = 0; lt <= 14; lt++) {
        var lpt = pointAt(lo, 0.68 * lt / 14)
        if (lt === 0) ctx.moveTo(lpt[0], lpt[1])
        else ctx.lineTo(lpt[0], lpt[1])
      }
      ctx.stroke()

      ctx.lineWidth = 0.015
      for (var lw = 0; lw < st.lower; lw++) {
        var lp = pointAt(lo, 0.18 + lw * 0.13)
        ctx.beginPath()
        ctx.moveTo(lp[0], lp[1])
        ctx.lineTo(lp[0] + 0.018, lp[1] + 0.065 * o)
        ctx.stroke()
      }
    }

    // Byakugan: bulging veins at the corners of the eye.
    if (irs.veins && o > 0.2) {
      ctx.strokeStyle = rgba(lash, 0.55 * o)
      ctx.lineWidth = 0.012
      ctx.lineCap = "round"
      var vs = [[Lx - 0.01, Ly, -1], [Rx + 0.01, Ry, 1]]
      for (var vi = 0; vi < 2; vi++) {
        var vx = vs[vi][0], vy = vs[vi][1], vd = vs[vi][2]
        for (var vb = 0; vb < 3; vb++) {
          var va = (-0.55 + vb * 0.5)
          ctx.beginPath()
          ctx.moveTo(vx, vy)
          ctx.quadraticCurveTo(vx + vd * 0.05, vy + va * 0.05, vx + vd * 0.1, vy + va * 0.12 - 0.02)
          ctx.stroke()
        }
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
