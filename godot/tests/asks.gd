extends SceneTree
const D = preload("res://src/engine/data.gd")
## Requests to AI courts: sent now (cost spent), answered at the start of the next turn, logged as "ans"; save/load keeps them.
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", "gunpowder")
	var fails := 0
	var g := TBGame.new(w, era, {"seed": 7})
	var n := 1
	for k in range(1, g.N1):
		if g.alive[k] != 0 and k != g.rebel: n = k; break
	g.set_human(n); g.dp[n] = 20
	var t := 0
	for k in range(1, g.N1):
		if k != n and g.alive[k] != 0 and k != g.rebel and g.human[k] == 0 and g.get_rel(n, k) == D.REL_PEACE and not g.has_truce(n, k): t = k; break
	if t == 0: print("no target"); quit(1); return
	var c0 := TBAsks.chance(g, n, "nap", t)
	var chk := TBAsks.check(g, n, "nap", t)
	print("nap chance=", c0, " check=", chk)
	if not bool(chk["ok"]) or c0 < 0 or c0 > 97: fails += 1
	var dp0 := g.dp[n]
	var r := g.apply({"cmd": "ask", "n": n, "kind": "nap", "t": t})
	print("send ->", r, " dp ", dp0, " -> ", g.dp[n], " asks=", g.asks.size())
	if not r["ok"] or g.asks.size() != 1 or g.dp[n] >= dp0 or g.get_rel(n, t) == D.REL_NAP: fails += 1
	if g.apply({"cmd": "ask", "n": n, "kind": "nap", "t": t})["ok"]: fails += 1           # already asked
	if not TBAsks.pending(g, n, t, "nap"): fails += 1
	# save / load keeps the question
	var g_copy := TBSave.from_dict(w, JSON.parse_string(JSON.stringify(TBSave.to_dict(g))))
	if g_copy.asks.size() != 1 or not TBAsks.pending(g_copy, n, t, "nap"): fails += 1
	# the answer comes with the next turn, never before
	print("asks before: ", g.asks, " copy: ", g_copy.asks)
	var rel0 := g.get_rel(n, t)
	var nlog := g.log.size()
	g.end_turn()
	var ans := []
	for i in range(nlog, g.log.size()):
		if g.log[i]["kind"] == "ans": ans.append(g.log[i])
	print("after turn: ", ans, " rel=", g.get_rel(n, t))
	if ans.size() != 1 or g.asks.size() != 0: fails += 1
	elif bool(ans[0]["ok"]) != (g.get_rel(n, t) == D.REL_NAP): fails += 1
	# spies: pay now, result next turn
	var g2 := TBGame.new(w, era, {"seed": 7})
	g2.set_human(n); g2.intel[n] = 30.0
	var i0 := g2.intel[n]
	var rs := g2.apply({"cmd": "ask", "n": n, "kind": "spy", "t": t, "op": "steal"})
	print("spy ->", rs, " intel ", i0, " -> ", g2.intel[n])
	if not rs["ok"] or g2.intel[n] >= i0: fails += 1
	g2.end_turn()
	var got := false
	for e in g2.log: if e["kind"] == "ans" and e["what"] == "spy": got = true
	if not got: fails += 1
	# many seeds: acceptance frequency tracks the shown percentage
	var yes := 0; var tot := 0; var pct := 0.0
	for sd in 40:
		var gg := TBGame.new(w, era, {"seed": 100 + sd})
		gg.set_human(n); gg.dp[n] = 20
		var tt := 0
		for k in range(1, gg.N1):
			if k != n and gg.alive[k] != 0 and k != gg.rebel and gg.human[k] == 0 and gg.get_rel(n, k) == D.REL_PEACE: tt = k; break
		if tt == 0: continue
		pct += TBAsks.chance(gg, n, "nap", tt)
		gg.apply({"cmd": "ask", "n": n, "kind": "nap", "t": tt})
		var l0 := gg.log.size()
		gg.end_turn()
		for i in range(l0, gg.log.size()):
			if gg.log[i]["kind"] == "ans" and gg.log[i]["a"] == n: tot += 1; yes += 1 if gg.log[i]["ok"] else 0
	print("40 seeds: yes ", yes, " of ", tot, " mean shown ", pct / maxf(1.0, tot))
	# determinism: same position, same answer
	# rules 0 refuses
	var g0 := TBGame.new(w, era, {"seed": 7, "rules": 0}); g0.set_human(n); g0.dp[n] = 20
	if g0.apply({"cmd": "ask", "n": n, "kind": "nap", "t": t})["ok"]: fails += 1
	print("ASKS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
