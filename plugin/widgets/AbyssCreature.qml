import QtQuick

// ---------------------------------------------------------------------------
// 👻 Abyss Creature -- the extra Buddy Types: jellyfish, flying saucer (with
// an alien inside), ghost, djinn, floating skull, a handsome squid-man and a
// smug unicorn. Each is a flat riso-
// style body on a Canvas (fills, hard shadow + halftone, ink outline) with
// live AbyssEyes placed on it, bobbing gently. Colours come from the eye
// theme: body = print colour (`glow`), pale parts = sclera, shadows =
// scleraShade, ink = lash. The two character buddies keep their own skin
// colours (lightly tinted by the theme) and get heavy half-lids drawn over
// their eyes on a second Canvas above them.
//
// Drawing happens in "creature units": the creature's box is extentW x
// extentH units, centred on (0, 0), scaled to fit the item.
// ---------------------------------------------------------------------------
Item {
  id: creature

  property string kind: "ghost"   // jelly | saucer | ghost | djinn | skull | squid | unicorn
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
    djinn: [1.0, 1.4, -0.01], skull: [0.98, 1.06, -0.03],
    squid: [1.0, 1.36, 0.04], unicorn: [1.4, 1.52, -0.07]
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
      case "squid": return [[-0.165, -0.15, 0.32, 0.25, true], [0.165, -0.15, 0.32, 0.25, false]]
      case "unicorn": return [[-0.16, -0.17, 0.27, 0.19, true], [0.18, -0.18, 0.29, 0.2, false]]
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
  // The character buddies' own colours, nudged a little toward the theme.
  function skinOf(base, amount) { return Qt.tint(base, Qt.alpha(col("glow", "#2a9d8f"), amount || 0.18)) }
  readonly property bool hasLids: kind === "squid" || kind === "unicorn"

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
      function star4(x, y, r) {
        ctx.beginPath()
        ctx.moveTo(x, y - r)
        ctx.quadraticCurveTo(x + r * 0.15, y - r * 0.15, x + r * 0.8, y)
        ctx.quadraticCurveTo(x + r * 0.15, y + r * 0.15, x, y + r)
        ctx.quadraticCurveTo(x - r * 0.15, y + r * 0.15, x - r * 0.8, y)
        ctx.quadraticCurveTo(x - r * 0.15, y - r * 0.15, x, y - r)
        ctx.closePath()
      }
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
      } else if (creature.kind === "squid") {
        // Handsome squid-man: shirt collar, thin neck, a huge bald dome of a
        // head over a chiselled jaw, pouty pink lips. (Nose, lids and brows
        // go on the overlay, in front of the eyes.)
        var skin = creature.skinOf("#a3d4bf")
        var skinDark = Qt.darker(skin, 1.28)
        var shirt = creature.skinOf("#b06a2c", 0.12)
        ctx.beginPath()
        ctx.moveTo(-0.46, 0.7); ctx.quadraticCurveTo(-0.4, 0.5, -0.12, 0.47)
        ctx.lineTo(0, 0.6); ctx.lineTo(0.12, 0.47)
        ctx.quadraticCurveTo(0.4, 0.5, 0.46, 0.7); ctx.closePath()
        fill(shirt); ink()
        ctx.beginPath(); ctx.moveTo(-0.08, 0.4); ctx.lineTo(-0.08, 0.56); ctx.lineTo(0, 0.6); ctx.lineTo(0.08, 0.56); ctx.lineTo(0.08, 0.4); ctx.closePath()
        fill(skinDark); ink(0.016)
        var squidHead = function() {
          ctx.beginPath()
          ctx.moveTo(-0.2, 0.46)
          ctx.quadraticCurveTo(-0.31, 0.42, -0.3, 0.12)
          ctx.bezierCurveTo(-0.3, -0.04, -0.46, -0.16, -0.44, -0.36)
          ctx.bezierCurveTo(-0.42, -0.7, 0.42, -0.7, 0.44, -0.36)
          ctx.bezierCurveTo(0.46, -0.16, 0.3, -0.04, 0.3, 0.12)
          ctx.quadraticCurveTo(0.31, 0.42, 0.2, 0.46)
          ctx.quadraticCurveTo(0, 0.51, -0.2, 0.46)
          ctx.closePath()
        }
        celShade(squidHead, skin, skinDark, -0.1, -0.26, 0.66)
        squidHead(); ink()
        // Dome sheen, forehead lines, cheekbones, chin cleft.
        ctx.beginPath(); ctx.arc(-0.1, -0.36, 0.2, Math.PI * 1.15, Math.PI * 1.5)
        ctx.strokeStyle = rgba(hl, 0.7); ctx.lineWidth = 0.03; ctx.stroke()
        ctx.beginPath(); ctx.moveTo(-0.16, -0.36); ctx.quadraticCurveTo(0, -0.4, 0.16, -0.36); ink(0.012)
        ctx.beginPath(); ctx.moveTo(-0.12, -0.31); ctx.quadraticCurveTo(0, -0.34, 0.12, -0.31); ink(0.012)
        ctx.beginPath(); ctx.moveTo(-0.27, 0.06); ctx.quadraticCurveTo(-0.22, 0.2, -0.24, 0.3); ink(0.012)
        ctx.beginPath(); ctx.moveTo(0.27, 0.06); ctx.quadraticCurveTo(0.22, 0.2, 0.24, 0.3); ink(0.012)
        ctx.beginPath(); ctx.moveTo(0, 0.44); ctx.lineTo(0, 0.48); ink(0.012)
        // Lips: a full pout under the nose.
        var lip = creature.skinOf("#e59aa6", 0.1)
        ctx.beginPath()
        ctx.moveTo(-0.1, 0.33)
        ctx.bezierCurveTo(-0.07, 0.27, -0.03, 0.27, 0, 0.3)
        ctx.bezierCurveTo(0.03, 0.27, 0.07, 0.27, 0.1, 0.33)
        ctx.bezierCurveTo(0.07, 0.41, -0.07, 0.41, -0.1, 0.33)
        ctx.closePath()
        fill(lip); ink(0.016)
        ctx.beginPath(); ctx.moveTo(-0.09, 0.33); ctx.quadraticCurveTo(0, 0.35, 0.09, 0.33); ink(0.012)
        ctx.beginPath(); ctx.ellipse(-0.04, 0.35, 0.05, 0.02); fill(rgba(hl, 0.6))
      } else if (creature.kind === "unicorn") {
        // Smug unicorn: mane streaming out behind, ears, a spiral horn, a long
        // snout with nostrils and buck teeth, and a knowing little smile.
        var coat = creature.skinOf("#f6efdd", 0.05)
        var coatDark = Qt.darker(coat, 1.16)
        var mane = creature.skinOf("#dce86a", 0.15)
        var peach = creature.skinOf("#efb99c", 0.1)
        // Twinkles.
        var twk = [[-0.54, -0.56, 0.06, 0], [0.6, -0.64, 0.05, 2.1], [0.58, 0.46, 0.055, 4.2], [-0.6, -0.2, 0.035, 1.3]]
        for (var tw = 0; tw < twk.length; tw++) {
          var tws = 0.55 + 0.45 * Math.sin(t * 2.2 + twk[tw][3])
          star4(twk[tw][0], twk[tw][1], twk[tw][2] * tws); fill(rgba(hl, 0.9))
        }
        // Mane, flowing out to the right.
        var sway = Math.sin(t * 1.3) * 0.03
        ctx.beginPath()
        ctx.moveTo(-0.05, -0.5)
        ctx.bezierCurveTo(0.25, -0.62, 0.5, -0.5, 0.66, -0.36 + sway)
        ctx.bezierCurveTo(0.56, -0.3, 0.64, -0.18 + sway, 0.62, -0.06 + sway)
        ctx.bezierCurveTo(0.54, -0.1, 0.56, 0.06, 0.5, 0.2 + sway)
        ctx.lineTo(0.38, 0.1)
        ctx.lineTo(0.3, -0.4)
        ctx.closePath()
        fill(mane); ink()
        ctx.beginPath(); ctx.moveTo(0.2, -0.5); ctx.quadraticCurveTo(0.42, -0.46, 0.56, -0.3 + sway); ink(0.012)
        // Neck.
        ctx.beginPath()
        ctx.moveTo(0.0, 0.3); ctx.quadraticCurveTo(-0.04, 0.5, -0.06, 0.68)
        ctx.lineTo(0.44, 0.68); ctx.quadraticCurveTo(0.44, 0.4, 0.42, 0.1); ctx.closePath()
        fill(coatDark); ink()
        // Ears.
        // Leaf-shaped ears, each side bulging outward on its way to the tip.
        var ear = function(bx, tipX, tipY, half, bulge) {
          ctx.beginPath()
          ctx.moveTo(bx - half, -0.37)
          ctx.quadraticCurveTo((bx - half + tipX) / 2 - bulge, (-0.37 + tipY) / 2, tipX, tipY)
          ctx.quadraticCurveTo((bx + half + tipX) / 2 + bulge, (-0.39 + tipY) / 2, bx + half, -0.39)
          ctx.closePath()
        }
        ear(-0.24, -0.42, -0.64, 0.09, 0.05); fill(coat); ink()
        ear(-0.25, -0.4, -0.6, 0.04, 0.02); fill(peach)
        ear(0.3, 0.5, -0.66, 0.09, 0.05); fill(coat); ink()
        ear(0.31, 0.48, -0.62, 0.04, 0.02); fill(peach)
        // Head: forehead, long snout down to the lower left, big jowl.
        var uniHead = function() {
          ctx.beginPath()
          ctx.moveTo(-0.34, -0.36)
          ctx.bezierCurveTo(-0.2, -0.47, 0.25, -0.48, 0.4, -0.34)
          ctx.bezierCurveTo(0.5, -0.2, 0.47, 0.05, 0.42, 0.14)
          ctx.bezierCurveTo(0.34, 0.34, 0.1, 0.4, -0.12, 0.4)
          ctx.bezierCurveTo(-0.3, 0.44, -0.46, 0.5, -0.58, 0.4)
          ctx.bezierCurveTo(-0.68, 0.3, -0.64, 0.16, -0.58, 0.08)
          ctx.bezierCurveTo(-0.5, -0.06, -0.4, -0.2, -0.34, -0.36)
          ctx.closePath()
        }
        celShade(uniHead, coat, coatDark, -0.12, -0.22, 0.64)
        uniHead(); ink()
        // Horn: a peach-banded spike.
        ctx.beginPath(); ctx.moveTo(-0.08, -0.43); ctx.lineTo(0.0, -0.8); ctx.lineTo(0.09, -0.44); ctx.closePath()
        fill(coat); ink()
        ctx.save()
        ctx.beginPath(); ctx.moveTo(-0.08, -0.43); ctx.lineTo(0.0, -0.8); ctx.lineTo(0.09, -0.44); ctx.closePath()
        ctx.clip()
        ctx.fillStyle = peach
        for (var hb = 0; hb < 4; hb++) {
          var hy = -0.47 - hb * 0.085
          ctx.beginPath(); ctx.moveTo(-0.12, hy); ctx.lineTo(0.12, hy - 0.05); ctx.lineTo(0.12, hy - 0.08); ctx.lineTo(-0.12, hy - 0.03); ctx.closePath(); ctx.fill()
        }
        ctx.restore()
        ctx.beginPath(); ctx.moveTo(-0.08, -0.43); ctx.lineTo(0.0, -0.8); ctx.lineTo(0.09, -0.44); ctx.closePath(); ink()
        // Nostrils, buck-toothed lips, the smug smile.
        ctx.fillStyle = peach
        ctx.beginPath(); ctx.ellipse(-0.56, 0.1, 0.04, 0.05); ctx.fill()
        ctx.beginPath(); ctx.ellipse(-0.44, 0.13, 0.04, 0.045); ctx.fill()
        ctx.beginPath(); ctx.moveTo(-0.6, 0.3); ctx.bezierCurveTo(-0.57, 0.26, -0.52, 0.26, -0.5, 0.29)
        ctx.bezierCurveTo(-0.47, 0.26, -0.42, 0.27, -0.4, 0.31); ink(0.016)
        ctx.beginPath(); ctx.moveTo(-0.58, 0.31); ctx.quadraticCurveTo(-0.5, 0.34, -0.41, 0.32); ink(0.014)
        ctx.beginPath(); ctx.rect(-0.55, 0.305, 0.045, 0.04); fill(hl); ink(0.01)
        ctx.beginPath(); ctx.rect(-0.505, 0.305, 0.045, 0.04); fill(hl); ink(0.01)
        ctx.beginPath(); ctx.moveTo(-0.56, 0.36); ctx.quadraticCurveTo(-0.5, 0.39, -0.43, 0.35); ink(0.014)
        ctx.beginPath(); ctx.moveTo(-0.52, 0.42); ctx.quadraticCurveTo(-0.5, 0.44, -0.48, 0.42); ink(0.01)
        ctx.beginPath(); ctx.moveTo(-0.1, 0.17); ctx.quadraticCurveTo(0.05, 0.24, 0.18, 0.14); ink(0.016)
        ctx.beginPath(); ctx.moveTo(0.17, 0.16); ctx.lineTo(0.2, 0.1); ink(0.014)
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

  // In front of the eyes: the character buddies' heavy half-lids (they drop
  // shut with a blink), brows and the squid-man's nose.
  Canvas {
    id: front
    anchors.fill: parent
    visible: creature.hasLids

    Connections {
      target: creature
      enabled: creature.hasLids
      function onTChanged() { front.requestPaint() }
      function onThemeChanged() { front.requestPaint() }
      function onKindChanged() { front.requestPaint() }
      function onOpennessChanged() { front.requestPaint() }
      function onWidthChanged() { front.requestPaint() }
      function onHeightChanged() { front.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      if (!creature.hasLids) return
      var S = creature.unitPx
      var lash = creature.col("lash", "#1c1f3f")
      var squid = creature.kind === "squid"
      var skin = squid ? creature.skinOf("#a3d4bf") : creature.skinOf("#f6efdd", 0.05)
      var o = Math.max(0, Math.min(1, creature.openness))
      ctx.save()
      ctx.translate(creature.cx, creature.cy)
      ctx.scale(S, S)
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      function ink(w) { ctx.strokeStyle = lash; ctx.lineWidth = w; ctx.stroke() }

      var slots = creature.eyeSlots
      for (var i = 0; i < slots.length; i++) {
        var x = slots[i][0], y = slots[i][1], w = slots[i][2], h = slots[i][3]
        var out = slots[i][4] ? -1 : 1          // which way the outer corner is
        var hw = w * 0.44
        // Lid edge, as a fraction down the eye box: heavy when open, all the
        // way down when shut.
        var edge = y - h / 2 + h * (squid ? 0.5 + 0.18 * (1 - o) : 0.46 + 0.22 * (1 - o))
        var sag = h * (squid ? 0.1 : 0.14)
        ctx.beginPath()
        ctx.moveTo(x - hw, y - h * 0.62)
        ctx.lineTo(x + hw, y - h * 0.62)
        ctx.lineTo(x + hw, edge + (out > 0 ? h * 0.04 : 0))
        ctx.quadraticCurveTo(x, edge + sag, x - hw, edge + (out < 0 ? h * 0.04 : 0))
        ctx.closePath()
        ctx.fillStyle = skin
        ctx.fill()
        // Lid line, and a lash flick at the outer corner for the unicorn.
        ctx.beginPath()
        ctx.moveTo(x - hw * 0.92, edge + (out < 0 ? h * 0.04 : 0) + sag * 0.12)
        ctx.quadraticCurveTo(x, edge + sag * 1.02, x + hw * 0.92, edge + (out > 0 ? h * 0.04 : 0) + sag * 0.12)
        ink(squid ? 0.022 : 0.018)
        if (!squid) {
          var ox = x + out * hw * 0.92, oy = edge + h * 0.04 + sag * 0.12
          ctx.beginPath(); ctx.moveTo(ox, oy); ctx.quadraticCurveTo(ox + out * 0.04, oy - 0.01, ox + out * 0.07, oy - 0.03); ink(0.014)
          // Arched brow, and a tired line under the eye.
          ctx.beginPath(); ctx.moveTo(x - hw * 0.8, y - h * 0.62); ctx.quadraticCurveTo(x, y - h * 0.95, x + hw * 0.9, y - h * 0.66); ink(0.012)
          ctx.beginPath(); ctx.moveTo(x - hw * 0.3, y + h * 0.62); ctx.quadraticCurveTo(x, y + h * 0.7, x + hw * 0.35, y + h * 0.6); ink(0.01)
        } else {
          // Heavy brow ridge.
          ctx.beginPath(); ctx.moveTo(x - hw, y - h * 0.5); ctx.quadraticCurveTo(x, y - h * 0.78, x + hw, y - h * 0.52); ink(0.016)
        }
      }

      if (squid) {
        // The nose: long and droopy, hanging from between the eyes.
        var nose = function() {
          ctx.beginPath()
          ctx.moveTo(-0.035, -0.17)
          ctx.bezierCurveTo(-0.05, -0.02, -0.12, 0.1, -0.1, 0.19)
          ctx.bezierCurveTo(-0.08, 0.27, 0.08, 0.27, 0.1, 0.19)
          ctx.bezierCurveTo(0.12, 0.1, 0.05, -0.02, 0.035, -0.17)
          ctx.closePath()
        }
        nose(); ctx.fillStyle = skin; ctx.fill()
        // Shadow down its right side, then the outline and a sheen.
        ctx.beginPath()
        ctx.moveTo(0.035, -0.17)
        ctx.bezierCurveTo(0.05, -0.02, 0.12, 0.1, 0.1, 0.19)
        ctx.bezierCurveTo(0.08, 0.25, 0.02, 0.26, 0.02, 0.26)
        ctx.bezierCurveTo(0.07, 0.18, 0.04, 0.02, 0.02, -0.17)
        ctx.closePath()
        ctx.fillStyle = Qt.darker(skin, 1.28); ctx.fill()
        nose(); ink(0.02)
        ctx.beginPath(); ctx.moveTo(-0.05, 0.08); ctx.quadraticCurveTo(-0.075, 0.14, -0.06, 0.2)
        ctx.strokeStyle = creature.rgba(creature.col("highlight", "#fff7ea"), 0.7); ctx.lineWidth = 0.018; ctx.stroke()
      }
      ctx.restore()
    }
  }
}
