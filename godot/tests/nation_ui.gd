extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best])
	var g: TBGame = main.g
	var me := g.human_id
	# find a neighbouring nation and declare war so war info is populated
	var tgt := 0
	for p in g.owned(me):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var o := g.owner[g.nb[e]]
			if o != 0 and o != me: tgt = o
	g.dp[me] = 10
	main._on_command({"cmd": "declareWar", "t": tgt})
	for i in 3: main.end_turn(); while main._busy: await process_frame
	for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": me, "uid": e["uid"], "i": 0})
	main._clear_overlay()
	main._open_nation(tgt)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/nation_detail.png")
	print("rel=", g.get_rel(me, tgt), " ws=", g.war_score[me * g.N1 + tgt], "/", g.war_score[tgt * g.N1 + me])
	quit()
