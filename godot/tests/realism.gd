extends SceneTree
## Rules 3: how far a quarrel reaches (allies feel it, less than the victim does), what a trade route needs (income, gold, people), and victories that must be held.
var fails := 0
func _ok(cond: bool, what: String) -> void:
	if cond: print("  ok   ", what)
	else: print("FAIL: ", what); fails += 1

func _pick(g: TBGame, k: int) -> Array:
	var out: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel and g.own_count(n) >= 4: out.append(n)
		if out.size() == k: break
	return out

func _clear(g: TBGame) -> void:
	g.grudge.fill(0); g.rel.fill(0); g.truce.fill(0); g.war_cnt.fill(0)

func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", "napoleonic")
	print("-- a quarrel reaches the victim's friends, less than the victim")
	var g := TBGame.new(w, era, {"seed": 4})
	_ok(g.rules == 3, "new games use rules 3")
	var p := _pick(g, 6)
	var A: int = p[0]; var V: int = p[1]; var Y: int = p[2]; var K: int = p[3]; var S: int = p[4]; var E: int = p[5]
	_clear(g)
	g.set_rel(V, Y, TBData.REL_ALLY); g.set_rel(V, K, TBData.REL_MARRIAGE); g.set_rel(V, E, TBData.REL_WAR)
	g.grudge[E * g.N1 + A] = 20
	TBDiplo.hurt(g, V, A, 40)
	var gv: int = g.grudge[V * g.N1 + A]; var gy: int = g.grudge[Y * g.N1 + A]; var gk: int = g.grudge[K * g.N1 + A]
	_ok(gv == 40, "the victim takes all of it (%d)" % gv)
	_ok(gy == 20, "an ally of the victim takes half (%d)" % gy)
	_ok(gk == 16, "kin by marriage take 40%% (%d)" % gk)
	_ok(gy > 0 and gy < gv and gk > 0 and gk < gv, "friends feel it, but less than the victim does")
	_ok(g.grudge[S * g.N1 + A] == 0, "a stranger feels nothing")
	_ok(g.grudge[E * g.N1 + A] == 10, "the victim's enemy warms to the offender (20 -> %d)" % g.grudge[E * g.N1 + A])
	# the offender's own friend is torn
	_clear(g)
	g.set_rel(V, Y, TBData.REL_ALLY); g.set_rel(A, Y, TBData.REL_ALLY)
	TBDiplo.hurt(g, V, A, 40)
	_ok(g.grudge[Y * g.N1 + A] == 8, "a friend of both is torn: 8 instead of 20 (%d)" % g.grudge[Y * g.N1 + A])
	# below rules 3 nothing travels
	var g2 := TBGame.new(w, era, {"seed": 4, "rules": 2})
	_clear(g2)
	g2.set_rel(V, Y, TBData.REL_ALLY)
	TBDiplo.hurt(g2, V, A, 40)
	_ok(g2.grudge[V * g2.N1 + A] == 40 and g2.grudge[Y * g2.N1 + A] == 0, "rules 2: only the victim's grudge, as before")
	# real commands: a war declaration, a broken pact, a seized province
	_clear(g)
	g.set_human(A); g.dp[A] = 20; g.set_rel(V, Y, TBData.REL_ALLY)
	var inf0: float = g.infamy[A]
	var r := g.apply({"cmd": "declareWar", "n": A, "t": V, "_force": true})
	_ok(bool(r["ok"]), "declareWar goes through")
	_ok(g.grudge[V * g.N1 + A] == 40 and g.grudge[Y * g.N1 + A] > 0 or g.get_rel(Y, A) == TBData.REL_WAR, "declaring war on V: V resents it fully, V's ally %s (%d)" % ["is at war with A too" if g.get_rel(Y, A) == TBData.REL_WAR else "resents it", g.grudge[Y * g.N1 + A]])
	_clear(g)
	g.set_rel(A, V, TBData.REL_ALLY); g.set_rel(V, Y, TBData.REL_ALLY); inf0 = g.infamy[A]
	g.apply({"cmd": "breakPact", "n": A, "t": V})
	_ok(g.grudge[V * g.N1 + A] == 25 and g.grudge[Y * g.N1 + A] == 12 or g.grudge[Y * g.N1 + A] == 13, "breaking an alliance: V 25, V's ally about half (%d)" % g.grudge[Y * g.N1 + A])
	_ok(g.infamy[A] > inf0 + 5.0, "an oath broken costs standing (infamy +%.1f)" % (g.infamy[A] - inf0))
	# goodwill: a pact with V softens V's friends, an alliance angers V's enemies
	_clear(g)
	g.set_rel(V, Y, TBData.REL_ALLY); g.set_rel(V, E, TBData.REL_WAR)
	g.grudge[Y * g.N1 + A] = 30
	TBDiplo.befriend(g, A, V, 16, true)
	_ok(g.grudge[Y * g.N1 + A] == 24, "an alliance with V: V's ally cools 30 -> %d" % g.grudge[Y * g.N1 + A])
	_ok(g.grudge[E * g.N1 + A] == 5, "...and V's enemy grows wary of A (%d)" % g.grudge[E * g.N1 + A])
	# acceptance: being at war with a court's friend hurts your request; an alliance without any record of trust is harder
	_clear(g)
	g.set_rel(Y, V, TBData.REL_ALLY); g.set_rel(A, V, TBData.REL_WAR)
	var base := TBDipView.pact(g, Y, A, TBData.REL_NAP)
	var has_loyal := false
	for tm in base["terms"]: if String(tm[0]) == "dv_loyalty": has_loyal = true
	_ok(has_loyal, "a court weighs it that you fight its ally (dv_loyalty)")
	_clear(g)
	var untried := TBDipView.pact(g, Y, A, TBData.REL_ALLY)
	var has_u := false
	for tm in untried["terms"]: if String(tm[0]) == "dv_untried": has_u = true
	_ok(has_u, "an alliance with no record of trust is harder (dv_untried)")
	g.set_rel(Y, A, TBData.REL_NAP)
	var tried := TBDipView.pact(g, Y, A, TBData.REL_ALLY)
	_ok(float(tried["score"]) > float(untried["score"]), "...and easier after a pact (%.2f -> %.2f)" % [untried["score"], tried["score"]])

	print("-- a trade route needs persistent income, money and people")
	var g3 := TBGame.new(w, era, {"seed": 4})
	var q := _pick(g3, 2)
	var a: int = q[0]; var b: int = q[1]
	_clear(g3)
	g3.set_human(a); g3.dp[a] = 20
	var v := TBTrade.yield_of(g3, a, b)
	_ok(v == TBTrade.yield_of(g3, b, a) and v >= 2 and v <= TBTrade.YIELD_CAP, "a route is worth the same to both sides (%d gold a turn)" % v)
	var fee := TBTrade.fee_gold(v); var men := TBTrade.fee_men(v)
	g3.gold[a] = fee * 3; g3.manpower[a] = men * 6; g3.net_ema[a] = float(v) * 4.0
	g3.gold[b] = fee * 3; g3.manpower[b] = men * 6; g3.net_ema[b] = float(v) * 4.0
	var rich := TBDipView.trade(g3, b, a)
	_ok(float(TBTrade.means(g3, a, v)["m"]) > 0.99, "with a surplus, a full treasury and men to spare the means are complete")
	var s_full: float = rich["score"]
	g3.net_ema[a] = float(v) * 0.5
	var s_inc: float = TBDipView.trade(g3, b, a)["score"]
	g3.net_ema[a] = float(v) * 4.0; g3.gold[a] = fee * 0.8
	var s_gold: float = TBDipView.trade(g3, b, a)["score"]
	g3.gold[a] = fee * 3; g3.manpower[a] = men * 1.5
	var s_men: float = TBDipView.trade(g3, b, a)["score"]
	_ok(s_inc < s_full and s_gold < s_full and s_men < s_full, "less income, less money or fewer people each lower their willingness (%.2f vs %.2f / %.2f / %.2f)" % [s_full, s_inc, s_gold, s_men])
	g3.manpower[a] = men * 6
	g3.net_ema[a] = -50.0
	var m_neg: float = TBTrade.means(g3, a, v)["m"]
	_ok(m_neg == 0.0, "a nation running a deficit has no means at all")
	g3.net_ema[a] = float(v) * 4.0
	# monotonic in each ingredient
	var prev := -1.0; var mono := true
	for k in 11:
		g3.gold[a] = fee * 2.0 * float(k) / 10.0
		var m: float = TBTrade.means(g3, a, v)["m"]
		if m < prev: mono = false
		prev = m
	_ok(mono, "means never fall as the treasury grows")
	# hard costs
	g3.gold[a] = fee - 1; g3.manpower[a] = men * 6
	var c1 := g3.can({"cmd": "trade", "n": a, "t": b})
	_ok(not bool(c1["ok"]) and String(c1["reason"]) == "gold", "can(): not enough gold for the caravans (%s)" % c1["reason"])
	g3.gold[a] = fee * 3; g3.manpower[a] = men - 1
	var c2 := g3.can({"cmd": "trade", "n": a, "t": b})
	_ok(not bool(c2["ok"]) and String(c2["reason"]) == "manpower", "can(): not enough people for the escorts (%s)" % c2["reason"])
	g3.manpower[a] = men * 6
	var c3 := g3.can({"cmd": "trade", "n": a, "t": b})
	_ok(bool(c3["ok"]) and int(c3["gold"]) == fee and int(c3["men"]) == men, "can(): costs are reported (%d gold, %d men)" % [c3["gold"], c3["men"]])
	var gold0: float = g3.gold[a]; var man0: float = g3.manpower[a]
	var pr := g3.apply({"cmd": "trade", "n": a, "t": b, "_force": true})
	_ok(bool(pr["ok"]) and absf((gold0 - g3.gold[a]) - fee) < 0.01 and absf((man0 - g3.manpower[a]) - men) < 0.01, "opening the route costs %d gold and %d people" % [fee, men])
	# gravity: bigger and nearer partners are worth more
	var pairs: Array = []
	for o in range(1, g3.N1):
		if o != a and g3.alive[o] != 0 and o != g3.rebel and g3.own_count(o) >= 3: pairs.append([TBTrade.yield_of(g3, a, o), TBTrade.reach(g3, a, o), g3.own_count(o)])
	var near_big := 0; var far_small := 0
	for pr2 in pairs:
		if pr2[1] > 0.8 and pr2[2] >= 15: near_big = maxi(near_big, pr2[0])
		if pr2[1] < 0.4 and pr2[2] <= 8: far_small = maxi(far_small, pr2[0])
	_ok(near_big == 0 or far_small == 0 or near_big > far_small, "a large neighbour is worth more than a small faraway realm (%d vs %d)" % [near_big, far_small])
	# a route lapses when the treasury is empty for long, or when the courts come to hate each other
	TBTrade.set_deal(g3, a, b, true)
	g3.grudge[a * g3.N1 + b] = 70
	TBTrade.maintain(g3)
	_ok(not TBTrade.has(g3, a, b), "a route lapses when the courts hate each other")
	TBTrade.set_deal(g3, a, b, true); g3.grudge.fill(0); g3.gold[b] = 0.0
	var lapsed := false
	for k in 40:
		TBTrade.maintain(g3)
		if not TBTrade.has(g3, a, b): lapsed = true; break
	_ok(lapsed, "a bankrupt partner loses the route sooner or later")

	print("-- victories are held, not touched")
	var g4 := TBGame.new(w, era, {"seed": 4})
	g4.set_human(1)
	for q2 in range(0, int(g4.P * 0.45)): g4.set_owner(q2, 1)
	g4.alive[1] = 1
	var held := 0
	for t in 12:
		TBTurn.check_victory(g4)
		held += 1
		if g4.over: break
	_ok(g4.over and g4.victory_kind == "domination" and held == TBTurn.HOLD["domination"], "domination ends the game only after %d turns held (took %d)" % [TBTurn.HOLD["domination"], held])
	var g5 := TBGame.new(w, era, {"seed": 4})
	g5.set_human(1)
	for q2 in range(0, int(g5.P * 0.45)): g5.set_owner(q2, 1)
	g5.alive[1] = 1
	for t in 5: TBTurn.check_victory(g5)
	_ok(not g5.over and int(TBTurn.victory_progress(g5, 1)["domination"] * 100.0) == 99, "while it is being held the goals screen reads 99%")
	for q2 in range(0, int(g5.P * 0.45)): g5.set_owner(q2, 0)
	TBTurn.check_victory(g5)
	_ok(TBTurn.hold_status(g5, 1, "domination").x == 0, "losing the position resets the count")
	# land without people does not dominate
	var g6 := TBGame.new(w, era, {"seed": 4})
	g6.set_human(1)
	for q2 in range(0, int(g6.P * 0.45)): g6.set_owner(q2, 1); g6.pop[q2] = 1
	g6.alive[1] = 1
	var pr6 := TBTurn.raw_progress(g6, 1)
	_ok(float(pr6["domination"]) < 0.9, "an empire of empty provinces does not dominate (%.2f)" % pr6["domination"])
	# diplomatic hegemony is an achievement, not an ending
	var g7 := TBGame.new(w, era, {"seed": 4})
	g7.set_human(1)
	var cnt := 0
	for o in range(2, g7.N1):
		if g7.alive[o] != 0 and o != g7.rebel and cnt < 12: g7.set_rel(1, o, TBData.REL_ALLY); cnt += 1
	for t in 30: TBTurn.check_victory(g7)
	_ok(not g7.over, "12 alliances held for 30 turns do not end the game")
	_ok(TBTurn.hold_status(g7, 1, "diplomatic").x >= TBTurn.HOLD["diplomatic"], "...but they are counted (%d turns)" % TBTurn.hold_status(g7, 1, "diplomatic").x)
	var hon := TBHonours.on_state(g7)
	_ok("concert" in hon, "...and earn the Concert of Nations honour")
	var g8 := TBGame.new(w, era, {"seed": 4, "rules": 2})
	g8.set_human(1)
	cnt = 0
	for o in range(2, g8.N1):
		if g8.alive[o] != 0 and o != g8.rebel and cnt < 12: g8.set_rel(1, o, TBData.REL_ALLY); cnt += 1
	TBTurn.check_victory(g8)
	_ok(g8.over and g8.victory_kind == "diplomatic", "rules 2 (older games) keep the old diplomatic ending")
	# save round trip
	g7.net_ema[3] = 12.5
	var d := TBSave.to_dict(g7)
	var g9 := TBSave.from_dict(w, d)
	_ok(g9 != null and g9.rules == 3 and g9.vic_hold == g7.vic_hold and absf(g9.net_ema[3] - 12.5) < 0.001, "rules 3, the holds and the smoothed income survive a save")
	print("-- where buildings may stand")
	var gb := TBGame.new(w, era, {"seed": 4})
	_ok(w.geo.size() == w.P, "the baked geography is there (%d provinces)" % w.geo.size())
	var arid_p := -1; var dry_ok := -1; var coast_p := -1; var inland_p := -1; var polar_p := -1
	for qq in gb.P:
		if gb.owner[qq] == 0 or gb.capital[qq] != 0: continue
		var f: int = w.geo[qq]
		if arid_p < 0 and (f & 2) != 0: arid_p = qq
		if polar_p < 0 and (f & 4) != 0: polar_p = qq
		if coast_p < 0 and (f & 1) != 0 and (f & 2) == 0 and (f & 4) == 0: coast_p = qq
		if inland_p < 0 and (f & 1) == 0: inland_p = qq
	_ok(arid_p >= 0 and coast_p >= 0 and inland_p >= 0, "the world has deserts, coasts and inland provinces")
	var tries := [["arid", arid_p, TBData.B_FARM, "arid"], ["inland", inland_p, TBData.B_PORT, "coast"], ["polar", polar_p, TBData.B_FARM, "polar"]]
	for t in tries:
		var tq: int = t[1]
		if tq < 0: continue
		var own: int = gb.owner[tq]
		gb.set_human(own); gb.gold[own] = 5000.0; gb.mp[own] = 6.0; gb.tech_level[own] = 3.0
		for k in 9: gb.b_lv[tq * gb.NB + k] = 0
		gb.b_building[tq] = 0
		var cn := gb.can({"cmd": "build", "n": own, "p": tq, "b": t[2]})
		var ap := gb.apply({"cmd": "build", "n": own, "p": tq, "b": t[2]})
		_ok(not bool(cn["ok"]) and String(cn["reason"]) == String(t[3]) and not bool(ap["ok"]) and String(ap["err"]) == String(t[3]), "%s: can() and apply() both say '%s' (%s / %s)" % [t[0], t[3], cn["reason"], ap.get("err", "ok")])
	if coast_p >= 0:
		var own2: int = gb.owner[coast_p]
		gb.set_human(own2); gb.gold[own2] = 5000.0; gb.mp[own2] = 6.0; gb.tech_level[own2] = 3.0
		for k in 9: gb.b_lv[coast_p * gb.NB + k] = 0
		gb.b_building[coast_p] = 0
		var okp := gb.apply({"cmd": "build", "n": own2, "p": coast_p, "b": TBData.B_PORT})
		_ok(bool(okp["ok"]), "a port goes up on a coast")
	var gold_old := TBGame.new(w, era, {"seed": 4, "rules": 2})
	_ok(gold_old.site_error(arid_p, TBData.B_FARM) == "", "rules 2 (older games) keep building anywhere")
	# a hundred turns of AI building: no farm in a desert, no port inland
	var gs := TBGame.new(w, era, {"seed": 5})
	for t in 100: gs.end_turn()
	var bad_farms := 0; var bad_ports := 0
	for q3 in gs.P:
		var f2: int = w.geo[q3]
		if gs.bl(q3, TBData.B_FARM) > 0 and (f2 & 6) != 0: bad_farms += 1
		if gs.bl(q3, TBData.B_PORT) > 0 and (f2 & 1) == 0: bad_ports += 1
	_ok(bad_farms == 0 and bad_ports == 0, "after 100 turns of AI building: no farm in a desert or beyond the polar circle (%d), no inland port (%d)" % [bad_farms, bad_ports])
	print("REALISM OK" if fails == 0 else "REALISM FAIL %d" % fails)
	quit(fails)
