extends SceneTree
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(2340, 1080)); root.size = Vector2i(2340, 1080)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	var a := OS.get_cmdline_user_args()
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = false; main.cfg["phone_ui"] = a[0]; main.cfg["lang"] = a[1]; main._update_ui_scale(); main._on_setting_changed("lang")
	main.show_menu()
	for i in 30: await process_frame
	main._open_era_picker()
	for i in 20: await process_frame
	var rows: Array = []
	var stack: Array = [main._overlay]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TBMenuParts.EraRow: rows.append(n)
		for c in n.get_children(): stack.append(c)
	rows.sort_custom(func(a, b): return a.get_index() < b.get_index())
	print("ERAROWS ", rows.size())
	if a.size() > 2 and rows.size() > 10: (rows[10] as TBMenuParts.EraRow).pressed.emit()
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/era_%s_%s.png" % [a[0], a[1]])
	quit()
