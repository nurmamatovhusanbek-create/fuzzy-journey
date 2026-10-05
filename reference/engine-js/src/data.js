// Static game tables, ported from the legacy engine (values preserved).
export const MONTHS = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];

export const ERAS = [
  { id: 'ancient',    incomeBonus: 0,  mpBonus: 0, combatMul: 1.0  },
  { id: 'classical',  incomeBonus: 2,  mpBonus: 1, combatMul: 1.10 },
  { id: 'medieval',   incomeBonus: 4,  mpBonus: 2, combatMul: 1.25 },
  { id: 'industrial', incomeBonus: 7,  mpBonus: 3, combatMul: 1.50 },
  { id: 'modern',     incomeBonus: 10, mpBonus: 4, combatMul: 1.80 },
];
export const DEV_INCOME = [0, 1, 3, 6, 10, 15];
export const TECH_STEP = 0.1;
export const techNeeded = (lvl) => Math.round(60 * Math.pow(1.08, (lvl || 0) * 10));
export const techGain = (pop, pct) => (3 + Math.floor((pop || 0) / 200)) * ((pct || 0) / 100);
export const ADMIN_DIST_FACTOR = 1.8;

// Terrain: index = Terrain id stored in Uint8Array
export const TERRAIN = [
  { id: 'plains',   atkMul: 1.10, defMul: 1.00, weight: 30 },
  { id: 'hills',    atkMul: 1.00, defMul: 1.12, weight: 22 },
  { id: 'mountain', atkMul: 0.85, defMul: 1.30, weight: 14 },
  { id: 'forest',   atkMul: 0.95, defMul: 1.15, weight: 16 },
  { id: 'marsh',    atkMul: 0.80, defMul: 1.20, weight: 8  },
  { id: 'steppe',   atkMul: 1.18, defMul: 0.95, weight: 10 },
];
export const TERRAIN_TOTAL = TERRAIN.reduce((s, t) => s + t.weight, 0);
// legacy defence bonus by terrain (resolveCombatV2): mountains .30, hills .15, forest .10
export const TERRAIN_DEF = [0, 0.15, 0.30, 0.10, 0, 0];

// Regimes (index = id stored in Uint8Array)
const R = (id, o) => ({ id, ...o });
export const REGIMES = [
  R('tribal',   { incMul: 0.85, stabCeil: 75,  colonyFree: true,  rebelChance: 0,    incTax: 0.70, incProd: 1.10, adminCost: 0.70, accTax: 20, upkeep: 1.60, defenseBonus: 0.10, minGoods: 0.10, minInvest: 0.05, moveCost: 1.875, recruitCost: 1.00,  sinceEra: 0 }),
  R('feudal',   { incMul: 0.95, stabCeil: 85,  colonyFree: false, rebelChance: 0.02, incTax: 1.00, incProd: 0.90, adminCost: 1.00, accTax: 30, upkeep: 1.00, defenseBonus: 0.02, minGoods: 0.15, minInvest: 0.10, moveCost: 1.00,  recruitCost: 1.00,  sinceEra: 0 }),
  R('monarchy', { incMul: 1.00, stabCeil: 90,  colonyFree: false, rebelChance: 0.02, incTax: 1.00, incProd: 1.00, adminCost: 1.00, accTax: 30, upkeep: 1.00, defenseBonus: 0.04, minGoods: 0.15, minInvest: 0.10, moveCost: 1.00,  recruitCost: 1.00,  sinceEra: 0 }),
  R('republic', { incMul: 1.20, stabCeil: 75,  colonyFree: false, rebelChance: 0,    incTax: 1.25, incProd: 1.10, adminCost: 0.85, accTax: 40, upkeep: 1.00, defenseBonus: 0.04, minGoods: 0.15, minInvest: 0.10, moveCost: 1.00,  recruitCost: 1.125, sinceEra: 0 }),
  R('empire',   { incMul: 1.10, stabCeil: 100, colonyFree: false, rebelChance: 0.05, incTax: 1.05, incProd: 1.05, adminCost: 1.20, accTax: 35, upkeep: 1.05, defenseBonus: 0.05, minGoods: 0.15, minInvest: 0.10, moveCost: 1.00,  recruitCost: 1.00,  sinceEra: 0 }),
  R('democracy',{ incMul: 1.00, stabCeil: 85,  colonyFree: false, rebelChance: 0,    incTax: 1.04, incProd: 1.00, adminCost: 1.04, accTax: 24, upkeep: 1.00, defenseBonus: 0.06, minGoods: 0.10, minInvest: 0.14, moveCost: 1.00,  recruitCost: 1.125, sinceEra: 0 }),
  R('communism',{ incMul: 1.00, stabCeil: 85,  colonyFree: false, rebelChance: 0.03, incTax: 0.98, incProd: 1.00, adminCost: 1.08, accTax: 28, upkeep: 0.97, defenseBonus: 0.03, minGoods: 0.15, minInvest: 0.10, moveCost: 1.00,  recruitCost: 1.00,  sinceEra: 3 }),
  R('fascism',  { incMul: 1.00, stabCeil: 85,  colonyFree: false, rebelChance: 0.03, incTax: 1.01, incProd: 1.04, adminCost: 1.00, accTax: 28, upkeep: 0.98, defenseBonus: 0.05, minGoods: 0.14, minInvest: 0.12, moveCost: 1.00,  recruitCost: 1.125, sinceEra: 3 }),
  R('horde',    { incMul: 1.00, stabCeil: 70,  colonyFree: true,  rebelChance: 0.02, incTax: 1.08, incProd: 0.96, adminCost: 1.04, accTax: 22, upkeep: 1.10, defenseBonus: 0.00, minGoods: 0.14, minInvest: 0.08, moveCost: 0.75,  recruitCost: 1.25,  sinceEra: 0 }),
  R('citystate',{ incMul: 1.00, stabCeil: 95,  colonyFree: false, rebelChance: 0,    incTax: 1.02, incProd: 1.02, adminCost: 1.20, accTax: 26, upkeep: 0.94, defenseBonus: 0.12, minGoods: 0.10, minInvest: 0.12, moveCost: 1.25,  recruitCost: 1.125, sinceEra: 0 }),
  R('rebels',   { incMul: 0.70, stabCeil: 60,  colonyFree: true,  rebelChance: 0,    incTax: 0.60, incProd: 0.80, adminCost: 1.50, accTax: 0,  upkeep: 1.20, defenseBonus: 0.08, minGoods: 0,    minInvest: 0,    moveCost: 1.00,  recruitCost: 1.50,  sinceEra: 0 }),
];
export const REGIME_ID = Object.fromEntries(REGIMES.map((r, i) => [r.id, i]));
export const REGIME_POOL = ['monarchy','republic','empire','democracy','feudal','communism','fascism','citystate','horde'].map(k => REGIME_ID[k]);

// Buildings (index+1 stored in Uint8Array; 0 = none)
export const BUILDINGS = [
  { id: 'fortress',   maxLevel: 2, buildTime: [3, 4],       cost: [150, 220],              mp: [1, 2],       tech: [0.5, 1.5] },
  { id: 'armory',     maxLevel: 1, buildTime: [4],          cost: [100],                   mp: [1],          tech: [0.4] },
  { id: 'port',       maxLevel: 1, buildTime: [1],          cost: [120],                   mp: [1],          tech: [0] },
  { id: 'market',     maxLevel: 1, buildTime: [1],          cost: [100],                   mp: [1],          tech: [0] },
  { id: 'watchtower', maxLevel: 1, buildTime: [1],          cost: [60],                    mp: [1],          tech: [0] },
  { id: 'supplycamp', maxLevel: 1, buildTime: [3],          cost: [90],                    mp: [1],          tech: [0.3] },
  { id: 'library',    maxLevel: 3, buildTime: [2, 3, 4],    cost: [90, 160, 260],          mp: [1, 1, 2],    tech: [0, 0.8, 2.0] },
  { id: 'farm',       maxLevel: 5, buildTime: [1, 1, 2, 2, 3], cost: [50, 70, 90, 110, 130], mp: [1, 1, 1, 1, 2], tech: [0, 0, 0.5, 1, 1.5] },
  { id: 'workshop',   maxLevel: 3, buildTime: [4, 5, 6],    cost: [80, 140, 200],          mp: [1, 1, 2],    tech: [0, 0.6, 1.2] },
];
export const B = Object.fromEntries(BUILDINGS.map((b, i) => [b.id, i + 1]));

export const PERSONALITIES = [
  { id: 'conqueror',   aggr: 0.85, econ: 0.40, dipl: 0.20, def: 0.55 },
  { id: 'merchant',    aggr: 0.25, econ: 0.90, dipl: 0.55, def: 0.50 },
  { id: 'diplomat',    aggr: 0.20, econ: 0.50, dipl: 0.95, def: 0.45 },
  { id: 'guardian',    aggr: 0.35, econ: 0.55, dipl: 0.50, def: 0.90 },
  { id: 'opportunist', aggr: 0.60, econ: 0.65, dipl: 0.45, def: 0.45 },
];

// Relations (Uint8 matrix)
export const REL = { PEACE: 0, WAR: 1, NAP: 2, ALLY: 3, MARRIAGE: 4 };

export const DIFFICULTY = {
  easy:   { startGold: 160, startManpower: 120, aiAggr: 0.7 },
  normal: { startGold: 100, startManpower: 90,  aiAggr: 1.0 },
  hard:   { startGold: 70,  startManpower: 70,  aiAggr: 1.3 },
};
export const COST = { recruitGold: 12, recruitMan: 18, mpAttack: 2, mpMove: 1, mpRecruit: 1, mpBuild: 2, dpWar: 3, dpPeace: 2, dpAlly: 4, dpNap: 2 };
export const TRUCE_TURNS = 8;
