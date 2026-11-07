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
	# how a court raises its guard: watchtowers, and a military academy (costly, twelve turns of training, then for good)
	var guard0 := TBSpy.guard(g, t)
	var own_t := g.owned(t)
	for i in mini(4, own_t.size()): g.set_bl(own_t[i], TBData.B_WATCHTOWER, 1)
	var guard1 := TBSpy.guard(g, t)
	_check(guard1 > guard0 and guard1 - guard0 <= TBSpy.TOWER_MAX + 0.001, "watchtowers raise the guard a little (%.2f -> %.2f)" % [guard0, guard1])
	for i in own_t.size(): g.set_bl(own_t[i], TBData.B_WATCHTOWER, 1)
	_check(TBSpy.guard(g, t) - guard0 <= TBSpy.TOWER_MAX + 0.001, "and never past their cap")
	for i in own_t.size(): g.set_bl(own_t[i], TBData.B_WATCHTOWER, 0)
	g.era[t] = 2; g.gold[t] = 5000.0; g.mp[t] = 20.0
	var ra := TBDecisions.apply(g, t, "mil_academy")
	_check(bool(ra["ok"]) and g.gold[t] <= 4300.0 + 0.1, "the academy is bought for a high price (%s, gold %.0f)" % [str(ra), g.gold[t]])
	_check(TBSpy.guard(g, t) == guard0, "during training nothing changes (%.2f)" % TBSpy.guard(g, t))
	g.turn += 11
	_check(not TBDecisions.graduated(g, t, "mil_academy"), "eleven turns are not enough")
	g.turn += 1
	_check(TBDecisions.graduated(g, t, "mil_academy") and TBSpy.guard(g, t) > guard0 + 0.1, "after twelve turns the guard is up for good (%.2f -> %.2f)" % [guard0, TBSpy.guard(g, t)])
	g.turn += 200
	_check(TBDecisions.graduated(g, t, "mil_academy"), "and stays")
	var cm := TBDecisions.combat_mul(g, t)
	_check(cm > 1.02, "it also schools the army (%.2f)" % cm)
	# your own academy helps your own agents
	g.era[me] = 2; g.gold[me] = 5000.0; g.mp[me] = 20.0
	var before_own := TBSpy.chance(g, me, t, "steal")
	TBDecisions.apply(g, me, "mil_academy"); g.turn += 12
	var keys2: Array = []
	for tm in TBSpy.terms(g, me, t, "steal"): keys2.append(String(tm[0]))
	_check(keys2.has("sp_academy"), "your own graduates show in your chance")
	g.turn -= 212
	g = TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4}); me = g.nat_code.find("france"); g.set_human(me); g.pending.clear(); t = g.nat_code.find("spain")
	g.set_rel(me, t, TBData.REL_PEACE); g.tech_level[me] = 2.0; g.tech_level[t] = 2.0
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
	# a save from before the academy existed (every nation's row of decrees one column shorter) still loads, with the old decrees where they were
	var dd: Dictionary = TBSave.to_dict(g)
	var ndec: int = TBDecisions.LIST.size()
	var old_arr := PackedInt32Array(); old_arr.resize(g.N1 * (ndec - 1))
	g.dec_until[me * ndec + 0] = 77
	for n in g.N1:
		for c in ndec - 1: old_arr[n * (ndec - 1) + c] = g.dec_until[n * ndec + c]
	dd["dec_until"] = old_arr
	var gl: TBGame = TBSave.from_dict(w, dd)
	_check(gl != null, "an older save with one decree fewer still loads")
	if gl != null: _check(gl.dec_until[me * ndec + 0] == 77 and gl.dec_until[me * ndec + ndec - 1] == 0, "its decrees are where they were and the new one is empty")
	# the old rules keep the flat chance
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var m3 := g3.nat_code.find("france"); var t3 := g3.nat_code.find("spain")
	g3.set_human(m3); g3.set_rel(m3, t3, TBData.REL_PEACE); g3.tech_level[m3] = 2.0; g3.tech_level[t3] = 2.0
	_check(TBAsks.chance(g3, m3, "spy", t3, "steal") == 60, "rules 3: 60 % at equal learning (%d)" % TBAsks.chance(g3, m3, "spy", t3, "steal"))
	# survey: a quiet look that only shows their armies for a while, easier than any strike, never traced when it works
	g = TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4}); me = g.nat_code.find("france"); g.set_human(me); g.pending.clear(); t = g.nat_code.find("spain")
	g.set_rel(me, t, TBData.REL_PEACE); g.intel[me] = 20.0
	_check(TBSpy.chance(g, me, t, "survey") > TBSpy.chance(g, me, t, "steal"), "survey is easier than stealing (%.2f vs %.2f)" % [TBSpy.chance(g, me, t, "survey"), TBSpy.chance(g, me, t, "steal")])
	g.see_until[me * g.N1 + t] = 0
	var seen_before := TBVision.nation_seen(g, me, t)
	var tries := 0
	while g.see_until[me * g.N1 + t] <= g.turn and tries < 30:
		g.intel[me] = 20.0; g.apply({"cmd": "spy", "n": me, "t": t, "op": "survey"}); tries += 1
	_check(g.see_until[me * g.N1 + t] > g.turn and TBVision.nation_seen(g, me, t), "a successful survey shows their armies (was %s, %d tries)" % [str(seen_before), tries])
	g.intel[me] = 20.0; var i0: float = g.intel[me]
	g.apply({"cmd": "spy", "n": me, "t": t, "op": "survey"})
	_check(absf(i0 - g.intel[me] - 3.0) < 0.01, "a survey costs 3 intelligence")
	print("SPY_LOGIC OK" if fails == 0 else "SPY_LOGIC FAIL %d" % fails)
	quit(fails)
