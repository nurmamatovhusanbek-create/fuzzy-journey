## Lineages (rules >= 5): a state is not stuck with the name it began with. Muscovy becomes the Russian Empire, the Empire becomes the USSR, the USSR the Russian Federation: each step is a
## stage the nation FORMS when it holds enough of that stage's historical core, lives under a government that fits it, and the year has come. Forming gives the new name and flag, historical
## claims on the core (a casus belli on whoever holds it), and a lasting bonus the size of which is the stage's weight. Data: data/lineages.json (tools/lineages/build.py from spec.json and the
## era files), so a release can add a line without touching the engine. Pure engine: RefCounted, no nodes.
class_name TBLineage
extends RefCounted

const D = preload("res://src/engine/data.gd")
const MP_COST := 3
const COST_TURNS := 6                # gold: turns of the nation's own output, times the stage's weight
static var STAGES: Array = []        # [{id, line, order, name, era, year, regimes, from, any, share, min, w, core}]
static var _by_id: Dictionary = {}
static var _loaded := false

static func ensure() -> void:
	if _loaded: return
	var txt := FileAccess.get_file_as_string("res://data/lineages.json")
	var d: Variant = JSON.parse_string(txt)
	if d is Dictionary:
		STAGES = (d as Dictionary).get("stages", [])
		for i in STAGES.size():
			_by_id[String(STAGES[i]["id"])] = i
			var rg: Array = []                                                  # JSON numbers come back as floats: compare as ints
			for r in (STAGES[i]["regimes"] as Array): rg.append(int(r))
			STAGES[i]["regimes"] = rg
			var cr: Array = []
			for q in (STAGES[i]["core"] as Array): cr.append(int(q))
			STAGES[i]["core"] = cr
	_loaded = true

static func index_of(id: String) -> int:
	ensure()
	return int(_by_id.get(id.to_lower(), -1))

## the stage a nation stands in now (its tag is a stage's tag), or -1
static func current(g: TBGame, n: int) -> int:
	ensure()
	if n <= 0 or n >= g.N1: return -1
	if g.stage.size() > n and g.stage[n] > 0: return g.stage[n] - 1
	return index_of(String(g.nat_code[n]))

static func line_of(si: int) -> String: return String(STAGES[si]["line"]) if si >= 0 and si < STAGES.size() else ""

## is the stage open to this nation at all (its tag is a predecessor, or the stage is open to anyone), whatever the conditions say
static func open_to(g: TBGame, n: int, si: int) -> bool:
	ensure()
	var s: Dictionary = STAGES[si]
	var code := String(g.nat_code[n]).to_lower()
	if code == String(s["id"]): return false
	if bool(s["any"]):
		var cur := current(g, n)                                                         # never back to an older stage of the line you already left
		return not (cur >= 0 and line_of(cur) == String(s["line"]) and int(STAGES[cur]["order"]) >= int(s["order"]))
	return (s["from"] as Array).has(code)

## the stages this nation could form someday: open to it, and not behind it
static func options(g: TBGame, n: int) -> Array:
	ensure()
	var out: Array = []
	if n <= 0 or g.alive[n] == 0 or n == g.rebel: return out
	for si in STAGES.size():
		if not open_to(g, n, si): continue
		if bool(STAGES[si]["any"]) and core_held(g, n, si) * 10 < (STAGES[si]["core"] as Array).size() * 3: continue      # a stage open to anyone is on offer only to a state that already holds a third of its land
		out.append(si)
	return out

static func core_held(g: TBGame, n: int, si: int) -> int:
	var k := 0
	for p in (STAGES[si]["core"] as Array):
		if g.owner[int(p)] == n and g.occupier[int(p)] == 0: k += 1
	return k

static func core_need(si: int) -> int:
	var s: Dictionary = STAGES[si]
	return maxi(int(s["min"]), int(ceil(float(s["share"]) * float((s["core"] as Array).size()))))

## which provinces of a stage's core, and who holds them: the data behind "hold N of its M provinces". Rows are grouped by the owner, the player's own first, then the biggest holder;
## inside a row the provinces are by population, the largest first. A province of yours under enemy occupation is in your row and in "occ": it does not count as held.
## {need, have, total, rows: [{o, ps, occ}], missing: [p] (every province not held, the ones still to win)}
static func core_report(g: TBGame, n: int, si: int) -> Dictionary:
	ensure()
	var core: Array = STAGES[si]["core"]
	var by: Dictionary = {}
	var missing: Array = []
	for p in core:
		var pi: int = int(p)
		var o: int = g.owner[pi]
		if not by.has(o): by[o] = {"o": o, "ps": [], "occ": []}
		(by[o]["ps"] as Array).append(pi)
		var held: bool = o == n and g.occupier[pi] == 0
		if o == n and not held: (by[o]["occ"] as Array).append(pi)
		if not held: missing.append(pi)
	var rows: Array = by.values()
	for r in rows: (r["ps"] as Array).sort_custom(func(a: int, b: int) -> bool: return g.pop[a] > g.pop[b] if g.pop[a] != g.pop[b] else a < b)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (int(a["o"]) == n) != (int(b["o"]) == n): return int(a["o"]) == n
		if (int(a["o"]) == 0) != (int(b["o"]) == 0): return int(b["o"]) == 0                    # land nobody holds last
		var ka: int = (a["ps"] as Array).size(); var kb: int = (b["ps"] as Array).size()
		return ka > kb if ka != kb else int(a["o"]) < int(b["o"]))
	return {"need": core_need(si), "have": core_held(g, n, si), "total": core.size(), "rows": rows, "missing": missing}

static func gold_cost(g: TBGame, n: int, si: int) -> int:
	return int(ceil(g.labour(n) * float(COST_TURNS) * float(STAGES[si]["w"])))

## the conditions as data: [{key, ok, have, need}], for the UI and the command alike; every one must be ok
static func conditions(g: TBGame, n: int, si: int) -> Array:
	var s: Dictionary = STAGES[si]
	var out: Array = []
	out.append({"key": "year", "ok": g.year >= int(s["year"]), "have": g.year, "need": int(s["year"])})
	var regimes: Array = s["regimes"]
	out.append({"key": "regime", "ok": regimes.has(g.regime[n]), "have": g.regime[n], "need": regimes})
	var need := core_need(si); var have := core_held(g, n, si)
	out.append({"key": "core", "ok": have >= need, "have": have, "need": need})
	var cost := gold_cost(g, n, si)
	out.append({"key": "gold", "ok": g.gold[n] >= float(cost), "have": int(g.gold[n]), "need": cost})
	out.append({"key": "moves", "ok": g.mp[n] >= float(MP_COST), "have": int(g.mp[n]), "need": MP_COST})
	return out

static func can_form(g: TBGame, n: int, si: int) -> Dictionary:
	var out := {"ok": true, "reason": "", "gold": 0, "moves": MP_COST, "men": 0, "dp": 0, "short": {}, "gain": 0, "kind": "", "infamy": 0.0}
	ensure()
	if si < 0 or si >= STAGES.size(): out["ok"] = false; out["reason"] = "unknown"; return out
	if n <= 0 or g.alive[n] == 0 or n == g.rebel or not open_to(g, n, si): out["ok"] = false; out["reason"] = "notopen"; return out
	out["gold"] = gold_cost(g, n, si)
	for c in conditions(g, n, si):
		if not bool(c["ok"]):
			out["ok"] = false
			if out["reason"] == "": out["reason"] = "form_" + String(c["key"])
			if String(c["key"]) == "gold": out["short"]["gold"] = int(c["need"]) - int(c["have"])
			if String(c["key"]) == "moves": out["short"]["moves"] = int(c["need"]) - int(c["have"])
	return out

## do it: the new name and tag, the claims, the bonus; the cost is paid. Returns {ok} or {ok: false, err}
static func form(g: TBGame, n: int, si: int) -> Dictionary:
	var c := can_form(g, n, si)
	if not bool(c["ok"]): return {"ok": false, "err": String(c["reason"])}
	var s: Dictionary = STAGES[si]
	g.gold[n] -= float(c["gold"]); g.mp[n] -= float(MP_COST)
	var old_name: String = g.nat_name[n]
	g.nat_name[n] = String(s["name"]); g.nat_code[n] = String(s["id"])
	g.stage[n] = si + 1
	var claimed := 0
	for p in (s["core"] as Array):
		var pi: int = int(p)
		if g.owner[pi] == n:
			if not g.core.is_empty(): g.core[pi] = n
		elif g.owner[pi] != 0 and g.owner[pi] != n:
			g.claim[pi] = n; claimed += 1
	g.dp[n] += float(s["w"])
	g.log.append({"turn": g.turn, "kind": "formed", "a": n, "b": si, "name": old_name, "k": claimed})
	g.occ_rev += 1
	g.ident_rev += 1
	return {"ok": true}

# ---- the lasting bonus: grows with the stage's weight (1..3), read by the income, levy, research and stability code
static func w(g: TBGame, n: int) -> int:
	var si := current(g, n)
	return int(STAGES[si]["w"]) if si >= 0 else 0

static func income_mul(g: TBGame, n: int) -> float: return 1.0 + 0.02 * float(w(g, n))
static func levy_mul(g: TBGame, n: int) -> float: return 1.0 + 0.04 * float(w(g, n))
static func research_mul(g: TBGame, n: int) -> float: return 1.0 + 0.03 * float(w(g, n))
static func stab_add(g: TBGame, n: int) -> float: return float(w(g, n))

## a nation that has never formed anything starts in the stage of its own tag (if it has one): called once when a game is made
static func init_stages(g: TBGame) -> void:
	ensure()
	for n in range(1, g.N1):
		var si := index_of(String(g.nat_code[n]))
		g.stage[n] = si + 1 if si >= 0 else 0

## AI: a nation that can form a stage does so (a few turns apart), the way history went: the strongest claim first
static func ai_step(g: TBGame, n: int) -> void:
	if (g.turn + n) % 4 != 0 or g.human[n] != 0: return
	var best := -1; var best_w := -1
	for si in options(g, n):
		if bool(can_form(g, n, si)["ok"]) and int(STAGES[si]["w"]) > best_w: best = si; best_w = int(STAGES[si]["w"])
	if best >= 0: form(g, n, best)
