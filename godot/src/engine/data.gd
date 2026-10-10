## Static game tables (ported from the legacy engine; values preserved).
class_name TBData
extends RefCounted

const MONTHS := ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]

const ERAS := [
	{"id": "ancient", "incomeBonus": 0, "mpBonus": 0, "combatMul": 1.0},
	{"id": "classical", "incomeBonus": 2, "mpBonus": 1, "combatMul": 1.10},
	{"id": "medieval", "incomeBonus": 4, "mpBonus": 2, "combatMul": 1.25},
	{"id": "industrial", "incomeBonus": 7, "mpBonus": 3, "combatMul": 1.50},
	{"id": "modern", "incomeBonus": 10, "mpBonus": 4, "combatMul": 1.80},
]
const DEV_INCOME := [0, 1, 3, 6, 10, 15]
const TECH_STEP := 0.1
const ADMIN_DIST_FACTOR := 1.8

static func tech_needed(lvl: float) -> int:
	return int(round(60.0 * pow(1.08, lvl * 10.0)))

static func tech_gain(pop: float, pct: float) -> float:
	return (3.0 + floor(pop / 200.0)) * (pct / 100.0)

# Terrain: atk/def multipliers + spawn weights
const TERRAIN_ID := ["plains", "hills", "mountain", "forest", "marsh", "steppe"]
const TERRAIN_ATK := [1.10, 1.00, 0.85, 0.95, 0.80, 1.18]
const TERRAIN_WEIGHT := [30, 22, 14, 16, 8, 10]
const TERRAIN_TOTAL := 100
const TERRAIN_DEF := [0.0, 0.15, 0.30, 0.10, 0.0, 0.0]

# Regimes. Index = id stored in Packed arrays.
const REGIME_ID := ["tribal","feudal","monarchy","republic","empire","democracy","communism","fascism","horde","citystate","rebels"]
const REGIMES := [
	{"incMul": 0.85, "stabCeil": 75, "colonyFree": true, "rebelChance": 0.0, "incTax": 0.70, "incProd": 1.10, "adminCost": 0.70, "upkeep": 1.60, "defenseBonus": 0.10, "moveCost": 1.875, "recruitCost": 1.00, "sinceEra": 0},
	{"incMul": 0.95, "stabCeil": 85, "colonyFree": false, "rebelChance": 0.02, "incTax": 1.00, "incProd": 0.90, "adminCost": 1.00, "upkeep": 1.00, "defenseBonus": 0.02, "moveCost": 1.00, "recruitCost": 1.00, "sinceEra": 0},
	{"incMul": 1.00, "stabCeil": 90, "colonyFree": false, "rebelChance": 0.02, "incTax": 1.00, "incProd": 1.00, "adminCost": 1.00, "upkeep": 1.00, "defenseBonus": 0.04, "moveCost": 1.00, "recruitCost": 1.00, "sinceEra": 0},
	{"incMul": 1.20, "stabCeil": 75, "colonyFree": false, "rebelChance": 0.0, "incTax": 1.25, "incProd": 1.10, "adminCost": 0.85, "upkeep": 1.00, "defenseBonus": 0.04, "moveCost": 1.00, "recruitCost": 1.125, "sinceEra": 0},
	{"incMul": 1.10, "stabCeil": 100, "colonyFree": false, "rebelChance": 0.05, "incTax": 1.05, "incProd": 1.05, "adminCost": 1.20, "upkeep": 1.05, "defenseBonus": 0.05, "moveCost": 1.00, "recruitCost": 1.00, "sinceEra": 0},
	{"incMul": 1.00, "stabCeil": 85, "colonyFree": false, "rebelChance": 0.0, "incTax": 1.04, "incProd": 1.00, "adminCost": 1.04, "upkeep": 1.00, "defenseBonus": 0.06, "moveCost": 1.00, "recruitCost": 1.125, "sinceEra": 0},
	{"incMul": 1.00, "stabCeil": 85, "colonyFree": false, "rebelChance": 0.03, "incTax": 0.98, "incProd": 1.00, "adminCost": 1.08, "upkeep": 0.97, "defenseBonus": 0.03, "moveCost": 1.00, "recruitCost": 1.00, "sinceEra": 3},
	{"incMul": 1.00, "stabCeil": 85, "colonyFree": false, "rebelChance": 0.03, "incTax": 1.01, "incProd": 1.04, "adminCost": 1.00, "upkeep": 0.98, "defenseBonus": 0.05, "moveCost": 1.00, "recruitCost": 1.125, "sinceEra": 3},
	{"incMul": 1.00, "stabCeil": 70, "colonyFree": true, "rebelChance": 0.02, "incTax": 1.08, "incProd": 0.96, "adminCost": 1.04, "upkeep": 1.10, "defenseBonus": 0.00, "moveCost": 0.75, "recruitCost": 1.25, "sinceEra": 0},
	{"incMul": 1.00, "stabCeil": 95, "colonyFree": false, "rebelChance": 0.0, "incTax": 1.02, "incProd": 1.02, "adminCost": 1.20, "upkeep": 0.94, "defenseBonus": 0.12, "moveCost": 1.25, "recruitCost": 1.125, "sinceEra": 0},
	{"incMul": 0.70, "stabCeil": 60, "colonyFree": true, "rebelChance": 0.0, "incTax": 0.60, "incProd": 0.80, "adminCost": 1.50, "upkeep": 1.20, "defenseBonus": 0.08, "moveCost": 1.00, "recruitCost": 1.50, "sinceEra": 0},
]
## rules >= 1: annual rate at which the era's money loses value (price revolution, assignats, wartime printing...); a turn is half a year
const INFLATION_ANNUAL := {"ancient": 0.002, "roman": 0.005, "medieval": 0.004, "mongol": 0.006, "timurid": 0.005, "discovery": 0.015, "gunpowder": 0.008,
	"napoleonic": 0.020, "victorian": 0.003, "ww1": 0.050, "ww2": 0.050, "coldwar": 0.040, "modern": 0.030}
static func infl_base(era_id: String) -> float: return pow(1.0 + float(INFLATION_ANNUAL.get(era_id, 0.01)), 0.5) - 1.0

## rules >= 1: how warlike the AI world is (chosen when picking a nation). Level 1 is the original behaviour.
## mul = AI aggression multiplier, wars = extra simultaneous wars, cd = turns between declarations, ratio = army edge an AI wants before declaring, atk = edge it wants before attacking,
## peace = how much harder an AI is to talk into peace
const AGGRESSION := [
	{"id": "calm", "mul": 0.5, "wars": 0, "cd": 20, "ratio": 1.30, "atk": 1.25, "peace": 0.0},
	{"id": "normal", "mul": 1.0, "wars": 0, "cd": 10, "ratio": 1.15, "atk": 1.10, "peace": 0.0},
	{"id": "warlike", "mul": 1.7, "wars": 1, "cd": 6, "ratio": 1.00, "atk": 1.00, "peace": 0.10},
	{"id": "total", "mul": 2.6, "wars": 2, "cd": 3, "ratio": 0.90, "atk": 0.90, "peace": 0.25},
]

const REGIME_REBELS := 10
const REGIME_POOL := [2, 3, 4, 5, 1, 6, 7, 9, 8]

# Buildings (index+1 stored in Packed arrays; 0 = none)
const B_FORTRESS := 1
const B_ARMORY := 2
const B_PORT := 3
const B_MARKET := 4
const B_WATCHTOWER := 5
const B_SUPPLYCAMP := 6
const B_LIBRARY := 7
const B_FARM := 8
const B_WORKSHOP := 9
const BUILDINGS := [
	{"id": "fortress", "maxLevel": 2, "buildTime": [3, 4], "cost": [150, 220], "mp": [1, 2], "tech": [0.5, 1.5]},
	{"id": "armory", "maxLevel": 1, "buildTime": [4], "cost": [100], "mp": [1], "tech": [0.4]},
	{"id": "port", "maxLevel": 1, "buildTime": [1], "cost": [120], "mp": [1], "tech": [0.0]},
	{"id": "market", "maxLevel": 1, "buildTime": [1], "cost": [100], "mp": [1], "tech": [0.0]},
	{"id": "watchtower", "maxLevel": 1, "buildTime": [1], "cost": [60], "mp": [1], "tech": [0.0]},
	{"id": "supplycamp", "maxLevel": 1, "buildTime": [3], "cost": [90], "mp": [1], "tech": [0.3]},
	{"id": "library", "maxLevel": 3, "buildTime": [2, 3, 4], "cost": [90, 160, 260], "mp": [1, 1, 2], "tech": [0.0, 0.8, 2.0]},
	{"id": "farm", "maxLevel": 5, "buildTime": [1, 1, 2, 2, 3], "cost": [50, 70, 90, 110, 130], "mp": [1, 1, 1, 1, 2], "tech": [0.0, 0.0, 0.5, 1.0, 1.5]},
	{"id": "workshop", "maxLevel": 3, "buildTime": [4, 5, 6], "cost": [80, 140, 200], "mp": [1, 1, 2], "tech": [0.0, 0.6, 1.2]},
]

const PERSONALITIES := [
	{"id": "conqueror", "aggr": 0.85, "econ": 0.40, "dipl": 0.20, "def": 0.55},
	{"id": "merchant", "aggr": 0.25, "econ": 0.90, "dipl": 0.55, "def": 0.50},
	{"id": "diplomat", "aggr": 0.20, "econ": 0.50, "dipl": 0.95, "def": 0.45},
	{"id": "guardian", "aggr": 0.35, "econ": 0.55, "dipl": 0.50, "def": 0.90},
	{"id": "opportunist", "aggr": 0.60, "econ": 0.65, "dipl": 0.45, "def": 0.45},
]

# Relations (Uint8 matrix values)
const REL_PEACE := 0
const REL_WAR := 1
const REL_NAP := 2
const REL_ALLY := 3
const REL_MARRIAGE := 4

const DIFFICULTY := {
	"easy": {"startGold": 160, "startManpower": 120, "aiAggr": 0.7},
	"normal": {"startGold": 100, "startManpower": 90, "aiAggr": 1.0},
	"hard": {"startGold": 70, "startManpower": 70, "aiAggr": 1.3},
}
const COST_RECRUIT_GOLD := 12
const COST_RECRUIT_MAN := 18
const MP_ATTACK := 2
const MP_MOVE := 1
const MP_RECRUIT := 1
const DP_WAR := 3
const DP_PEACE := 2
const DP_ALLY := 4
const DP_NAP := 2
const TRUCE_TURNS := 8

const ERA_TECH_BASE := {"ancient": 0.0, "roman": 0.8, "medieval": 1.7, "mongol": 1.9, "timurid": 2.2, "discovery": 2.5, "gunpowder": 2.9, "napoleonic": 3.2, "victorian": 3.6, "ww1": 4.0, "ww2": 4.4, "coldwar": 4.6}
