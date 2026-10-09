// Builds src/map_data.js: Napoleonic countries (+ French departments) projected with Mercator into a 1920x1080 frame.
import fs from 'fs'; import * as t from 'topojson-client';
const W = 1920, H = 1080;
const lon0 = -24, lon1 = 49, latc = 46.5;
const rad = d => d * Math.PI / 180;
const k = W / (rad(lon1) - rad(lon0));
const merc = lat => Math.log(Math.tan(Math.PI / 4 + rad(lat) / 2));
const X = lon => (rad(lon) - rad(lon0)) * k;
const Y = lat => H / 2 - (merc(lat) - merc(latc)) * k;
const invY = y => 2 * (Math.atan(Math.exp((H / 2 - y) / k + merc(latc))) - Math.PI / 4) * 180 / Math.PI;
const n = JSON.parse(fs.readFileSync('maps/napoleonic.topojson'));
const geoms = n.objects.countries.geometries;
const feats = t.feature(n, n.objects.countries).features;
const nb = t.neighbors(geoms);
// greedy colouring, largest first
const order = feats.map((f, i) => i);
const ringArea = r => { let a = 0; for (let i = 0, j = r.length - 1; i < r.length; j = i++) a += (r[j][0] + r[i][0]) * (r[j][1] - r[i][1]); return Math.abs(a / 2); };
const polys = f => f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
const pathOf = f => polys(f).map(p => p.map(r => 'M' + r.map(c => X(c[0]).toFixed(1) + ' ' + Y(c[1]).toFixed(1)).join('L') + 'Z').join('')).join('');
const info = feats.map(f => {
  let best = null, ba = 0;
  for (const p of polys(f)) { const a = ringArea(p[0]); if (a > ba) { ba = a; best = p[0]; } }
  let minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9;
  for (const [lo, la] of best) { minx = Math.min(minx, lo); maxx = Math.max(maxx, lo); miny = Math.min(miny, la); maxy = Math.max(maxy, la); }
  const bx0 = X(minx), bx1 = X(maxx), by0 = Y(maxy), by1 = Y(miny);
  const vx0 = Math.max(bx0, 0), vx1 = Math.min(bx1, W), vy0 = Math.max(by0, 0), vy1 = Math.min(by1, H);
  return { cx: (vx0 + vx1) / 2, cy: (vy0 + vy1) / 2, w: vx1 - vx0, h: vy1 - vy0, area: ba, ov: vx1 > vx0 + 8 && vy1 > vy0 + 8 };
});
const vis = feats.map((f, i) => info[i].ov ? i : -1).filter(i => i >= 0);
const col = {};
for (const i of vis.slice().sort((a, b) => info[b].area - info[a].area)) {
  const used = new Set(nb[i].map(j => col[j]).filter(c => c !== undefined));
  let c = 0; while (used.has(c)) c++; col[i] = c % 7;
}
const countries = vis.map(i => ({ id: feats[i].id, name: feats[i].properties.name, d: pathOf(feats[i]), c: col[i], cx: +info[i].cx.toFixed(1), cy: +info[i].cy.toFixed(1), w: +info[i].w.toFixed(0), h: +info[i].h.toFixed(0) }));
// French departments
const p = JSON.parse(fs.readFileSync('maps/provinces.topojson'));
const pg = p.objects.countries.geometries.filter(g => g.properties.nation === 'FRA');
const pcoll = { type: 'GeometryCollection', geometries: pg };
const pf = t.feature(p, pcoll).features;
const fr = pf.filter(f => f.properties.lon > -6 && f.properties.lon < 10 && f.properties.lat > 41).map(f => ({ name: f.properties.name, d: pathOf(f), cx: +X(f.properties.lon).toFixed(1), cy: +Y(f.properties.lat).toFixed(1) }));
const out = { W, H, lon0, lon1, latc, k, countries, france: fr };
const js = 'const MAP=' + JSON.stringify(out) + ';\n' +
  `MAP.x=lon=>(lon-(${lon0}))*Math.PI/180*${k};MAP.y=lat=>${H / 2}-(Math.log(Math.tan(Math.PI/4+lat*Math.PI/360))-${merc(latc)})*${k};\n`;
fs.writeFileSync('docs/ui_variants/src/map_data.js', js);
console.log('countries', countries.length, 'FR depts', fr.length, (js.length / 1024).toFixed(0) + 'KB', 'lat range', invY(H).toFixed(1), invY(0).toFixed(1));
console.log(fr.map(d => d.name).slice(0, 12).join(','));
console.log(countries.filter(c => ['france', 'spain', 'great_britain', 'prussia', 'austria', 'ottoman_empire', 'russian_empire'].includes(c.id)).map(c => c.id + ':' + c.cx + ',' + c.cy + ' c' + c.c).join(' | '));
