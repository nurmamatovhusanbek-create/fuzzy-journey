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
	if inc["capLost"]: out.append(_a("capital_lost", 2, -1))
	# frontier threat / occupation / unrest / war leverage
	var threat_p := -1; var threat_ratio := 0.0; var occ := 0; var occ_p := -1
	var unrest := 0; var unrest_p := -1; var unrest_min := 101
	var own := g.owned(n)
	for p in own:
		if g.occupier[p] != 0 and g.get_rel(n, g.occupier[p]) == D.REL_WAR:
			occ += 1
			if occ_p < 0 or g.capital[p] != 0: occ_p = p
		if g.capital[p] == 0 and g.stab[p] < 30:
			unrest += 1
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
	if unrest > 0: out.append(_a("unrest", 1, unrest_p, unrest))
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
	if g.mp[n] >= cap_mp - 0.5: out.append(_a("idle_mp", 0, -1))
	if g.manpower[n] >= inc["manCap"] * 0.95 and inc["manCap"] > 50: out.append(_a("idle_men", 0, -1))
	if g.budget[n * 4 + 2] == 0: out.append(_a("no_research", 0, -1))
	if wars == 0 and g.turn > 3 and g.gold[n] > 120.0: out.append(_a("peacetime", 0, -1))
	out.sort_custom(func(a, b): return int(a["sev"]) > int(b["sev"]))
	return out

static func _a(id: String, sev: int, p: int, k: int = 0) -> Dictionary:
	return {"id": id, "sev": sev, "p": p, "k": k}

## crisis ids, used to toast only what is *new* after a turn
static func crisis_ids(al: Array) -> PackedStringArray:
	var s := PackedStringArray()
	for a in al:
		if int(a["sev"]) >= 2: s.append(String(a["id"]))
	return s
