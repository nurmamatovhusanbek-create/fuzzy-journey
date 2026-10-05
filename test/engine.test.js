import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Game, REL } from '../src/engine/index.js';

const world = JSON.parse(fs.readFileSync('public/data/world.json', 'utf8'));
const era = (id) => JSON.parse(fs.readFileSync(`public/data/eras/${id}.json`, 'utf8'));

function run(seed, turns, eraId) {
  const g = new Game(world, eraId ? era(eraId) : null, { seed });
  const t0 = performance.now();
  for (let i = 0; i < turns; i++) g.endTurn();
  return { g, ms: performance.now() - t0 };
}

test('deterministic: same seed => same hash; different seed => different', () => {
  const a = run(7, 30).g.hash(), b = run(7, 30).g.hash(), c = run(8, 30).g.hash();
  assert.equal(a, b); assert.notEqual(a, c);
});

test('AI is active: wars happen, provinces change hands, nobody explodes', () => {
  const { g, ms } = run(3, 60);
  const wars = g.log.filter(l => l.kind === 'war').length;
  const nonNeutral = Array.from(g.owner).filter(Boolean).length;
  console.log(`  60 turns: ${ms.toFixed(0)}ms (${(ms / 60).toFixed(1)}ms/turn), wars=${wars}, peace=${g.log.filter(l => l.kind === 'peace').length}, alive=${g.alive.reduce((s, v) => s + v, 0)}`);
  assert.ok(wars > 5, 'AI should declare wars');
  assert.ok(nonNeutral > 1000);
  for (let n = 1; n <= g.N; n++) assert.ok(Number.isFinite(g.gold[n]));
});

test('era pack loads and runs', () => {
  const { g } = run(5, 20, 'roman');
  assert.equal(g.eraId, 'roman'); assert.ok(g.alive.reduce((s, v) => s + v, 0) > 10);
});

test('commands validate', () => {
  const g = new Game(world, null, { seed: 1 }); const n = 1; g.setHuman(n);
  const p = g.owned(n)[0];
  assert.equal(g.apply({ cmd: 'recruit', n, p }).ok, true);
  assert.equal(g.apply({ cmd: 'recruit', n: 2, p }).ok, false);
});
