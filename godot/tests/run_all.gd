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
	quit(1 if failed > 0 else 0)
