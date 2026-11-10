## Rules >= 5: "Raise troops", the one order that stands for Recruit and Hire. You say how many men; they come out of the province's levy pool first (a fee and a price per man,
## the people leave the fields) and the rest are hired (gold only, forty-five worker-turns a man). One move point. The old commands stay in the engine (saves, the AI, replays).
class_name TBRaise
extends RefCounted

const D = preload("res://src/engine/data.gd")

## how many men the province can still take: room under its army cap, the levy pool and what a hired company can add
static func max_amount(g: TBGame, p: int) -> int:
	var room: int = maxi(0, g.army_cap(p) - g.army[p])
	return mini(room, pool(g, p) + g.au(60.0))

static func pool(g: TBGame, p: int) -> int: return maxi(0, mini(g.levy[p], g.levy_cap(p)))

## the usual number to offer: the whole of a tenth of the pool, else a small company
static func default_amount(g: TBGame, p: int) -> int:
	var hi: int = max_amount(g, p)
	var pl: int = pool(g, p)
	return clampi(maxi(1, pl / 10) if pl > 0 else g.au(10.0), 1, maxi(1, hi))

## {amount, levy, hired, levy_gold, hire_gold, gold}: what raising `amount` men in p costs, and from where they come
static func plan(g: TBGame, n: int, p: int, amount: int) -> Dictionary:
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	var a: int = clampi(amount, 1, maxi(1, max_amount(g, p)))
	var levy: int = mini(a, pool(g, p))
	var hired: int = a - levy
	var lg: int = TBCan.recruit_gold(g, p, levy, reg) if levy > 0 else 0
	var hg: int = int(ceil(float(hired) * g.wage(n) * 45.0 * float(reg["recruitCost"]))) if hired > 0 else 0
	return {"amount": a, "levy": levy, "hired": hired, "levy_gold": lg, "hire_gold": hg, "gold": lg + hg}

## the same men all hired: what the order saves
static func all_hired_gold(g: TBGame, n: int, amount: int) -> int:
	return int(ceil(float(amount) * g.wage(n) * 45.0 * float(D.REGIMES[g.regime[n]]["recruitCost"])))
