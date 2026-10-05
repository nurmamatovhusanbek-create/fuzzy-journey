// Seeded deterministic RNG (mulberry32). The ONLY source of randomness in the engine,
// so identical seed + commands => identical state (lockstep multiplayer, replays, tests).
export class Rng {
  constructor(seed) { this.s = (seed >>> 0) || 1; }
  next() {
    let t = (this.s = (this.s + 0x6D2B79F5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  int(n) { return (this.next() * n) | 0; }
  range(a, b) { return a + this.int(b - a + 1); }
  chance(p) { return this.next() < p; }
}
export function hashStr(s) { let h = 2166136261 >>> 0; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h >>> 0; }
