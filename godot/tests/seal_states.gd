extends SceneTree
## The End Turn dial in each state, as pictures (read only): rest, rest with a crisis waiting, busy (animated and still). Usage: -s tests/seal_states.gd -- <outdir> (TB_NOANIM= empty)
func _crop(main: Control, out: String, tag: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var sc: float = float(img.get_width()) / root.get_visible_rect().size.x
	var r: Rect2 = main.hud._seal_rect(); r.position += main.hud.global_position
	r = r.grow(36.0)
	var cr := Rect2i(Vector2i(r.position * sc), Vector2i(r.size * sc))
	var cut: Image = img.get_region(cr); cut.resize(cut.get_width() * 2, cut.get_height() * 2, Image.INTERPOLATE_NEAREST)
	cut.save_png("%s/seal_%s.png" % [out, tag])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	DisplayServer.window_set_size(Vector2i(1600, 900)); root.size = Vector2i(1600, 900)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "full"; TBFx.apply(main.cfg)
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 40: await process_frame
	var s = main.hud._seal
	print("state ", s.state, " attention ", s.attention, " animated ", s._animated())
	_crop(main, a[0], "1_rest")
	s.attention = 2; s.queue_redraw()
	for i in 3: await process_frame
	_crop(main, a[0], "2_rest_crisis")
	s.attention = 0
	main.hud.set_busy(true)
	for i in 12: await process_frame
	print("busy state ", s.state, " sub '", s.sub, "' animated ", s._animated())
	_crop(main, a[0], "3_busy_a")
	for i in 7: await process_frame
	_crop(main, a[0], "4_busy_b")
	main.hud.set_busy(false)
	quit()
