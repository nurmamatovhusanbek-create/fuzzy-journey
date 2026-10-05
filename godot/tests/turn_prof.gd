extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 3})
	g.set_human(g.owner[1000])
	for t in 30: g.end_turn()
	var acc := {}
	for t in 60:
		var parts := {}
		var t0 := Time.get_ticks_usec()
		TBAI.run(g); parts["ai"] = Time.get_ticks_usec() - t0; t0 = Time.get_ticks_usec()
		TBTurn._tick(g); parts["tick"] = Time.get_ticks_usec() - t0; t0 = Time.get_ticks_usec()
		TBTurn.rebel_turn(g); parts["rebel"] = Time.get_ticks_usec() - t0
		g.turn += 1; g.month_idx += 6
		if g.month_idx >= 12: g.month_idx -= 12; g.year += 1
		t0 = Time.get_ticks_usec(); TBRulers.tick(g); parts["rulers"] = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec(); TBDiplo.tick(g); parts["diplo"] = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec(); TBStats.record(g); parts["stats"] = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec(); TBEvents.run(g); parts["events"] = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec(); TBTurn.check_victory(g); parts["victory"] = Time.get_ticks_usec() - t0
		g.take_dirty()
		for k in parts: acc[k] = acc.get(k, 0) + parts[k]
	for k in acc: print("%-8s %6.1f ms/turn" % [k, acc[k] / 60.0 / 1000.0])
	quit()
