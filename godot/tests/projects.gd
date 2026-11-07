extends SceneTree
## Rules 4: province worth follows people, economy, development and buildings and its trend shows; the Develop verb is a choice of projects that cost gold and a move, run turns and pay off at the end;
## a country's standing stars come from what everyone can see. Run: godot --headless -s tests/projects.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "timurid"), {"seed": 3, "rules": 4})
	var me := g.nat_code.find("timurid_empire"); g.set_human(me); g.pending.clear()
	var p := -1
	for q in g.owned(me): if w.id[q] == "uzb_samarkand": p = q
	g.gold[me] = 1000.0; g.mp[me] = 8.0
	# ---- worth follows its parts
	var v0 := g.province_value(p)
	g.pop[p] += 80; var v1 := g.province_value(p)
	_check(v1 > v0 + 0.9, "80 more people raise the worth (%.2f -> %.2f)" % [v0, v1])
	g.econ[p] = mini(5, g.econ[p] + 1); var v2 := g.province_value(p)
	_check(v2 > v1 + 0.7, "an economy level raises it (%.2f -> %.2f)" % [v1, v2])
	g.dev[p] += 1; var v3 := g.province_value(p)
	_check(v3 > v2 + 1.1, "a development level raises it (%.2f -> %.2f)" % [v2, v3])
	var st0 := g.stab[p]; g.stab[p] = 20; var v4 := g.province_value(p)
	_check(v4 < v3, "unrest lowers it (%.2f -> %.2f)" % [v3, v4])
	g.stab[p] = st0
	# ---- projects: cost, needs, effects
	var base := g.gold[me]
	g.pop[p] = 165; g.econ[p] = 3; g.dev[p] = 1; g.stab[p] = 60
	var cn := g.can({"cmd": "develop", "p": p, "k": 1})
	_check(bool(cn["ok"]) and int(cn["gold"]) > 0 and cn.has("needs") and (cn["needs"] as Array).size() >= 5, "a project lists its needs (%s)" % str(cn.get("reason", "")))
	var d0: int = g.dev[p]
	var r := g.apply({"cmd": "develop", "p": p, "k": 1, "n": me})
	_check(bool(r["ok"]) and g.proj_kind[p] == 1 and g.gold[me] < base and g.dev[p] == d0, "starting a project costs gold and the work has not paid yet")
	var again := g.can({"cmd": "develop", "p": p, "k": 2})
	_check(not bool(again["ok"]) and String(again["reason"]) == "project_busy", "one project at a time (%s)" % str(again["reason"]))
	for i in 4: TBTurn.end_turn(g)
	_check(g.proj_kind[p] == 0 and g.dev[p] >= d0 + 1, "development arrives when the work ends (dev %d -> %d, left %d)" % [d0, g.dev[p], g.proj_left[p]])
	# settlement and order
	g.gold[me] = 1000.0; g.mp[me] = 8.0; g.stab[p] = 90
	_check(String(g.can({"cmd": "develop", "p": p, "k": 4})["reason"]) == "calm", "public order is refused where stability is high")
	g.stab[p] = 50
	var pop0: int = g.pop[p]
	g.apply({"cmd": "develop", "p": p, "k": 3, "n": me})
	for i in 3: TBTurn.end_turn(g)
	_check(g.pop[p] > pop0, "settlement adds people (%d -> %d)" % [pop0, g.pop[p]])
	# ---- the trend
	TBTurn.end_turn(g)
	_check(g.worth_prev[p] > 0.0, "the worth before the turn is kept for the trend")
	# ---- standing stars: public facts only
	var s_me := TBStanding.stars(g, me)
	_check(s_me >= 1 and s_me <= 5, "standing is 1..5 (%d)" % s_me)
	var weak := g.nat_code.find("corsica")
	if weak > 0: _check(TBStanding.stars(g, weak) <= 2, "a one-province country is low (%d)" % TBStanding.stars(g, weak))
	# ---- stars have effects: a pact with a high-standing country weighs more, a demand on a weak one yields sooner
	var hi := -1; var lo := -1
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		var sn := TBStanding.stars(g, n)
		if sn >= 5 and hi < 0: hi = n
		if sn <= 1 and lo < 0: lo = n
	_check(hi > 0 and lo > 0, "there are five-star and one-star countries (%d, %d)" % [hi, lo])
	if hi > 0 and lo > 0:
		var tb := g.nat_code.find("france")
		var t_hi := TBDiplo.pact_terms(g, tb, hi, TBData.REL_NAP); var t_lo := TBDiplo.pact_terms(g, tb, lo, TBData.REL_NAP)
		var sh := 0.0; var sl := 0.0
		for x in t_hi: if x[0] == "dv_standing": sh = float(x[1])
		for x in t_lo: if x[0] == "dv_standing": sl = float(x[1])
		_check(sh > 0.0 and sl < 0.0, "a five-star country draws pacts, a one-star one is weighed down (%.2f, %.2f)" % [sh, sl])
		_check(TBDiplo.ult_need(g, lo, hi, 2.4) > TBDiplo.ult_need(g, hi, lo, 2.4), "a weak country is pressed sooner than a strong one")
	# ---- old rules keep the old worth and verb
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "timurid"), {"seed": 3, "rules": 3})
	var q3 := -1
	for q in g3.world.P: if w.id[q] == "uzb_samarkand": q3 = q
	_check(absf(g3.province_value(q3) - (1.0 + clampi(g3.econ[q3], 1, 5) * 0.1 + clampi(g3.dev[q3], 1, 5) * 2.0 + g3.pop[q3] * 0.001) * (4.0 if g3.capital[q3] != 0 else 1.0)) < 0.01, "rules 3 keep the old worth formula")
	print("PROJECTS OK" if fails == 0 else "PROJECTS FAIL %d" % fails)
	quit(fails)
