extends SceneTree
## Rules 4 war score and the peace table: field victories, sieges and an exhausted enemy add to the score; demands are priced in points; an AI loser accepts up to a limit that moves with exhaustion;
## land, gold, vassalage and disarmament are carried out; the command schema takes only a short list of real provinces. Usage: -s tests/peace.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var a := g.nat_code.find("france"); var b := -1
	for n in range(1, g.N1):
		if n != a and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 5: b = n; break
	g.set_human(a); g.pending.clear()
	g.set_rel(a, b, TBData.REL_WAR)
	var bl: Array = g.owned(b)
	for i in 4: g.occupier[bl[i]] = a; g.siege[bl[i]] = 0
	# score sources
	var ia := a * g.N1 + b
	_check(g.war_pts[ia] == 0.0, "a new war starts at no points")
	g.army[bl[5]] = 1000
	TBWar.on_battle(g, a, b, 50, 1000, 800, 1000)
	_check(g.war_pts[ia] > 0.0 and g.war_pts[ia] <= TBWar.BATTLE_CAP, "a won battle earns points (%.2f)" % g.war_pts[ia])
	var p1: float = g.war_pts[ia]
	TBWar.on_battle(g, b, a, 10, 1000, 10, 1000)
	_check(g.war_pts[b * g.N1 + a] > 0.0 and g.war_pts[ia] == p1, "points go to the winner only")
	TBWar.earn(g, a, b, TBWar.SIEGE_PTS)
	_check(absf(g.war_pts[ia] - (p1 + TBWar.SIEGE_PTS)) < 0.001, "a siege won adds its points")
	g.exh[b] = 50.0
	_check(TBWar.score(g, a, b, 10.0) == int(round(10.0 + g.war_pts[ia] + 10.0)), "the score is land + field + a fifth of his exhaustion")
	g.war_pts[ia] = 0.0; g.exh[b] = 0.0
	# the table
	var offs: Array = TBPeace.offers(g, a, b)
	_check(offs.size() == 4, "the four held provinces are on the table (%d)" % offs.size())
	var pct := 0.0
	for o in offs: pct += float(o["pct"])
	_check(pct > 0.0 and pct <= 100.0, "their prices are shares of his land (%.1f %%)" % pct)
	_check(float(offs[0]["cost"]) >= float(offs[3]["cost"]), "dearest first")
	g.core[bl[0]] = a
	var offs2: Array = TBPeace.offers(g, a, b)
	var c0 := 0.0; var c1 := 0.0
	for o in offs: if int(o["p"]) == bl[0]: c0 = float(o["cost"])
	for o in offs2: if int(o["p"]) == bl[0]: c1 = float(o["cost"])
	_check(absf(c1 - c0 * TBPeace.CLAIM_MUL) < 0.001, "a claim of mine costs three quarters (%.2f -> %.2f)" % [c0, c1])
	g.war_score[ia] = 60; g.war_score[b * g.N1 + a] = 30; g.exh[a] = 0.0; g.exh[b] = 0.0          # he has scored too, so the budget does not cap his limit
	var lim0 := TBPeace.limit(g, a, b)
	g.exh[b] = 10.0
	var lim1 := TBPeace.limit(g, a, b)
	g.exh[a] = 40.0
	var lim2 := TBPeace.limit(g, a, b)
	_check(lim1 > lim0 and lim2 < lim1, "his exhaustion raises what he will give, mine lowers it (%.1f %.1f %.1f)" % [lim0, lim1, lim2])
	_check(lim0 <= TBPeace.budget(g, a, b) + 0.001, "never more than the score")
	g.exh[a] = 0.0; g.exh[b] = 0.0
	# pricing
	var all4: Array = []
	for o in offs2: all4.append(int(o["p"]))
	var pr_all := TBPeace.price(g, a, b, {"provs": all4})
	_check(float(pr_all["pts"]) > 0.0, "all four are priced (%.1f points)" % float(pr_all["pts"]))
	var one := [int(offs2[offs2.size() - 1]["p"])]
	var cheap := TBPeace.price(g, a, b, {"provs": one})
	_check(float(cheap["pts"]) < float(pr_all["pts"]), "one costs less than four")
	_check(String(TBPeace.price(g, a, b, {"provs": [bl[10]]})["why"]) == "province", "land I do not hold cannot be asked")
	g.war_score[ia] = 5
	var starve := TBPeace.price(g, a, b, {"provs": all4})
	_check(not bool(starve["ok"]) and (starve["why"] == "warscore" or starve["why"] == "limit"), "more than the score is refused (%s)" % str(starve["why"]))
	g.war_score[ia] = 60; g.war_score[b * g.N1 + a] = 0
	# commands: the cheap demand within the limit is accepted
	var gold_a0: float = g.gold[a]
	g.gold[b] = 2000.0
	var room := TBPeace.gold_room(g, b)
	_check(room > 0, "he has gold to give (%d points)" % room)
	var lim_now := TBPeace.limit(g, a, b)
	var take_gold := mini(2, room)
	var res := g.apply({"cmd": "peaceDeal", "n": a, "t": b, "provs": one, "gold": take_gold})
	var cost_ok := float(TBPeace.price(g, a, b, {"provs": one, "gold": take_gold})["pts"]) <= lim_now
	_check(bool(res["ok"]) == cost_ok, "the command follows the price (%s, limit %.1f)" % [str(res), lim_now])
	if bool(res["ok"]):
		_check(g.owner[one[0]] == a and g.get_rel(a, b) == TBData.REL_PEACE and g.has_truce(a, b), "land changed hands and a truce began")
		_check(g.gold[a] > gold_a0 and g.gold[b] < 2000.0, "gold moved to the winner")
		_check(g.occupier[bl[1]] == 0 and g.occupier[bl[2]] == 0, "the occupations of the war lapse")
	# a refused over-ask leaves the war on
	g.set_rel(a, b, TBData.REL_WAR)
	for i in 4: if g.owner[bl[i]] == b: g.occupier[bl[i]] = a
	g.war_score[ia] = 60; g.exh[a] = 0.0; g.exh[b] = 0.0; g.war_score[b * g.N1 + a] = 30
	var over := g.apply({"cmd": "peaceDeal", "n": a, "t": b, "provs": all4, "vassal": 1})
	_check(not bool(over["ok"]) and g.get_rel(a, b) == TBData.REL_WAR, "an over-ask is refused and the war goes on (%s)" % str(over))
	# vassal and disarm
	g.war_score[ia] = 100; g.war_score[b * g.N1 + a] = 0; g.exh[b] = 60.0
	g.army[bl[6]] = 200
	var vas := g.apply({"cmd": "peaceDeal", "n": a, "t": b, "vassal": 1, "disarm": 1})
	_check(bool(vas["ok"]) and g.overlord[b] == a, "a vassal peace with disarmament (%s)" % str(vas))
	if bool(vas["ok"]): _check(g.army[bl[6]] <= 100 or g.owner[bl[6]] != b, "his armies were halved (%d)" % g.army[bl[6]])
	# white peace stays a white peace
	var c2 := -1
	for n in range(1, g.N1):
		if n != a and n != b and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 2 and not g.friendly(a, n): c2 = n; break
	g.set_rel(a, c2, TBData.REL_WAR)
	var wp := g.can({"cmd": "peaceDeal", "n": a, "t": c2})
	_check(bool(wp["ok"]) and int(wp["dp"]) == TBData.DP_PEACE, "an empty deal is a white peace for the price of the old one")
	# the command schema
	var big: Array = []
	for i in 70: big.append(i)
	_check(TBCommands.normalize(g, {"cmd": "peaceDeal", "n": a, "t": b, "provs": big}).is_empty(), "a list of 70 provinces is refused")
	_check(TBCommands.normalize(g, {"cmd": "peaceDeal", "n": a, "t": b, "provs": [g.P + 5]}).is_empty(), "a province that does not exist is refused")
	_check(TBCommands.normalize(g, {"cmd": "peaceDeal", "n": a, "t": b, "provs": ["x"]}).is_empty(), "a word is not a province")
	_check(not TBCommands.normalize(g, {"cmd": "peaceDeal", "n": a, "t": b, "provs": [1, 2, 3]}).is_empty(), "a short list of real provinces passes")
	# old rules refuse
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var r3 := g3.apply({"cmd": "peaceDeal", "n": 1, "t": 2})
	_check(not bool(r3["ok"]), "rules 3 has no peace table")
	print("PEACE OK" if fails == 0 else "PEACE FAIL %d" % fails)
	quit(fails)
