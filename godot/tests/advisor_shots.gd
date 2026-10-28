extends SceneTree
## Pictures of the Advisor's note, real: the title, and a game while a turn processes. Usage: -s tests/advisor_shots.gd -- <outdir> <w> <h> [tag]   (TB_NOANIM= empty)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[1]); var h := int(a[2]); var tag: String = a[3] if a.size() > 3 else "x"
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "full"
	main._apply_quality(); main._update_ui_scale(); TBFx.apply(main.cfg)
	main._spin = false; main.show_menu(); main._spin = false
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/adv_title_%s.png" % [a[0], tag])
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 40: await process_frame
	main.hud.set_busy(true)
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/adv_game_%s.png" % [a[0], tag])
	main.hud.set_busy(false)
	quit()
