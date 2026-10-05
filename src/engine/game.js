// Core simulation. Pure data + typed arrays, no DOM, deterministic (seeded RNG).
// Province index p in [0,P). Nation index n in [1,N]; 0 = neutral / none.
import { Rng, hashStr } from './rng.js';
import {
  ERAS, REGIMES, REGIME_POOL, REGIME_ID, DEV_INCOME, TECH_STEP, techNeeded, techGain, ADMIN_DIST_FACTOR,
  TERRAIN, TERRAIN_TOTAL, TERRAIN_DEF, BUILDINGS, B, PERSONALITIES, REL, DIFFICULTY, COST, TRUCE_TURNS,
} from './data.js';

const DEG = Math.PI / 180;
export function gcDist(lon1, lat1, lon2, lat2) {
  const dl = (lon2 - lon1) * DEG, a = lat1 * DEG, b = lat2 * DEG;
  const x = Math.sin((b - a) / 2) ** 2 + Math.cos(a) * Math.cos(b) * Math.sin(dl / 2) ** 2;
  return 2 * Math.asin(Math.min(1, Math.sqrt(x)));
}

export class Game {
  /**
   * @param world  baked static world (world.json)
   * @param era    optional era pack ({nations:[{id,name}], owner:Int[], discoverable, year}) – null = modern baseline
   * @param opts   {seed, difficulty, human}  human = nation index or 0
   */
  constructor(world, era, opts = {}) {
    this.world = world;
    const P = this.P = world.P;
    this.rng = new Rng(opts.seed || 1);
    this.seed = opts.seed || 1;
    this.difficulty = opts.difficulty || 'normal';
    this.turn = 1;
    this.year = era ? era.year : 2024; this.monthIdx = 0;
    this.eraId = era ? era.id : 'modern';
    this.over = false; this.winner = 0;

    // ---- nations -------------------------------------------------------------
    this.natName = ['—']; this.natCode = [''];
    const owner = new Uint16Array(P);
    if (era) {
      for (const n of era.nations) { this.natName.push(n.name); this.natCode.push(n.id); }
      for (let i = 0; i < P; i++) owner[i] = era.owner[i] || 0;
    } else {
      const map = new Int32Array(world.natCode.length).fill(0);
      for (let k = 0; k < world.natCode.length; k++) if (world.natCode[k]) { this.natName.push(world.natName[k]); this.natCode.push(world.natCode[k]); map[k] = this.natName.length - 1; }
      for (let i = 0; i < P; i++) owner[i] = map[world.provNat[i]];
    }
    this.rebel = this.natName.length; this.natName.push('Rebels'); this.natCode.push('XRB');
    const N = this.N = this.natName.length - 1;
    const N1 = this.N1 = N + 1;

    // ---- province arrays -----------------------------------------------------
    this.owner = owner;
    this.occupier = new Uint16Array(P);
    this.army = new Uint16Array(P);
    this.pop = new Uint16Array(P);
    this.dev = new Uint8Array(P);
    this.econ = new Uint8Array(P);
    this.stab = new Uint8Array(P);
    this.happy = new Uint8Array(P);
    this.defense = new Uint8Array(P);
    this.terrain = new Uint8Array(P);
    this.building = new Uint8Array(P);
    this.bLevel = new Uint8Array(P);
    this.bBuilding = new Uint8Array(P);   // under construction (building type), 0 none
    this.bTurns = new Uint8Array(P);      // turns left of construction
    this.capital = new Uint8Array(P);
    this.discoverable = new Uint8Array(P);
    if (era) for (const p of era.discoverable || []) this.discoverable[p] = 1;
    this.dirtyFlag = new Uint8Array(P); this.dirtyList = [];
    this.occRev = 0;

    const r = this.rng;
    for (let p = 0; p < P; p++) {
      this.army[p] = 15 + r.int(25);
      this.pop[p] = 80 + r.int(120);
      this.dev[p] = 1 + r.int(3);
      this.econ[p] = 1 + r.int(3);
      this.happy[p] = 55 + r.int(20);
      this.stab[p] = 70 + r.int(22);
      let h = hashStr(world.id[p]) % TERRAIN_TOTAL;
      let t = 0; for (; t < TERRAIN.length - 1; t++) { h -= TERRAIN[t].weight; if (h < 0) break; }
      this.terrain[p] = t;
    }

    // ---- nation arrays -------------------------------------------------------
    const f32 = () => new Float32Array(N1), u8 = () => new Uint8Array(N1);
    this.gold = f32(); this.manpower = f32(); this.mp = f32(); this.dp = f32();
    this.techLevel = f32(); this.research = f32(); this.era = u8();
    this.regime = u8(); this.personality = u8(); this.alive = u8();
    this.human = u8(); this.capitalOf = new Int32Array(N1).fill(-1);
    this.budget = new Uint8Array(N1 * 4);   // tax, goods, research, invest (%)
    this.overlord = new Uint16Array(N1); this.tribute = u8(); this.liberty = f32();
    this.lastWarTurn = new Int32Array(N1).fill(-99);
    this.color = new Uint32Array(N1);
    this.rel = new Uint8Array(N1 * N1);
    this.truce = new Int32Array(N1 * N1);     // expiry turn
    this.warScore = new Int16Array(N1 * N1);  // a's % of b's province value occupied
    this.warTurns = new Uint16Array(N1 * N1);
    this.grudge = new Uint8Array(N1 * N1);
    this.capLost = u8();
    this.ownStart = new Uint32Array(N1 + 1); this.ownList = new Uint16Array(P); this.ownDirty = true;

    const diff = DIFFICULTY[this.difficulty] || DIFFICULTY.normal;
    this.diff = diff;
    for (let n = 1; n <= N; n++) {
      this.gold[n] = 45 + r.int(35); this.manpower[n] = 55 + r.int(40);
      this.mp[n] = 6; this.dp[n] = 4;
      this.techLevel[n] = 0.1 + r.next() * 0.3;
      this.regime[n] = n === this.rebel ? REGIME_ID.rebels : REGIME_POOL[(n - 1) % REGIME_POOL.length];
      this.personality[n] = (hashStr(this.natCode[n]) % PERSONALITIES.length);
      this.budget.set([50, 20, 15, 15], n * 4);
      this.color[n] = genColor(n);
    }
    this.era.fill(0);
    this.nbOff = Uint32Array.from(world.nbOff); this.nb = Uint16Array.from(world.nb); this.nbSea = new Uint8Array(world.nb.length);
    this.rebuildOwned();
    for (let n = 1; n <= N; n++) { this.alive[n] = n !== this.rebel && this.ownCount(n) > 0 ? 1 : 0; if (this.alive[n]) this.reassignCapital(n); }
    for (let n = 1; n <= N; n++) this.era[n] = Math.min(4, Math.floor(this.techLevel[n]));
    if (era) this._eraTech(era);
    this.queue = [];
    this.log = [];            // {turn, kind, a, b, p}
    this.addSeaLinks();
    if (opts.human) this.setHuman(opts.human);
  }

  _eraTech(era) { // historical eras start more advanced
    const base = { ancient: 0, roman: 0.8, medieval: 1.7, mongol: 1.9, timurid: 2.2, discovery: 2.5, gunpowder: 2.9, napoleonic: 3.2, victorian: 3.6, ww1: 4.0, ww2: 4.4, coldwar: 4.6 }[era.id] ?? 0;
    for (let n = 1; n <= this.N; n++) { this.techLevel[n] = Math.min(5, base + this.rng.next() * 0.3); this.era[n] = Math.min(4, Math.floor(this.techLevel[n])); }
  }

  setHuman(n) {
    this.human.fill(0); this.human[n] = 1; this.humanId = n;
    this.gold[n] = this.diff.startGold; this.manpower[n] = this.diff.startManpower; this.mp[n] = 10; this.dp[n] = 6;
  }

  // ------------------------------------------------------------------ adjacency
  addSeaLinks() {
    // Sea-links: coastal/island provinces with <=2 land neighbours get up to 3 nearest overseas links (flag in seaMask)
    const w = this.world, P = this.P;
    const extra = Array.from({ length: P }, () => []);
    const deg = (p) => w.nbOff[p + 1] - w.nbOff[p];
    const cand = [];
    for (let p = 0; p < P; p++) if (deg(p) <= 2 && this.world.area[p] >= 0) cand.push(p);
    // grid index by 10-degree cell to avoid O(P^2)
    const cells = new Map();
    for (let p = 0; p < P; p++) { const k = ((w.lon[p] + 180) / 10 | 0) * 100 + ((w.lat[p] + 90) / 10 | 0); (cells.get(k) || cells.set(k, []).get(k)).push(p); }
    const MAX = 0.42;
    for (const p of cand) {
      const cx = ((w.lon[p] + 180) / 10) | 0, cy = ((w.lat[p] + 90) / 10) | 0;
      const near = [];
      for (let dx = -3; dx <= 3; dx++) for (let dy = -3; dy <= 3; dy++) {
        const k = (((cx + dx) % 36 + 36) % 36) * 100 + (cy + dy);
        const c = cells.get(k); if (!c) continue;
        for (const q of c) {
          if (q === p) continue;
          let isNb = false; for (let i = w.nbOff[p]; i < w.nbOff[p + 1]; i++) if (w.nb[i] === q) { isNb = true; break; }
          if (isNb) continue;
          near.push([gcDist(w.lon[p], w.lat[p], w.lon[q], w.lat[q]), q]);
        }
      }
      near.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
      let added = 0;
      for (const [d, q] of near) { if (added < 2 || (d < MAX && added < 3)) { extra[p].push(q); extra[q].push(p); added++; } else break; }
    }
    // Build merged CSR: land neighbours first, then sea (mask marks sea edges)
    const off = new Uint32Array(P + 1); const list = []; const sea = [];
    for (let p = 0; p < P; p++) {
      const land = []; for (let i = w.nbOff[p]; i < w.nbOff[p + 1]; i++) land.push(w.nb[i]);
      const set = new Set(land);
      const ex = [...new Set(extra[p])].filter(q => !set.has(q)).sort((a, b) => a - b);
      for (const q of land) { list.push(q); sea.push(0); }
      for (const q of ex) { list.push(q); sea.push(1); }
      off[p + 1] = list.length;
    }
    this.nbOff = off; this.nb = Uint16Array.from(list); this.nbSea = Uint8Array.from(sea);
  }

  // ------------------------------------------------------------------ ownership
  rebuildOwned() {
    const N1 = this.N1, P = this.P, s = this.ownStart;
    s.fill(0);
    for (let p = 0; p < P; p++) s[this.owner[p] + 1]++;
    for (let n = 0; n < N1; n++) s[n + 1] += s[n];
    const fill = new Uint32Array(N1);
    for (let p = 0; p < P; p++) { const o = this.owner[p]; this.ownList[s[o] + fill[o]++] = p; }
    this.ownDirty = false;
  }
  ownCount(n) { if (this.ownDirty) this.rebuildOwned(); return this.ownStart[n + 1] - this.ownStart[n]; }
  owned(n) { if (this.ownDirty) this.rebuildOwned(); return this.ownList.subarray(this.ownStart[n], this.ownStart[n + 1]); }
  touch(p) { if (!this.dirtyFlag[p]) { this.dirtyFlag[p] = 1; this.dirtyList.push(p); } }
  takeDirty() { const l = this.dirtyList; for (const p of l) this.dirtyFlag[p] = 0; this.dirtyList = []; return l; }
  setOwner(p, n) { if (this.owner[p] === n) return; this.owner[p] = n; this.ownDirty = true; this.touch(p); }
  controller(p) { return this.occupier[p] || this.owner[p]; }
  reassignCapital(n) {
    const own = this.owned(n);
    for (const p of own) if (this.capital[p]) this.capital[p] = 0;
    if (!own.length) { this.capitalOf[n] = -1; return; }
    let best = own[0], bd = -1;
    for (const p of own) { const d = this.nbOff[p + 1] - this.nbOff[p]; if (d > bd) { bd = d; best = p; } }
    this.capital[best] = 1; this.capitalOf[n] = best; this.touch(best);
  }

  // ------------------------------------------------------------------ relations
  getRel(a, b) { return this.rel[a * this.N1 + b]; }
  setRel(a, b, v) { this.rel[a * this.N1 + b] = v; this.rel[b * this.N1 + a] = v; if (v === REL.WAR) { this.warScore[a * this.N1 + b] = 0; this.warScore[b * this.N1 + a] = 0; this.warTurns[a * this.N1 + b] = 0; this.warTurns[b * this.N1 + a] = 0; } }
  atWar(n) { const N1 = this.N1, b = n * N1; for (let o = 1; o < N1; o++) if (this.rel[b + o] === REL.WAR && this.alive[o]) return true; return false; }
  hasTruce(a, b) { return this.truce[a * this.N1 + b] > this.turn; }
  friendly(a, b) { if (a === b) return true; const r = this.getRel(a, b); return r === REL.ALLY || r === REL.MARRIAGE || this.overlord[a] === b || this.overlord[b] === a; }
  /** can nation n move troops through/attack province p? */
  hostile(n, p) { const c = this.controller(p); if (c === n) return false; if (c === 0) return true; return !this.friendly(n, c); }

  // ------------------------------------------------------------------ economy
  provinceValue(p) {
    const e = Math.min(5, Math.max(1, this.econ[p])), d = Math.min(5, Math.max(1, this.dev[p]));
    let v = 1 + e * 0.1 + d * 2 + this.pop[p] * 0.001;
    if (this.capital[p]) v *= 10; return v;
  }
  income(n) {
    const own = this.owned(n), w = this.world;
    const out = { gold: 0, manpower: 0, upkeep: 0, tax: 0, production: 0, admin: 0, net: 0, manCap: 120, lands: own.length, capLost: false, pop: 0, happyAvg: 60, researchBonus: 0 };
    if (!own.length) return out;
    const era = ERAS[this.era[n]], reg = REGIMES[this.regime[n]];
    const taxPct = this.budget[n * 4];
    const tl = this.techLevel[n];
    const techIncMul = 1 + tl * 0.03, techAdminMul = 1 / (1 + tl * 0.05), techUpMul = 1 / (1 + tl * 0.04);
    const cap = this.capitalOf[n];
    const capLost = cap >= 0 && this.controller(cap) !== n;
    out.capLost = capLost;
    let prod = 0, tax = 0, admin = 0, man = 0, upBase = 0, hs = 0, tp = 0, rb = 0;
    const capLon = cap >= 0 ? w.lon[cap] : 0, capLat = cap >= 0 ? w.lat[cap] : 0;
    for (let i = 0; i < own.length; i++) {
      const p = own[i];
      if (this.occupier[p] && this.occupier[p] !== n) { tp += this.pop[p]; hs += this.happy[p]; continue; }
      const stabMod = 0.5 + this.stab[p] / 200;
      const dev = Math.min(5, Math.max(1, this.dev[p])), eco = Math.min(5, Math.max(1, this.econ[p]));
      hs += this.happy[p]; tp += this.pop[p];
      const popB = Math.floor(this.pop[p] / 80), mkt = this.building[p] === B.market ? 2 : 0;
      let pp = Math.floor((3 + DEV_INCOME[dev] + popB + era.incomeBonus + mkt) * stabMod * reg.incProd);
      pp += Math.floor(eco * dev * 0.4 * stabMod);
      if (this.capital[p]) pp += 3;
      if (this.building[p] === B.workshop) pp = Math.floor(pp * (1 + 0.05 * this.bLevel[p]));
      prod += pp;
      tax += Math.floor(this.pop[p] / 20 * (taxPct / 100) * (this.happy[p] / 100) * reg.incTax);
      if (!this.capital[p] && cap >= 0) admin += Math.floor(gcDist(capLon, capLat, w.lon[p], w.lat[p]) * ADMIN_DIST_FACTOR * reg.adminCost);
      man += Math.floor((2 + Math.floor(this.pop[p] / 100) + era.mpBonus) * stabMod);
      upBase += this.army[p] * (this.building[p] === B.supplycamp ? 0.8 : 1);
      if (this.building[p] === B.library) rb += (this.pop[p] / 750) * this.bLevel[p];
    }
    let gold = prod + tax; if (capLost) gold = Math.floor(gold * 0.5);
    gold = Math.floor(gold * reg.incMul * techIncMul);
    admin = Math.floor(admin * techAdminMul);
    const upkeep = Math.floor(upBase * (0.25 + this.era[n] * 0.05) * techUpMul * reg.upkeep);
    out.gold = gold; out.manpower = man; out.upkeep = upkeep; out.tax = tax; out.production = prod; out.admin = admin;
    out.net = gold - admin - upkeep; out.manCap = Math.max(120 + this.era[n] * 50, own.length * 30 + this.era[n] * 35);
    out.pop = tp; out.happyAvg = Math.round(hs / own.length); out.researchBonus = rb;
    return out;
  }

  // ------------------------------------------------------------------ combat / movement
  defMul(p) {
    let m = 1 + TERRAIN_DEF[this.terrain[p]];
    const b = this.building[p];
    if (b === B.fortress) m += this.bLevel[p] >= 2 ? 0.8 : 0.5; else if (b === B.watchtower) m += 0.03;
    const c = this.controller(p); if (c) m += REGIMES[this.regime[c]].defenseBonus;
    return m + this.defense[p] / 100;
  }
  combatMul(n) { return n ? ERAS[this.era[n]].combatMul : 1; }
  seaEdge(from, to) { for (let i = this.nbOff[from]; i < this.nbOff[from + 1]; i++) if (this.nb[i] === to) return this.nbSea[i] === 1 ? 1 : 0; return -1; }
  adjacent(from, to) { return this.seaEdge(from, to) >= 0; }

  /** Move or attack. Returns 'move' | 'win' | 'loss' | error string starting with '!' */
  moveOrAttack(n, from, to, troops) {
    if (this.controller(from) !== n) return '!notyours';
    const se = this.seaEdge(from, to); if (se < 0) return '!notadjacent';
    if (se === 1 && this.building[from] !== B.port) return '!needport';
    if (this.army[from] <= 1) return '!noarmy';
    const ctrlTo = this.controller(to);
    if (ctrlTo === n) {
      const k = Math.min(troops || this.army[from] - 1, this.army[from] - 1); if (k <= 0) return '!noarmy';
      this.army[from] -= k; this.army[to] = Math.min(65000, this.army[to] + k); this.touch(from); this.touch(to); return 'move';
    }
    if (ctrlTo !== 0 && this.friendly(n, ctrlTo)) return '!friendly';
    // attacking needs war unless neutral land
    if (ctrlTo !== 0 && this.getRel(n, ctrlTo) !== REL.WAR) return '!nowar';
    if (this.discoverable[to] && this.techLevel[n] < 2 && this.owner[to] === 0) return '!undiscovered';
    return this.resolveCombat(n, from, to, troops);
  }
  resolveCombat(n, from, to, troops) {
    const avail = this.army[from], send = Math.max(1, Math.min(troops || avail - 1, avail - 1));
    const atkN = n, defN = this.controller(to);
    const atk = send * this.combatMul(atkN) * TERRAIN[this.terrain[to]].atkMul;
    const def = this.army[to] * this.combatMul(defN) * this.defMul(to);
    if (atk > def) {
      const surv = Math.max(1, Math.round((atk - def) / Math.max(0.01, this.combatMul(atkN))));
      const occ = Math.min(send, surv);
      if (this.owner[to] === 0) this.setOwner(to, atkN);
      else if (this.owner[to] === atkN) { this.occupier[to] = 0; this.occRev++; }
      else if (atkN === this.rebel || defN === this.rebel) this.cede(to, atkN);
      else { this.occupier[to] = atkN; this.occRev++; }
      this.army[to] = occ; this.defense[to] = 0;
      this.army[from] = Math.max(0, avail - occ);
      this.touch(from); this.touch(to);
      return 'win';
    }
    const atkLoss = Math.round(send * Math.min(0.9, def / (atk + def)));
    this.army[from] = Math.max(0, avail - atkLoss);
    this.army[to] = Math.max(1, this.army[to] - Math.round(this.army[to] * (atk / (atk + def)) * 0.55));
    this.touch(from); this.touch(to);
    return 'loss';
  }
  cede(p, to) {
    const from = this.owner[p];
    this.setOwner(p, to); this.occupier[p] = 0; this.occRev++;
    if (from && this.capital[p]) { this.capital[p] = 0; this.capitalOf[from] = -1; this.reassignCapital(from); if (this.ownCount(from) === 0 && from !== this.rebel) this.eliminate(from); }
  }
  eliminate(n) { this.alive[n] = 0; for (let o = 1; o <= this.N; o++) if (this.rel[n * this.N1 + o] === REL.WAR) this.setRel(n, o, REL.PEACE); this.log.push({ turn: this.turn, kind: 'eliminated', a: n }); }

  // ------------------------------------------------------------------ commands (the only mutation API)
  /** Apply one command now. Returns {ok:true,...} or {ok:false,err}. */
  apply(c) {
    const fn = Game.CMD[c.cmd]; if (!fn) return { ok: false, err: 'unknown' };
    if (!this.alive[c.n] && c.cmd !== 'noop') return { ok: false, err: 'dead' };
    return fn.call(this, c);
  }
}

// ---- command table -----------------------------------------------------------
Game.CMD = {
  move(c) {
    const cost = COST.mpMove; if (this.mp[c.n] < cost) return { ok: false, err: 'mp' };
    const att = this.controller(c.to) !== c.n;
    const need = att ? COST.mpAttack : cost; if (this.mp[c.n] < need) return { ok: false, err: 'mp' };
    const r = this.moveOrAttack(c.n, c.from, c.to, c.troops);
    if (r[0] === '!') return { ok: false, err: r.slice(1) };
    this.mp[c.n] -= need; return { ok: true, result: r };
  },
  recruit(c) {
    const n = c.n, p = c.p; if (this.controller(p) !== n || this.owner[p] !== n) return { ok: false, err: 'notyours' };
    const reg = REGIMES[this.regime[n]];
    const amount = Math.max(5, Math.min(30, c.amount || 15));
    const goldCost = Math.ceil((COST.recruitGold + amount * 0.6) * reg.recruitCost * (this.building[p] === B.armory ? 0.5 : 1));
    const manCost = COST.recruitMan + amount;
    if (this.gold[n] < goldCost) return { ok: false, err: 'gold' };
    if (this.manpower[n] < manCost) return { ok: false, err: 'manpower' };
    if (this.mp[n] < COST.mpRecruit) return { ok: false, err: 'mp' };
    this.gold[n] -= goldCost; this.manpower[n] -= manCost; this.mp[n] -= COST.mpRecruit;
    this.army[p] = Math.min(65000, this.army[p] + amount); this.touch(p); return { ok: true };
  },
  declareWar(c) {
    const { n, t } = c; if (n === t || !this.alive[t]) return { ok: false, err: 'target' };
    if (this.getRel(n, t) === REL.WAR) return { ok: false, err: 'already' };
    if (this.hasTruce(n, t)) return { ok: false, err: 'truce' };
    if (this.dp[n] < COST.dpWar) return { ok: false, err: 'dp' };
    if (this.overlord[n] === t || this.overlord[t] === n) return { ok: false, err: 'vassal' };
    const was = this.getRel(n, t);
    this.dp[n] -= COST.dpWar; this.setRel(n, t, REL.WAR); this.lastWarTurn[n] = this.turn;
    this.grudge[t * this.N1 + n] = Math.min(100, this.grudge[t * this.N1 + n] + (was === REL.ALLY ? 80 : was === REL.NAP ? 60 : 40));
    this.log.push({ turn: this.turn, kind: 'war', a: n, b: t });
    // allies of the defender join if they are not allied to the aggressor
    for (let o = 1; o <= this.N; o++) if (o !== n && o !== t && this.alive[o] && this.getRel(t, o) === REL.ALLY && !this.friendly(n, o) && this.getRel(n, o) !== REL.WAR && !this.hasTruce(n, o)) { this.setRel(n, o, REL.WAR); this.log.push({ turn: this.turn, kind: 'war', a: o, b: n, ally: 1 }); }
    return { ok: true };
  },
  peace(c) {
    const { n, t } = c; if (this.getRel(n, t) !== REL.WAR) return { ok: false, err: 'notwar' };
    const ws = this.warScore[n * this.N1 + t];  // my occupation of their land
    const kind = c.kind || 'white';
    // AI (or human target) acceptance: handled by caller for humans; for AI targets we evaluate here
    if (!this.human[t] && !c._force && !this.aiAcceptsPeace(t, n, kind)) return { ok: false, err: 'refused' };
    if (kind === 'cede') {
      if (ws < 25) return { ok: false, err: 'warscore' };
      // take occupied provinces worth up to ws budget
      let budget = ws * 0.9, taken = 0;
      const prov = []; for (const p of this.owned(t)) if (this.occupier[p] === n) prov.push(p);
      prov.sort((a, b) => this.provinceValue(a) - this.provinceValue(b));
      const totalVal = this.owned(t).reduce((s, p) => s + this.provinceValue(p), 0) || 1;
      for (const p of prov) { const pct = this.provinceValue(p) / totalVal * 100; if (pct > budget) continue; budget -= pct; this.cede(p, n); taken++; }
      this.log.push({ turn: this.turn, kind: 'ceded', a: n, b: t, k: taken });
    }
    // clear occupations both ways
    for (const p of this.owned(t)) if (this.occupier[p] === n) { this.occupier[p] = 0; this.touch(p); }
    for (const p of this.owned(n)) if (this.occupier[p] === t) { this.occupier[p] = 0; this.touch(p); }
    this.occRev++;
    this.setRel(n, t, REL.PEACE); this.truce[n * this.N1 + t] = this.truce[t * this.N1 + n] = this.turn + TRUCE_TURNS;
    this.dp[n] = Math.max(0, this.dp[n] - COST.dpPeace);
    this.log.push({ turn: this.turn, kind: 'peace', a: n, b: t });
    return { ok: true };
  },
  ally(c) {
    const { n, t } = c; if (this.getRel(n, t) === REL.WAR) return { ok: false, err: 'war' };
    if (this.dp[n] < COST.dpAlly) return { ok: false, err: 'dp' };
    if (!this.human[t] && !this.aiAcceptsPact(t, n, REL.ALLY)) return { ok: false, err: 'refused' };
    this.dp[n] -= COST.dpAlly; this.setRel(n, t, REL.ALLY); this.log.push({ turn: this.turn, kind: 'ally', a: n, b: t }); return { ok: true };
  },
  nap(c) {
    const { n, t } = c; if (this.getRel(n, t) !== REL.PEACE) return { ok: false, err: 'state' };
    if (this.dp[n] < COST.dpNap) return { ok: false, err: 'dp' };
    if (!this.human[t] && !this.aiAcceptsPact(t, n, REL.NAP)) return { ok: false, err: 'refused' };
    this.dp[n] -= COST.dpNap; this.setRel(n, t, REL.NAP); this.napExpiry = this.napExpiry || {}; this.napExpiry[Math.min(n, t) * this.N1 + Math.max(n, t)] = this.turn + 20;
    return { ok: true };
  },
  breakPact(c) {
    const r = this.getRel(c.n, c.t); if (r !== REL.ALLY && r !== REL.NAP) return { ok: false, err: 'state' };
    this.setRel(c.n, c.t, REL.PEACE); this.grudge[c.t * this.N1 + c.n] = Math.min(100, this.grudge[c.t * this.N1 + c.n] + 25); return { ok: true };
  },
  build(c) {
    const { n, p } = c; const bt = BUILDINGS[c.b - 1]; if (!bt) return { ok: false, err: 'type' };
    if (this.owner[p] !== n || this.occupier[p]) return { ok: false, err: 'notyours' };
    if (this.bBuilding[p]) return { ok: false, err: 'busy' };
    const cur = this.building[p] === c.b ? this.bLevel[p] : 0;
    if (this.building[p] && this.building[p] !== c.b) return { ok: false, err: 'occupied' };
    const lvl = cur + 1; if (lvl > bt.maxLevel) return { ok: false, err: 'max' };
    if (this.techLevel[n] < bt.tech[lvl - 1]) return { ok: false, err: 'tech' };
    const reg = REGIMES[this.regime[n]];
    const mpc = Math.max(1, Math.round(bt.mp[lvl - 1] * reg.moveCost));
    if (this.gold[n] < bt.cost[lvl - 1]) return { ok: false, err: 'gold' };
    if (this.mp[n] < mpc) return { ok: false, err: 'mp' };
    this.gold[n] -= bt.cost[lvl - 1]; this.mp[n] -= mpc;
    this.bBuilding[p] = c.b; this.bTurns[p] = bt.buildTime[lvl - 1]; this.touch(p); return { ok: true };
  },
  budget(c) {
    const i = ['tax', 'goods', 'research', 'invest'].indexOf(c.key); if (i < 0) return { ok: false, err: 'key' };
    const b = this.budget, o = c.n * 4; const v = Math.max(0, Math.min(100, c.val | 0));
    b[o + i] = v; let sum = b[o] + b[o + 1] + b[o + 2] + b[o + 3];
    // rebalance: take/give the difference from the largest other slot
    let guard = 8; while (sum !== 100 && guard--) { const d = 100 - sum; let k = -1, best = -1; for (let j = 0; j < 4; j++) if (j !== i && (d < 0 ? b[o + j] > 0 : b[o + j] < 100)) { const w = d < 0 ? b[o + j] : 100 - b[o + j]; if (w > best) { best = w; k = j; } } if (k < 0) break; const nv = Math.max(0, Math.min(100, b[o + k] + d)); b[o + k] = nv; sum = b[o] + b[o + 1] + b[o + 2] + b[o + 3]; }
    return { ok: true };
  },
  colonize(c) {
    const { n, p } = c; if (this.owner[p] !== 0) return { ok: false, err: 'taken' };
    if (this.discoverable[p] && this.techLevel[n] < 2) return { ok: false, err: 'tech' };
    let adj = false; for (let i = this.nbOff[p]; i < this.nbOff[p + 1]; i++) { const q = this.nb[i]; if (this.owner[q] === n && (this.nbSea[i] === 0 || this.building[q] === B.port)) { adj = true; break; } }
    if (!adj) return { ok: false, err: 'notadjacent' };
    const reg = REGIMES[this.regime[n]];
    const cost = reg.colonyFree ? 0 : 60 + this.ownCount(n) * 2;
    if (this.gold[n] < cost) return { ok: false, err: 'gold' };
    if (this.mp[n] < 2) return { ok: false, err: 'mp' };
    this.gold[n] -= cost; this.mp[n] -= 2; this.setOwner(p, n); this.army[p] = Math.max(this.army[p], 8); this.discoverable[p] = 0; return { ok: true };
  },
  relocate(c) {
    const { n, p } = c; if (this.owner[p] !== n) return { ok: false, err: 'notyours' }; if (this.gold[n] < 80) return { ok: false, err: 'gold' };
    this.gold[n] -= 80; const old = this.capitalOf[n]; if (old >= 0) { this.capital[old] = 0; this.touch(old); }
    this.capital[p] = 1; this.capitalOf[n] = p; this.touch(p); return { ok: true };
  },
  regime(c) {
    const r = REGIMES[c.r]; if (!r || r.id === 'rebels') return { ok: false, err: 'type' };
    if (this.era[c.n] < r.sinceEra) return { ok: false, err: 'era' }; if (this.gold[c.n] < 120) return { ok: false, err: 'gold' };
    this.gold[c.n] -= 120; this.regime[c.n] = c.r;
    for (const p of this.owned(c.n)) { this.stab[p] = Math.max(5, this.stab[p] - 15); }
    return { ok: true };
  },
  noop() { return { ok: true }; },
};

export function genColor(n) {
  const h = (n * 137.508) % 360, s = 0.55 + (n % 3) * 0.1, l = 0.45 + (n % 4) * 0.05;
  const a = s * Math.min(l, 1 - l), f = (k) => { const x = (k + h / 30) % 12; return l - a * Math.max(-1, Math.min(x - 3, 9 - x, 1)); };
  return ((Math.round(f(0) * 255) << 16) | (Math.round(f(8) * 255) << 8) | Math.round(f(4) * 255)) >>> 0;
}
