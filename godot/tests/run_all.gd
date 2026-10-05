extends SceneTree
# Headless test runner:  godot --headless --path godot -s tests/run_all.gd

var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond: print("  ok   ", msg)
	else:
		print("  FAIL ", msg); failed += 1

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var w := TBWorld.load_from("res://data")
	check(w.P == 1788, "world loads (P=%d)" % w.P)
	check(w.ids.size() == w.W * w.H * 2, "id raster size")
	var g := TBGame.new(w, {}, {"seed": 7})
	check(g.N > 200, "nations (%d)" % g.N)
	print("  init ms: ", Time.get_ticks_msec() - t0)
	var t1 := Time.get_ticks_msec()
	for i in 30: g.end_turn()
	print("  30 turns ms: ", Time.get_ticks_msec() - t1, "  (", float(Time.get_ticks_msec() - t1) / 30.0, " ms/turn)")
	print("  checksum: ", g.state_checksum())
	var g2 := TBGame.new(w, {}, {"seed": 7})
	for i in 30: g2.end_turn()
	check(g.state_checksum() == g2.state_checksum(), "deterministic")
	# --- command checks (rules 1)
	var g3 := TBGame.new(w, {}, {"seed": 21})
	var me := 0
	for p in g3.P: if g3.owner[p] != 0: me = g3.owner[p]; break
	g3.set_human(me); g3.gold[me] = 5000; g3.mp[me] = 20; g3.dp[me] = 20; g3.intel[me] = 30
	var mine: PackedInt32Array = g3.owned(me)
	var a0: int = g3.army[mine[0]]
	check(g3.apply({"cmd": "hire", "n": me, "p": mine[0], "amount": 40})["ok"] and g3.army[mine[0]] == a0 + 40, "hire mercenaries")
	var d0: int = g3.dev[mine[0]]
	var rdev := g3.apply({"cmd": "develop", "n": me, "p": mine[0]})
	check(rdev["ok"] or rdev["err"] == "max", "develop (ok or tech-capped)")
	var tgt := 0
	for p in mine:
		for e in range(g3.nb_off[p], g3.nb_off[p + 1]):
			var o: int = g3.owner[g3.nb[e]]
			if o != 0 and o != me: tgt = o
	check(g3.apply({"cmd": "declareWar", "n": me, "t": tgt})["ok"], "declare war")
	check(g3.get_rel(me, tgt) == TBData.REL_WAR and g3.war_cnt[me] == 1, "relation + war counter")
	var sp := g3.apply({"cmd": "spy", "n": me, "t": tgt, "op": "steal"})
	check(sp["ok"] and sp.has("success"), "spy op resolves")
	check(not g3.apply({"cmd": "spy", "n": me, "t": me, "op": "steal"})["ok"], "cannot spy on self")
	var pr := g3.apply({"cmd": "peace", "n": me, "t": tgt, "kind": "white", "_force": true})
	check(pr["ok"] and g3.war_cnt[me] == 0 and g3.has_truce(me, tgt), "white peace + truce, war counter cleared")
	check(not g3.apply({"cmd": "declareWar", "n": me, "t": tgt})["ok"], "truce blocks war")
	check(not g3.apply({"cmd": "recruit", "n": 0, "p": mine[0]})["ok"], "invalid nation rejected")
	quit(1 if failed > 0 else 0)
