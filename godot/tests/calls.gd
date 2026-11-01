extends SceneTree
## Rules 4 calls to arms: an AI ally weighs trust, the threat, a shared border, the distance and its own exhaustion; one that stays out loses the friendship of the ally it left alone.
## Usage: -s tests/calls.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _pick(g: TBGame, skip: Array) -> int:
	for n in range(1, g.N1):
		if n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 2 and not (n in skip) and g.human[n] == 0: return n
	return -1
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var n := _pick(g, []); var t := _pick(g, [n]); var o := _pick(g, [n, t])
	g.set_human(1 if n != 1 else 2); g.pending.clear()
	g.grudge[o * g.N1 + t] = 0; g.exh[o] = 0.0
	var w0 := TBWar.call_willingness(g, o, t, n)
	g.grudge[o * g.N1 + t] = 60
	var w1 := TBWar.call_willingness(g, o, t, n)
	g.grudge[o * g.N1 + t] = 0; g.exh[o] = 100.0
	var w2 := TBWar.call_willingness(g, o, t, n)
	_check(w1 < w0 and w2 < w0, "distrust and exhaustion lower the willingness (%.2f %.2f %.2f)" % [w0, w1, w2])
	_check(w0 <= 1.0 and w0 >= -1.0, "within bounds")
	var terms: Array = TBWar.call_terms(g, o, t, n)
	_check(terms.size() == 5, "five terms are shown")
	# a refusing ally
	g.exh[o] = 100.0; g.grudge[o * g.N1 + t] = 60
	g.set_rel(o, t, TBData.REL_ALLY)
	g.set_rel(n, o, TBData.REL_PEACE); g.set_rel(n, t, TBData.REL_PEACE)
	g.truce[n * g.N1 + o] = 0; g.truce[o * g.N1 + n] = 0; g.truce[n * g.N1 + t] = 0; g.truce[t * g.N1 + n] = 0
	g.dp[n] = 30.0
	var gr0 := int(g.grudge[t * g.N1 + o])
	var res := g.apply({"cmd": "declareWar", "n": n, "t": t, "_force": true})
	_check(bool(res["ok"]), "the war is declared (%s)" % str(res))
	_check(g.get_rel(n, o) != TBData.REL_WAR, "the exhausted, distrustful ally stays out")
	_check(g.grudge[t * g.N1 + o] == mini(100, gr0 + TBWar.CALL_SNUB_GRUDGE), "the ally left alone resents it")
	var logged := false
	for e in g.log: if String(e["kind"]) == "call_refused": logged = true
	_check(logged, "the refusal is in the chronicle")
	# a willing ally joins
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	g2.set_human(1 if n != 1 else 2); g2.pending.clear()
	g2.grudge[o * g2.N1 + t] = 0; g2.exh[o] = 0.0
	g2.set_rel(o, t, TBData.REL_ALLY)
	g2.set_rel(n, o, TBData.REL_PEACE); g2.set_rel(n, t, TBData.REL_PEACE)
	g2.truce[n * g2.N1 + o] = 0; g2.truce[o * g2.N1 + n] = 0; g2.truce[n * g2.N1 + t] = 0; g2.truce[t * g2.N1 + n] = 0
	g2.dp[n] = 30.0
	var will := TBWar.call_willingness(g2, o, t, n)
	g2.apply({"cmd": "declareWar", "n": n, "t": t, "_force": true})
	_check((g2.get_rel(n, o) == TBData.REL_WAR) == (will > TBWar.CALL_YES), "the ally joins exactly when its willingness (%.2f) is above %.2f" % [will, TBWar.CALL_YES])
	# old rules: allies always join
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	g3.set_human(1 if n != 1 else 2); g3.pending.clear()
	g3.set_rel(o, t, TBData.REL_ALLY); g3.set_rel(n, o, TBData.REL_PEACE); g3.set_rel(n, t, TBData.REL_PEACE)
	g3.truce[n * g3.N1 + o] = 0; g3.truce[o * g3.N1 + n] = 0; g3.truce[n * g3.N1 + t] = 0; g3.truce[t * g3.N1 + n] = 0
	g3.dp[n] = 30.0; g3.exh[o] = 100.0; g3.grudge[o * g3.N1 + t] = 60
	g3.apply({"cmd": "declareWar", "n": n, "t": t, "_force": true})
	_check(g3.get_rel(n, o) == TBData.REL_WAR, "rules 3: an ally always joins")
	print("CALLS OK" if fails == 0 else "CALLS FAIL %d" % fails)
	quit(fails)
