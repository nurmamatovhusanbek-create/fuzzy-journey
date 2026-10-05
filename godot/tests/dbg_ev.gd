extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "roman"), {"seed": 3})
	g.set_human(g.owner[1000])
	print("human=", g.human_id, " start_year=", g.start_year, " year=", g.year, " sched=", TBEvents.scheduled_for("roman").size())
	for t in 8:
		g.end_turn()
		print("turn=%d year=%d m=%d pending=%d fired=%s" % [g.turn, g.year, g.month_idx, g.pending.size(), str(g.ev_fired.keys())])
	quit()
