extends SceneTree
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
	main.cfg["lang"] = "en"; TBI18n.load_lang("en")
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	# find a border pair with a foreign neighbour and declare war
	var from := -1; var to := -1
	for p in g.owned(fr):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[e]
			if g.owner[q] != 0 and g.owner[q] != fr and g.nb_sea[e] == 0 and from < 0: from = p; to = q
	g.dp[fr] = 10; g.set_rel(fr, g.owner[to], 1)
	g.army[from] = 120
	main.map.fly_to(main.world.lon[from], main.world.lat[from], 3.4)
	main._select(from)
	main._set_move_from(from)
	for i in 6: await process_frame
	main._try_move(from, to)
	for i in 6: await process_frame
	await _shot("pv1")
	main._clear_overlay(); main.hud.hide_preview(); main._pv_to = -1
	root.warp_mouse(Vector2(640, 300)) if false else null
	main._on_hover(to)
	main._tip.position = Vector2(560, 330)
	await _shot("pv2_tip")
	quit(0)
