extends SceneTree
## Map label pictures for before / after comparisons of the label layout code (names, army markers, capitals): -s tests/label_shots.gd -- <outdir>
func _init() -> void:
	var dir := String(OS.get_cmdline_user_args()[0])
	root.size = Vector2i(1280, 720); DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = (OS.get_environment("TB_Q") if OS.get_environment("TB_Q") != "" else "high")
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_quality(); main._update_ui_scale()
	main.hud.visible = false
	var views := [["globe", 0, 1.1, 9.5, 46.0], ["globe", 0, 2.4, 9.5, 46.0], ["globe", 0, 3.4, 30.0, 45.0], ["globe", 0, 6.5, 2.3, 48.8], ["flat", 1, 1.0, 0.0, 20.0], ["flat", 1, 3.5, 9.5, 46.0], ["flat", 1, 8.0, 12.0, 45.0]]
	var i := 0
	for v in views:
		main.map.set_mode(int(v[1]))
		main.map.fly_to(float(v[3]), float(v[4]), float(v[2]) if int(v[1]) == 0 else maxf(float(v[2]), main.map.flat_fit()))
		for k in 30: await process_frame
		for lens in ["political", "military"]:
			main.map.set_lens(lens)
			for k in 12: await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/l%d_%s.png" % [dir, i, lens])
		i += 1
	# an order arrow and a selection
	main.map.set_lens("political")
	for p in main.g.P:
		if main.world.name[p] == "Bas-Rhin": main._select(p)
	for k in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/l_sel.png" % dir)
	quit()
