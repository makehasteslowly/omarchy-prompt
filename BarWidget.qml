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
    return (bg.a !== undefined && bg.a < 0.25) ? Color.background : bg
  }
  readonly property bool lightBar: 0.2126 * barBg.r + 0.7152 * barBg.g + 0.0722 * barBg.b > 0.48

  readonly property var traditionMarks: ({ elements: "deco", alchemy: "alchemy", godai: "zen", wuxing: "seal" })
  readonly property var drawnMarks: ["classic", "modern", "retro", "deco", "atomic", "nouveau", "alchemy", "zen", "seal", "pixel"]
  readonly property var fontMarks: ({
    omarchy:   { glyph: 0xE900, family: "omarchy" },
    archlinux: { glyph: 0xE732, family: "" },
    hyprland:  { glyph: 0xF359, family: "" },
    linux:     { glyph: 0xF17C, family: "" }
  })
  readonly property string mark: {
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

  // Elementa's sizes: 12 px of ink, strokes 1.4 (Light) / 1.65 (Bold)
  readonly property real ink: 12
  readonly property real stroke: bold ? 1.65 : 1.4

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
    tooltipText: "Menu  ·  right-click for a terminal"
    onPressed: function(which) {
      if (!root.bar) return
      if (which === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }

    Item {
      id: stage
      width: 16
      height: 16
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.elementaOnBar && !root.vertical ? -1 : 0
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
        onKindChanged: requestPaint()
        onTintChanged: requestPaint()
        onLwChanged: requestPaint()
        onSolidChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var c = String(tint)
          // A 12 x 12 grid centered in the canvas: X(u)/Y(u) map grid units to px
          var u = root.ink / 12, ox = width / 2 - 6 * u, oy = height / 2 - 6 * u
          function X(v) { return ox + v * u }
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
          function sparkle(x, y, R) {
            ctx.beginPath()
            for (var i = 0; i < 8; i++) {
              var a = -Math.PI / 2 + i * Math.PI / 4, rr = i % 2 ? R * 0.26 : R
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
            line([1 + h * 1.5, 1.6, 6, 6, 1 + h * 1.5, 10.4])
            ctx.fillRect(X(8.2), Y(1.8), 3.4 * u, 8.4 * u)
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
            ctx.moveTo(X(0.4), Y(0.8))
            ctx.quadraticCurveTo(X(4.2), Y(3.2), X(7.2), Y(5.6))
            ctx.quadraticCurveTo(X(4.2), Y(8.4), X(0.4), Y(11.2))
            ctx.quadraticCurveTo(X(2.6), Y(6), X(0.4), Y(0.8))
            ctx.closePath(); ctx.fill()
            sparkle(9.3, 8.7, 3.3)
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
            var cx = X(6), cy = Y(6), R = (6 - h) * u
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
            var p = 1.5
            var cells = [[0,0],[1,1],[2,2],[3,3],[2,4],[1,5],[0,6]]
            for (var i = 0; i < cells.length; i++) ctx.fillRect(X(cells[i][0] * p), Y(0.75 + cells[i][1] * p), p * u, p * u)
            ctx.fillRect(X(6.75), Y(12 - p), 5.25 * u, p * u)
          }
        }
      }

      // Font marks, normalized to the same ink and centered on it
      InkGlyph {
        anchors.fill: parent
        visible: !root.drawn
        tint: root.tint
        target: root.ink
        glyph: root.fontMarks[root.mark] ? String.fromCodePoint(root.fontMarks[root.mark].glyph) : ""
        family: root.fontMarks[root.mark] && root.fontMarks[root.mark].family !== ""
          ? root.fontMarks[root.mark].family
          : (root.bar ? root.bar.fontFamily : Style.font.family)
      }
    }
  }

  // A font glyph scaled so its ink is `target` px tall (or 16 px wide, if it
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
      ? Math.min(g.target / ref.tightBoundingRect.height, 16 / Math.max(1, ref.tightBoundingRect.width))
      : 0.12
    readonly property real px: Math.max(6, Math.round(100 * fit * 2) / 2)
    TextMetrics { id: tm; text: g.glyph; font.family: g.family; font.weight: g.weight; font.pixelSize: g.px }

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
