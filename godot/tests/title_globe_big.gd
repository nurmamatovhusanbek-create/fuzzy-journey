extends SceneTree
## A big picture of the title globe alone (no interface) for the main-menu mocks. Usage: -s tests/title_globe_big.gd -- <out.png> <size> <zoom> <lon> <lat>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sz := int(a[1])
	DisplayServer.window_set_size(Vector2i(sz, sz)); root.size = Vector2i(sz, sz)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(sz, sz)
	for i in 3: await process_frame
	main._update_ui_scale()
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	main._spin = false
	main.show_menu(); main._spin = false
	for i in 4: await process_frame
	main._overlay.visible = false
	main.map.grid_k = 0.38
	main.map.zoom = float(a[2]); main.map.lon0 = deg_to_rad(float(a[3])); main.map.lat0 = deg_to_rad(float(a[4])); main.map._push_view()
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
