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
