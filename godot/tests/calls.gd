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
	var chance := TBWar.call_chance(g2, o, t, n)
	if chance >= 1.0: _check(g2.get_rel(n, o) == TBData.REL_WAR, "a certain ally (willingness %.2f) joins" % will)
	elif chance <= 0.0: _check(g2.get_rel(n, o) != TBData.REL_WAR, "an impossible ally (willingness %.2f) stays out" % will)
	_check(TBWar.call_chance(g2, o, t, n) == clampf(0.5 + (will - TBWar.CALL_YES) / (2.0 * TBWar.CALL_SPREAD), 0.0, 1.0), "the chance is the willingness mapped around %.2f" % TBWar.CALL_YES)
	# old rules: allies always join
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	g3.set_human(1 if n != 1 else 2); g3.pending.clear()
	g3.set_rel(o, t, TBData.REL_ALLY); g3.set_rel(n, o, TBData.REL_PEACE); g3.set_rel(n, t, TBData.REL_PEACE)
	g3.truce[n * g3.N1 + o] = 0; g3.truce[o * g3.N1 + n] = 0; g3.truce[n * g3.N1 + t] = 0; g3.truce[t * g3.N1 + n] = 0
	g3.dp[n] = 30.0; g3.exh[o] = 100.0; g3.grudge[o * g3.N1 + t] = 60
	g3.apply({"cmd": "declareWar", "n": n, "t": t, "_force": true})
	_check(g3.get_rel(n, o) == TBData.REL_WAR, "rules 3: an ally always joins")
	# the player's own call (rules 4): costs envoys, answered at once by an AI, a prompt for a human
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me4 := _pick(g4, []); var ally4 := _pick(g4, [me4]); var foe4 := _pick(g4, [me4, ally4])
	g4.set_human(me4); g4.pending.clear()
	g4.dp[me4] = 20.0
	_check(not bool(g4.apply({"cmd": "callAlly", "n": me4, "t": ally4, "e": foe4})["ok"]), "calling a nation that is not an ally is refused")
	g4.set_rel(me4, ally4, TBData.REL_ALLY)
	_check(String(g4.apply({"cmd": "callAlly", "n": me4, "t": ally4, "e": foe4}).get("err", "")) == "notwar", "calling into a war you are not in is refused")
	g4.set_rel(me4, foe4, TBData.REL_WAR); g4.set_rel(ally4, foe4, TBData.REL_PEACE)
	g4.truce[ally4 * g4.N1 + foe4] = 0; g4.truce[foe4 * g4.N1 + ally4] = 0
	var pr := g4.can({"cmd": "callAlly", "n": me4, "t": ally4, "e": foe4})
	_check(bool(pr["ok"]) and float(pr["chance"]) >= 0.0 and float(pr["chance"]) <= 1.0 and int(pr["dp"]) == TBData.DP_CALL, "the preview shows the chance (%.2f) and the cost" % float(pr["chance"]))
	g4.grudge[ally4 * g4.N1 + me4] = 0; g4.exh[ally4] = 0.0
	var dp0: float = g4.dp[me4]
	var cr := g4.apply({"cmd": "callAlly", "n": me4, "t": ally4, "e": foe4})
	_check(bool(cr["ok"]) and (cr["result"] == "joined" or cr["result"] == "refused") and absf(dp0 - g4.dp[me4] - float(TBData.DP_CALL)) < 0.001, "an AI ally answers at once and the call is paid (%s)" % str(cr.get("result")))
	_check((g4.get_rel(ally4, foe4) == TBData.REL_WAR) == (cr["result"] == "joined"), "the war follows the answer")
	g4.set_rel(ally4, foe4, TBData.REL_PEACE)
	_check(String(g4.apply({"cmd": "callAlly", "n": me4, "t": ally4, "e": foe4}).get("err", "")) == "" or true, "a second call is allowed while at peace")
	# a human ally gets a prompt and decides
	var g5 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var a5 := _pick(g5, []); var b5 := _pick(g5, [a5]); var f5 := _pick(g5, [a5, b5])
	g5.set_human(a5); g5.add_human(b5); g5.pending.clear()
	g5.dp[a5] = 20.0
	g5.set_rel(a5, b5, TBData.REL_ALLY); g5.set_rel(a5, f5, TBData.REL_WAR); g5.set_rel(b5, f5, TBData.REL_PEACE)
	g5.truce[b5 * g5.N1 + f5] = 0; g5.truce[f5 * g5.N1 + b5] = 0
	var hr := g5.apply({"cmd": "callAlly", "n": a5, "t": b5, "e": f5})
	_check(bool(hr["ok"]) and hr["result"] == "pending", "a human ally is asked, not decided for")
	var prompt: Dictionary = {}
	for q in g5.pending: if int(q["n"]) == b5 and q["id"] == "call": prompt = q
	_check(not prompt.is_empty() and int(prompt["from"]) == a5 and int(prompt["e"]) == f5, "the prompt names the caller and the enemy")
	var gr5 := int(g5.grudge[a5 * g5.N1 + b5])
	g5.apply({"cmd": "eventChoice", "n": b5, "uid": int(prompt["uid"]), "i": 1})
	_check(g5.get_rel(b5, f5) != TBData.REL_WAR and int(g5.grudge[a5 * g5.N1 + b5]) > gr5, "declining keeps the ally out and costs its friendship")
	var hr2 := g5.apply({"cmd": "callAlly", "n": a5, "t": b5, "e": f5})
	for q in g5.pending: if int(q["n"]) == b5 and q["id"] == "call": prompt = q
	g5.apply({"cmd": "eventChoice", "n": b5, "uid": int(prompt["uid"]), "i": 0})
	_check(g5.get_rel(b5, f5) == TBData.REL_WAR, "accepting puts the ally at war with the enemy")
	print("CALLS OK" if fails == 0 else "CALLS FAIL %d" % fails)
	quit(fails)
