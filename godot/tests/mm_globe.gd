extends SceneTree
## minimap: flat plate vs mini-globe, with a click on the globe flying the main view. Usage: -s tests/mm_globe.gd -- <outdir>
func _init() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["view"] = "globe"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true; main.hud.set_seal_pulse(false)
	for i in 8: await process_frame
	var failed := 0
	var mm: TBMinimap = main.hud._minimap
	print("globe mode=", main.map.mode, " minimap globe=", mm.is_globe(), " size=", mm.size)
	if not (main.map.mode == 0 and mm.is_globe() and absf(mm.size.x - mm.size.y) < 0.5): failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_globe.png")
	# a click right of centre turns the main globe east
	var l0: float = main.map.lon0
	mm._fly(mm.size * 0.5 + Vector2(mm.size.x * 0.3, 0))
	for i in 40: await process_frame
	print("lon0 ", l0, " -> ", main.map.lon0)
	if not (main.map.lon0 > l0 + 0.2): failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_globe2.png")
	main.cfg["view"] = "flat"; main.map.set_mode(1)
	for i in 8: await process_frame
	print("flat: minimap globe=", mm.is_globe(), " size=", mm.size)
	if mm.is_globe() or mm.size.x < 150: failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_flat.png")
	quit(failed)
