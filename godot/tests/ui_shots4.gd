extends SceneTree
## generals + ultimatum panel review. Usage: -- <outdir>
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	g.gold[fr] = 800; g.dp[fr] = 8
	var p: int = g.capital_of[fr]
	g.army[p] = 60
	g.apply({"cmd": "appoint", "n": fr, "p": p})
	g.gen[p] = TBGenerals.pack(3, 9, 1)
	main.hud.refresh(); main._select(p)
	main.map.fly_to(main.world.lon[p], main.world.lat[p], 3.0)
	for i in 6: await process_frame
	await _shot("g1_general")
	# a foreign border province at peace
	var q := -1
	for n in range(1, g.N1):
		if n == fr or n == g.rebel or g.alive[n] == 0 or g.get_rel(fr, n) != 0: continue
		for pp in g.owned(n):
			if TBDiplo.can_ultimatum(g, fr, n, pp) == "": q = pp; break
		if q >= 0: break
	print("ultimatum target province ", q)
	if q >= 0:
		main._select(q); await _shot("g2_ultimatum")
		main._select(-1)
		var o: int = g.owner[q]
		g.ev_uid += 1
		var e := {"uid": g.ev_uid, "n": fr, "kind": "prop", "id": "ultimatum", "from": o, "p": p, "icon": "📜", "cat": "", "count": 2}
		TBModals.event_prompt(main._overlay, e, func(i): pass, g)
		await _shot("g3_prompt")
	quit(0)
