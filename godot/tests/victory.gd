extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var w := TBWorld.load_from("res://data")
	var failed := 0
	# economic victory triggers
	var g := TBGame.new(w, {}, {"seed": 4})
	var me := g.owner[g.owned(1)[0]] if false else 1
	g.set_human(me); g.gold[me] = 6000
	g.end_turn()
	print("economic: over=%s winner=%d kind=%s" % [g.over, g.winner, g.victory_kind]); if not (g.over and g.winner == me and g.victory_kind == "economic"): failed += 1
	# domination triggers by giving the human 26% of provinces
	var g2 := TBGame.new(w, {}, {"seed": 4})
	g2.set_human(1)
	for p in range(0, int(g2.P * 0.27)): g2.set_owner(p, 1)
	g2.alive[1] = 1
	g2.end_turn()
	print("domination: over=%s kind=%s progress=%s" % [g2.over, g2.victory_kind, str(TBTurn.victory_progress(g2, 1))]); if not (g2.over and g2.winner == 1): failed += 1
	# no false positive for a normal start
	var g3 := TBGame.new(w, {}, {"seed": 4}); g3.set_human(1)
	for i in 5: g3.end_turn()
	print("normal start: over=%s" % g3.over); if g3.over: failed += 1
	# UI screenshot of the goals modal
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best]); main._clear_overlay()
	main.hud.goals_pressed.emit()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/goals.png")
	quit(failed)
