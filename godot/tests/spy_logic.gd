extends SceneTree
## Rules 4 covert operations: the chance has named terms (lead, guard, a report, kinship, merchants, unrest, the work's hardness), a failed operation may be caught and then costs relations, infamy and ties
## (nap, trade), a successful one may be traced at half the price, and rules < 4 keep the old flat chance. Usage: -s tests/spy_logic.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("france"); g.set_human(me); g.pending.clear()
	var t := g.nat_code.find("spain")
	g.set_rel(me, t, TBData.REL_PEACE)
	g.tech_level[me] = 2.0; g.tech_level[t] = 2.0
	var base := TBSpy.chance(g, me, t, "steal")
	_check(base > 0.4 and base < 0.7, "equal learning gives a middling chance (%.2f)" % base)
	g.tech_level[me] = 3.0
	_check(TBSpy.chance(g, me, t, "steal") > base, "being ahead in learning raises it")
	g.tech_level[me] = 2.0; g.tech_level[t] = 3.0
	_check(TBSpy.chance(g, me, t, "steal") < base, "a better-guarded court lowers it")
	g.tech_level[t] = 2.0
	_check(TBSpy.chance(g, me, t, "incite") < TBSpy.chance(g, me, t, "sabotage") and TBSpy.chance(g, me, t, "sabotage") < TBSpy.chance(g, me, t, "steal"), "the nastier the work, the lower the chance")
	g.see_until[me * g.N1 + t] = g.turn + 5
	_check(TBSpy.chance(g, me, t, "steal") > base, "a fresh report from their court raises it")
	g.see_until[me * g.N1 + t] = 0
	var keys: Array = []
	for tm in TBSpy.terms(g, me, t, "sabotage"): keys.append(String(tm[0]))
	_check(keys.has("sp_base") and keys.has("sp_guard") and keys.has("sp_hard"), "the terms are named (%s)" % str(keys))
	_check(TBAsks.chance(g, me, "spy", t, "steal") == int(roundf(TBSpy.chance(g, me, t, "steal") * 100.0)), "the button shows the same chance")
	# consequences over many operations: caught ones cost relations, infamy and ties
	var caught := 0; var traced := 0; var cut_nap := 0; var cut_trade := 0; var runs := 600
	var gr_sum := 0
	for i in runs:
		g.set_rel(me, t, TBData.REL_NAP); g.nap_expiry[mini(me, t) * g.N1 + maxi(me, t)] = g.turn + 20
		TBTrade.set_deal(g, me, t, true)
		g.grudge[t * g.N1 + me] = 0; g.infamy[me] = 0.0
		g.intel[me] = 20.0
		var r := g.apply({"cmd": "spy", "n": me, "t": t, "op": "sabotage"})
		if not bool(r["ok"]): continue
		if bool(r.get("caught", false)): caught += 1; gr_sum += g.grudge[t * g.N1 + me]
		if bool(r.get("traced", false)): traced += 1
		for c in r.get("cut", []):
			if c == "nap": cut_nap += 1
			if c == "trade": cut_trade += 1
		if bool(r.get("caught", false)): _check(g.infamy[me] >= 2.9, "a caught agent costs infamy (%.1f)" % g.infamy[me])
	print("caught %d, traced %d, nap cut %d, trade cut %d of %d" % [caught, traced, cut_nap, cut_trade, runs])
	_check(caught > 50 and cut_nap > 20 and cut_trade > 20, "agents are caught and ties are cut now and then")
	_check(gr_sum / maxi(1, caught) >= 35, "a caught sabotage leaves a big grudge (%d)" % (gr_sum / maxi(1, caught)))
	# a quiet failure costs nothing but the intel
	var quiet := 0
	for i in 400:
		g.grudge[t * g.N1 + me] = 0; g.intel[me] = 20.0
		var r2 := g.apply({"cmd": "spy", "n": me, "t": t, "op": "steal"})
		if bool(r2["ok"]) and not bool(r2["success"]) and not bool(r2.get("caught", false)) and g.grudge[t * g.N1 + me] == 0: quiet += 1
	_check(quiet > 0, "some failures go unseen (%d)" % quiet)
	# the old rules keep the flat chance
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var m3 := g3.nat_code.find("france"); var t3 := g3.nat_code.find("spain")
	g3.set_human(m3); g3.set_rel(m3, t3, TBData.REL_PEACE); g3.tech_level[m3] = 2.0; g3.tech_level[t3] = 2.0
	_check(TBAsks.chance(g3, m3, "spy", t3, "steal") == 60, "rules 3: 60 % at equal learning (%d)" % TBAsks.chance(g3, m3, "spy", t3, "steal"))
	print("SPY_LOGIC OK" if fails == 0 else "SPY_LOGIC FAIL %d" % fails)
	quit(fails)
