extends SceneTree
## Rules 5 mass orders: spread marches the capital's army out to the front and keeps a guard; muster raises levies in every front province in one go; both cost a move or two,
## the preview (can) agrees with the order (apply), and the AI spreads its own army. Usage: -s tests/mass5.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	var n: int = g.nat_code.find("france")
	g.set_human(n)
	var cap: int = g.capital_of[n]
	var total := 0
	for p in g.owned(n): total += g.army[p]
	_check(g.army[cap] == total and total > 0, "the whole army stands in the capital (%d of %d)" % [g.army[cap], total])
	g.mp[n] = 10.0
	var pv := g.can({"cmd": "spread", "n": n, "p": cap})
	_check(bool(pv["ok"]), "spread is possible from the capital (%s)" % pv["reason"])
	print("preview: %d provinces, %d men, %d moves" % [int(pv.get("n_targets", 0)), int(pv["gain"]), int(pv["moves"])])
	var mp0: float = g.mp[n]
	var r := g.apply({"cmd": "spread", "n": n, "p": cap})
	_check(bool(r["ok"]), "spread works (%s)" % str(r.get("err", "")))
	_check(int(r.get("sent", 0)) == int(pv["gain"]) and int(r.get("k", 0)) == int(pv["n_targets"]), "the preview and the order agree (%s vs %s)" % [str(pv["gain"]), str(r.get("sent", 0))])
	_check(absf((mp0 - g.mp[n]) - float(pv["moves"])) < 0.01, "it costs what the preview says")
	_check(g.army[cap] >= int(total * 0.3) - 5, "a guard stays home (%d of %d)" % [g.army[cap], total])
	var elsewhere := 0
	for p in g.owned(n): if p != cap: elsewhere += g.army[p]
	for m in g.marches: if int(m["n"]) == n: elsewhere += int(m["k"])
	_check(elsewhere >= int(pv["gain"]) - 5, "the men are on the move or arrived (%d)" % elsewhere)
	# muster
	g.gold[n] = 5.0e6; g.mp[n] = 10.0
	var mv := g.can({"cmd": "muster", "n": n, "pct": 25})
	_check(bool(mv["ok"]) and int(mv["gain"]) > 0, "muster has men to raise (%s)" % mv["reason"])
	var men0 := 0
	for p in g.owned(n): men0 += g.army[p]
	var gold0: float = g.gold[n]
	var mr := g.apply({"cmd": "muster", "n": n, "pct": 25})
	var men1 := 0
	for p in g.owned(n): men1 += g.army[p]
	_check(bool(mr["ok"]) and men1 - men0 == int(mr["men"]) and int(mr["men"]) == int(mv["gain"]), "muster raises what the preview said (%d)" % (men1 - men0))
	_check(absf((gold0 - g.gold[n]) - float(mr["gold"])) < 2.0, "and charges what it said")
	# refuses without moves, and in older rules
	g.mp[n] = 0.0
	_check(not bool(g.can({"cmd": "muster", "n": n, "pct": 25})["ok"]), "no moves, no muster")
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 4})
	_check(not bool(g4.can({"cmd": "spread", "n": 1, "p": 0})["ok"]), "rules 4 knows nothing of it")
	# the AI spreads its own army
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 6, "difficulty": "normal", "rules": 5})
	var spread_ais := 0
	for t in 6: g2.end_turn()
	for k in range(1, g2.N1):
		if g2.alive[k] == 0 or k == g2.rebel: continue
		var c2: int = g2.capital_of[k]
		var all := 0
		for p in g2.owned(k): all += g2.army[p]
		if c2 >= 0 and all > g2.au(100.0) and float(g2.army[c2]) < 0.8 * float(all): spread_ais += 1
	_check(spread_ais >= 5, "AI nations spread their armies (%d)" % spread_ais)
	print("MASS5 OK" if fails == 0 else "MASS5 FAIL %d" % fails)
	quit(fails)
