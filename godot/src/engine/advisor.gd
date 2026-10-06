## Advisor: derives alerts and tips from the current state (pure read; never mutates). Severity 2 = crisis, 1 = warning, 0 = tip.
class_name TBAdvisor
extends RefCounted

const D = preload("res://src/engine/data.gd")

## -> Array of {"id": String, "sev": int, "p": int (province to look at or -1), "k": int (count/amount for the text)}
static func alerts(g: TBGame, n: int) -> Array:
	var out: Array = []
	if n <= 0 or g.alive[n] == 0: return out
	var inc := g.income(n)
	var net: int = inc["net"]
	if g.gold[n] <= 0.0 and net < 0: out.append(_a("bankrupt", 2, g.capital_of[n]))
	elif net < 0 and g.gold[n] < -net * 4: out.append(_a("low_treasury", 1, -1, int(g.gold[n] / -net)))
	if inc["capLost"]: out.append(_a("capital_lost", 2, g.capital_of[n]))
	# frontier threat / occupation / unrest / war leverage
	var threat_p := -1; var threat_ratio := 0.0; var occ := 0; var occ_p := -1
	var unrest := 0; var unrest_p := -1; var unrest_min := 101
	var unrest_ps: Array = []
	var own := g.owned(n)
	for p in own:
		if g.occupier[p] != 0 and g.get_rel(n, g.occupier[p]) == D.REL_WAR:
			occ += 1
			if occ_p < 0 or g.capital[p] != 0: occ_p = p
		if g.capital[p] == 0 and g.stab[p] < 30:
			unrest += 1; unrest_ps.append(p)
			if g.stab[p] < unrest_min: unrest_min = g.stab[p]; unrest_p = p
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			var eo: int = g.owner[q]
			if eo == 0 or eo == n or g.get_rel(n, eo) != D.REL_WAR: continue
			if g.occupier[q] == n: continue
			if g.nb_sea[i] != 0 and g.building[q] != D.B_PORT: continue
			var r := float(g.army[q]) / float(maxi(1, g.army[p]))
			if g.army[q] >= 6 and r > 1.3 and r > threat_ratio: threat_ratio = r; threat_p = p
	if threat_p >= 0: out.append(_a("threat", 2, threat_p, int(round(threat_ratio * 10.0))))
	if occ > 0: out.append(_a("occupied", 1, occ_p, occ))
	if unrest > 0:
		unrest_ps.sort_custom(func(a: int, b: int) -> bool: return g.stab[a] < g.stab[b])
		var ua := _a("unrest", 1, unrest_p, unrest); ua["ps"] = unrest_ps; out.append(ua)
	# read-only HUD additions: war declared on us during the last resolution, armies starving outside our land
	if g.rules >= 1:
		var wd := _war_declared(g, n)
		if wd > 0: out.append(_a("war_declared", 2, g.capital_of[n], 0, wd))
		var starving: Array = []
		for q in g.P:
			if g.army[q] > 0 and g.owner[q] != n and g.controller(q) == n and g.attrition(q) > 0: starving.append(q)
		if not starving.is_empty():
			starving.sort_custom(func(a: int, b: int) -> bool: return g.attrition(a) > g.attrition(b))
			var sa := _a("attrition", 1, starving[0], starving.size()); sa["ps"] = starving; out.append(sa)
	if g.rules >= 1:
		if g.coalition[n] != 0: out.append(_a("coalition", 2, -1, int(g.infamy[n])))
		elif g.infamy[n] >= 12.0: out.append(_a("infamy", 1, -1, int(g.infamy[n])))
	# opportunities
	var best_ws := 0; var best_o := 0
	var wars := 0
	for o in range(1, g.N1):
		if g.alive[o] == 0 or g.get_rel(n, o) != D.REL_WAR: continue
		wars += 1
		if g.war_score[n * g.N1 + o] > best_ws: best_ws = g.war_score[n * g.N1 + o]; best_o = o
	if best_ws >= 25: out.append(_a("war_winning", 0, g.capital_of[best_o], best_ws))
	if g.gold[n] > 250.0 and net >= 0: out.append(_a("idle_gold", 0, -1, int(g.gold[n])))
	var cap_mp := 6.0 + g.era[n] * 2.0
	if g.rules >= 1 and g.trade_cnt[n] == 0 and g.dp[n] >= 2.0 and g.turn > 4: out.append(_a("no_trade", 0, -1))
	if g.rules >= 1 and g.turn > 2:
		if TBGenerals.count(g, n) < TBGenerals.cap(g, n) and g.gold[n] >= TBGenerals.cost(g, n) + 60:
			var gp := -1; var gbest := 0
			for p in own:
				if g.gen[p] == 0 and g.army[p] >= TBGenerals.MIN_ARMY and g.army[p] > gbest and g.controller(p) == n: gbest = g.army[p]; gp = p
			if gp >= 0: out.append(_a("no_general", 0, gp))
		if g.dp[n] >= TBDiplo.DP_ULT and g.infamy[n] < 12.0:
			var seen := {}
			var up := -1; var ur := 0.0
			for p in own:
				for i in range(g.nb_off[p], g.nb_off[p + 1]):
					var t: int = g.owner[g.nb[i]]
					if t == 0 or t == n or seen.has(t) or g.nb_sea[i] != 0: continue
					seen[t] = true
					if g.get_rel(n, t) != D.REL_PEACE or g.has_truce(n, t): continue
					var rr := TBDiplo.ult_ratio(g, n, t)
					if rr >= TBDiplo.ULT_RATIO + 0.2 and rr > ur:
						var tp := TBDiplo.ult_target(g, n, t)
						if tp >= 0: ur = rr; up = tp
			if up >= 0: out.append(_a("ult_chance", 0, up, int(ur * 10.0)))
	if g.mp[n] >= cap_mp - 0.5: out.append(_a("idle_mp", 0, -1))
	if g.manpower[n] >= inc["manCap"] * 0.95 and inc["manCap"] > 50: out.append(_a("idle_men", 0, -1))
	if g.budget[n * 4 + 2] == 0: out.append(_a("no_research", 0, -1))
	if wars == 0 and g.turn > 3 and g.gold[n] > 120.0: out.append(_a("peacetime", 0, -1))
	out.sort_custom(func(a, b): return int(a["sev"]) > int(b["sev"]))
	return out

## "n" = the other nation concerned (-1 none), "ps" = every province behind a merged alert (unrest, attrition)
static func _a(id: String, sev: int, p: int, k: int = 0, other: int = -1) -> Dictionary:
	return {"id": id, "sev": sev, "p": p, "k": k, "n": other, "ps": []}

## the nation that declared war on n in the last resolved turn (and is still at war with it), else 0
static func _war_declared(g: TBGame, n: int) -> int:
	var i := g.log.size() - 1
	while i >= 0:
		var e: Dictionary = g.log[i]
		if int(e["turn"]) < g.turn - 1: break
		if String(e["kind"]) == "war" and int(e.get("b", -1)) == n and int(e.get("a", 0)) > 0 and g.alive[int(e["a"])] != 0 and g.get_rel(n, int(e["a"])) == D.REL_WAR: return int(e["a"])
		i -= 1
	return 0

## crisis ids, used to toast only what is *new* after a turn
static func crisis_ids(al: Array) -> PackedStringArray:
	var s := PackedStringArray()
	for a in al:
		if int(a["sev"]) >= 2: s.append(String(a["id"]))
	return s

# ---------------------------------------------------------------- HUD support (read-only helpers; never mutate state)

## ticker classes, most urgent first (design/ux/hud.md section 8)
const CLASSES := ["war", "revolt", "offer", "event", "supply"]

## alert id -> ticker class; "" = a tip / opportunity, which never enters the ticker
static func class_of(id: String) -> String:
	match id:
		"threat", "occupied", "capital_lost", "coalition", "war_declared", "bankrupt": return "war"      # a bankrupt treasury is promoted to class 1
		"unrest": return "revolt"
		"low_treasury", "attrition": return "supply"
	return ""

## everything the alert ticker shows, priority sorted: criticals first, then class order, then severity.
## Entry: {key (stable), cls, sev, id, p (subject province or -1), n (other nation or -1), k, uid (pending prompt or -1), ps (all provinces), ult}
## Alerts are state-based: re-evaluated on every call, so a chip is gone as soon as its condition is.
static func ticker(g: TBGame, n: int) -> Array:
	var out: Array = []
	if n <= 0 or g.alive[n] == 0: return out
	for a in alerts(g, n):
		var cls := class_of(String(a["id"]))
		if cls == "": continue
		out.append({"key": "a:" + String(a["id"]), "cls": cls, "sev": int(a["sev"]), "id": String(a["id"]), "p": int(a["p"]), "n": int(a["n"]), "k": int(a["k"]), "uid": -1, "ps": a["ps"], "ult": false})
	for e in g.pending:
		if int(e["n"]) != n: continue
		var uid: int = int(e["uid"])
		if String(e["kind"]) == "prop":
			var ult: bool = String(e["id"]) == "ultimatum"
			out.append({"key": "o:%d" % uid, "cls": "offer", "sev": 2 if ult else 1, "id": String(e["id"]), "p": int(e.get("p", -1)), "n": int(e["from"]), "k": 0, "uid": uid, "ps": [], "ult": ult})
		else:
			out.append({"key": "e:%d" % uid, "cls": "event", "sev": 1, "id": String(e["id"]), "p": -1, "n": -1, "k": 0, "uid": uid, "ps": [], "ult": false})
	var order := func(a: Dictionary, b: Dictionary) -> bool:
		var ca: int = 0 if int(a["sev"]) >= 2 else 1
		var cb: int = 0 if int(b["sev"]) >= 2 else 1
		if ca != cb: return ca < cb
		var ia: int = CLASSES.find(String(a["cls"])); var ib: int = CLASSES.find(String(b["cls"]))
		if ia != ib: return ia < ib
		return int(a["sev"]) > int(b["sev"])
	out.sort_custom(order)
	return out

## action-point cap and per-turn refill, diplomacy cap and gain (mirror of TBTurn._tick; used for chip tooltips)
static func mp_cap(g: TBGame, n: int) -> float: return 6.0 + g.era[n] * 2.0
static func mp_gain(g: TBGame, n: int) -> float: return 1.0 + g.era[n] * 0.4
static func dp_cap(g: TBGame, n: int) -> float: return 4.0 + g.era[n] * 2.0
static func dp_gain(g: TBGame, n: int) -> float: return 1.0 + g.era[n] * 0.3 + (TBRulers.dp_add(g, n) if g.rules >= 1 else 0.0)

## resource breakdown for the HUD chips and their tooltips. `inc` may be passed to avoid recomputing g.income(n).
static func breakdown(g: TBGame, n: int, inc: Dictionary = {}) -> Dictionary:
	if inc.is_empty(): inc = g.income(n)
	var net: int = inc["net"]
	var gold: float = g.gold[n]
	var runs_out := -1                       # turns until the treasury is empty at the current net; -1 = never
	if net < 0: runs_out = 0 if gold <= 0.0 else int(ceil(gold / float(-net)))
	var man_cap: int = inc["manCap"]
	return {
		"gold": gold, "gross": int(inc["gold"]), "tax": int(inc["tax"]), "production": int(inc["production"]), "upkeep": int(inc["upkeep"]), "admin": int(inc["admin"]),
		"net": net, "runs_out": runs_out,
		"man": g.manpower[n], "man_cap": man_cap, "man_gain": int(inc["manpower"]), "man_full": g.manpower[n] >= man_cap * 0.95 and man_cap > 50,
		"mp": g.mp[n], "mp_cap": mp_cap(g, n), "mp_gain": mp_gain(g, n),
		"dp": g.dp[n], "dp_cap": dp_cap(g, n), "dp_gain": dp_gain(g, n),
		"lands": int(inc["lands"]),
	}
