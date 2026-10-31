extends SceneTree
## The Settings tab, one picture per category (rail layout). Usage: -s tests/settings_shots.gd -- <w> <h> <text scale> <lang> <out dir>   (TB_PHONE_UI=compact, TB_DPR/TB_DPI as for the other UI shots)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var sc := float(a[2]); var lang := a[3]; var out: String = a[4]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(lang)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["lang"] = lang; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._on_setting_changed("lang")
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	for i in 20: await process_frame
	for cat in ["display", "map", "comfort", "sound", "language", "advanced"]:
		TBMenuHub.mem["set_cat"] = cat; TBMenuHub.mem["scroll"] = 0
		main._clear_overlay()
		main._open_menu_hub("settings")
		for i in 12: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/set_%s_%dx%d_s%d_%s.png" % [out, cat, w, h, int(sc * 100), lang])
	print("SETTINGS_SHOTS DONE")
	quit()
