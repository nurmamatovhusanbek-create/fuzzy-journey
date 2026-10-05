extends SceneTree
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 3})
	var n := 1
	for k in range(1, g.N1):
		if k != g.rebel and g.alive[k] != 0: n = k; break
	g.set_human(n)
	var fails := 0
	g.gold[n] = 1000; g.mp[n] = 20; g.era[n] = 2
	var inc0: int = g.income(n)["gold"]
	var r := g.apply({"cmd": "decide", "n": n, "id": "trade_fair"})
	var inc1: int = g.income(n)["gold"]
	print("trade fair: ", r, " income ", inc0, " -> ", inc1)
	if not r["ok"] or inc1 <= inc0: fails += 1
	r = g.apply({"cmd": "decide", "n": n, "id": "trade_fair"})
	print("repeat refused: ", r); if r["ok"]: fails += 1
	r = g.apply({"cmd": "decide", "n": n, "id": "nonsense"}); if r["ok"]: fails += 1
	for t in 21: g.end_turn()
	var i := TBDecisions.index_of("trade_fair")
	print("expired after 21 turns: ", not TBDecisions.is_active(g, n, i)); if TBDecisions.is_active(g, n, i): fails += 1
	g.gold[n] = 1000; g.mp[n] = 20; g.infamy[n] = 10
	r = g.apply({"cmd": "decide", "n": n, "id": "amnesty"}); print("amnesty: ", r, " infamy ", g.infamy[n])
	if not r["ok"]: fails += 1
	r = g.apply({"cmd": "decide", "n": n, "id": "mil_reform"}); print("mil reform: ", r)
	print("combat mul: ", g.combat_mul(n))
	# AI uses decisions
	var g2 := TBGame.new(w, {}, {"seed": 4}); var used := 0
	for t in 120: g2.end_turn()
	for e in g2.log: if e["kind"] == "decision": used += 1
	print("AI decisions enacted in 120 turns: ", used); if used == 0: fails += 1
	print("DECISIONS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
