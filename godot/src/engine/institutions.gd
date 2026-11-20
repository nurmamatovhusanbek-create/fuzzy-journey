## Institutions (rules >= 5): the advances of an age (banking, printing, navigation, standing armies, joint stock, enlightenment, industry, railways, electricity, welfare, computing). Each is born in one
## historical place in its year, then SPREADS province to province (faster through neighbours, development and an owner who has embraced it). A state EMBRACES it once a quarter of its land has it, for
## a lasting gain; a state that does not, while the world has moved on, falls behind. Nothing is scripted per country: the AI plays by the same rules. Data: data/institutions.json. Pure engine.
class_name TBInstitutions
extends RefCounted

const D = preload("res://src/engine/data.gd")
const EMBRACE_SHARE := 0.25          # of a state's provinces that must carry it before it can be embraced
const KNOWN_SHARE := 0.30            # of the world's provinces: from here a state that has not embraced it is behind
const LAG_RESEARCH := 0.06           # per institution behind (at most LAG_MAX of them)
const LAG_INCOME := 0.02
const LAG_MAX := 4
static var LIST: Array = []
static var _loaded := false

static func ensure() -> void:
	if _loaded: return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/institutions.json"))
	if d is Array: LIST = d
	_loaded = true

static func count() -> int:
	ensure()
	return LIST.size()

static func index_of(id: String) -> int:
	ensure()
	for i in LIST.size():
		if String(LIST[i]["id"]) == id: return i
	return -1

static func has(g: TBGame, p: int, i: int) -> bool: return (g.inst[p] >> i) & 1 == 1
static func embraced(g: TBGame, n: int, i: int) -> bool: return (g.inst_ok[n] >> i) & 1 == 1

## the province nearest to a place
static func nearest(g: TBGame, lat: float, lon: float) -> int:
	var best := 0; var bd := 1e9
	for p in g.P:
		var d := TBGame.gc_dist(lon, lat, g.world.lon[p], g.world.lat[p])
		if d < bd: bd = d; best = p
	return best

## a game's start: what already exists in its year has spread around its birthplace by as much as the years since, and the states that are plainly in it have embraced it
static func init(g: TBGame) -> void:
	ensure()
	g.inst.fill(0); g.inst_ok.fill(0); g.inst_seen.fill(0)
	for i in LIST.size():
		var s: Dictionary = LIST[i]
		if int(s["year"]) > g.year: continue
		g.inst_seen[i] = 1
		var reach_km: float = clampf(500.0 + 9.0 * float(g.year - int(s["year"])), 500.0, 7000.0)
		for p in g.P:
			var km: float = TBGame.gc_dist(float(s["lon"]), float(s["lat"]), g.world.lon[p], g.world.lat[p]) * 6371.0
			var fuzz: float = 0.55 + 0.45 * float(TBRng.hash_str("%s:%d" % [s["id"], p]) % 100) / 100.0
			if km <= reach_km * fuzz: g.inst[p] |= (1 << i)
		g.inst[nearest(g, float(s["lat"]), float(s["lon"]))] |= (1 << i)
	refresh(g)
	for n in range(1, g.N1):
		if n == g.rebel or g.alive[n] == 0: continue
		for i in LIST.size():
			if g.inst_seen[i] == 1 and share(g, n, i) >= 0.5: g.inst_ok[n] |= (1 << i)

## the world's share of provinces that carry each institution (kept for the lag test, which runs inside the income)
static func refresh(g: TBGame) -> void:
	ensure()
	g.inst_share.resize(maxi(1, LIST.size()))
	var tot := 0.0
	for i in LIST.size():
		var k := 0
		for p in g.P: if (g.inst[p] >> i) & 1 == 1: k += 1
		g.inst_share[i] = float(k) / float(maxi(1, g.P))

## the share of nation n's provinces that carry institution i
static func share(g: TBGame, n: int, i: int) -> float:
	var tot := 0; var k := 0
	for p in g.owned(n):
		tot += 1
		if (g.inst[p] >> i) & 1 == 1: k += 1
	return float(k) / float(maxi(1, tot))

static func cost(g: TBGame, n: int, i: int) -> int:
	return int(ceil(g.labour(n) * float(LIST[i]["turns"])))

static func can_embrace(g: TBGame, n: int, i: int) -> Dictionary:
	ensure()
	var out := {"ok": true, "reason": "", "gold": 0, "moves": 2, "men": 0, "dp": 0, "short": {}, "gain": 0, "kind": "", "infamy": 0.0}
	if i < 0 or i >= LIST.size() or n <= 0 or g.alive[n] == 0: out["ok"] = false; out["reason"] = "unknown"; return out
	if g.inst_seen[i] == 0: out["ok"] = false; out["reason"] = "inst_unborn"; return out
	if embraced(g, n, i): out["ok"] = false; out["reason"] = "inst_have"; return out
	var sh := share(g, n, i)
	out["gold"] = cost(g, n, i)
	if sh < EMBRACE_SHARE: out["ok"] = false; out["reason"] = "inst_share"
	elif g.gold[n] < float(out["gold"]): out["ok"] = false; out["reason"] = "gold"; out["short"]["gold"] = int(out["gold"]) - int(g.gold[n])
	elif g.mp[n] < 2.0: out["ok"] = false; out["reason"] = "mp"; out["short"]["moves"] = 1
	return out

static func embrace(g: TBGame, n: int, i: int) -> Dictionary:
	var c := can_embrace(g, n, i)
	if not bool(c["ok"]): return {"ok": false, "err": String(c["reason"])}
	g.gold[n] -= float(c["gold"]); g.mp[n] -= 2.0
	g.inst_ok[n] |= (1 << i)
	g.log.append({"turn": g.turn, "kind": "inst_embraced", "a": n, "i": i})
	return {"ok": true}

# ---- the gains: summed over what the nation has embraced
static func _sum(g: TBGame, n: int, key: String) -> float:
	ensure()
	if n <= 0: return 0.0
	var s := 0.0
	for i in LIST.size():
		if embraced(g, n, i): s += float((LIST[i]["fx"] as Dictionary).get(key, 0.0))
	return s

## how many known institutions the nation has not embraced (capped)
static func lag(g: TBGame, n: int) -> int:
	ensure()
	if n <= 0: return 0
	var k := 0
	for i in LIST.size():
		if g.inst_seen[i] == 1 and not embraced(g, n, i) and i < g.inst_share.size() and g.inst_share[i] >= KNOWN_SHARE: k += 1
	return mini(k, LAG_MAX)

static func income_mul(g: TBGame, n: int) -> float: return 1.0 + _sum(g, n, "income") - LAG_INCOME * float(lag(g, n))
static func research_mul(g: TBGame, n: int) -> float: return 1.0 + _sum(g, n, "research") - LAG_RESEARCH * float(lag(g, n))
static func levy_mul(g: TBGame, n: int) -> float: return 1.0 + _sum(g, n, "levy")
static func pop_mul(g: TBGame, n: int) -> float: return 1.0 + _sum(g, n, "pop")
static func stab_add(g: TBGame, n: int) -> float: return _sum(g, n, "stab")

## per turn: births, then the spread
static func tick(g: TBGame) -> void:
	ensure()
	for i in LIST.size():
		var s: Dictionary = LIST[i]
		if g.inst_seen[i] == 0 and g.year >= int(s["year"]):
			g.inst_seen[i] = 1
			var p0 := nearest(g, float(s["lat"]), float(s["lon"]))
			g.inst[p0] |= (1 << i)
			g.log.append({"turn": g.turn, "kind": "inst_born", "i": i, "p": p0})
	var add := PackedInt32Array(); add.resize(g.P)
	for i in LIST.size():
		if g.inst_seen[i] == 0: continue
		var bit := 1 << i
		for p in g.P:
			if (g.inst[p] & bit) != 0: continue
			var nbs := g.nb_off[p + 1] - g.nb_off[p]
			if nbs <= 0: continue
			var with := 0
			for e in range(g.nb_off[p], g.nb_off[p + 1]):
				if (g.inst[g.nb[e]] & bit) != 0: with += 1
			if with == 0 and g.rng.next() > 0.0008: continue
			var o: int = g.owner[p]
			var chance := 0.0008 + 0.025 * float(with) / float(nbs)
			if o > 0 and (g.inst_ok[o] & bit) != 0: chance += 0.03
			chance += 0.002 * float(g.dev[p])
			if with > 0 and g.rng.next() < chance: add[p] |= bit
			elif with == 0: add[p] |= bit
	var changed := false
	for p in g.P:
		if add[p] != 0: g.inst[p] |= add[p]; changed = true
	refresh(g)
	if g.turn % 3 == 0 and changed: g.inst_rev += 1

## AI: embrace when it can afford it twice over; the oldest first
static func ai_step(g: TBGame, n: int) -> void:
	if g.human[n] != 0: return
	for i in LIST.size():
		var c := can_embrace(g, n, i)
		if bool(c["ok"]) and g.gold[n] >= 2.0 * float(c["gold"]): embrace(g, n, i); return
