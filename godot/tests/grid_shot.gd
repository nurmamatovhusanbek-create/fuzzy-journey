extends SceneTree
## A picture of the globe over the Atlantic and Africa at the zoom where the sea graticule used to turn to a fine 5 degree mesh. Usage: -s tests/grid_shot.gd -- <w> <h> <out.png> [zoom]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main._apply_quality()
	main._begin_pick("modern", "normal")
	main._start_game(main.g.nat_code.find("kazakhstan") if main.g.nat_code.find("kazakhstan") > 0 else 1)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 8: await process_frame
	var map = main.map
	map.set_mode(0)
	map.zoom = float(a[3]) if a.size() > 3 else 1.6
	map.lon0 = deg_to_rad(-5.0); map.lat0 = deg_to_rad(22.0); map._push_view()
	for i in 90: await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[2])
	print("GRID_SHOT zoom ", snappedf(map.zoom, 0.01), " deg/px ", snappedf(map.prov_dpp(), 0.01))
	quit()
