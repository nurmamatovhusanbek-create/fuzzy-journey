// Budgeted AI for province mode (legacy v2 had none). Each nation scans only its
// own provinces + frontier; integer-ish scoring; all randomness via g.rng.
import { REL, PERSONALITIES, COST, B, BUILDINGS, REGIMES, TRUCE_TURNS } from './data.js';

export function runAI(g) {
  const N = g.N;
  // fixed order, but start index rotates with turn so no nation is permanently first
  const start = g.turn % N;
  for (let k = 0; k < N; k++) {
    const n = ((start + k) % N) + 1;
    if (n === g.rebel || !g.alive[n] || g.human[n]) continue;
    aiNation(g, n);
  }
}

function frontier(g, n) {
  // provinces I control that touch a hostile/foreign province; returns {mine, at, to} lists
  const out = [];
  const own = g.owned(n);
  for (let i = 0; i < own.length; i++) {
    const p = own[i]; if (g.controller(p) !== n) continue;
    for (let e = g.nbOff[p]; e < g.nbOff[p + 1]; e++) {
      const q = g.nb[e]; if (g.controller(q) === n) continue;
      if (g.nbSea[e] && g.building[p] !== B.port) continue;
      out.push(p, q);
    }
  }
  return out;
}

function aiNation(g, n) {
  const pers = PERSONALITIES[g.personality[n]];
  const own = g.owned(n);
  if (!own.length) return;
  const aggr = pers.aggr * g.diff.aiAggr;
  const fr = frontier(g, n);
  const atWar = g.atWar(n);

  // 1. economy: build / invest when flush
  if (g.gold[n] > 150 && g.mp[n] >= 2 && g.rng.chance(0.3 + pers.econ * 0.2)) {
    let best = -1, bs = -1;
    for (let i = 0; i < own.length; i += 1 + (own.length > 30 ? 2 : 0)) {
      const p = own[i]; if (g.building[p] || g.bBuilding[p] || g.occupier[p]) continue;
      const s = g.pop[p] + g.dev[p] * 20 + (g.capital[p] ? 100 : 0); if (s > bs) { bs = s; best = p; }
    }
    if (best >= 0) {
      const wantMil = atWar || pers.def > 0.7;
      const choice = wantMil ? B.fortress : (g.techLevel[n] > 0.8 && g.rng.chance(0.4) ? B.library : (g.rng.chance(0.5) ? B.market : B.farm));
      g.apply({ cmd: 'build', n, p: best, b: choice });
    }
  }
  // 2. colonize neutral land next door (cheap expansion, replaces legacy aiColonizeV2)
  if (g.gold[n] > 90 && g.mp[n] >= 2) {
    for (let i = 0; i < fr.length; i += 2) {
      const q = fr[i + 1]; if (g.owner[q] !== 0) continue;
      if (g.apply({ cmd: 'colonize', n, p: q }).ok) break;
    }
  }
  // 3. recruit at the most threatened frontier province (rich nations raise several levies)
  const levies = g.gold[n] > 500 ? 3 : g.gold[n] > 250 ? 2 : 1;
  for (let lv = 0; lv < levies && g.gold[n] > 30 && g.manpower[n] > 40 && g.mp[n] >= 1 && (lv > 0 || g.rng.chance(0.3 + aggr * 0.4 + (atWar ? 0.3 : 0))); lv++) {
    let best = -1, bs = -1e9;
    for (let i = 0; i < fr.length; i += 2) {
      const p = fr[i], q = fr[i + 1];
      const hostile = g.owner[q] !== 0 && g.getRel(n, g.controller(q)) === REL.WAR;
      const s = (hostile ? 3 : 0.5) - g.army[p] / 60 + g.rng.next() * 0.3;
      if (s > bs) { bs = s; best = p; }
    }
    if (best >= 0) g.apply({ cmd: 'recruit', n, p: best, amount: 20 });
  }
  // 4. war: attack hostile neighbours; declare new war when strong
  if (g.mp[n] >= COST.mpAttack) maybeDeclare(g, n, pers, aggr, fr);
  if (atWar || g.atWar(n)) fight(g, n, fr);
  // 5. peace when losing
  if (g.atWar(n)) seekPeace(g, n);
  // 6. diplomacy
  if (g.dp[n] >= COST.dpNap && g.rng.chance(pers.dipl * 0.15)) diplomacy(g, n, fr);
}

function maybeDeclare(g, n, pers, aggr, fr) {
  if (g.turn < 6 || g.turn - g.lastWarTurn[n] < 6 || g.dp[n] < COST.dpWar) return;
  if (!g.rng.chance(Math.min(1, aggr * 0.5))) return;
  // pick weakest bordering nation we could beat
  let tgt = 0, ts = -1;
  const seen = new Set();
  for (let i = 0; i < fr.length; i += 2) {
    const p = fr[i], q = fr[i + 1]; const t = g.owner[q];
    if (!t || t === n || seen.has(t) || !g.alive[t] || g.friendly(n, t) || g.hasTruce(n, t) || g.getRel(n, t) === REL.NAP || g.getRel(n, t) === REL.WAR) continue;
    seen.add(t);
    if (g.army[p] / Math.max(8, g.army[q] + 10) < 1.15) continue;
    const s = g.army[p] / (g.army[q] + 10) + g.grudge[n * g.N1 + t] / 50 + g.rng.next() * 0.5;
    if (s > ts) { ts = s; tgt = t; }
  }
  if (tgt) {
    // do not pile onto a nation already fighting 2+ wars
    if (g.stab[g.capitalOf[n] >= 0 ? g.capitalOf[n] : 0] < 25) return;
    g.apply({ cmd: 'declareWar', n, t: tgt });
  }
}

function fight(g, n, fr) {
  let attacks = Math.min(3, Math.floor(g.mp[n] / COST.mpAttack));
  if (attacks <= 0) return;
  const cands = [];
  for (let i = 0; i < fr.length; i += 2) {
    const p = fr[i], q = fr[i + 1]; const c = g.controller(q);
    if (c === 0 || g.getRel(n, c) !== REL.WAR) continue;
    if (g.army[p] < 12) continue;
    const atk = g.army[p] * 0.9, def = g.army[q] * g.defMul(q) + 1;
    const score = atk / def + g.provinceValue(q) * 0.05 + (g.capital[q] ? 1 : 0);
    if (atk > def * 1.1) cands.push([score, p, q]);
  }
  cands.sort((a, b) => b[0] - a[0] || a[1] - b[1] || a[2] - b[2]);
  const used = new Set();
  for (const [, p, q] of cands) {
    if (attacks <= 0) break; if (used.has(p)) continue;
    const r = g.apply({ cmd: 'move', n, from: p, to: q, troops: g.army[p] - 1 });
    if (r.ok) { attacks--; used.add(p); }
  }
  // push reinforcements from interior toward the front
  if (g.mp[n] >= 1) {
    const own = g.owned(n);
    for (let i = 0; i < own.length && g.mp[n] >= 1; i++) {
      const p = own[i]; if (g.army[p] < 25 || g.controller(p) !== n) continue;
      let hasFront = false, best = -1, bs = -1;
      for (let e = g.nbOff[p]; e < g.nbOff[p + 1]; e++) {
        const q = g.nb[e]; if (g.controller(q) !== n) { hasFront = true; break; }
        // step toward neighbour with fewer troops that touches enemies
        let touchesEnemy = false; for (let e2 = g.nbOff[q]; e2 < g.nbOff[q + 1]; e2++) { const r = g.nb[e2]; const c = g.controller(r); if (c && c !== n && g.getRel(n, c) === REL.WAR) { touchesEnemy = true; break; } }
        if (touchesEnemy && g.nbSea[e] === 0 && 1 / (1 + g.army[q]) > bs) { bs = 1 / (1 + g.army[q]); best = q; }
      }
      if (!hasFront && best >= 0 && g.rng.chance(0.5)) g.apply({ cmd: 'move', n, from: p, to: best, troops: g.army[p] - 10 });
    }
  }
}

function seekPeace(g, n) {
  const N1 = g.N1;
  for (let o = 1; o < N1; o++) {
    if (g.rel[n * N1 + o] !== REL.WAR || !g.alive[o]) continue;
    const mine = g.warScore[n * N1 + o], theirs = g.warScore[o * N1 + n];
    const dur = g.warTurns[n * N1 + o];
    if (g.human[o] ) { // AI may offer: handled by UI proposals; here only auto-end very long stalemates
      if (dur > 24 && mine < 5 && theirs < 5 && g.rng.chance(0.2)) g.apply({ cmd: 'peace', n, t: o, kind: 'white', _force: true });
      continue;
    }
    const losing = theirs - mine;
    if (losing > 15 || (dur > 8 && Math.abs(losing) < 12 && g.rng.chance(0.3))) {
      g.apply({ cmd: 'peace', n, t: o, kind: mine >= 25 ? 'cede' : 'white', _force: !g.aiAcceptsPeace(o, n, 'white') && losing > 35 });
    } else if (mine >= 40 && g.rng.chance(0.3)) {
      g.apply({ cmd: 'peace', n, t: o, kind: 'cede' });
    }
  }
}

function diplomacy(g, n, fr) {
  // ally or NAP with a bordering nation we are friendly with
  for (let i = 0; i < fr.length; i += 2) {
    const t = g.controller(fr[i + 1]); if (!t || t === n || !g.alive[t] || g.human[t]) continue;
    const r = g.getRel(n, t);
    if (r === REL.PEACE && g.grudge[t * g.N1 + n] < 20) {
      const k = g.rng.chance(0.5) ? 'nap' : 'ally';
      if (k === 'ally' && g.dp[n] >= COST.dpAlly) g.apply({ cmd: 'ally', n, t });
      else g.apply({ cmd: 'nap', n, t });
      return;
    }
  }
}

// ---- acceptance models (target T evaluating proposer P) --------------------------
export function aiAcceptsPeace(g, t, p, kind) {
  const N1 = g.N1;
  const myWs = g.warScore[t * N1 + p], theirWs = g.warScore[p * N1 + t];
  const dur = g.warTurns[t * N1 + p];
  let want = 0;
  want += (theirWs - myWs) * 0.04;                  // they are winning vs me → I want peace
  want += Math.min(1.5, dur / 20);                  // war weariness
  want -= g.grudge[t * N1 + p] / 80;
  if (kind === 'cede') want -= 0.5 + theirWs * 0.02;
  return want > 0.2;
}
export function aiAcceptsPact(g, t, p, rel) {
  const pers = PERSONALITIES[g.personality[t]];
  if (g.grudge[t * g.N1 + p] > 20 || g.hasTruce(t, p) && rel === REL.ALLY) return false;
  let s = pers.dipl * 0.6 + (rel === REL.NAP ? 0.3 : 0);
  // common enemy bonus
  for (let o = 1; o <= g.N; o++) if (g.getRel(t, o) === REL.WAR && g.getRel(p, o) === REL.WAR) s += 0.3;
  const mine = g.ownCount(t), theirs = g.ownCount(p);
  if (theirs > mine * 3) s -= 0.2;
  return s > 0.45;
}
