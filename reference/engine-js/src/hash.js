// FNV-1a over the simulation-critical arrays. Used by lockstep multiplayer and tests.
export function stateHash(g) {
  let h = 2166136261 >>> 0;
  const mix = (arr) => { const u = new Uint8Array(arr.buffer, arr.byteOffset, arr.byteLength); for (let i = 0; i < u.length; i++) { h ^= u[i]; h = Math.imul(h, 16777619) >>> 0; } };
  mix(g.owner); mix(g.occupier); mix(g.army); mix(g.pop); mix(g.stab); mix(g.dev);
  mix(g.rel); mix(g.gold); mix(g.manpower); mix(g.techLevel);
  h ^= g.turn; h = Math.imul(h, 16777619) >>> 0; h ^= g.rng.s; h = Math.imul(h, 16777619) >>> 0;
  return h >>> 0;
}
