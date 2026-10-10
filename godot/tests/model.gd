extends SceneTree
## the economic / research / aggression / rebellion model (docs/MODEL.md)
var failed := 0
func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond: failed += 1

func _init() -> void:
	var w := TBWorld.load_from("res://data")
	# inflation: base rate per era, money-supply term, ceiling, never negative, off for the legacy rules
	var g := TBGame.new(w, {}, {"seed": 7})
	var i0 := TBTurn.inflation(g)
	ok(i0 > 0.0 and i0 < 0.02, "inflation at start is a small positive per-turn share (%.4f)" % i0)
	var base := TBTurn.inflation(g)
	for n in range(1, g.N1): g.gold[n] = 1.0e7
	ok(TBTurn.inflation(g) > base and TBTurn.inflation(g) <= TBTurn.INFL_MAX + 1e-9, "a flooded money supply raises inflation, capped at %.2f" % TBTurn.INFL_MAX)
	var g0 := TBGame.new(w, {}, {"seed": 7, "rules": 0})
	ok(TBTurn.inflation(g0) == 0.0, "legacy rules have no inflation")
	# steady state: a treasury fed s per turn at inflation pi settles at s(1-pi)/pi
	var s := 500.0; var pi := 0.02; var gold := 0.0
	for i in 600: gold = gold * (1.0 - pi) + s
	ok(absf(gold - s / pi) / (s / pi) < 0.01, "hoard converges to s/pi (%.0f vs %.0f)" % [gold, s / pi])
	# aggression: stricter levels declare sooner, attack on thinner edges and accept peace less readily
	var prev := -1.0
	var mono := true
	for i in TBData.AGGRESSION.size():
		var m: float = TBData.AGGRESSION[i]["mul"]
		if m <= prev: mono = false
		prev = m
	ok(mono, "aggression multipliers rise with the level")
	var g1 := TBGame.new(w, {}, {"seed": 7, "aggression": 3})
	var g2 := TBGame.new(w, {}, {"seed": 7, "aggression": 0})
	ok(g1.aggr_level == 3 and g2.aggr_level == 0 and TBAI.peace_bar(g1) > TBAI.peace_bar(g2), "levels are stored and a total-war world is harder to make peace with")
	var wars := [0, 0]
	for k in 2:
		var gg: TBGame = [g1, g2][k]
		gg.set_human(1)
		for t in 40: gg.end_turn()
		for a in range(1, gg.N1):
			wars[k] += gg.war_cnt[a]
	ok(wars[0] > wars[1], "40 turns: warlike world has more war-fronts than a calm one (%d vs %d)" % [wars[0], wars[1]])
	# rebellion: hazard is zero above the threshold, grows with the shortfall; lifecycle ends a revolt
	var gr := TBGame.new(w, {}, {"seed": 3})
	var p := 0
	for q in gr.P: if gr.owner[q] > 1 and gr.capital[q] == 0: p = q; break
	gr.stab[p] = 60; gr.happy[p] = 50
	ok(TBTurn.rebel_hazard(gr, p, 0.05) == 0.0, "no rebels above stability 45")
	gr.stab[p] = 35; var h1 := TBTurn.rebel_hazard(gr, p, 0.05)
	gr.stab[p] = 10; var h2 := TBTurn.rebel_hazard(gr, p, 0.05)
	ok(h1 > 0.0 and h2 > h1 and h2 <= TBTurn.REB_HAZARD_CAP, "hazard rises as stability collapses (%.4f -> %.4f)" % [h1, h2])
	var former := gr.owner[p]
	TBTurn.spawn_rebel(gr, p)
	ok(gr.owner[p] == gr.rebel and gr.reb_from[p] == former, "the revolt remembers its government")
	for t in TBTurn.REB_DISSOLVE + 2:
		gr.set_rel(gr.rebel, former, TBData.REL_WAR)
		gr.army[p] = 5
		TBTurn.rebel_turn(gr)
		if gr.owner[p] != gr.rebel: break
	ok(gr.owner[p] != gr.rebel, "a revolt never lasts forever (owner now %d)" % gr.owner[p])
	var ended := false
	for e in gr.log: if String(e["kind"]) in ["reconciled", "rebels_end"]: ended = true
	ok(ended, "the ending is chronicled")
	# the save keeps the new fields
	var gs := TBGame.new(w, {}, {"seed": 5, "aggression": 2})
	for t in 3: gs.end_turn()
	var d := TBSave.to_dict(gs)
	var back := TBSave.from_dict(w, d)
	ok(back.aggr_level == 2 and absf(back.infl - gs.infl) < 1e-12 and absf(back.econ_goal - gs.econ_goal) < 1e-12 and back.reb_age == gs.reb_age, "save round-trips aggression, inflation and the era goals")
	quit(failed)
