// Prints the same checksum as godot TBGame.state_checksum() for (seed, turns, era) — oracle for the GDScript port.
import fs from 'node:fs';
import { Game } from './src/index.js';
const [seed = 7, turns = 30, eraId = ''] = process.argv.slice(2);
const world = JSON.parse(fs.readFileSync('godot/data/world.json', 'utf8'));
const era = eraId ? JSON.parse(fs.readFileSync(`godot/data/eras/${eraId}.json`, 'utf8')) : null;
const g = new Game(world, era, { seed: +seed });
export function checksum(g) {
  let h = 2166136261;
  for (const arr of [g.owner, g.occupier, g.army, g.pop]) for (let i = 0; i < arr.length; i++) h = Math.imul(h ^ (arr[i] & 0xFFFF), 16777619);
  for (let i = 0; i < g.gold.length; i++) h = Math.imul(h ^ (Math.trunc(g.gold[i]) & 0xFFFF), 16777619);
  for (let i = 0; i < g.rel.length; i++) h = Math.imul(h ^ g.rel[i], 16777619);
  h = Math.imul(h ^ g.turn, 16777619);
  return h >>> 0;
}
const out = [];
for (let t = 0; t <= +turns; t++) { if (t > 0) g.endTurn(); if (t === 0 || t % 5 === 0 || t === +turns) out.push(`${t}:${checksum(g)}`); }
console.log(out.join(' '));
