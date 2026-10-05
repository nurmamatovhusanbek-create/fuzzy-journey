extends SceneTree
func _pair(g: TBGame) -> Array:
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		for p in g.owned(n):
			for i in range(g.nb_off[p], g.nb_off[p + 1]):
				var q: int = g.nb[i]; var t := g.owner[q]
				if t != 0 and t != n and t != g.rebel and g.nb_sea[i] == 0 and g.get_rel(n, t) == D.REL_PEACE and not g.has_truce(n, t) and g.capital[q] == 0 and g.overlord[n] != t and g.overlord[t] != n:
					return [n, t, q]
	return []
const D = preload("res://src/engine/data.gd")
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var era := TBWorld.load_era("res://data", "gunpowder")
	# 1. strong demander, AI target: yields
	var g := TBGame.new(w, era, {"seed": 4})
	var pr := _pair(g); var n: int = pr[0]; var t: int = pr[1]; var q: int = pr[2]
	g.set_human(n); g.dp[n] = 10
	for p in g.owned(n): g.army[p] = 400
	for p in g.owned(t): g.army[p] = 5
	var inf0 := g.infamy[n]
	var r := g.apply({"cmd": "ultimatum", "n": n, "t": t, "p": q})
	print("strong ->", r, " owner now=", g.owner[q] == n, " infamy +", g.infamy[n] - inf0, " rel=", g.get_rel(n, t))
	if not r["ok"] or g.owner[q] != n or g.get_rel(n, t) != D.REL_PEACE or g.dp[n] > 8.01: fails += 1
	if g.apply({"cmd": "ultimatum", "n": n, "t": t, "p": g.owned(t)[0]})["ok"]: fails += 1      # truce now
	# 2. weak demander: refused, war with free casus belli
	var g2 := TBGame.new(w, era, {"seed": 4})
	g2.set_human(n); g2.dp[n] = 10
	for p in g2.owned(n): g2.army[p] = 5
	for p in g2.owned(t): g2.army[p] = 400
	var i0 := g2.infamy[n]
	var r2 := g2.apply({"cmd": "ultimatum", "n": n, "t": t, "p": q})
	print("weak ->", r2, " rel=", g2.get_rel(n, t), " infamy +", g2.infamy[n] - i0)
	if g2.get_rel(n, t) != D.REL_WAR or g2.infamy[n] != i0 or g2.owner[q] != t: fails += 1
	# 3. human target gets a prompt; yielding hands over the province
	var g3 := TBGame.new(w, era, {"seed": 4})
	g3.set_human(t); g3.dp[n] = 10
	var r3 := TBDiplo.ultimatum(g3, n, t, q)
	var pend := -1
	for e in g3.pending: if e["id"] == "ultimatum": pend = int(e["uid"])
	print("human target -> ", r3, " pending uid=", pend)
	if pend < 0: fails += 1
	else:
		g3.apply({"cmd": "eventChoice", "n": t, "uid": pend, "i": 0})
		if g3.owner[q] != n: fails += 1
	var g4 := TBGame.new(w, era, {"seed": 4}); g4.set_human(t); g4.dp[n] = 10
	TBDiplo.ultimatum(g4, n, t, q)
	for e in g4.pending: if e["id"] == "ultimatum": g4.apply({"cmd": "eventChoice", "n": t, "uid": int(e["uid"]), "i": 1})
	if g4.get_rel(n, t) != D.REL_WAR or g4.owner[q] != t: fails += 1
	# 4. capitals and rules 0 are off limits
	var cap := g.capital_of[t]
	if cap >= 0 and TBDiplo.can_ultimatum(g2, n, t, cap) == "": fails += 1
	var g0 := TBGame.new(w, era, {"seed": 4, "rules": 0}); g0.set_human(n); g0.dp[n] = 10
	if g0.apply({"cmd": "ultimatum", "n": n, "t": t, "p": q})["ok"]: fails += 1
	# 5. a long game: AI issues ultimatums, results are consistent
	var g5 := TBGame.new(w, era, {"seed": 2})
	var y := 0; var d := 0
	for k in 250:
		g5.end_turn()
	for e in g5.log:
		if e["kind"] == "ultimatum":
			if e["k"] == "yield": y += 1
			else: d += 1
	print("250 turns: ultimatums yielded=%d defied=%d" % [y, d])
	if y + d == 0: fails += 1
	print("ULTIMATUM ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
