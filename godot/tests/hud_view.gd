extends SceneTree
## One full-window HUD screenshot (globe and flat): -s tests/hud_view.gd -- <outdir> <w> <h> [tag]   (a phone held sideways: 1688 780 = 844 x 390 logical)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[1]); var h: int = int(a[2]); var tag: String = a[3] if a.size() > 3 else "v"
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true
	if OS.get_environment("TQ") != "": main.cfg["quality"] = OS.get_environment("TQ"); main._apply_quality()           # TQ=low|medium|high: the tier a real phone / desktop would pick (the test machine guesses low)
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_globe.png" % [a[0], tag])
	main.map.set_mode(1)
	main.hud._minimap.refresh()
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_flat.png" % [a[0], tag])
	print("map buffer ", main.map._vp.size, " scale ", main.map._rs(), " tier ", main.map.quality)
	print("logical ", root.get_visible_rect().size, " prof ", main.hud._prof)
	quit()
