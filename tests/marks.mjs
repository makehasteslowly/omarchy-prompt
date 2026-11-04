// Static consistency checks for Portal's marks. Run: node tests/marks.mjs
//
// Every mark offered in settings must be drawable, placeable and reachable:
//   - drawn marks have a paint branch, ink extents, and (if wide) a stretch
//   - font marks have a codepoint
//   - every mark except "elementa" is in the middle-click cycle, in the
//     settings order, exactly once
//   - Match Elementa maps every tradition to a real drawn mark
//   - defaults and enum values agree; the README lists every drawn style
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const qml = readFileSync(join(root, "BarWidget.qml"), "utf8")
const manifest = JSON.parse(readFileSync(join(root, "manifest.json"), "utf8"))
const readme = readFileSync(join(root, "README.md"), "utf8")

let checks = 0, failures = 0
function ok(cond, what) { checks++; if (!cond) { failures++; console.log("FAIL  " + what) } }

// Pull a JS literal assigned to a readonly property out of the QML
function literal(name) {
  const m = qml.match(new RegExp("readonly property var " + name + ":\\s*(\\(\\{[\\s\\S]*?\\}\\)|\\[[\\s\\S]*?\\])"))
  if (!m) throw new Error("property not found: " + name)
  return Function('"use strict"; return ' + m[1].replace(/^\(|\)$/g, ""))()
}
const drawn = literal("drawnMarks")
const cycle = literal("cycleOrder")
const stretch = literal("markStretch")
const extents = literal("markExtents")
const fontMarks = Function('"use strict"; return ' + qml.match(/readonly property var fontMarks:\s*\(([\s\S]*?\})\)/)[1]
  .replace(/\/\/[^\n]*/g, ""))()
const traditions = literal("traditionMarks")

const schema = manifest.barWidget.schema
const byKey = Object.fromEntries(schema.map(s => [s.key, s]))
const markOptions = byKey.mark.options.map(o => o.value)

// Settings ↔ implementation
for (const v of markOptions) {
  if (v === "elementa") continue
  ok(drawn.includes(v) || fontMarks[v] !== undefined, `mark "${v}" is offered but neither drawn nor a font mark`)
}
for (const d of drawn) {
  ok(markOptions.includes(d), `drawn mark "${d}" is not offered in settings`)
  ok(qml.includes(`kind === "${d}"`), `drawn mark "${d}" has no paint branch`)
  const ext = extents[d]
  const valid = Array.isArray(ext) && ext.length === 2 && ext[0] < ext[1]
  ok(valid, `drawn mark "${d}" has no valid ink extents`)
  if (valid) {
    const w = (ext[1] - ext[0]) * (stretch[d] || 1)
    ok(w > 4 && w <= 16, `drawn mark "${d}" is ${w.toFixed(1)} units wide (expected 4–16)`)
  }
}
for (const f of Object.keys(fontMarks)) {
  ok(markOptions.includes(f), `font mark "${f}" is not offered in settings`)
  ok(Number.isInteger(fontMarks[f].glyph) && fontMarks[f].glyph > 0, `font mark "${f}" has no codepoint`)
}
for (const k of Object.keys(stretch)) ok(drawn.includes(k), `stretch given for unknown mark "${k}"`)
for (const k of Object.keys(extents)) ok(drawn.includes(k), `extents given for unknown mark "${k}"`)

// Middle-click cycle: every mark but "elementa", once each, in settings order
const expectedCycle = markOptions.filter(v => v !== "elementa")
ok(JSON.stringify(cycle) === JSON.stringify(expectedCycle),
  `cycle order differs from settings order:\n      cycle    ${cycle.join(" ")}\n      settings ${expectedCycle.join(" ")}`)
ok(new Set(cycle).size === cycle.length, "cycle has duplicates")

// Match Elementa
for (const t of ["elements", "alchemy", "godai", "wuxing"]) ok(drawn.includes(traditions[t]), `tradition "${t}" maps to "${traditions[t]}", not a drawn mark`)

// Defaults and enums
for (const s of schema) {
  const d = manifest.barWidget.defaults[s.key]
  ok(d !== undefined, `no default for "${s.key}"`)
  ok(s.defaultValue === d, `"${s.key}" defaultValue ${s.defaultValue} ≠ defaults ${d}`)
  if (s.type === "enum") {
    ok(s.options.some(o => o.value === d), `"${s.key}" default "${d}" is not one of its options`)
    ok(new Set(s.options.map(o => o.value)).size === s.options.length, `"${s.key}" has duplicate options`)
  }
  ok(qml.includes(`setting("${s.key}"`), `setting "${s.key}" is never read in the QML`)
}

// README lists every drawn style by its settings name
const names = Object.fromEntries(byKey.mark.options.map(o => [o.value, o.label.split("  ·  ")[0].trim()]))
for (const d of drawn) ok(readme.includes(`**${names[d]}**`), `README does not list "${names[d]}"`)
ok(manifest.barWidget.description.includes(["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"][drawn.length] + " styles"),
  `manifest description does not say ${drawn.length} styles`)

// No test hooks left behind
ok(!qml.includes("TMP-TEST"), "a TMP-TEST hook is still in BarWidget.qml")

console.log(`Marks: ${drawn.length} drawn, ${Object.keys(fontMarks).length} font; ${checks - failures}/${checks} checks pass`)
process.exit(failures ? 1 : 0)
