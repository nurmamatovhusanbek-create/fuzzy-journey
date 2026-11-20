extends SceneTree
## An event card says what happens: the preview of an effect is exactly what applying it adds (gold, manpower, research, a trade windfall, armies, people), for a big nation and a small one;
## and the amounts scale with the nation. Usage: -s tests/event_amounts.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5})
	var fr := g.nat_code.find("france"); g.set_human(fr); g.pending.clear()
	var small := -1
	for n in range(1, g.N1):
		if n != fr and n != g.rebel and g.alive[n] != 0 and (small < 0 or g.labour(n) < g.labour(small)) and g.owned(n).size() > 0: small = n
	_check(g.labour(fr) > 20.0 * g.labour(small), "a big and a small nation to compare (%.0f vs %.0f)" % [g.labour(fr), g.labour(small)])
	for n in [fr, small]:
		g.gold[n] = 5e4; g.manpower[n] = 1e5; g.research[n] = 0.0
		# gold
		var g0: float = g.gold[n]
		var fx := [{"op": "gold", "d": -60}]
		var pv: Array = TBEvents.preview(g, n, fx)
		TBEvents.apply_effects(g, n, fx)
		_check(absf((g.gold[n] - g0) - float(pv[0]["v"])) < 0.01, "nation %d: the gold in the card is the gold taken (%.1f vs %.1f)" % [n, float(pv[0]["v"]), g.gold[n] - g0])
		# manpower
		var m0: float = g.manpower[n]
		pv = TBEvents.preview(g, n, [{"op": "manpower", "d": 25}])
		TBEvents.apply_effects(g, n, [{"op": "manpower", "d": 25}])
		_check(absf((g.manpower[n] - m0) - float(pv[0]["v"])) < 0.01 and float(pv[0]["v"]) >= 1.0, "nation %d: the manpower in the card is the manpower added (%.1f)" % [n, g.manpower[n] - m0])
		# research
		var r0: float = g.research[n]
		pv = TBEvents.preview(g, n, [{"op": "research", "d": 40}])
		TBEvents.apply_effects(g, n, [{"op": "research", "d": 40}])
		_check(absf((g.research[n] - r0) - float(pv[0]["v"])) < 0.01 and g.research[n] > r0, "nation %d: the research in the card is the research gained (%.1f)" % [n, g.research[n] - r0])
		# a trade windfall
		var t0: int = g.trade_bonus[n]
		pv = TBEvents.preview(g, n, [{"op": "bonus", "kind": "trade", "amount": 40}])
		TBEvents.apply_effects(g, n, [{"op": "bonus", "kind": "trade", "amount": 40}])
		_check(g.trade_bonus[n] - t0 == int(float(pv[0]["v"])), "nation %d: the windfall in the card is the windfall (%d vs %d)" % [n, g.trade_bonus[n] - t0, int(float(pv[0]["v"]))])
		# an army effect in the capital
		var cp: int = g.capital_of[n]
		g.army[cp] = g.army_cap(cp) / 2
		var a0: int = g.army[cp]
		pv = TBEvents.preview(g, n, [{"op": "army", "scope": "capital", "d": -20}])
		TBEvents.apply_effects(g, n, [{"op": "army", "scope": "capital", "d": -20}])
		_check(g.army[cp] - a0 == int(float(pv[0]["v"])) or g.army[cp] == g.au(5.0), "nation %d: the soldiers in the card are the soldiers lost (%d vs %d)" % [n, g.army[cp] - a0, int(float(pv[0]["v"]))])
	_check(absf(TBEvents.amount(g, fr, "gold", -60.0)) > 5.0 * absf(TBEvents.amount(g, small, "gold", -60.0)), "the same decree costs a big nation more gold than a small one")
	# every effect of every random event has a preview row
	var missing := 0
	for ev in TBEvents.random_defs():
		for ch in ev["choices"]:
			var ef: Array = ch["effects"]
			var rows: Array = TBEvents.preview(g, fr, ef)
			var known := 0
			for e in ef: if String(e.get("op", "")) != "": known += 1
			if rows.size() != known: missing += 1; print("  no row for ", ev["id"], " ", ef)
	_check(missing == 0, "every effect of every random event can be shown on its card (%d choices short)" % missing)
	print("EVENT_AMOUNTS ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(fails)
