extends SceneTree
## map quality at close zoom, globe and flat. Usage: -- <outdir>
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
	main._select(-1)
	var cap: int = main.g.capital_of[fr]
	print("ids texture: ", main.world.W, "x", main.world.H, " provinces ", main.g.P)
	for z in [6.0, 12.0]:
		main.map.fly_to(main.world.lon[cap], main.world.lat[cap], z)
		for i in 6: await process_frame
		await _shot("zq_globe_%d" % int(z))
	main.map.set_mode(1)
	for z in [8.0, 20.0]:
		main.map.fly_to(main.world.lon[cap], main.world.lat[cap], z)
		for i in 6: await process_frame
		await _shot("zq_flat_%d" % int(z))
	quit(0)
