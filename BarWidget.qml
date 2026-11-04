import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Portal: the Omarchy menu button as a terminal glyph, drawn in a choice of
// styles: Classic, Modern, Retro, Deco, Atomic, Nouveau, Alchemical, Zen, Seal
// and Pixel, plus the Omarchy, Arch, Hyprland and Linux marks.
//
// Every mark is held to one grid: 12 px of ink, centered on the ink itself
// (not the font box, which is why font glyphs such as >_ usually sit low), and
// lifted 1 px when Elementa Spaces is on the bar so the two read as one row.
// Strokes are 1.4 px (Light) or 1.65 px (Bold), Elementa's weights.
// "Match Elementa" picks the style of Elementa's tradition and its Light/Bold:
// Elemental -> Deco, Alchemical -> Alchemical, Godai -> Zen, Wu Xing -> Seal.
BarWidget {
  id: root
  moduleName: "makehasteslowly.portal"

  readonly property string markSetting: String(setting("mark", "elementa"))
  readonly property string colorSetting: String(setting("color", "theme"))
  readonly property string weightSetting: String(setting("weight", "light"))
  readonly property string sizeSetting: String(setting("size", "follow"))

  // ---- Elementa's settings, read from the shell config (plugins can't see
  // each other's widgets). Elementa saves every change there, right-click
  // switches included, so watching the file keeps Portal in step. A file read
  // mid-write is skipped; the next change event brings the good copy.
  property bool elementaOnBar: false
  property string elementaStyle: "elements"
  property string elementaColorMode: "elemental"
  function readElementa(raw) {
    var d
    try { d = JSON.parse(raw) } catch (e) { return }
    var layout = d && d.bar && d.bar.layout ? d.bar.layout : null
    if (!layout) return
    var found = null
    for (var sec in layout) {
      var list = layout[sec]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) if (list[i] && list[i].id === "makehasteslowly.elementa") found = list[i]
    }
    root.elementaOnBar = found !== null
    var st = found && found.style ? String(found.style) : "elements"
    root.elementaStyle = ["elements", "alchemy", "godai", "wuxing"].indexOf(st) >= 0 ? st : "elements"
    root.elementaColorMode = found && found.colorMode ? String(found.colorMode) : "elemental"
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readElementa(text())
  }

  readonly property string tradition: elementaStyle
  readonly property bool bold: markSetting === "elementa" ? elementaColorMode === "bold" : weightSetting === "bold"
  // Light or dark bar, decided exactly as Elementa decides it
  readonly property color barBg: {
    var bg = (Color.bar && Color.bar.background !== undefined) ? Color.bar.background : Color.background
    if (!bg) return Qt.rgba(0, 0, 0, 1)
    return (bg.a !== undefined && bg.a < 0.25 && Color.background) ? Color.background : bg
  }
  readonly property bool lightBar: 0.2126 * barBg.r + 0.7152 * barBg.g + 0.0722 * barBg.b > 0.48

  readonly property var traditionMarks: ({ elements: "deco", alchemy: "alchemy", godai: "zen", wuxing: "seal" })
  readonly property var drawnMarks: ["classic", "modern", "retro", "deco", "atomic", "nouveau", "alchemy", "zen", "seal", "pixel"]
  readonly property var fontMarks: ({
    omarchy:   { glyph: 0xE900, family: "omarchy" },
    archlinux: { glyph: 0xE732, family: "" },
    hyprland:  { glyph: 0xF359, family: "" },
    linux:     { glyph: 0xF17C, family: "", optical: 1.22, drop: 0.05 }   // Tux: light outline, hairline feet
  })
  // Middle-click steps through the marks in the settings order. The new mark
  // shows at once (pendingMark) and is saved like any setting.
  readonly property var cycleOrder: ["classic", "modern", "retro", "deco", "atomic", "nouveau", "alchemy", "zen", "seal", "pixel",
                                     "omarchy", "archlinux", "hyprland", "linux"]
  property string pendingMark: ""
  onMarkSettingChanged: pendingMark = ""
  function cycleMark() {
    var i = cycleOrder.indexOf(root.mark)
    var next = cycleOrder[(i + 1) % cycleOrder.length]
    root.pendingMark = next
    if (root.bar) root.bar.run("omarchy-bar set makehasteslowly.portal mark " + next)
  }
  readonly property string mark: {
    if (pendingMark !== "") return pendingMark
    if (markSetting === "elementa") return traditionMarks[tradition] || "deco"
    return drawnMarks.indexOf(markSetting) >= 0 || fontMarks[markSetting] !== undefined ? markSetting : "classic"
  }
  readonly property bool drawn: drawnMarks.indexOf(mark) >= 0

  // ---- Color: the bar's own text color, so the button belongs to the bar
  // (the seal keeps its vermilion), or the theme accent.
  readonly property color themeColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color sealColor: lightBar ? "#B22222" : "#C8322A"   // Elementa's Wu Xing seal
  readonly property color tint: colorSetting === "accent" ? Color.accent
    : (mark === "seal" ? sealColor : themeColor)

  // ---- Size and placement. Standard is Elementa's 12 px of ink. "Match next
  // widget" (the default) measures the widget that follows Portal on the bar
  // from a snapshot: its first glyph (the first run of lit columns) and the
  // gap to its second. Portal then takes the glyph's height (the tallest
  // unbroken run of rows in those columns, so a state mark beneath it is left
  // out), sits on the same bottom line, and leaves the same gap before the
  // neighbor that the neighbor leaves between its own glyphs. A reading is
  // thrown away if it looks like a hover highlight or a frame (taller than
  // 80% of the widget) or nothing at all (under 6 px), keeping the last good one.
  property real followInk: 0        // 0 = no reading yet
  property real followBottom: 0     // ink bottom, in Portal's own coordinates
  property real followLeft: 0       // neighbor's first ink column, Portal coordinates
  property real followGap: -1       // gap between the neighbor's first two glyphs (-1 = unknown)
  property var neighbor: null
  readonly property bool following: sizeSetting !== "standard" && followInk > 0
  readonly property real ink: (following ? followInk : 12) * (sizeSetting === "large" ? 1.15 : 1)
  // Strokes are Elementa's 1.4 (Light) / 1.65 (Bold) at 12 px, scaled with the ink
  readonly property real stroke: (bold ? 1.65 : 1.4) * Math.max(0.85, Math.min(1.35, ink / 12))
  readonly property real stageOffset: following
    ? followBottom - (drawn ? ((markBottoms[mark] || 12) - 6) * gridUnit
                            : markInk * (0.5 - ((fontMarks[mark] && fontMarks[mark].drop) || 0))) - root.height / 2
    : (elementaOnBar && !vertical ? -1 : 0)
  // Drawn marks: sideways stretch of the grid (prompt shapes are wider than
  // tall), and the exact left/right extent of each mark's ink, strokes
  // included, in grid units. Font marks report their own ink width.
  readonly property var markStretch: ({ classic: 1.25, alchemy: 1.25, modern: 1.15, atomic: 1.15, nouveau: 1.15, retro: 1.15 })
  readonly property var markExtents: ({ classic: [0.6, 11.6], modern: [1, 11.6], retro: [0, 12], deco: [0, 12], atomic: [0, 11.6],
                                        nouveau: [0.6, 11.8], alchemy: [0, 12], zen: [0, 12], seal: [0, 12], pixel: [-1.5, 13.5] })
  // Where the visible ink ends at the bottom, in grid units, for marks whose
  // lowest point is a fine tip that fades out on screen (others end at 12)
  readonly property var markBottoms: ({ atomic: 10.8 })
  readonly property real gridUnit: ink / 12
  // Ink height actually drawn: font marks may carry an optical boost
  readonly property real markInk: drawn ? ink : ink * ((fontMarks[mark] && fontMarks[mark].optical) || 1)
  readonly property real inkWidth: {
    if (!drawn) return fontGlyph.inkWidth
    var e = markExtents[mark] || [0, 12]
    return (e[1] - e[0]) * gridUnit * (markStretch[mark] || 1)
  }
  // How far the ink's middle sits from the stage's middle (drawn marks only)
  readonly property real inkMidOffset: {
    if (!drawn) return 0
    var e = markExtents[mark] || [0, 12]
    return ((e[0] + e[1]) / 2 - 6) * gridUnit * (markStretch[mark] || 1)
  }
  readonly property real stageShift: {
    if (!following || vertical || followGap <= 0) return 0
    var inkMid = followLeft - followGap - inkWidth / 2
    return Math.max(-10, Math.min(10, inkMid - inkMidOffset - root.width / 2))
  }

  function findNeighbor() {
    if (root.vertical || !root.visible || root.width <= 0) { root.neighbor = null; return }
    var me = root.mapToItem(null, 0, 0), myRight = me.x + root.width
    var level = root, best = null, bestX = 1e9
    for (var depth = 0; depth < 6 && level && level.parent && !best; depth++) {
      var sibs = level.parent.children
      for (var i = 0; i < sibs.length; i++) {
        var c = sibs[i]
        if (c === level || !c.visible || c.width < 4 || c.height < 4) continue
        var p = c.mapToItem(null, 0, 0)
        if (p.x >= myRight - 2 && p.x < bestX && p.y < me.y + root.height && p.y + c.height > me.y) { best = c; bestX = p.x }
      }
      level = level.parent
    }
    root.neighbor = best
  }
  function measureNeighbor() {
    if (root.sizeSetting === "standard") return
    findNeighbor()
    var n = root.neighbor
    if (!n) return
    var h = n.height
    n.grabToImage(function(result) {
      var at = n.mapToItem(root, 0, 0)
      probe.snapTop = at.y
      probe.snapLeft = at.x
      probe.snapH = h
      // Draw the snapshot at a known size (2x) and read back what the canvas
      // really holds; its pixel size is taken from the data, not assumed
      probe.fullW = Math.ceil(n.width * 2)
      probe.imgW = Math.ceil(n.width * 2); probe.imgH = Math.ceil(h * 2)
      probe.snapUrl = result.url
      probe.loadImage(result.url)
    }, Qt.size(Math.ceil(n.width * 2), Math.ceil(h * 2)))
  }
  Timer { id: measureSoon; interval: 400; onTriggered: root.measureNeighbor() }
  Timer { interval: 15000; repeat: true; running: root.sizeSetting !== "standard"; onTriggered: root.measureNeighbor() }
  Component.onCompleted: measureSoon.restart()
  onSizeSettingChanged: measureSoon.restart()
  onWidthChanged: measureSoon.restart()
  Connections {
    target: root.neighbor
    ignoreUnknownSignals: true
    function onWidthChanged() { measureSoon.restart() }
    function onHeightChanged() { measureSoon.restart() }
  }

  // Off-screen reader for the snapshot (a Canvas can read pixels back)
  Canvas {
    id: probe
    property string snapUrl: ""
    property real snapTop: 0
    property real snapLeft: 0
    property real snapH: 0
    property int imgW: 1
    property int imgH: 1
    property int fullW: 1
    width: Math.max(1, imgW)
    height: Math.max(1, imgH)
    opacity: 0
    enabled: false
    renderStrategy: Canvas.Immediate
    onImageLoaded: requestPaint()
    onPaint: {
      if (snapUrl === "" || !isImageLoaded(snapUrl)) return
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.drawImage(snapUrl, 0, 0, fullW, imgH)
      var img = ctx.getImageData(0, 0, imgW, imgH)
      var data = img.data, W = img.width, H = img.height
      var k = H / snapH   // device pixels per logical pixel in what we read
      // An edge is where coverage passes half, as the eye reads it
      function on(x, y) { return data[(y * W + x) * 4 + 3] > 127 }
      // Columns: the first glyph is the first run of lit columns; a gap of 3 px
      // or more ends it (strokes inside one glyph are closer than that)
      var minGap = Math.max(2, Math.round(3 * k)), a0 = -1, a1 = -1, b0 = -1, dark = 0
      for (var x = 0; x < W && b0 < 0; x++) {
        var litCol = false
        for (var yy = 0; yy < H; yy++) { if (on(x, yy)) { litCol = true; break } }
        if (litCol) {
          if (a0 < 0) a0 = x
          else if (a1 >= 0 && dark >= minGap) b0 = x
          if (b0 < 0) { a1 = x; dark = 0 }
        } else if (a0 >= 0) dark++
      }
      if (a0 < 0) { unloadImage(snapUrl); return }
      // Rows, within the first glyph's columns: the tallest unbroken run
      var runStart = -1, bestTop = -1, bestLen = 0
      for (var y = 0; y <= H; y++) {
        var lit = false
        if (y < H) for (var cx = a0; cx <= a1; cx++) { if (on(cx, y)) { lit = true; break } }
        if (lit && runStart < 0) runStart = y
        if (!lit && runStart >= 0) { if (y - runStart > bestLen) { bestLen = y - runStart; bestTop = runStart } runStart = -1 }
      }
      unloadImage(snapUrl)
      var inkPx = bestLen / k
      if (inkPx < 6 || inkPx > snapH * 0.8) return
      root.followInk = Math.round(Math.min(18, inkPx) * 2) / 2
      root.followBottom = snapTop + (bestTop + bestLen) / k
      root.followLeft = snapLeft + a0 / k
      root.followGap = b0 > 0 ? (b0 - a1 - 1) / k : -1
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 6
    verticalPadding: 6
    fixedWidth: root.vertical ? root.barSize : Style.space(22)
    fixedHeight: root.barSize
    tooltipText: ""   // no hover popup: the button speaks for itself
    onPressed: function(which) {
      if (!root.bar) return
      if (which === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else if (which === Qt.MiddleButton) root.cycleMark()
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }

    Item {
      id: stage
      width: Math.max(16, Math.ceil(root.markInk * 1.3 + 4))
      height: Math.max(16, Math.ceil(root.markInk + 4))
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.stageOffset
      anchors.horizontalCenterOffset: root.stageShift
      scale: button.pressScale

      // Drawn marks: the arch, the circumpunct, the seal
      Canvas {
        id: sigil
        anchors.fill: parent
        visible: root.drawn
        antialiasing: true
        property string kind: root.mark
        property color tint: root.tint
        property real lw: root.stroke
        property bool solid: root.bold
        property real inkSize: root.ink
        onInkSizeChanged: requestPaint()
        onKindChanged: requestPaint()
        onTintChanged: requestPaint()
        onLwChanged: requestPaint()
        onSolidChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var c = String(tint)
          // A 12-unit-tall grid centered in the canvas: X(u)/Y(u) map grid units
          // to px. Prompt-shaped marks are wider than tall, as a prompt is, so
          // their grid is stretched sideways (sx); strokes stay round.
          var sx = root.markStretch[kind] || 1
          var u = root.ink / 12, ox = width / 2 - 6 * u * sx, oy = height / 2 - 6 * u
          function X(v) { return ox + v * u * sx }
          function Y(v) { return oy + v * u }
          function line(pts) { ctx.beginPath(); ctx.moveTo(X(pts[0]), Y(pts[1])); for (var i = 2; i < pts.length; i += 2) ctx.lineTo(X(pts[i]), Y(pts[i + 1])); ctx.stroke() }
          function poly(pts) { ctx.beginPath(); ctx.moveTo(X(pts[0]), Y(pts[1])); for (var i = 2; i < pts.length; i += 2) ctx.lineTo(X(pts[i]), Y(pts[i + 1])); ctx.closePath() }
          function rrect(x, y, w, h, r) {
            ctx.beginPath()
            ctx.moveTo(X(x + r), Y(y)); ctx.lineTo(X(x + w - r), Y(y)); ctx.quadraticCurveTo(X(x + w), Y(y), X(x + w), Y(y + r))
            ctx.lineTo(X(x + w), Y(y + h - r)); ctx.quadraticCurveTo(X(x + w), Y(y + h), X(x + w - r), Y(y + h))
            ctx.lineTo(X(x + r), Y(y + h)); ctx.quadraticCurveTo(X(x), Y(y + h), X(x), Y(y + h - r))
            ctx.lineTo(X(x), Y(y + r)); ctx.quadraticCurveTo(X(x), Y(y), X(x + r), Y(y)); ctx.closePath()
          }
          function sparkle(x, y, R, waist) {
            ctx.beginPath()
            for (var i = 0; i < 8; i++) {
              var a = -Math.PI / 2 + i * Math.PI / 4, rr = i % 2 ? R * (waist || 0.26) : R
              var px = X(x) + Math.cos(a) * rr * u, py = Y(y) + Math.sin(a) * rr * u
              if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
            }
            ctx.closePath(); ctx.fill()
          }
          ctx.strokeStyle = c; ctx.fillStyle = c
          ctx.lineWidth = lw; ctx.lineJoin = "round"; ctx.lineCap = "round"
          var h = lw / u / 2   // half a stroke, in grid units: keeps ink inside 0..12

          if (kind === "classic") {
            // >_  the prompt itself
            line([0.6 + h, 1.4, 5.8, 6, 0.6 + h, 10.6])
            line([7.2, 12 - h, 11.6 - h, 12 - h])
          } else if (kind === "modern") {
            // a heavy chevron and a block cursor, as today's shell prompts
            ctx.lineWidth = lw * 1.5
            line([1 + h * 1.5, 0.4 + h * 1.5, 6, 6, 1 + h * 1.5, 11.6 - h * 1.5])
            ctx.fillRect(X(8.2), Y(0.6), 3.4 * u * sx, 10.8 * u)
          } else if (kind === "retro") {
            // a small CRT: rounded screen, a prompt on it, a neck and a foot
            rrect(h, h, 12 - 2 * h, 9 - h, 2.2); ctx.stroke()
            ctx.lineWidth = lw * 0.85
            line([3.2, 3, 5, 4.6, 3.2, 6.2])
            line([6, 6.3, 8.6, 6.3])
            ctx.lineWidth = lw
            line([6, 9, 6, 12 - h]); line([3.6, 12 - h, 8.4, 12 - h])
          } else if (kind === "deco") {
            // Art Deco: a streamline double chevron in a cut-corner frame
            var k = 2.6
            poly([k, h, 12 - k, h, 12 - h, k, 12 - h, 12 - k, 12 - k, 12 - h, k, 12 - h, h, 12 - k, h, k]); ctx.stroke()
            ctx.lineWidth = lw * 0.9
            line([3.2, 3.6, 5.6, 6, 3.2, 8.4])
            line([6.2, 3.6, 8.6, 6, 6.2, 8.4])
          } else if (kind === "atomic") {
            // Googie: a boomerang prompt and a starburst cursor
            ctx.beginPath()
            // blunt tips (a thin point fades out at bar size)
            ctx.moveTo(X(0), Y(0.4))
            ctx.lineTo(X(1.1), Y(0))
            ctx.quadraticCurveTo(X(4.6), Y(2.8), X(7.4), Y(5.6))
            ctx.quadraticCurveTo(X(4.6), Y(8.6), X(1.1), Y(11.6))
            ctx.lineTo(X(0), Y(11.2))
            ctx.quadraticCurveTo(X(2.4), Y(5.8), X(0), Y(0.4))
            ctx.closePath(); ctx.fill()
            sparkle(9.3, 8.6, 3.4, 0.36)
          } else if (kind === "nouveau") {
            // a whiplash prompt that ends in a curl, and a leaf for the cursor
            ctx.lineWidth = lw * 1.2
            ctx.beginPath()
            ctx.moveTo(X(1.2), Y(1))
            ctx.bezierCurveTo(X(3.6), Y(2.2), X(6.2), Y(4.2), X(6.2), Y(6))
            ctx.bezierCurveTo(X(6.2), Y(7.8), X(3.6), Y(9.6), X(2.4), Y(10.2))
            ctx.bezierCurveTo(X(1.2), Y(10.8), X(0.6), Y(9.6), X(1.6), Y(9.1))
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(X(6.8), Y(11.7))
            ctx.quadraticCurveTo(X(8.4), Y(7.4), X(11.8), Y(7.8))
            ctx.quadraticCurveTo(X(10.8), Y(11.9), X(6.8), Y(11.7))
            ctx.closePath(); ctx.fill()
          } else if (kind === "alchemy") {
            // the fire triangle laid on its side as the prompt, then the cursor
            poly([h, 1.2, 7.4 - h, 6, h, 10.8]); ctx.stroke()
            line([8.6, 12 - h, 12 - h, 12 - h])
          } else if (kind === "zen") {
            // an enso, the brush circle left open, around a waiting cursor
            var cx = X(6), cy = Y(6), R = 6 * u
            var a0 = -Math.PI * 0.38, a1 = a0 + Math.PI * 1.82
            ctx.beginPath()
            ctx.arc(cx, cy, R, a0, a1, false)
            ctx.arc(cx, cy, R - lw * 0.9, a1 - 0.08, a0 + 0.22, true)
            ctx.closePath(); ctx.fill()
            ctx.lineWidth = lw
            line([4.4, 7.4, 7.6, 7.4])
          } else if (kind === "seal") {
            // a scholar's seal around 令, "command": outlined (Light) or cut
            // from a solid vermilion chop (Bold)
            rrect(solid ? 0 : h, solid ? 0 : h, solid ? 12 : 12 - 2 * h, solid ? 12 : 12 - 2 * h, 1.6)
            if (solid) ctx.fill(); else ctx.stroke()
            ctx.font = "600 " + Math.round(8.6 * u) + "px \"Noto Serif CJK JP\""
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            if (solid) ctx.globalCompositeOperation = "destination-out"
            ctx.fillText("令", X(6), Y(6.5))
            ctx.globalCompositeOperation = "source-over"
          } else if (kind === "pixel") {
            // 8-bit: the prompt built from whole pixels
            // 15 units wide, square pixels (sx is 1 for Pixel)
            var p = 1.6, x0 = -1.5
            var cells = [[0,0],[1,1],[2,2],[3,3],[2,4],[1,5],[0,6]]
            for (var i = 0; i < cells.length; i++) ctx.fillRect(X(x0 + cells[i][0] * p), Y(0.4 + cells[i][1] * p), p * u, p * u)
            ctx.fillRect(X(x0 + 5 * p), Y(12 - p), 4 * p * u, p * u)
          }
        }
      }

      // Font marks, normalized to the same ink and centered on it
      InkGlyph {
        id: fontGlyph
        anchors.fill: parent
        visible: !root.drawn
        tint: root.tint
        target: root.markInk
        glyph: root.fontMarks[root.mark] ? String.fromCodePoint(root.fontMarks[root.mark].glyph) : ""
        family: root.fontMarks[root.mark] && root.fontMarks[root.mark].family !== ""
          ? root.fontMarks[root.mark].family
          : (root.bar ? root.bar.fontFamily : Style.font.family)
      }
    }
  }

  // A font glyph scaled so its ink is `target` px tall (or 4/3 of that wide, if it
  // is wide), then placed so the ink's center sits on the item's center.
  component InkGlyph: Item {
    id: g
    property string glyph: ""
    property string family: ""
    property int weight: Font.Normal
    property color tint: "white"
    property real target: 12

    TextMetrics { id: ref; text: g.glyph; font.family: g.family; font.weight: g.weight; font.pixelSize: 100 }
    readonly property real fit: ref.tightBoundingRect.height > 0
      ? Math.min(g.target / ref.tightBoundingRect.height, (g.target * 4 / 3) / Math.max(1, ref.tightBoundingRect.width))
      : 0.12
    readonly property real px: Math.max(6, Math.round(100 * fit * 2) / 2)
    TextMetrics { id: tm; text: g.glyph; font.family: g.family; font.weight: g.weight; font.pixelSize: g.px }
    readonly property real inkWidth: tm.tightBoundingRect.width

    Text {
      id: t
      text: g.glyph
      textFormat: Text.PlainText
      color: g.tint
      font.family: g.family
      font.weight: g.weight
      font.pixelSize: g.px
      renderType: Text.CurveRendering
      x: Math.round((g.width / 2 - (tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2)) * 2) / 2
      y: Math.round((g.height / 2 - (t.baselineOffset + tm.tightBoundingRect.y + tm.tightBoundingRect.height / 2)) * 2) / 2
    }
  }
}
