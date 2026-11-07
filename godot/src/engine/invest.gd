## Investment in provinces, rules 4 (docs/PROVINCE_WORTH.md). The budget's investment share no longer rolls a die for each province every turn: it fills a progress bar in each province
## (economy and development), the same speed on average as before, and a level is gained when the bar is full. Returns shrink as economy outgrows what the people can work (the potential
## follows the population), and development waits for workers (job fill), so money into a province that cannot use it buys little.
class_name TBInvest
extends RefCounted

const D = preload("res://src/engine/data.gd")
const POP_PER_LEVEL := 70.0                    # people that support one level of economy
const OVER_STEP := 0.6                         # each level above the potential takes this much off the efficiency
const MIN_EFF := 0.10

## the economy level the province's people can work (1..5)
static func econ_potential(g: TBGame, p: int) -> float:
	return clampf(1.0 + float(g.pop[p]) / POP_PER_LEVEL, 1.0, 5.0)

## 1 while the economy is within the potential, falling to 0.1 as it runs past it
static func econ_eff(g: TBGame, p: int) -> float:
	var over: float = float(g.econ[p]) - econ_potential(g, p)
	return 1.0 if over <= 0.0 else maxf(MIN_EFF, 1.0 - over * OVER_STEP)

## 1 when the next development level has the workers for it, else 0 (the bar waits)
static func dev_eff(g: TBGame, p: int, dev_cap: int) -> float:
	if g.dev[p] >= dev_cap: return 0.0
	return 1.0 if g.job_fill(p, g.dev[p] + 1) >= 0.9 else 0.0

## one turn of a province: `rate` is the expected levels per turn the budget buys (investment share × 0.05 × the ruler's gift). Returns true when a level was gained.
static func step(g: TBGame, p: int, rate: float, dev_cap: int) -> bool:
	var gained := false
	if g.econ[p] < 5:
		g.inv_e[p] += rate * econ_eff(g, p)
		if g.inv_e[p] >= 1.0: g.inv_e[p] -= 1.0; g.econ[p] += 1; gained = true
	if g.dev[p] < dev_cap:
		g.inv_d[p] += rate * 0.15 * dev_eff(g, p, dev_cap)
		if g.inv_d[p] >= 1.0: g.inv_d[p] -= 1.0; g.dev[p] += 1; gained = true
	if g.econ[p] >= 5: g.inv_e[p] = 0.0
	if g.dev[p] >= dev_cap: g.inv_d[p] = minf(g.inv_d[p], 0.999)
	return gained

## what the player sees: the progress of each bar, 0..1
static func progress(g: TBGame, p: int) -> Dictionary:
	return {"econ": clampf(g.inv_e[p], 0.0, 1.0) if g.econ[p] < 5 else 1.0, "dev": clampf(g.inv_d[p], 0.0, 1.0)}

# ---------------------------------------------------------------- projects (rules 4): the Develop verb opens a choice of work, each costing gold and a move, running some turns, paying off at the end
const PROJECTS := ["dev", "econ", "settle", "order"]          # kind 1..4 (0 = none)
const PROJECT_MOVES := 1
const ORDER_CALM := 80                                         # stability at which public order has nothing left to mend
const ROOM_MAX := 2000

static func project_id(kind: int) -> String: return PROJECTS[kind - 1] if kind >= 1 and kind <= PROJECTS.size() else ""

static func project_cost(g: TBGame, p: int, kind: int) -> int:
	match kind:
		1: return g.develop_cost(p)
		2: return 35 + 30 * g.econ[p]
		3: return 50 + g.pop[p] / 10
		4: return 30 + (100 - g.stab[p]) / 2
	return 0

static func project_turns(g: TBGame, p: int, kind: int) -> int:
	match kind:
		1: return 3 if g.dev[p] < 3 else 4
		2: return 3
		3, 4: return 2
	return 0

## what the project would give, as numbers for the screen: {dev, econ, pop, stab} changes
static func project_gain(g: TBGame, p: int, kind: int) -> Dictionary:
	match kind:
		1: return {"dev": 1, "pop": 20, "stab": 4}
		2: return {"econ": 1 if econ_eff(g, p) >= 1.0 else 0, "econ_half": econ_eff(g, p) < 1.0}
		3: return {"pop": maxi(20, int(round(float(g.pop[p]) * 0.12)))}
		4: return {"stab": mini(12, 100 - g.stab[p])}
	return {}

## every requirement of a project: [[met, i18n key, vars]], and the reason (an err_ key) of the first one that is not met
static func project_needs(g: TBGame, n: int, p: int, kind: int) -> Array:
	var out: Array = []
	var cost := project_cost(g, p, kind)
	out.append([g.proj_kind[p] == 0, "proj_need_free", {}])
	match kind:
		1:
			var cap := clampi(int(floor(g.tech_level[n])) + 1, 1, 5)
			out.append([g.dev[p] < cap, "proj_need_level", {"t": cap}])
			var fill: float = g.job_fill(p, g.dev[p] + 1) if g.dev[p] < 5 else 0.0
			out.append([fill >= 0.9 or g.rules < 2, "proj_need_workers", {"n": int(roundf(minf(fill, 1.0) * 100.0))}])
		2: out.append([g.econ[p] < 5, "proj_need_econ", {}])
		3: out.append([g.pop[p] < ROOM_MAX, "proj_need_room", {"p": g.pop[p], "m": ROOM_MAX}])
		4: out.append([g.stab[p] < ORDER_CALM, "proj_need_calm", {"s": ORDER_CALM, "n": g.stab[p]}])
	out.append([g.gold[n] >= float(cost), "colony_need_gold", {"g": cost, "h": int(g.gold[n])}])
	out.append([g.mp[n] + 0.0001 >= float(PROJECT_MOVES), "colony_need_moves", {"m": PROJECT_MOVES, "h": snappedf(g.mp[n], 0.1)}])
	return out

## "" = possible, else the err_ key of the first requirement that fails
static func project_why(g: TBGame, n: int, p: int, kind: int) -> String:
	if g.rules < 4 or kind < 1 or kind > PROJECTS.size(): return "type"
	if p < 0 or p >= g.P or g.owner[p] != n or g.occupier[p] != 0: return "notyours"
	if g.proj_kind[p] != 0: return "project_busy"
	match kind:
		1:
			if g.dev[p] >= clampi(int(floor(g.tech_level[n])) + 1, 1, 5): return "max"
			if g.job_fill(p, g.dev[p] + 1) < 0.9: return "workers"
		2: if g.econ[p] >= 5: return "max"
		3: if g.pop[p] >= ROOM_MAX: return "max"
		4: if g.stab[p] >= ORDER_CALM: return "calm"
	if g.gold[n] < float(project_cost(g, p, kind)): return "gold"
	if g.mp[n] + 0.0001 < float(PROJECT_MOVES): return "mp"
	return ""

static func start(g: TBGame, n: int, p: int, kind: int) -> Dictionary:
	var why := project_why(g, n, p, kind)
	if why != "": return {"ok": false, "err": why}
	g.gold[n] -= float(project_cost(g, p, kind)); g.mp[n] -= float(PROJECT_MOVES)
	g.proj_kind[p] = kind; g.proj_left[p] = project_turns(g, p, kind)
	g.log.append({"turn": g.turn, "kind": "project", "a": n, "p": p, "k": kind})
	g.touch(p)
	return {"ok": true}

## one turn of a running project; returns the kind that was finished this turn (0 = none)
static func tick_project(g: TBGame, p: int) -> int:
	var k: int = g.proj_kind[p]
	if k == 0: return 0
	var o: int = g.owner[p]
	if o == 0 or g.occupier[p] != 0:                                       # a lost or occupied province stops the work
		g.proj_kind[p] = 0; g.proj_left[p] = 0; return 0
	g.proj_left[p] = maxi(0, int(g.proj_left[p]) - 1)
	if g.proj_left[p] > 0: return 0
	match k:
		1:
			g.dev[p] = mini(5, g.dev[p] + 1); g.stab[p] = mini(100, g.stab[p] + 4); g.pop[p] = mini(ROOM_MAX, g.pop[p] + 20); g.inv_d[p] = 0.0
		2:
			if econ_eff(g, p) >= 1.0: g.econ[p] = mini(5, g.econ[p] + 1)
			else:
				g.inv_e[p] += 0.5                                           # beyond what the people can work a project buys half a level
				if g.inv_e[p] >= 1.0: g.inv_e[p] -= 1.0; g.econ[p] = mini(5, g.econ[p] + 1)
		3: g.pop[p] = mini(ROOM_MAX, g.pop[p] + maxi(20, int(round(float(g.pop[p]) * 0.12))))
		4: g.stab[p] = mini(100, g.stab[p] + 12); g.happy[p] = mini(100, g.happy[p] + 5)
	g.proj_kind[p] = 0
	g.touch(p)
	g.log.append({"turn": g.turn, "kind": "project_done", "a": o, "p": p, "k": k})
	return k
