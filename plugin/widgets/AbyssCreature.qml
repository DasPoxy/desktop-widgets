import QtQuick

// ---------------------------------------------------------------------------
// 👻 Abyss Creature -- the extra Buddy Types: jellyfish, flying saucer (with
// an alien inside), ghost, djinn and floating skull. Each is a flat riso-
// style body on a Canvas (fills, hard shadow + halftone, ink outline) with
// live AbyssEyes placed on it, bobbing gently. Colours come from the eye
// theme: body = print colour (`glow`), pale parts = sclera, shadows =
// scleraShade, ink = lash.
//
// Drawing happens in "creature units": the creature's box is extentW x
// extentH units, centred on (0, 0), scaled to fit the item.
// ---------------------------------------------------------------------------
Item {
  id: creature

  property string kind: "ghost"   // jelly | saucer | ghost | djinn | skull
  property string styleId: "classic"
  property string irisStyle: "auto"
  property var theme: ({})
  property real gazeX: 0
  property real gazeY: 0
  property real openness: 1
  property real pupilScale: 1
  property real glow: 1
  property real irisGlow: 0
  // Off for the static previews in the menu.
  property bool animate: true

  property real t: 0
  FrameAnimation {
    running: creature.animate && creature.visible && creature.openness > 0.05
    onTriggered: creature.t += frameTime
  }

  // [width, height, vertical centre] of each creature's drawing, in units.
  readonly property var extents: ({
    jelly: [1.0, 1.36, 0.06], saucer: [1.35, 1.18, 0.04], ghost: [0.98, 1.12, -0.02],
    djinn: [1.0, 1.4, -0.01], skull: [0.98, 1.06, -0.03]
  })
  readonly property var ext: extents[kind] || [1, 1, 0]
  readonly property real unitPx: Math.max(1, Math.min(width / ext[0], height / ext[1]) * 0.94)
  readonly property real cx: width / 2
  readonly property real bob: Math.sin(t * 1.5) * 0.025
  readonly property real cy: height / 2 + (bob - ext[2]) * unitPx

  // Where the eyes sit, in creature units: [x, y, w, h, mirrored].
  readonly property var eyeSlots: {
    switch (kind) {
      case "jelly": return [[-0.16, -0.2, 0.34, 0.26, true], [0.16, -0.2, 0.34, 0.26, false]]
      case "saucer": return [[-0.07, -0.2, 0.17, 0.13, true], [0.07, -0.2, 0.17, 0.13, false]]
      case "ghost": return [[-0.14, -0.2, 0.3, 0.23, true], [0.14, -0.2, 0.3, 0.23, false]]
      case "djinn": return [[-0.075, -0.4, 0.16, 0.12, true], [0.075, -0.4, 0.16, 0.12, false]]
      case "skull": return [[-0.155, -0.1, 0.26, 0.2, true], [0.155, -0.1, 0.26, 0.2, false]]
    }
    return []
  }

  function col(key, fallback) {
    var v = theme ? theme[key] : undefined
    return (v === undefined || v === null || v === "") ? fallback : v
  }
  function rgba(c, a) {
    var q = Qt.color(c)
    return "rgba(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255) + "," + Math.round(q.b * 255) + "," + (q.a * a) + ")"
  }

  Canvas {
    id: body
    anchors.fill: parent

    Connections {
      target: creature
      function onTChanged() { body.requestPaint() }
      function onThemeChanged() { body.requestPaint() }
      function onKindChanged() { body.requestPaint() }
      function onIrisGlowChanged() { body.requestPaint() }
      function onWidthChanged() { body.requestPaint() }
      function onHeightChanged() { body.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var t = creature.t, S = creature.unitPx
      var lash = creature.col("lash", "#1c1f3f")
      var flesh = creature.col("glow", "#2a9d8f")
      var fleshDark = Qt.darker(flesh, 1.45)
      var pale = creature.col("sclera", "#f2e6d0")
      var paleShade = creature.col("scleraShade", "#8fc5b8")
      var light = creature.col("irisLight", "#ffb3a7")
      var hl = creature.col("highlight", "#fff7ea")
      var lw = 0.022
      ctx.save()
      ctx.translate(creature.cx, creature.cy)
      ctx.scale(S, S)
      ctx.lineJoin = "round"
      ctx.lineCap = "round"

      function ink(w) { ctx.strokeStyle = lash; ctx.lineWidth = w || lw; ctx.stroke() }
      function fill(c) { ctx.fillStyle = c; ctx.fill() }
      function dotsBand(cxp, cyp, r0, a0, a1, color) {
        // A halftone fade just inside a shadow edge (arc from a0 to a1).
        ctx.fillStyle = color
        ctx.beginPath()
        for (var row = 0; row < 3; row++) {
          for (var a = a0; a <= a1; a += 0.09) {
            var aa = a + (row % 2) * 0.045, rr = r0 - 0.02 - row * 0.022, dr = 0.009 * (1 - row / 3.4)
            var x = cxp + Math.cos(aa) * rr, y = cyp + Math.sin(aa) * rr
            ctx.moveTo(x + dr, y)
            ctx.arc(x, y, dr, 0, Math.PI * 2)
          }
        }
        ctx.fill()
      }
      // Hard shadow on the lower right of a shape already on the path:
      // fill it with the shade, then the lit disc offset up-left on top.
      function celShade(pathFn, lit, shade, lx, ly, lr) {
        ctx.save()
        pathFn()
        ctx.clip()
        ctx.fillStyle = shade
        ctx.fillRect(-2, -2, 4, 4)
        ctx.fillStyle = lit
        ctx.beginPath(); ctx.arc(lx, ly, lr, 0, Math.PI * 2); ctx.fill()
        dotsBand(lx, ly, lr, -0.3, 1.9, shade)
        ctx.restore()
      }

      if (creature.kind === "jelly") {
        // Tentacles first (behind the bell): wavy ribbons + two frilly arms.
        for (var ti = 0; ti < 5; ti++) {
          var tx0 = -0.3 + ti * 0.15
          ctx.beginPath()
          for (var ty = 0; ty <= 24; ty++) {
            var yy = 0.05 + ty / 24 * 0.62
            var xx = tx0 + Math.sin(yy * 11 - t * 2.6 + ti * 1.3) * 0.035 * (yy + 0.2)
            if (ty === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy)
          }
          ctx.lineWidth = 0.05; ctx.strokeStyle = lash; ctx.stroke()
          ctx.lineWidth = 0.028; ctx.strokeStyle = flesh; ctx.stroke()
        }
        for (var fa = 0; fa < 2; fa++) {
          var fx = fa ? 0.07 : -0.07
          ctx.beginPath()
          for (var fy = 0; fy <= 20; fy++) {
            var y2 = 0.05 + fy / 20 * 0.45
            var x2 = fx + Math.sin(y2 * 9 - t * 2 + fa * 2) * 0.05
            if (fy === 0) ctx.moveTo(x2, y2); else ctx.lineTo(x2, y2)
          }
          ctx.lineWidth = 0.09; ctx.strokeStyle = lash; ctx.stroke()
          ctx.lineWidth = 0.065; ctx.strokeStyle = light; ctx.stroke()
        }
        // Bell: dome with a scalloped hem that pulses.
        var pulse = Math.sin(t * 2.2) * 0.02
        var bell = function() {
          ctx.beginPath()
          ctx.moveTo(-0.46 - pulse, 0.08)
          ctx.bezierCurveTo(-0.5 - pulse, -0.62, 0.5 + pulse, -0.62, 0.46 + pulse, 0.08)
          for (var sc = 0; sc < 6; sc++) {
            var xa = 0.46 + pulse - (sc + 1) * (0.92 + 2 * pulse) / 6
            ctx.quadraticCurveTo(xa + (0.92 + 2 * pulse) / 12, 0.16, xa, 0.08)
          }
          ctx.closePath()
        }
        celShade(bell, flesh, fleshDark, -0.12, -0.28, 0.5)
        bell(); ink()
        // Glossy highlight arc on the dome.
        ctx.beginPath(); ctx.arc(0, -0.05, 0.36, Math.PI * 1.15, Math.PI * 1.45)
        ctx.strokeStyle = rgba(hl, 0.7); ctx.lineWidth = 0.035; ctx.stroke()
        // Spots.
        ctx.fillStyle = rgba(light, 0.55)
        var spots = [[-0.28, -0.08, 0.03], [0.3, -0.12, 0.025], [0.05, -0.4, 0.028], [-0.1, 0.0, 0.02]]
        for (var sp = 0; sp < spots.length; sp++) { ctx.beginPath(); ctx.arc(spots[sp][0], spots[sp][1], spots[sp][2], 0, Math.PI * 2); ctx.fill() }
        // Little smile.
        ctx.beginPath(); ctx.arc(0, -0.04, 0.05, 0.2, Math.PI - 0.2); ink(0.016)
      } else if (creature.kind === "saucer") {
        // Tractor beam while glowing (Buddy Mode + recording).
        if (creature.irisGlow > 0.02) {
          ctx.beginPath()
          ctx.moveTo(-0.13, 0.26); ctx.lineTo(0.13, 0.26); ctx.lineTo(0.42, 0.58); ctx.lineTo(-0.42, 0.58); ctx.closePath()
          fill(rgba(light, 0.35 * creature.irisGlow))
          ctx.strokeStyle = rgba(hl, 0.5 * creature.irisGlow); ctx.lineWidth = 0.012
          for (var bl = 0; bl < 4; bl++) {
            var by = 0.3 + ((t * 0.25 + bl * 0.25) % 1) * 0.28, bw = 0.13 + (by - 0.26) * 0.9
            ctx.beginPath(); ctx.moveTo(-bw, by); ctx.lineTo(bw, by); ctx.stroke()
          }
        }
        // Alien (behind the glass): green head with antennae.
        var skin = Qt.tint("#8fd694", Qt.alpha(flesh, 0.25))
        for (var an = -1; an <= 1; an += 2) {
          ctx.beginPath(); ctx.moveTo(an * 0.07, -0.33); ctx.quadraticCurveTo(an * 0.1, -0.44, an * 0.13 + Math.sin(t * 3 + an) * 0.015, -0.47); ink(0.016)
          ctx.beginPath(); ctx.arc(an * 0.13 + Math.sin(t * 3 + an) * 0.015, -0.47, 0.022, 0, Math.PI * 2); fill(light); ink(0.012)
        }
        ctx.beginPath(); ctx.ellipse(-0.17, -0.37, 0.34, 0.34); fill(skin); ink(0.018)
        ctx.beginPath(); ctx.arc(0, -0.1, 0.035, 0.25, Math.PI - 0.25); ink(0.012)
        // Glass dome.
        ctx.beginPath(); ctx.arc(0, -0.05, 0.3, Math.PI, 0); ctx.closePath()
        fill(rgba(light, 0.22)); ink()
        ctx.beginPath(); ctx.arc(0, -0.05, 0.24, Math.PI * 1.1, Math.PI * 1.35)
        ctx.strokeStyle = rgba(hl, 0.8); ctx.lineWidth = 0.025; ctx.stroke()
        // Hull: wide disc + lower bulge, cel shaded, with blinking rim lights.
        ctx.beginPath(); ctx.ellipse(-0.24, 0.1, 0.48, 0.2); fill(Qt.darker(paleShade, 1.3)); ink()
        var hull = function() { ctx.beginPath(); ctx.ellipse(-0.64, -0.08, 1.28, 0.3) }
        celShade(hull, paleShade, Qt.darker(paleShade, 1.35), -0.25, -0.35, 0.72)
        hull(); ink()
        ctx.beginPath(); ctx.ellipse(-0.6, 0.0, 1.2, 0.1); ctx.strokeStyle = rgba(lash, 0.5); ctx.lineWidth = 0.014; ctx.stroke()
        var lights = [creature.col("iris", "#e8456b"), light, flesh, hl]
        for (var li = 0; li < 7; li++) {
          var la = Math.PI * (0.12 + li * 0.127)
          var lx = Math.cos(la) * 0.56, ly = 0.07 + Math.sin(la) * 0.08
          var on = ((Math.floor(t * 3) + li) % 3) !== 0
          ctx.beginPath(); ctx.arc(lx, ly, 0.028, 0, Math.PI * 2)
          fill(on ? lights[li % lights.length] : rgba(lash, 0.5)); ink(0.01)
        }
      } else if (creature.kind === "ghost") {
        // Sheet ghost: dome head, little arms, rippling hem.
        var sheet = function() {
          ctx.beginPath()
          ctx.moveTo(-0.36, 0.05)
          ctx.bezierCurveTo(-0.38, -0.66, 0.38, -0.66, 0.36, 0.05)
          ctx.quadraticCurveTo(0.46, 0.1 + Math.sin(t * 2.4) * 0.03, 0.4, 0.2)
          ctx.lineTo(0.4, 0.44)
          for (var hm = 0; hm <= 16; hm++) {
            var hx = 0.4 - hm * 0.05, hy = 0.44 + Math.sin(hx * 16 + t * 4) * 0.035
            ctx.lineTo(hx, hy)
          }
          ctx.lineTo(-0.4, 0.2)
          ctx.quadraticCurveTo(-0.46, 0.1 + Math.sin(t * 2.4 + 1.5) * 0.03, -0.36, 0.05)
          ctx.closePath()
        }
        celShade(sheet, Qt.lighter(pale, 1.03), paleShade, -0.1, -0.22, 0.74)
        sheet(); ink()
        // Blush + a little "o" mouth.
        ctx.fillStyle = rgba(light, 0.55)
        ctx.beginPath(); ctx.ellipse(-0.3, -0.07, 0.12, 0.05); ctx.fill()
        ctx.beginPath(); ctx.ellipse(0.18, -0.07, 0.12, 0.05); ctx.fill()
        ctx.beginPath(); ctx.ellipse(-0.035, 0.0, 0.07, 0.09); fill(lash)
      } else if (creature.kind === "djinn") {
        // Smoke tail: one tapering swirl rising to the waist, with a couple
        // of wisp lines inside it.
        var spine = []
        for (var sp2 = 0; sp2 <= 24; sp2++) {
          var u = sp2 / 24
          spine.push([Math.sin(u * 5.5 + t * 1.6) * 0.1 * (1 - u) + 0.07 * (1 - u), 0.62 - u * 0.52, 0.012 + u * 0.12])
        }
        ctx.beginPath()
        for (var sl = 0; sl < spine.length; sl++) ctx.lineTo(spine[sl][0] - spine[sl][2], spine[sl][1])
        for (var sr = spine.length - 1; sr >= 0; sr--) ctx.lineTo(spine[sr][0] + spine[sr][2], spine[sr][1])
        ctx.closePath()
        fill(Qt.lighter(flesh, 1.18)); ink()
        ctx.strokeStyle = rgba(fleshDark, 0.8); ctx.lineWidth = 0.014
        for (var wl = 0; wl < 2; wl++) {
          ctx.beginPath()
          for (var wi = 4; wi <= 22; wi++) {
            var wp = spine[wi], off = (wl ? 0.4 : -0.35) * wp[2] * Math.sin(wi * 0.6 + t * 2)
            if (wi === 4) ctx.moveTo(wp[0] + off, wp[1]); else ctx.lineTo(wp[0] + off, wp[1])
          }
          ctx.stroke()
        }
        // Torso.
        var torso = function() {
          ctx.beginPath()
          ctx.moveTo(-0.13, 0.12)
          ctx.quadraticCurveTo(-0.3, -0.05, -0.25, -0.2)
          ctx.quadraticCurveTo(0, -0.3, 0.25, -0.2)
          ctx.quadraticCurveTo(0.3, -0.05, 0.13, 0.12)
          ctx.closePath()
        }
        celShade(torso, flesh, fleshDark, -0.1, -0.25, 0.4)
        torso(); ink()
        // Crossed arms with gold bracers.
        var gold = Qt.tint("#f2c14e", Qt.alpha(light, 0.2))
        ctx.beginPath(); ctx.moveTo(-0.26, -0.13); ctx.lineTo(0.2, -0.03); ctx.lineWidth = 0.11; ctx.strokeStyle = lash; ctx.stroke()
        ctx.lineWidth = 0.075; ctx.strokeStyle = fleshDark; ctx.stroke()
        ctx.beginPath(); ctx.moveTo(0.26, -0.13); ctx.lineTo(-0.2, -0.03); ctx.lineWidth = 0.11; ctx.strokeStyle = lash; ctx.stroke()
        ctx.lineWidth = 0.075; ctx.strokeStyle = flesh; ctx.stroke()
        ctx.beginPath(); ctx.arc(-0.2, -0.04, 0.045, 0, Math.PI * 2); fill(gold); ink(0.014)
        ctx.beginPath(); ctx.arc(0.2, -0.04, 0.045, 0, Math.PI * 2); fill(gold); ink(0.014)
        // Head, topknot, earring, goatee.
        ctx.beginPath(); ctx.moveTo(0, -0.58); ctx.quadraticCurveTo(0.2 + Math.sin(t * 2) * 0.03, -0.68, 0.24, -0.5)
        ctx.lineWidth = 0.07; ctx.strokeStyle = lash; ctx.stroke(); ctx.lineWidth = 0.045; ctx.strokeStyle = fleshDark; ctx.stroke()
        var head = function() { ctx.beginPath(); ctx.arc(0, -0.4, 0.18, 0, Math.PI * 2) }
        celShade(head, flesh, fleshDark, -0.06, -0.47, 0.2)
        head(); ink()
        ctx.beginPath(); ctx.arc(0, -0.59, 0.045, 0, Math.PI * 2); fill(fleshDark); ink(0.014)
        ctx.beginPath(); ctx.arc(-0.185, -0.35, 0.03, 0, Math.PI * 2); ctx.strokeStyle = gold; ctx.lineWidth = 0.014; ctx.stroke()
        ctx.beginPath(); ctx.moveTo(-0.03, -0.25); ctx.lineTo(0, -0.18); ctx.lineTo(0.03, -0.25); ctx.closePath(); fill(lash)
        ctx.beginPath(); ctx.arc(0, -0.33, 0.04, 0.3, Math.PI - 0.3); ink(0.014)
      } else if (creature.kind === "skull") {
        // Jaw (chatters a little), then cranium over it.
        var chat = Math.max(0, Math.sin(t * 7)) * 0.02 * (0.5 + 0.5 * Math.sin(t * 0.7))
        var jaw = function() {
          ctx.beginPath()
          ctx.moveTo(-0.24, 0.18 + chat)
          ctx.quadraticCurveTo(-0.24, 0.42 + chat, 0, 0.44 + chat)
          ctx.quadraticCurveTo(0.24, 0.42 + chat, 0.24, 0.18 + chat)
          ctx.closePath()
        }
        celShade(jaw, pale, paleShade, -0.1, 0.05, 0.4)
        jaw(); ink()
        var skullShape = function() {
          ctx.beginPath()
          ctx.moveTo(-0.3, 0.2)
          ctx.bezierCurveTo(-0.52, 0.05, -0.5, -0.52, 0, -0.52)
          ctx.bezierCurveTo(0.5, -0.52, 0.52, 0.05, 0.3, 0.2)
          ctx.quadraticCurveTo(0, 0.28, -0.3, 0.2)
          ctx.closePath()
        }
        celShade(skullShape, pale, paleShade, -0.12, -0.3, 0.62)
        skullShape(); ink()
        // Sockets (the eyes sit inside), nose, crack, teeth.
        ctx.fillStyle = lash
        ctx.beginPath(); ctx.ellipse(-0.3, -0.23, 0.29, 0.26); ctx.fill()
        ctx.beginPath(); ctx.ellipse(0.01, -0.23, 0.29, 0.26); ctx.fill()
        ctx.beginPath(); ctx.moveTo(0, 0.02); ctx.lineTo(-0.045, 0.11); ctx.lineTo(0.045, 0.11); ctx.closePath(); ctx.fill()
        ctx.beginPath(); ctx.moveTo(0.12, -0.5); ctx.lineTo(0.16, -0.42); ctx.lineTo(0.13, -0.37); ctx.lineTo(0.18, -0.3); ink(0.012)
        for (var tth = 0; tth < 6; tth++) {
          var txp = -0.15 + tth * 0.06
          ctx.beginPath(); ctx.moveTo(txp, 0.17); ctx.lineTo(txp, 0.27 + chat * 0.5); ink(0.01)
        }
        ctx.beginPath(); ctx.moveTo(-0.18, 0.22 + chat * 0.5); ctx.lineTo(0.18, 0.22 + chat * 0.5); ink(0.012)
      }
      ctx.restore()
    }
  }

  Repeater {
    model: creature.eyeSlots

    AbyssEye {
      required property var modelData
      width: modelData[2] * creature.unitPx
      height: modelData[3] * creature.unitPx
      x: creature.cx + modelData[0] * creature.unitPx - width / 2
      y: creature.cy + modelData[1] * creature.unitPx - height / 2
      mirrored: modelData[4]
      styleId: creature.styleId
      irisStyle: creature.irisStyle
      theme: creature.theme
      gazeX: creature.gazeX
      gazeY: creature.gazeY
      openness: creature.openness
      pupilScale: creature.pupilScale
      glow: 0
      irisGlow: creature.irisGlow
    }
  }
}
