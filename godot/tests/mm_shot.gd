extends SceneTree
## Minimap screenshots in the flat and globe views: -s tests/mm_shot.gd -- <outdir> <w> <h>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[1]); var h: int = int(a[2])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 6: await process_frame
	var mm: TBMinimap = main.hud._minimap
	for t in ["globe", "flat", "flat_zoom"]:
		if t == "globe": main.map.set_mode(0)
		else: main.map.set_mode(1)
		if t == "flat_zoom": main.map.zoom = main.map.flat_fit() * 3.0; main.map.lon0 = 0.2; main.map.lat0 = 0.8; main.map._push_view()
		for i in 8: await process_frame
		mm.refresh()
		for i in 4: await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var r: Rect2 = mm.get_global_rect()
		var sc: float = float(img.get_width()) / root.get_visible_rect().size.x
		var cr := Rect2i(Vector2i(r.position * sc) - Vector2i(10, 10), Vector2i(r.size * sc) + Vector2i(20, 20))
		var cut: Image = img.get_region(cr); cut.resize(cut.get_width() * 3, cut.get_height() * 3, Image.INTERPOLATE_NEAREST)
		cut.save_png("%s/mm_%s.png" % [a[0], t])
	quit()
