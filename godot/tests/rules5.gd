extends SceneTree
## Rules 5: armies begin in the capital only, at a believable share of the people; incomes follow what the people make; every price is in the nation's own terms
## (a development level pays back in about thirty turns in every era, a decree costs about the same share of the income); a recruited man costs a few worker-turns.
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	for e in ["ancient", "medieval", "napoleonic", "ww1", "modern"]:
		var pack := TBWorld.load_era("res://data", e) if e != "modern" else {}
		var g := TBGame.new(w, pack, {"seed": 5, "difficulty": "normal", "rules": 5})
		var off_cap := 0; var caps_with := 0
		for p in g.P:
			if g.army[p] > 0 and g.capital[p] == 0: off_cap += 1
			if g.capital[p] != 0 and g.army[p] > 0: caps_with += 1
		_check(off_cap == 0, "%s: no army outside a capital at the start (%d provinces have one)" % [e, off_cap])
		_check(caps_with >= 20, "%s: capitals hold the armies (%d)" % [e, caps_with])
		# a big nation: standing army share, income per head, payback of development, decree cost in turns of income
		var n := 0; var best := 0
		for k in range(1, g.N1):
			if g.alive[k] != 0 and k != g.rebel and g.own_count(k) > best: best = g.own_count(k); n = k
		var pop := 0; var army := 0
		for p in g.owned(n): pop += g.pop[p]; army += g.army[p]
		var inc: Dictionary = g.income(n)
		var share := float(army) / float(pop)
		var per_head: float = float(inc["gold"]) / float(pop) / g.wage(n)
		var cap_p: int = g.capital_of[n]
		var cost_sum := 0.0; var gain_sum := 0.0
		for q in g.owned(n):
			if g.dev[q] < 4: cost_sum += float(g.develop_cost(q)); gain_sum += float(g.develop_gain(q, n))
		var pay := cost_sum / maxf(1.0, gain_sum)
		var dec_turns: float = float(TBDecisions.cost(g, n, 0)) / maxf(1.0, float(inc["net"]))
		print("%-10s %s: army %.2f%% of people, income %.2f wages per head, upkeep %.1f%% of income, development pays back in %.0f turns, a decree costs %.1f turns of income" % [e, g.dname(n), share * 100.0, per_head, 100.0 * float(inc["upkeep"]) / float(inc["gold"]), pay, dec_turns])
		_check(share > 0.002 and share < 0.05, "%s: the standing army is a believable share of the people (%.2f%%)" % [e, share * 100.0])
		_check(per_head > 0.2 and per_head < 1.2, "%s: income per head is a fraction of a worker's wage (%.2f)" % [e, per_head])
		_check(float(inc["upkeep"]) < 0.25 * float(inc["gold"]), "%s: the standing army costs under a quarter of the income" % e)
		_check(pay > 10.0 and pay < 80.0, "%s: development pays back, province by province, in 10 to 80 turns (%.0f)" % [e, pay])
		_check(dec_turns > 0.1 and dec_turns < 6.0, "%s: a decree costs a fraction of a few turns of income (%.1f)" % [e, dec_turns])
		# recruiting a thousand men costs a few worker-turns each, and the pool of the province gives them
		var cpro: int = g.capital_of[n]
		var cost := TBCan.recruit_gold(g, cpro, 1000, TBData.REGIMES[g.regime[n]])
		_check(cost < int(inc["gold"]), "%s: a thousand men cost less than a turn of income (%d)" % [e, cost])
	print("RULES5 OK" if fails == 0 else "RULES5 FAIL %d" % fails)
	quit(fails)
