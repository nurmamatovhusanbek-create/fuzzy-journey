extends SceneTree
## Districts (rules >= 2): several buildings per province, slots from development, development limited by the people to staff it, demolish, save / net round trips.
var fails := 0
func ok(c: bool, m: String) -> void:
	if c: print("  ok   ", m)
	else: print("  FAIL ", m); fails += 1

func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 3})
	ok(g.rules == 2, "new games use rules 2")
	var n := 1
	for x in range(1, g.N1):
		if g.alive[x] != 0 and x != g.rebel and g.own_count(x) >= 6: n = x; break
	g.human_id = n; g.human[n] = 1
	g.gold[n] = 5000.0; g.mp[n] = 20.0; g.tech_level[n] = 5.0
	var own := g.owned(n)
	var p := -1
	for q in own:
		if g.capital[q] == 0 and g.occupier[q] == 0: p = q; break
	g.dev[p] = 1
	ok(g.b_slots(p) == 1, "dev 1 province has one slot")
	var r1 := g.apply({"cmd": "build", "n": n, "p": p, "b": TBData.B_MARKET})
	ok(bool(r1.get("ok", false)), "first building starts")
	g.b_turns[p] = 1
	g.mp[n] = 20.0
	# finish the construction through the real turn path
	g.end_turn()
	ok(g.bl(p, TBData.B_MARKET) == 1 and g.building[p] == TBData.B_MARKET, "market stands, single view mirrors it")
	g.gold[n] = 5000.0; g.mp[n] = 20.0
	var c2 := g.can({"cmd": "build", "p": p, "b": TBData.B_FARM})
	ok(not bool(c2["ok"]) and String(c2["reason"]) == "slots", "second type is refused while the single slot is used")
	g.dev[p] = 2
	ok(g.b_slots(p) == 2, "dev 2 opens a second slot")
	var c3 := g.can({"cmd": "build", "p": p, "b": TBData.B_FARM})
	ok(bool(c3["ok"]), "second type fits now")
	ok(int(c3["gold"]) == int(ceil(float(TBData.BUILDINGS[TBData.B_FARM - 1]["cost"][0]) * 1.2)), "a new type costs 20%% more per building already there (%d)" % int(c3["gold"]))
	g.apply({"cmd": "build", "n": n, "p": p, "b": TBData.B_FARM})
	g.b_turns[p] = 1; g.end_turn()
	ok(g.bl(p, TBData.B_FARM) == 1 and g.bl(p, TBData.B_MARKET) == 1 and g.b_used(p) == 2, "two buildings stand in one province")
	ok(g.b_list(p).size() == 2, "b_list names both")
	# income knows both
	var farm_up := g.can({"cmd": "build", "p": p, "b": TBData.B_FARM})
	ok(int(farm_up.get("levels", 0)) == 2, "farm upgrades to level 2")
	# demolish
	g.gold[n] = 5000.0; g.mp[n] = 20.0
	var dm := g.apply({"cmd": "demolish", "n": n, "p": p, "b": TBData.B_MARKET})
	ok(bool(dm.get("ok", false)) and g.bl(p, TBData.B_MARKET) == 0 and g.b_used(p) == 1, "demolish frees the slot")
	ok(g.building[p] == TBData.B_FARM, "single view follows the remaining building")
	# job fill: few people, a lower level's income
	g.dev[p] = 3; g.pop[p] = 30
	var low := g.job_income(p, 3)
	g.pop[p] = 400
	var high := g.job_income(p, 3)
	ok(low < high and absf(high - float(TBData.DEV_INCOME[3])) < 0.001, "short of people the top level pays less (%.1f < %.1f)" % [low, high])
	g.pop[p] = 30; var gain_low := g.develop_gain(p, n)
	g.pop[p] = 400; var gain_high := g.develop_gain(p, n)
	ok(gain_high > gain_low and gain_high > 0, "the Develop verb's gain is smaller where the people are few (%d vs %d a turn)" % [gain_low, gain_high])
	var al := TBAdvisor.alerts(g, n)
	g.gold[n] = 900.0
	al = TBAdvisor.alerts(g, n)
	var ig := -1
	for a in al:
		if String(a["id"]) == "idle_gold": ig = int(a["p"])
	ok(ig >= 0 and g.owner[ig] == n, "idle gold points at one of your districts")
	ok(g.develop_cost(p) == int(ceil(28.0 * float(TBData.DEV_INCOME[4] - TBData.DEV_INCOME[3]))), "development step cost follows the income step")
	# save / load
	TBSave.save(g, "dist_test")
	var g2 := TBSave.load_game(w, "dist_test")
	TBSave.delete("dist_test")
	ok(g2 != null and g2.rules == 2 and g2.bl(p, TBData.B_FARM) == 2 - 1 and g2.b_lv == g.b_lv, "save round-trips the levels")
	# net delta
	var prev := {}
	g.dirty_list = PackedInt32Array([p])
	var delta := TBNetProto.make_delta(g, PackedInt32Array([p]), 0, true, prev)
	var g3 := TBSave.from_dict(w, TBSave.to_dict(g))
	g3.b_lv[p * g3.NB + TBData.B_FARM - 1] = 0
	TBNetProto.apply_delta(g3, delta)
	ok(g3.bl(p, TBData.B_FARM) == g.bl(p, TBData.B_FARM), "net delta carries the levels")
	# AI: after a while somebody has two buildings in a province
	var ga := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5})
	for t in 80: ga.end_turn()
	var multi := 0; var built := 0
	for q in ga.P:
		if ga.b_used(q) >= 2: multi += 1
		if ga.b_used(q) >= 1: built += 1
	ok(multi > 0, "AIs end up with provinces holding several buildings (%d multi of %d built)" % [multi, built])
	var over := 0
	for q in ga.P:
		if ga.b_used(q) > ga.b_slots(q): over += 1
	ok(over * 50 <= built, "buildings rarely outnumber slots (only after a capital moves): %d of %d" % [over, built])
	# rules 1 keeps one building
	var g1 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 3, "rules": 1})
	ok(g1.b_slots(0) == 1 and g1.develop_cost(0) == 80 + g1.dev[0] * 80, "rules 1 keeps one slot and the old development price")
	print("DISTRICTS ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
