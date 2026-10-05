// Build-time data bake: legacy topojson/era JSON -> compact binary + JSON for the runtime.
// Output (public/data): world.json, ids.bin.gz (Uint16 equirect province-id raster), eras/<id>.json
import fs from 'node:fs';
import zlib from 'node:zlib';
import * as topojson from 'topojson-client';
import { Game } from '../reference/engine-js/src/index.js';

const W = 4096, H = 2048;
const OUT = 'godot/data';
fs.mkdirSync(OUT + '/eras', { recursive: true });

const topo = JSON.parse(fs.readFileSync('maps/provinces.topojson', 'utf8'));
const feats = topojson.feature(topo, topo.objects.countries).features.filter(f => f.id && f.geometry);
const P = feats.length;
const idIndex = new Map(feats.map((f, i) => [String(f.id), i]));

const ids = new Uint16Array(W * H); // 0 = ocean, else provinceIndex+1
const area = new Uint32Array(P);

function polysOf(g) { return g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : []; }

function fillPolygon(rings, val) {
  // even-odd scanline over all rings of one polygon
  const edges = [];
  let minY = Infinity, maxY = -Infinity;
  for (const ring of rings) {
    for (let i = 0, n = ring.length; i < n - 1; i++) {
      let x0 = (ring[i][0] + 180) / 360 * W, y0 = (90 - ring[i][1]) / 180 * H;
      let x1 = (ring[i + 1][0] + 180) / 360 * W, y1 = (90 - ring[i + 1][1]) / 180 * H;
      if (y0 === y1) continue;
      if (y0 > y1) { [x0, x1] = [x1, x0]; [y0, y1] = [y1, y0]; }
      edges.push(x0, y0, x1, y1);
      if (y0 < minY) minY = y0; if (y1 > maxY) maxY = y1;
    }
  }
  if (!edges.length) return 0;
  let count = 0;
  const y0i = Math.max(0, Math.floor(minY)), y1i = Math.min(H - 1, Math.ceil(maxY));
  const xs = [];
  for (let y = y0i; y <= y1i; y++) {
    const yc = y + 0.5; xs.length = 0;
    for (let e = 0; e < edges.length; e += 4) {
      const ya = edges[e + 1], yb = edges[e + 3];
      if (yc < ya || yc >= yb) continue;
      xs.push(edges[e] + (yc - ya) / (yb - ya) * (edges[e + 2] - edges[e]));
    }
    xs.sort((a, b) => a - b);
    for (let k = 0; k + 1 < xs.length; k += 2) {
      const xa = Math.max(0, Math.round(xs[k])), xb = Math.min(W, Math.round(xs[k + 1]));
      for (let x = xa; x < xb; x++) { ids[y * W + x] = val; count++; }
    }
  }
  return count;
}

let dropped = 0;
// larger provinces first so small enclaves/islands paint on top
const order = feats.map((f, i) => i);
const bboxArea = feats.map(f => { let a = 0; for (const poly of polysOf(f.geometry)) { const o = poly[0]; let mn = 1e9, mx = -1e9, my = 1e9, My = -1e9; for (const p of o) { mn = Math.min(mn, p[0]); mx = Math.max(mx, p[0]); my = Math.min(my, p[1]); My = Math.max(My, p[1]); } a += (mx - mn) * (My - my); } return a; });
order.sort((a, b) => bboxArea[b] - bboxArea[a]);
for (const i of order) {
  for (const poly of polysOf(feats[i].geometry)) {
    const o = poly[0]; if (!o || o.length < 4) continue;
    let mn = 181, mx = -181; for (const p of o) { if (p[0] < mn) mn = p[0]; if (p[0] > mx) mx = p[0]; }
    if (mx - mn > 180) { dropped++; continue; } // antimeridian/pole-straddling ring (same rule as legacy)
    fillPolygon(poly, i + 1);
  }
}
// stamp centroid for provinces that vanished at this resolution
let stamped = 0;
for (let i = 0; i < P; i++) {
  const p = feats[i].properties;
  if (p.lon == null || p.lat == null) continue;
  const x = Math.min(W - 1, Math.max(0, Math.floor((p.lon + 180) / 360 * W)));
  const y = Math.min(H - 1, Math.max(0, Math.floor((90 - p.lat) / 180 * H)));
  let has = false;
  // cheap check: any pixel of this id in a 3x3 around centroid, else scan later
  if (ids[y * W + x] === i + 1) has = true;
  feats[i]._stamp = has ? null : [x, y];
}
for (let k = 0; k < ids.length; k++) if (ids[k]) area[ids[k] - 1]++;
for (let i = 0; i < P; i++) if (area[i] === 0 && feats[i]._stamp) { const [x, y] = feats[i]._stamp; if (!ids[y * W + x]) { ids[y * W + x] = i + 1; area[i] = 1; stamped++; } }

// raster adjacency (4-neighbour, wraps horizontally)
const adj = Array.from({ length: P }, () => new Set());
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const a = ids[y * W + x]; if (!a) continue;
  const b = ids[y * W + (x + 1) % W]; if (b && b !== a) { adj[a - 1].add(b - 1); adj[b - 1].add(a - 1); }
  if (y + 1 < H) { const c = ids[(y + 1) * W + x]; if (c && c !== a) { adj[a - 1].add(c - 1); adj[c - 1].add(a - 1); } }
}
// union with authoritative precomputed neighbours (incl. land borders hidden by raster resolution)
for (let i = 0; i < P; i++) for (const nbId of (feats[i].properties.nb || [])) {
  const j = idIndex.get(String(nbId)); if (j != null && j !== i) { adj[i].add(j); adj[j].add(i); }
}
const nbOff = new Uint32Array(P + 1); const nbList = [];
for (let i = 0; i < P; i++) { const a = [...adj[i]].sort((x, y) => x - y); nbOff[i + 1] = nbOff[i] + a.length; nbList.push(...a); }

// nations (modern baseline)
const natCode = [], natName = [], natIdx = new Map();
const provNat = new Uint16Array(P);
for (let i = 0; i < P; i++) {
  const p = feats[i].properties; const c = p.nation || '';
  if (!natIdx.has(c)) { natIdx.set(c, natCode.length); natCode.push(c); natName.push(p.nationName || c); }
  provNat[i] = natIdx.get(c);
}
const world = {
  W, H, P,
  id: feats.map(f => String(f.id)),
  name: feats.map(f => f.properties.name || '?'),
  lat: feats.map(f => f.properties.lat ?? 0), lon: feats.map(f => f.properties.lon ?? 0),
  area: Array.from(area),
  nbOff: Array.from(nbOff), nb: nbList,
  natCode, natName, provNat: Array.from(provNat),
};
// precompute adjacency incl. sea links (the engine's add_sea_links is O(P*cells) — 260 ms on desktop, >1 s on phones)
{ const g0 = new Game(world, null, { seed: 1 }); world.nbOffX = Array.from(g0.nbOff); world.nbX = Array.from(g0.nb); world.nbSeaX = Array.from(g0.nbSea); }
fs.writeFileSync(OUT + '/world.json', JSON.stringify(world));
fs.writeFileSync(OUT + '/ids.bin.gz', zlib.gzipSync(Buffer.from(ids.buffer), { level: 9 }));

// era packs: ownership by province index, nations list
const eraFiles = fs.readdirSync('maps').filter(f => /^era_.*\.json$/.test(f));
for (const f of eraFiles) {
  const e = JSON.parse(fs.readFileSync('maps/' + f, 'utf8'));
  const nIds = Object.keys(e.nations || {});
  const nIdx = new Map(nIds.map((n, i) => [n, i + 1])); // 0 = neutral
  const owner = new Array(P).fill(0);
  for (const pid in e.prov) { const i = idIndex.get(pid); if (i == null) continue; owner[i] = nIdx.get(e.prov[pid]) || 0; }
  const disc = (e.discoverable || []).map(p => idIndex.get(p)).filter(v => v != null);
  fs.writeFileSync(`${OUT}/eras/${e.id}.json`, JSON.stringify({
    id: e.id, year: e.year,
    nations: nIds.map(n => ({ id: n, name: e.nations[n].name })),
    owner, discoverable: disc, colonize: e.colonize || null,
  }));
}
const sz = f => (fs.statSync(f).size / 1024).toFixed(0) + ' KB';
console.log(`provinces=${P} nations=${natCode.length} droppedRings=${dropped} stamped=${stamped} zeroArea=${[...area].filter(a => !a).length}`);
console.log('world.json', sz(OUT + '/world.json'), '| ids.bin.gz', sz(OUT + '/ids.bin.gz'), '| eras', eraFiles.length);
