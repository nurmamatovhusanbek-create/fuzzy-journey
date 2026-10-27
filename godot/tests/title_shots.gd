extends SceneTree
## Title screenshots. Usage: -s tests/title_shots.gd -- <out dir> <w> <h> <save|nosave> [lang] [fx]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]; var w: int = int(a[1]); var h: int = int(a[2]); var with_save: bool = a[3] == "save"
	var lang: String = a[4] if a.size() > 4 else "en"
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	await process_frame; await process_frame
	main._update_ui_scale()
	await process_frame
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	if a.size() > 5: main.cfg["fx"] = a[5]; main._apply_a11y()
	if with_save:
		main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
		main.g.pending.clear()
		for t in 22: main.g.end_turn()
		TBSave.save(main.g, "auto")
	else:
		DirAccess.remove_absolute(TBSave.path_for("auto"))
	main._spin = false
	main.show_menu(); main._spin = false
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/t_%s_%dx%d_%s.png" % [out, "save" if with_save else "nosave", w, h, lang])
	quit()
