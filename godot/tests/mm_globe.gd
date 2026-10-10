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
	if not (main.map.mode == 0 and mm.is_globe() and mm.size.x > 100.0): failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_globe.png")
	# a click right of centre turns the main globe east
	var l0: float = main.map.lon0
	mm._fly(Vector2(mm.size.x * 0.5 + (mm.round_r - 12.0) * 0.5, 10.0 + mm.round_r))
	for i in 40: await process_frame
	print("lon0 ", l0, " -> ", main.map.lon0)
	if not (main.map.lon0 > l0 + 0.2): failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_globe2.png")
	main.cfg["view"] = "flat"; main.map.set_mode(1)
	for i in 8: await process_frame
	print("flat: minimap globe=", mm.is_globe(), " size=", mm.size)
	if not (mm.is_globe() and mm.size.x > 100.0 and mm.visible): failed += 1            # the demo's minimap is a round globe whatever the map's view mode
	var l1: float = main.map.lon0
	mm._fly(Vector2(mm.size.x * 0.5 + (mm.round_r - 12.0) * 0.5, 10.0 + mm.round_r))
	for i in 40: await process_frame
	print("flat lon0 ", l1, " -> ", main.map.lon0)
	if not (main.map.lon0 > l1 + 0.1): failed += 1
	root.get_viewport().get_texture().get_image().save_png(dir + "/mm_flat.png")
	quit(failed)
