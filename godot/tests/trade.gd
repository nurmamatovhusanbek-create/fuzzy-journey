extends SceneTree
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 6})
	var fails := 0
	var a := 0; var b := 0
	for k in range(1, g.N1):
		if k == g.rebel or g.alive[k] == 0 or g.own_count(k) < 3: continue
		if a == 0: a = k
		elif b == 0: b = k; break
	g.set_human(a); g.dp[a] = 10
	var i0: int = g.income(a)["gold"]
	var r := g.apply({"cmd": "trade", "n": a, "t": b})
	print("propose: ", r)
	var i1: int = g.income(a)["gold"]
	print("income ", i0, " -> ", i1, " (partner ", g.nat_name[b], ", value ", TBTrade.value(g, b), ")")
	if r["ok"] and i1 <= i0: fails += 1
	if not r["ok"] and r["err"] != "refused": fails += 1
	if r["ok"]:
		g.dp[a] = 10; g.dp[b] = 10
		g.apply({"cmd": "declareWar", "n": a, "t": b})
		print("deal cancelled by war: ", not TBTrade.has(g, a, b)); if TBTrade.has(g, a, b): fails += 1
		print("counts: ", g.trade_cnt[a], g.trade_cnt[b]); if g.trade_cnt[a] != 0 or g.trade_cnt[b] != 0: fails += 1
	var g2 := TBGame.new(w, {}, {"seed": 7}); var deals := 0
	for t in 100: g2.end_turn()
	for n in range(1, g2.N1): deals += g2.trade_cnt[n]
	print("AI trade deal endpoints after 100 turns: ", deals); if deals == 0: fails += 1
	print("TRADE ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
