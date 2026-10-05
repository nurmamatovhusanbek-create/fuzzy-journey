// Generic save/restore of a Game: typed arrays + scalars + plain objects. Static world is not saved.
const SKIP = new Set(['world', 'rng', 'dirtyFlag', 'dirtyList', 'queue', 'nbOff', 'nb', 'nbSea', 'ownStart', 'ownList', 'ownDirty', 'diff', 'humanId']);
export const SAVE_VERSION = 1;

export function serialize(g) {
  const out = { v: SAVE_VERSION, rngS: g.rng.s, humanId: g.humanId || 0, f: {} };
  for (const k of Object.keys(g)) {
    if (SKIP.has(k)) continue; const v = g[k];
    if (ArrayBuffer.isView(v)) out.f[k] = { ta: v.constructor.name, data: v.slice() };
    else if (typeof v === 'function') continue; else out.f[k] = { val: JSON.parse(JSON.stringify(v)) };
  }
  return out;
}
const CTORS = { Uint8Array, Uint16Array, Uint32Array, Int16Array, Int32Array, Float32Array, Float64Array };
export function restore(g, s) {
  if (s.v !== SAVE_VERSION) throw new Error('save version');
  for (const k in s.f) { const e = s.f[k]; if (e.ta) g[k] = new CTORS[e.ta](e.data); else g[k] = e.val; }
  g.rng.s = s.rngS; g.humanId = s.humanId; g.ownDirty = true; g.dirtyList = []; g.dirtyFlag.fill(0); g.queue = [];
  g.diff = g.diff || {};
  return g;
}
