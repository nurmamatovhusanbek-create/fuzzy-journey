// node docs/ui_variants/src/make_globe.mjs : world outlines for the demo's mini-globe -> src/globe_data.js (const GLOBE=[{id,c,r:[[lon,lat,...],...]}]).
// Colours: the main map's own colour index where the country is on it, otherwise a greedy colouring over neighbours (so the globe agrees with the map).
import fs from 'fs'; import * as t from 'topojson-client';
const here = new URL('.', import.meta.url).pathname;
const MAP = new Function(fs.readFileSync(here + 'map_data.js', 'utf8') + ';return MAP')();
const n = JSON.parse(fs.readFileSync('maps/napoleonic.topojson'));
const geoms = n.objects.countries.geometries; const feats = t.feature(n, n.objects.countries).features; const nb = t.neighbors(geoms);
const known = new Map(MAP.countries.map(c => [c.id, c.c]));
const col = {};
feats.forEach((f, i) => { if (known.has(f.id)) col[i] = known.get(f.id); });
for (let i = 0; i < feats.length; i++) { if (col[i] !== undefined) continue; const used = new Set(nb[i].map(j => col[j]).filter(c => c !== undefined)); let c = 0; while (used.has(c)) c++; col[i] = c % 7; }
const dp = (pts, tol) => { // Douglas-Peucker on a closed ring (lon/lat degrees)
  const keep = new Uint8Array(pts.length); keep[0] = keep[pts.length - 1] = 1;
  let far = 0, fd = -1; for (let i = 1; i < pts.length - 1; i++) { const d = Math.hypot(pts[i][0] - pts[0][0], pts[i][1] - pts[0][1]); if (d > fd) { fd = d; far = i; } }   // a closed ring: split at the point farthest from the start
  keep[far] = 1;
  const st = [[0, far], [far, pts.length - 1]];
  while (st.length) { const [a, b] = st.pop(); let md = 0, mi = -1; const [x1, y1] = pts[a], [x2, y2] = pts[b]; const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy) || 1e-9;
    for (let i = a + 1; i < b; i++) { const d = Math.abs(dy * pts[i][0] - dx * pts[i][1] + x2 * y1 - y2 * x1) / L; if (d > md) { md = d; mi = i; } }
    if (md > tol && mi > 0) { keep[mi] = 1; st.push([a, mi], [mi, b]); } }
  return pts.filter((_, i) => keep[i]); };
const area = r => { let a = 0; for (let i = 0, j = r.length - 1; i < r.length; j = i++) a += (r[j][0] + r[i][0]) * (r[j][1] - r[i][1]); return Math.abs(a / 2); };
const out = []; let np = 0; console.log("feats", feats.length);
feats.forEach((f, i) => {
  const polys = f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates; const rings = [];
  for (const p of polys) { if (area(p[0]) < 0.12) continue; const s = dp(p[0], 0.45); if (s.length < 4) continue; np += s.length; rings.push(s.flatMap(c => [+c[0].toFixed(1), +c[1].toFixed(1)])); }
  if (rings.length) out.push({ id: f.id, c: col[i], r: rings });
});
fs.writeFileSync(here + 'globe_data.js', 'const GLOBE=' + JSON.stringify(out) + ';\n');
console.log('countries', out.length, 'points', np, (fs.statSync(here + 'globe_data.js').size / 1024).toFixed(0) + 'KB');
