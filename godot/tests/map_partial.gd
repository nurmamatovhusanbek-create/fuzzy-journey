extends SceneTree
## A hover or a selection redraws only the part of the map it changes; the picture must be the one a full redraw gives. Random views, hovers and selections, both ways, compared.
## Usage: -s tests/map_partial.gd -- <w> <h> <cases> [seed]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1]); var cases: int = int(a[2])
	var rng := RandomNumberGenerator.new(); rng.seed = int(a[3]) if a.size() > 3 else 7
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.visible = false; main.map.labels.visible = false; main.map.routes.visible = false; main.ring.visible = false
	var m: TBMapView = main.map
	var g: TBGame = main.g
	var bad := 0; var total_px := 0
	for c in cases:
		var globe: bool = rng.randf() < 0.5
		m.set_mode(0 if globe else 1)
		var z: float = rng.randf_range(0.8, 7.0) if globe else rng.randf_range(m.flat_fit(), 12.0)
		m.fly_to(rng.randf_range(-20.0, 60.0), rng.randf_range(10.0, 60.0), z)
		for i in 25: await process_frame
		var provs: Array = []
		for p in 12: provs.append(rng.randi_range(0, g.P - 1))
		# a few hovers and a selection, each drawn partially
		for k in 5:
			m._set_hover(provs[k])
			for i in 14: await process_frame
			if k == 2: m.select(provs[k + 3])
		for i in 14: await process_frame
		var part: Image = m._vp.get_texture().get_image()
		var full_before: int = m.full_redraws
		m._rend_sig = []                                            # force a full redraw of the very same state
		m._push_view()
		for i in 6: await process_frame
		var full: Image = m._vp.get_texture().get_image()
		var n := 0
		for y in range(0, part.get_height(), 1):
			for x in range(0, part.get_width(), 2):
				var c0: Color = part.get_pixel(x, y); var c1: Color = full.get_pixel(x, y)
				if absf(c0.r - c1.r) + absf(c0.g - c1.g) + absf(c0.b - c1.b) > 0.012: n += 1
		total_px += n
		if n > 0:
			bad += 1
			part.save_png("/tmp/partial_%d_part.png" % c); full.save_png("/tmp/partial_%d_full.png" % c)
		print("case %d %s z%.1f: %d differing pixels (full redraws %d, partial %d)" % [c, "globe" if globe else "flat", z, n, m.full_redraws, m.partial_redraws])
		m.select(-1); m._set_hover(-1)
		for i in 10: await process_frame
	print("PARTIAL ", "OK" if bad == 0 else "FAIL (%d cases, %d pixels)" % [bad, total_px])
	quit(0 if bad == 0 else 1)
