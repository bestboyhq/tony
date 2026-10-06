// `node scripts/icon.ts`: draws the app icon's artwork into build/Tony.icon (Icon Composer), its one source: a capsule
// mic head in the color sweep of Grip's dot, over a grey glass smile on a short stem. Change the numbers below, run it,
// and check the result in Icon Composer or a packaged build. scripts/icon.test.ts fails when the two drift apart.
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'

// The mark on the 1024 pt canvas, centered on it. The smile is centered on the circle that rounds the head's lower end.
const head = { w: 248, h: 398 }
const gap = 56 // between the head and the smile
const line = 66 // the smile and the stem
const stem = 74 // how far the stem shows below the smile
const tip = (15 * Math.PI) / 180 // how far below its center the smile's tips end

// Grip's dot color, logdash's sweep: a conic gradient centered at the shape's left edge, 40% of its height below its
// bottom, baked into thin wedges because SVG has no conic gradient. The stops run across the head (within 1/255 of
// Grip's dot, which samples the ramp from logdash's favicon).
const sweep: [number, string][] = [
  [0, '#1857fa'], [0.029, '#1d58f9'], [0.058, '#305cf0'], [0.144, '#5663d8'], [0.201, '#6a66c7'], [0.301, '#8a67a9'],
  [0.373, '#a06592'], [0.445, '#b5607b'], [0.502, '#c55a66'], [0.588, '#dd4d40'], [0.616, '#e5462e'], [0.631, '#e94222'],
  [0.645, '#ed3e10'], [0.659, '#ef3e00'], [0.688, '#f04600'], [0.845, '#f66800'], [0.96, '#f97e00'], [1, '#fa8500'],
]

type Pt = [number, number]
const n = (v: number) => +v.toFixed(2)
const svg = (body: string) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">${body}</svg>\n`
const rgb = (hex: string) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))

function color(t: number) {
  const i = sweep.findIndex(([u]) => u >= t)
  const [t0, c0] = sweep[i - 1], [t1, c1] = sweep[i]
  return '#' + rgb(c0).map((v, j) => Math.round(v + (rgb(c1)[j] - v) * ((t - t0) / (t1 - t0))).toString(16).padStart(2, '0')).join('')
}

/** The part of convex polygon `poly` on the `side` of the line through `o` along `d` (one Sutherland-Hodgman pass). */
function clip(poly: Pt[], o: Pt, d: Pt, side: 1 | -1): Pt[] {
  const s = (p: Pt) => side * (d[0] * (p[1] - o[1]) - d[1] * (p[0] - o[0]))
  return poly.flatMap((p, i) => {
    const q = poly[(i + 1) % poly.length], sp = s(p), sq = s(q)
    const cut: Pt[] = sp * sq < 0 ? [[p[0] + ((q[0] - p[0]) * sp) / (sp - sq), p[1] + ((q[1] - p[1]) * sp) / (sp - sq)]] : []
    return sp >= 0 ? [p, ...cut] : cut
  })
}

/** Convex `poly` filled with the sweep, as wedges that overlap their neighbors so no seams show. */
function wedges(poly: Pt[], count = 140) {
  const xs = poly.map((p) => p[0]), ys = poly.map((p) => p[1]), bottom = Math.max(...ys)
  const o: Pt = [Math.min(...xs), bottom + 0.4 * (bottom - Math.min(...ys))]
  const angles = poly.map((p) => Math.atan2(p[1] - o[1], p[0] - o[0]))
  const lo = Math.min(...angles), step = (Math.max(...angles) - lo) / count
  let paths = ''
  for (let i = 0; i < count; i++) {
    const a0 = lo + (i - 0.6) * step, a1 = lo + (i + 1.6) * step
    const piece = clip(clip(poly, o, [Math.cos(a0), Math.sin(a0)], 1), o, [Math.cos(a1), Math.sin(a1)], -1)
    if (piece.length > 2) paths += `<path fill="${color((i + 0.5) / count)}" d="M${piece.map((p) => `${n(p[0])} ${n(p[1])}`).join('L')}Z"/>`
  }
  return svg(paths)
}

/** The files of build/Tony.icon this script owns, by path inside the bundle. */
export function artwork(): Record<string, string> {
  const r = head.w / 2, half = line / 2
  const R = r + gap + half, Ro = R + half, Ri = R - half // the smile's centerline, outer and inner radius
  const above = head.h - r, below = Ro + stem // the mark's extent around the smile's center
  const cy = 512 - (below - above) / 2 // the smile's center, so the mark centers on the canvas
  // ponytail: the head's outline is a 722-point polygon (sub-pixel error at 1024 pt); true arcs need a path boolean library.
  const outline: Pt[] = []
  for (let i = 0; i <= 360; i++) outline.push([512 - r * Math.cos((Math.PI * i) / 360), cy + r - head.h + r - r * Math.sin((Math.PI * i) / 360)])
  for (let i = 0; i <= 360; i++) outline.push([512 + r * Math.cos((Math.PI * i) / 360), cy + r * Math.sin((Math.PI * i) / 360)])
  const P = (x: number, y: number) => `${n(512 + x)} ${n(cy + y)}`
  const A = (radius: number, sweepFlag: 0 | 1, x: number, y: number) => `A${n(radius)} ${n(radius)} 0 0 ${sweepFlag} ${P(x, y)}`
  const c = Math.cos(tip), s = Math.sin(tip)
  const meet = Math.sqrt(Ro ** 2 - half ** 2) // where the stem's sides meet the smile
  const end = Ro + stem - half // the stem's round end's center
  const d = `M${P(Ro * c, Ro * s)}${A(Ro, 1, half, meet)}L${P(half, end)}${A(half, 1, -half, end)}L${P(-half, meet)}` +
    `${A(Ro, 1, -Ro * c, Ro * s)}${A(half, 1, -Ri * c, Ri * s)}${A(Ri, 0, Ri * c, Ri * s)}${A(half, 1, Ro * c, Ro * s)}Z`
  const group = (layer: object, translucency: object) => ({ layers: [layer], shadow: { kind: 'neutral', opacity: 0.5 }, translucency })
  const icon = {
    fill: { 'automatic-gradient': 'srgb:0.11000,0.11000,0.12000,1.00000' },
    groups: [
      group({ glass: true, 'image-name': 'head.svg', name: 'head' }, { enabled: false, value: 0.5 }),
      group({ fill: { solid: 'srgb:0.50000,0.50000,0.50000,1.00000' }, glass: true, 'image-name': 'cradle.svg', name: 'cradle' }, { enabled: true, value: 0.4 }),
    ],
    'supported-platforms': { squares: ['macOS'] },
  }
  return {
    'Assets/head.svg': wedges(outline),
    'Assets/cradle.svg': svg(`<path fill="#fff" d="${d}"/>`),
    'icon.json': JSON.stringify(icon, null, 2) + '\n',
  }
}

if (import.meta.main) {
  for (const [file, text] of Object.entries(artwork())) writeFileSync(join(import.meta.dirname, '../build/Tony.icon', file), text)
}
