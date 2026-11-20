## Estates (rules >= 5): the four orders of a state (nobility, clergy, merchants, army). Each has an INFLUENCE (its share of the realm's weight, from the government and from the institutions
## embraced) and a LOYALTY (0-100, drifting toward a target that reads the government, the taxes, war, stability, the institutions embraced and the privileges granted). A loyal estate with
## weight gives a lasting gain (income, levy, stability, research); a disloyal one costs the same and, below a line, petitions the crown (events). The player COURTS an estate (gold and a move:
## a lasting privilege, dear to the others); the AI courts the angriest when it can afford it. Pure functions of state, no dice. Data: data/estates.json.
class_name TBEstates
extends RefCounted

const COUNT := 4
const PRIV_MAX := 3
const DRIFT := 0.12                  # of the gap to the target closed every turn
const PRIV_TARGET := 4.0             # target loyalty per privilege held
const PRIV_OTHERS := 1.5             # what every other estate loses in its target per privilege
const COURT_GAIN := 10.0             # immediate loyalty from courting
const LOW := 35.0                    # below this an estate petitions
static var IDS: Array = []
static var ICON: Array = []
static var _w: Dictionary = {}
static var _inst: Dictionary = {}
static var _loaded := false

static func ensure() -> void:
	if _loaded: return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/estates.json"))
	if d is Dictionary:
		for e in (d["estates"] as Array): IDS.append(String(e["id"])); ICON.append(String(e["icon"]))
		_w = d["weights"]; _inst = d["inst"]
	_loaded = true

static func index_of(id: String) -> int:
	ensure()
	return IDS.find(id)

static func init(g: TBGame) -> void:
	ensure()
	g.est_loy.fill(50.0); g.est_priv.fill(0)
	for n in range(1, g.N1):
		for e in COUNT: g.est_loy[n * COUNT + e] = clampf(target(g, n, e), 5.0, 95.0)

## the weight of each estate before normalising: the government's, shifted by the institutions embraced
static func _weights(g: TBGame, n: int) -> Array:
	ensure()
	var base: Array = _w.get(String(TBData.REGIME_ID[g.regime[n]]), [25, 25, 25, 25])
	var out: Array = []
	for e in COUNT: out.append(float(base[e]))
	for i in TBInstitutions.count():
		if not TBInstitutions.embraced(g, n, i): continue
		var row: Variant = _inst.get(String(TBInstitutions.LIST[i]["id"]), null)
		if row == null: continue
		for e in COUNT: out[e] += float((row["w"] as Array)[e])
	for e in COUNT: out[e] = maxf(2.0, out[e])
	return out

static func share(g: TBGame, n: int, e: int) -> float:
	var w := _weights(g, n)
	var s := 0.0
	for x in w: s += float(x)
	return float(w[e]) / maxf(1.0, s)

static func loyalty(g: TBGame, n: int, e: int) -> float: return g.est_loy[n * COUNT + e]
static func privileges(g: TBGame, n: int, e: int) -> int: return g.est_priv[n * COUNT + e]

## what the estate is drifting toward this turn
static func target(g: TBGame, n: int, e: int) -> float:
	ensure()
	var t := 50.0 + (share(g, n, e) - 0.25) * 40.0
	for i in TBInstitutions.count():
		if not TBInstitutions.embraced(g, n, i): continue
		var row: Variant = _inst.get(String(TBInstitutions.LIST[i]["id"]), null)
		if row != null: t += float((row["t"] as Array)[e])
	var mine := privileges(g, n, e)
	var others := 0
	for o in COUNT: if o != e: others += privileges(g, n, o)
	t += PRIV_TARGET * float(mine) - PRIV_OTHERS * float(others)
	if e != 3: t -= 0.5 * (g.budget[n * 4] - 50.0)                              # the taxes burden the three civil estates
	var war := g.at_war(n)
	if e == 3 and war: t += 6.0
	if e == 2 and war: t -= 6.0
	var sa := 0.0; var k := 0
	for p in g.owned(n): sa += float(g.stab[p]); k += 1
	if k > 0: t += 0.15 * (sa / float(k) - 60.0)
	return clampf(t, 0.0, 100.0)

## the strength of what an estate gives (negative when it is angry): -1 .. 1 at a quarter's weight
static func strength(g: TBGame, n: int, e: int) -> float:
	return (loyalty(g, n, e) - 50.0) / 50.0 * minf(1.0, share(g, n, e) * 4.0)

static func income_mul(g: TBGame, n: int) -> float:
	if n <= 0: return 1.0
	return 1.0 + 0.06 * strength(g, n, 2)
static func levy_mul(g: TBGame, n: int) -> float:
	if n <= 0: return 1.0
	return 1.0 + 0.08 * strength(g, n, 0) + 0.06 * strength(g, n, 3)
static func research_mul(g: TBGame, n: int) -> float:
	if n <= 0: return 1.0
	return 1.0 - 0.03 * strength(g, n, 1)                                     # a devout court studies less
static func stab_add(g: TBGame, n: int) -> float:
	if n <= 0: return 0.0
	return 2.0 * strength(g, n, 0) + 3.0 * strength(g, n, 1)

## the lowest estate and its loyalty
static func angriest(g: TBGame, n: int) -> int:
	var worst := 0; var wl := 1000.0
	for e in COUNT:
		var l := loyalty(g, n, e)
		if l < wl: wl = l; worst = e
	return worst

static func tick(g: TBGame) -> void:
	ensure()
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		for e in COUNT:
			var i := n * COUNT + e
			g.est_loy[i] = clampf(g.est_loy[i] + (target(g, n, e) - g.est_loy[i]) * DRIFT, 0.0, 100.0)

static func cost(g: TBGame, n: int, e: int) -> int:
	return int(float(g.income(n)["gold"]) * 0.5 * float(1 + privileges(g, n, e)))

static func can_court(g: TBGame, n: int, e: int) -> Dictionary:
	ensure()
	var out := {"ok": true, "reason": "", "gold": 0, "moves": 1, "short": {}}
	if e < 0 or e >= COUNT or n <= 0 or g.alive[n] == 0: out["ok"] = false; out["reason"] = "unknown"; return out
	out["gold"] = cost(g, n, e)
	if privileges(g, n, e) >= PRIV_MAX: out["ok"] = false; out["reason"] = "est_max"
	elif g.gold[n] < float(out["gold"]): out["ok"] = false; out["reason"] = "gold"; out["short"]["gold"] = int(out["gold"]) - int(g.gold[n])
	elif g.mp[n] < 1.0: out["ok"] = false; out["reason"] = "mp"; out["short"]["moves"] = 1
	return out

static func court(g: TBGame, n: int, e: int) -> Dictionary:
	var c := can_court(g, n, e)
	if not bool(c["ok"]): return {"ok": false, "err": String(c["reason"])}
	g.gold[n] -= float(c["gold"]); g.mp[n] -= 1.0
	g.est_priv[n * COUNT + e] += 1
	g.est_loy[n * COUNT + e] = minf(100.0, g.est_loy[n * COUNT + e] + COURT_GAIN)
	g.log.append({"turn": g.turn, "kind": "estate_courted", "a": n, "e": e})
	return {"ok": true}

## the AI courts the angriest estate when it is angry and the treasury is full
static func ai_step(g: TBGame, n: int) -> void:
	if g.human[n] != 0: return
	var e := angriest(g, n)
	if loyalty(g, n, e) >= LOW: return
	var c := can_court(g, n, e)
	if bool(c["ok"]) and g.gold[n] >= 3.0 * float(c["gold"]): court(g, n, e)

## events: the loyalty of an estate moves by d (the op "loyalty" with "estate": id)
static func shift(g: TBGame, n: int, id: String, d: float) -> void:
	var e := index_of(id)
	if e < 0 or n <= 0: return
	var i := n * COUNT + e
	g.est_loy[i] = clampf(g.est_loy[i] + d, 0.0, 100.0)
