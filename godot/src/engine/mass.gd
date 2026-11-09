## Rules 5: orders that work on many provinces at once, so a realm of a hundred provinces is not run one tap at a time.
##   spread  one province's army marches out to the provinces that need it most (the front first), keeping a guard at home
##   muster  every province on the front raises a share of its levy pool, paid in one go
## Both cost one move plus one more for every few provinces they touch. The engine, the interface and the AI all use the same plans, so a preview and the order agree.
class_name TBMass
extends RefCounted

const KEEP_HOME := 0.30                 # of the army that stays where it stands
const MAX_TARGETS := 8
const PER_MOVE := 4                     # provinces a single move point covers after the first
const MIN_PCT := 5
const MAX_PCT := 100
const DEFAULT_PCT := 25

## is p one of n's own provinces on a front: next to land that is not n's (a foreign realm, a free land, an enemy held province)
static func is_front(g: TBGame, n: int, p: int) -> bool:
	if g.owner[p] != n or g.controller(p) != n: return false
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		if g.nb_sea[i] != 0: continue
		var q: int = g.nb[i]
		if g.owner[q] != n or g.controller(q) != n: return true
	return false

static func fronts(g: TBGame, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in g.owned(n):
		if is_front(g, n, p): out.append(p)
	return out

static func _moves(k: int) -> float: return 1.0 + float(maxi(0, k - 1) / PER_MOVE)

## where p's army would go: {ok, err, targets: [[province, men]], mp, kept}
static func spread_plan(g: TBGame, n: int, p: int) -> Dictionary:
	var out := {"ok": false, "err": "", "targets": [], "mp": 0.0, "kept": 0, "sent": 0}
	if g.rules < 5: out["err"] = "rules"; return out
	if p < 0 or p >= g.P or g.controller(p) != n or g.owner[p] != n: out["err"] = "notyours"; return out
	var a: int = g.army[p]
	var floor_men: int = g.au(10.0)
	if a < floor_men * 2: out["err"] = "army"; return out
	var reach: Dictionary = TBMarch.targets(g, n, p)
	var cands: Array = []
	var front_exists := false
	for q in reach:
		if int(q) == p or String((reach[q] as Dictionary)["kind"]) != "move": continue
		if g.owner[q] != n or g.controller(q) != n: continue
		var fr: bool = is_front(g, n, int(q))
		if fr: front_exists = true
		var score: float = (2.0 if fr else 1.0) * float(maxi(1, g.pop[q])) / (1.0 + float(g.army[q]) / float(g.au(50.0)))
		cands.append([score, int(q), fr])
	if cands.is_empty(): out["err"] = "notargets"; return out
	if front_exists: cands = cands.filter(func(x): return bool(x[2]))
	cands.sort_custom(func(x, y): return float(x[0]) > float(y[0]) if float(x[0]) != float(y[0]) else int(x[1]) < int(y[1]))
	var k: int = clampi(a / maxi(1, g.au(30.0)), 2, MAX_TARGETS)
	cands = cands.slice(0, mini(k, cands.size()))
	var total_w := 0.0
	for c in cands: total_w += float(c[0])
	var send_total: int = int(float(a) * (1.0 - KEEP_HOME))
	var targets: Array = []
	var sent := 0
	for c in cands:
		var men: int = int(float(send_total) * float(c[0]) / total_w)
		if men < g.au(5.0): continue
		targets.append([int(c[1]), men]); sent += men
	if targets.is_empty(): out["err"] = "army"; return out
	out["targets"] = targets; out["mp"] = _moves(targets.size()); out["sent"] = sent; out["kept"] = a - sent; out["ok"] = true
	return out

static func spread(g: TBGame, n: int, p: int) -> Dictionary:
	var pl := spread_plan(g, n, p)
	if not bool(pl["ok"]): return {"ok": false, "err": String(pl["err"])}
	if g.mp[n] + 0.0001 < float(pl["mp"]): return {"ok": false, "err": "mp"}
	var done := 0; var sent := 0
	for t in pl["targets"]:
		var r := TBMarch.order(g, n, p, int(t[0]), int(t[1]))
		if not r.begins_with("!"): done += 1; sent += int(t[1])
	if done == 0: return {"ok": false, "err": "notargets"}
	g.mp[n] -= float(pl["mp"])
	return {"ok": true, "k": done, "sent": sent}

## what a muster would raise: {ok, err, items: [[province, men, gold]], gold, men, mp}
static func muster_plan(g: TBGame, n: int, pct: int) -> Dictionary:
	var out := {"ok": false, "err": "", "items": [], "gold": 0, "men": 0, "mp": 0.0}
	if g.rules < 5: out["err"] = "rules"; return out
	pct = clampi(pct, MIN_PCT, MAX_PCT)
	var reg: Dictionary = TBData.REGIMES[g.regime[n]]
	var items: Array = []
	var gold := 0; var men := 0
	for p in fronts(g, n):
		var room: int = g.recruit_range(p).y
		var amount: int = int(float(room) * float(pct) / 100.0)
		if amount < 1: continue
		var cost: int = TBCan.recruit_gold(g, p, amount, reg)
		items.append([p, amount, cost]); gold += cost; men += amount
	if items.is_empty(): out["err"] = "manpower"; return out
	out["items"] = items; out["gold"] = gold; out["men"] = men; out["mp"] = _moves(items.size()); out["ok"] = true
	return out

static func muster(g: TBGame, n: int, pct: int) -> Dictionary:
	var pl := muster_plan(g, n, pct)
	if not bool(pl["ok"]): return {"ok": false, "err": String(pl["err"])}
	if g.mp[n] + 0.0001 < float(pl["mp"]): return {"ok": false, "err": "mp"}
	var spent := 0.0; var raised := 0; var k := 0
	for it in pl["items"]:                                        # as many provinces as the treasury pays for, dearest last
		if g.gold[n] - spent < float(it[2]): continue
		spent += float(it[2]); raised += int(it[1]); k += 1
		var p: int = int(it[0]); var amount: int = int(it[1])
		g.levy[p] -= amount; g.manpower[n] = maxf(0.0, g.manpower[n] - float(amount))
		g.army[p] = mini(g.army_cap(p), g.army[p] + amount); g.touch(p)
	if k == 0: return {"ok": false, "err": "gold"}
	g.gold[n] -= spent; g.mp[n] -= float(pl["mp"])
	return {"ok": true, "k": k, "men": raised, "gold": int(spent)}
