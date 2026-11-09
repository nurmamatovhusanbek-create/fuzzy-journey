## Rules 5: state works, the lasting things a rich realm builds with its treasury. Each has levels; a level costs turns of the realm's own output (so the bigger the realm, the more
## there is to buy) and the next one costs half as much again. The AI buys them too. Nothing is taken from anyone: gold is only ever spent by choice.
class_name TBWorks
extends RefCounted

## id, turns of the realm's labour output the first level costs, most levels, effect per level (shown as a percent where it is one)
static var LIST: Array = [
	{"id": "academy", "turns": 8.0, "max": 8, "per": 6.0},        # research +6 % a level
	{"id": "roads", "turns": 6.0, "max": 8, "per": 5.0},          # administration costs -5 % a level
	{"id": "granaries", "turns": 5.0, "max": 8, "per": 4.0},       # the land feeds 4 % more people a level
	{"id": "guard", "turns": 5.0, "max": 8, "per": 5.0},           # the levy pools hold 5 % more a level
	{"id": "palace", "turns": 12.0, "max": 5, "per": 3.0},         # income +3 % and stability +1 a level
	{"id": "canals", "turns": 6.0, "max": 6, "per": 5.0},         # trade routes yield 5 % more a level
]
const COUNT := 6
const MP_COST := 2.0
const GROWTH := 1.5
const LABOUR_TO_INCOME := 1.5          # a realm's gross income is about this many times its base labour output

static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id: return i
	return -1

static func level(g: TBGame, n: int, i: int) -> int:
	if g.rules < 5 or n <= 0 or g.works.size() != g.N1 * COUNT: return 0
	return g.works[n * COUNT + i]

static func cost(g: TBGame, n: int, i: int) -> int:
	var w: Dictionary = LIST[i]
	return int(ceil(float(w["turns"]) * g.labour(n) * LABOUR_TO_INCOME * pow(GROWTH, float(level(g, n, i)))))

## "" or why not
static func why_not(g: TBGame, n: int, i: int) -> String:
	if g.rules < 5: return "rules"
	if level(g, n, i) >= int(LIST[i]["max"]): return "max"
	if g.gold[n] < float(cost(g, n, i)): return "gold"
	if g.mp[n] + 0.0001 < MP_COST: return "mp"
	return ""

static func buy(g: TBGame, n: int, id: String) -> Dictionary:
	var i := index_of(id)
	if i < 0: return {"ok": false, "err": "unknown"}
	var why := why_not(g, n, i)
	if why != "": return {"ok": false, "err": why}
	var c := cost(g, n, i)
	g.gold[n] -= float(c); g.mp[n] -= MP_COST
	g.works[n * COUNT + i] += 1
	g.log.append({"turn": g.turn, "kind": "works", "a": n, "id": id, "lvl": g.works[n * COUNT + i]})
	return {"ok": true, "lvl": g.works[n * COUNT + i], "gold": c}

## the multipliers and terms the rest of the engine asks for (1.0 and 0.0 when there are none)
static func _pct(g: TBGame, n: int, id: String) -> float: return float(level(g, n, index_of(id))) * float(LIST[index_of(id)]["per"]) / 100.0
static func research_mul(g: TBGame, n: int) -> float: return 1.0 + _pct(g, n, "academy")
static func admin_mul(g: TBGame, n: int) -> float: return 1.0 - _pct(g, n, "roads")
static func pop_cap_mul(g: TBGame, n: int) -> float: return 1.0 + _pct(g, n, "granaries")
static func levy_mul(g: TBGame, n: int) -> float: return 1.0 + _pct(g, n, "guard")
static func income_mul(g: TBGame, n: int) -> float: return (1.0 + _pct(g, n, "palace")) * (1.0 + 0.02 * float(TBRealms.done_count(g, n)))        # a united region pays 2 % more for good
static func stab_add(g: TBGame, n: int) -> float: return float(level(g, n, index_of("palace")))
static func trade_mul(g: TBGame, n: int) -> float: return 1.0 + _pct(g, n, "canals")

## the AI's turn at the treasury: the work it wants most that it can pay for with three turns of income to spare
static func ai_buy(g: TBGame, n: int, pers: Dictionary, at_war: bool) -> void:
	if g.rules < 5 or g.mp[n] < MP_COST + 1.0: return
	var income: float = float(g.income(n)["gold"])
	var reserve: float = 3.0 * income
	var rounds: int = 1 + (2 if g.gold[n] > 25.0 * income else 0)           # a realm sitting on twenty-five turns of income spends it faster
	var order: Array = ["granaries", "roads", "academy", "palace", "canals", "guard"]
	if at_war: order = ["guard", "granaries", "roads", "palace", "academy", "canals"]
	elif float(pers["econ"]) > 0.7: order = ["palace", "academy", "granaries", "canals", "roads", "guard"]
	for _r in rounds:
		var done := false
		for id in order:
			var i := index_of(id)
			if why_not(g, n, i) == "" and g.gold[n] - float(cost(g, n, i)) >= reserve:
				buy(g, n, id); done = true; break
		if not done or g.mp[n] < MP_COST: return
