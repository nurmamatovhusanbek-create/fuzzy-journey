extends SceneTree
func _init() -> void:
	var sz := Vector2i(1920, 1080)
	DisplayServer.window_set_size(sz); root.size = sz
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "flat"; main.cfg["fx"] = "off"; main.cfg["text_scale"] = 1.0
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	for i in 90: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/lg/onb/t0.png")
	main.hud._seal.pressed.emit()
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/lg/onb/t1.png")
	quit(0)
