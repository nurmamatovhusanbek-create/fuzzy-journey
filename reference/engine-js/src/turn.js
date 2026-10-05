// End-of-turn pipeline. Operates on a Game; deterministic.
import { ERAS, REGIMES, REL, TECH_STEP, techNeeded, techGain, B, BUILDINGS, TRUCE_TURNS } from './data.js';

const DEF_CAP = 50;

export function endTurn(g) {
  // 1. queued commands (lockstep): applied in nation order for determinism
  if (g.queue.length) {
    g.queue.sort((a, b) => a.n - b.n || a.seq - b.seq);
    for (const c of g.queue) g.apply(c);
    g.queue.length = 0;
  }
  // 2. AI nations act
  g.runAI();
  // 3. world tick
  tick(g);
  // 4. rebels
  g.rebelTurn();
  // 5. time
  g.turn++; g.monthIdx += 6; if (g.monthIdx >= 12) { g.monthIdx -= 12; g.year++; }
  g.checkVictory();
  return g.takeDirty();
}

function tick(g) {
  const P = g.P, N1 = g.N1;
  // truces/NAP expiry
  if (g.napExpiry) for (const k in g.napExpiry) if (g.napExpiry[k] <= g.turn) { const a = (k / N1) | 0, b = k % N1; if (g.getRel(a, b) === REL.NAP) g.setRel(a, b, REL.PEACE); delete g.napExpiry[k]; }
  // defence accrual (peace only) + construction
  for (let p = 0; p < P; p++) {
    const o = g.owner[p];
    if (o && !g.atWar(o) && g.defense[p] < DEF_CAP) { g.defense[p]++; }
    if (g.bBuilding[p]) {
      if (--g.bTurns[p] <= 0) {
        if (g.building[p] === g.bBuilding[p]) g.bLevel[p]++; else { g.building[p] = g.bBuilding[p]; g.bLevel[p] = 1; }
        g.bBuilding[p] = 0; g.touch(p);
      }
    }
  }
  const rebelsToSpawn = [];
  for (let n = 1; n <= g.N; n++) {
    if (!g.alive[n]) continue;
    const own = g.owned(n);
    if (!own.length) { g.eliminate(n); continue; }
    const inc = g.income(n), reg = REGIMES[g.regime[n]], era = g.era[n];
    g.gold[n] = Math.max(0, g.gold[n] + inc.net);
    g.manpower[n] = Math.min(inc.manCap, g.manpower[n] + inc.manpower);
    g.mp[n] = Math.min(6 + era * 2, g.mp[n] + 1 + era * 0.4);
    g.dp[n] = Math.min(4 + era * 2, g.dp[n] + 1 + era * 0.3);
    const capShock = inc.capLost && !g.capLost[n]; g.capLost[n] = inc.capLost ? 1 : 0;
    // war score / weariness
    let weary = 0, atWar = false;
    for (let o = 1; o < N1; o++) {
      const i = n * N1 + o;
      if (g.rel[i] !== REL.WAR || !g.alive[o]) continue;
      atWar = true; g.warTurns[i]++;
      weary = Math.max(weary, Math.min(40, g.warTurns[i] * 1.5));
      let tot = 0, occ = 0; const th = g.owned(o);
      for (let k = 0; k < th.length; k++) { const v = g.provinceValue(th[k]); tot += v; if (g.occupier[th[k]] === n) occ += v; }
      g.warScore[i] = Math.max(0, Math.min(100, Math.round(occ / (tot || 1) * 100)));
    }
    const stabDelta = atWar ? -0.5 - weary / 100 : 2;
    const bud = n * 4, tax = g.budget[bud], goods = g.budget[bud + 1], resPct = g.budget[bud + 2], invPct = g.budget[bud + 3];
    const happyTarget = Math.max(0, Math.min(100, 50 + (goods - 20) * 0.6 - Math.max(0, tax - 50) * 0.5 - (atWar ? 8 : 0) - weary * 0.15));
    const investChance = invPct / 100 * 0.05;
    g.research[n] += techGain(inc.pop, resPct) + inc.researchBonus;
    let need = techNeeded(g.techLevel[n]);
    while (g.research[n] >= need) { g.research[n] -= need; g.techLevel[n] = Math.min(5, Math.round((g.techLevel[n] + TECH_STEP) * 100) / 100); g.era[n] = Math.min(ERAS.length - 1, Math.floor(g.techLevel[n])); need = techNeeded(g.techLevel[n]); }
    const devCap = Math.min(5, Math.max(1, Math.floor(g.techLevel[n]) + 1));
    for (let i = 0; i < own.length; i++) {
      const p = own[i];
      if (capShock) g.stab[p] = Math.max(5, g.stab[p] - 20);
      if (g.occupier[p]) g.stab[p] = Math.max(5, g.stab[p] - 1);
      g.stab[p] = Math.max(5, Math.min(reg.stabCeil, g.stab[p] + stabDelta));
      const h = g.happy[p], diff = happyTarget - h;
      g.happy[p] = Math.max(0, Math.min(100, h + Math.sign(diff) * Math.min(2, Math.abs(diff))));
      const stabMod = 0.5 + g.stab[p] / 200;
      const farm = g.building[p] === B.farm ? 1 + 0.05 * g.bLevel[p] : 1;
      const growth = Math.floor(g.pop[p] * 0.01 * (g.happy[p] / 100) * stabMod * farm);
      if (growth > 0) g.pop[p] = Math.min(2000, g.pop[p] + growth);
      if (g.econ[p] < 5 && g.rng.next() < investChance) g.econ[p]++;
      if (g.dev[p] < devCap && g.rng.next() < investChance * 0.5) g.dev[p]++;
      if (reg.rebelChance > 0 && !g.capital[p] && g.stab[p] < 30 && g.rng.next() < reg.rebelChance) rebelsToSpawn.push(p);
    }
    // bankruptcy: desertion
    if (g.gold[n] <= 0 && inc.net < 0) for (let i = 0; i < own.length; i++) g.army[own[i]] = Math.max(1, Math.floor(g.army[own[i]] * 0.95));
  }
  for (const p of rebelsToSpawn) g.spawnRebel(p);
  // vassals
  for (let n = 1; n <= g.N; n++) {
    const ov = g.overlord[n]; if (!g.alive[n] || !ov) continue;
    if (!g.alive[ov]) { g.overlord[n] = 0; continue; }
    const t = g.tribute[n];
    if (t > 0) { const amt = Math.floor(Math.max(0, g.income(n).gold) * t / 100); g.gold[n] = Math.max(0, g.gold[n] - amt); g.gold[ov] += amt; }
    g.liberty[n] = Math.max(0, Math.min(100, g.liberty[n] + t * 0.04 - 0.5));
    if (g.liberty[n] >= 100) { g.overlord[n] = 0; g.tribute[n] = 0; g.liberty[n] = 0; g.setRel(n, ov, REL.WAR); g.log.push({ turn: g.turn, kind: 'independence', a: n, b: ov }); }
  }
  // grudges cool
  if (g.turn % 4 === 0) for (let i = 0; i < g.grudge.length; i++) if (g.grudge[i]) g.grudge[i]--;
}

export function spawnRebel(g, p) {
  const former = g.owner[p]; if (!former) return;
  g.cede(p, g.rebel); g.alive[g.rebel] = 1; g.army[p] = Math.max(g.army[p], 8); g.stab[p] = 55; g.happy[p] = 50;
  g.setRel(g.rebel, former, REL.WAR); g.lastWarTurn[g.rebel] = g.turn;
  g.gold[g.rebel] = 40; g.manpower[g.rebel] = 60;
  if (!g.capitalOf[g.rebel] || g.capitalOf[g.rebel] < 0) g.reassignCapital(g.rebel);
  g.log.push({ turn: g.turn, kind: 'rebels', a: former, p });
}

export function rebelTurn(g) {
  const r = g.rebel; if (!g.alive[r]) return;
  const own = Array.from(g.owned(r));
  if (!own.length) { g.alive[r] = 0; return; }
  for (const p of own) {
    if (g.army[p] < 4 || !g.rng.chance(0.35)) continue;
    let tgt = -1, weakest = 1e9;
    for (let i = g.nbOff[p]; i < g.nbOff[p + 1]; i++) {
      const q = g.nb[i]; if (g.owner[q] === r || g.owner[q] === 0) continue;
      if (g.nbSea[i] && g.building[p] !== B.port) continue;
      if (g.army[q] < weakest) { weakest = g.army[q]; tgt = q; }
    }
    if (tgt < 0) continue;
    const former = g.owner[tgt]; if (g.getRel(r, former) !== REL.WAR) g.setRel(r, former, REL.WAR);
    g.resolveCombat(r, p, tgt, Math.floor(g.army[p] * 0.7));
  }
}

export function checkVictory(g) {
  if (g.over) return;
  const h = g.humanId; if (!h) return;
  if (!g.alive[h]) { g.over = true; g.winner = 0; g.log.push({ turn: g.turn, kind: 'defeat', a: h }); return; }
  let total = 0; for (let p = 0; p < g.P; p++) if (g.owner[p]) total++;
  const mine = g.ownCount(h);
  // domination: hold 60% of owned land
  if (mine / (total || 1) >= 0.6) { g.over = true; g.winner = h; g.log.push({ turn: g.turn, kind: 'victory', a: h }); }
}
