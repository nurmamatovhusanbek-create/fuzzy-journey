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
	var mine := g.owned(fr)
	var cap: int = g.capital_of[fr]
	main.map.fly_to(main.world.lon[cap], main.world.lat[cap], 4.5)
	for i in 8: await process_frame
	main.map._set_hover(mine[8])
	main._select(mine[3])
	g.army[mine[3]] = 180
	for i in 8: await process_frame
	await _shot("hv1_zoomed")
	quit(0)
