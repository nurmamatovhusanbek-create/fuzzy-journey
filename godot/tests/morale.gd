extends SceneTree
## Rules 4 morale and war exhaustion: winners gain heart and losers lose it, morale scales strength, a long bloody war wears a country out, peace restores it, a broken army deserts.
## Usage: -s tests/morale.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var a := g.nat_code.find("france"); var b := -1
	for n in range(1, g.N1):
		if n != a and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 2: b = n; break
	g.set_human(a); g.pending.clear()
	_check(is_equal_approx(g.morale[a], TBWar.MORALE_START) and g.exh[a] == 0.0, "a new game starts at the usual morale and no weariness")
	_check(is_equal_approx(g.combat_mul(a), g.combat_mul(a) * TBWar.morale_mul(g, a) / TBWar.morale_mul(g, a)), "morale factor is 1.0 at the usual level")
	_check(absf(TBWar.morale_mul(g, a) - 1.0) < 0.0001, "usual morale scales nothing")
	var base := g.combat_mul(a)
	g.morale[a] = 100.0; var hi := g.combat_mul(a)
	g.morale[a] = 0.0; var lo := g.combat_mul(a)
	g.morale[a] = 70.0
	_check(hi > base and lo < base and absf(hi / base - 1.09) < 0.001 and absf(lo / base - 0.79) < 0.001, "morale 100 hits 9 %% harder, morale 0 hits 21 %% weaker (%.3f %.3f)" % [hi / base, lo / base])
	# a battle moves the two sides' hearts
	TBWar.on_battle(g, a, b, 100, 1000, 600, 1000)
	_check(g.morale[a] > 70.0 and g.morale[b] < 70.0, "the winner gains heart, the loser loses it (%.1f %.1f)" % [g.morale[a], g.morale[b]])
	_check(is_equal_approx(g.morale[b], 70.0 - TBWar.LOSS_BASE - TBWar.LOSS_SHARE_K * 0.6), "the loser pays more the more of his army fell")
	_check(g.lost_turn[a] == 100 and g.lost_turn[b] == 600, "casualties are counted for the turn")
	# at war: exhaustion grows with the turns, the dead and the land held by the enemy
	g.set_rel(a, b, TBData.REL_WAR)
	var pop_a := 0
	for p in g.owned(a): pop_a += g.pop[p]
	TBWar.tick(g, b, true, pop_a)
	var e1: float = g.exh[b]
	_check(e1 > TBWar.EXH_TURN, "casualties add to the weariness (%.2f)" % e1)
	_check(g.lost_turn[b] == 0, "the turn's casualty count is spent")
	TBWar.tick(g, b, true, pop_a)
	_check(absf(g.exh[b] - e1 - TBWar.EXH_TURN) < 0.001, "a quiet turn at war adds only the turn's share")
	var q: int = g.owned(b)[0]
	g.occupier[q] = a
	var before: float = g.exh[b]
	TBWar.tick(g, b, true, pop_a)
	_check(g.exh[b] - before > TBWar.EXH_TURN + TBWar.EXH_OCC - 0.001, "an occupied province adds weariness")
	g.exh[b] = 80.0; g.morale[b] = 70.0
	TBWar.tick(g, b, true, pop_a)
	_check(g.morale[b] < 70.0, "a worn-out country fights with less heart (%.1f)" % g.morale[b])
	_check(TBWar.weary(g, b) > 30.0 and TBWar.weary(g, b) <= 40.0, "high exhaustion feeds the old weariness, capped at 40")
	# peace restores
	g.exh[b] = 20.0; g.morale[b] = 40.0
	TBWar.tick(g, b, false, pop_a)
	_check(g.exh[b] == 20.0 - TBWar.EXH_REST and g.morale[b] > 40.0, "peace rests the country and the army")
	# a broken army deserts over a turn
	g.set_rel(a, b, TBData.REL_PEACE); g.occupier[q] = 0
	var home: int = g.owned(a)[0]
	g.army[home] = 400; g.morale[a] = 10.0
	g.end_turn()
	_check(g.army[home] < 400, "a broken army melts away (%d)" % g.army[home])
	# the AI's peace weighing sees the exhaustion
	g.set_rel(a, b, TBData.REL_WAR)
	g.exh[b] = 0.0; g.exh[a] = 0.0
	var w0 := float(TBDipView.peace(g, b, a, "white")["score"])
	g.exh[b] = 60.0
	var w1 := float(TBDipView.peace(g, b, a, "white")["score"])
	_check(w1 > w0, "an exhausted country is readier for peace (%.2f -> %.2f)" % [w0, w1])
	# old rules are untouched
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var f3 := g3.nat_code.find("france")
	g3.morale[f3] = 0.0
	_check(absf(g3.combat_mul(f3) - TBData.ERAS[g3.era[f3]]["combatMul"] * TBRulers.combat_mul(g3, f3)) < 0.0001, "rules 3 ignores morale")
	print("MORALE OK" if fails == 0 else "MORALE FAIL %d" % fails)
	quit(fails)
