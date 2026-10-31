extends SceneTree
## Routes lens on the flat map: a line is straight on the paper (no swing over the pole), it takes the short way round the sideways wrap, and it never jumps across the screen.
## Usage: -s tests/routes_flat.gd -- <w> <h> [out.png]
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var gg: TBGame = main.g
	var me := -1; var far := -1; var far_d := 0.0                       # the pair of capitals whose short way round the world crosses the date line, the most
	for i in range(1, gg.N1):
		if gg.alive[i] == 0 or i == gg.rebel or gg.capital_of[i] < 0: continue
		for o in range(1, gg.N1):
			if o == i or gg.alive[o] == 0 or o == gg.rebel or gg.capital_of[o] < 0: continue
			var raw: float = gg.world.lon[gg.capital_of[o]] - gg.world.lon[gg.capital_of[i]]
			var wr: float = wrapf(raw, -180.0, 180.0)
			if absf(raw - wr) > 1.0 and absf(wr) > far_d: far_d = absf(wr); far = o; me = i
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(30)
	var cm: int = g.capital_of[me]
	print("seam pair: ", g.nat_code[me], " -> ", g.nat_code[far] if far > 0 else "none", " short way ", snappedf(far_d, 0.1), " deg")
	_check(far > 0, "a nation across the date line exists")
	g.set_rel(me, far, TBGame.D.REL_WAR)
	var map = main.map
	map.set_lens("routes"); map.set_mode(1)
	for zoom_f in [1.0, 2.0]:
		map.zoom = map.flat_fit() * zoom_f
		var mid_lon: float = (g.world.lon[cm] + wrapf(g.world.lon[g.capital_of[far]] - g.world.lon[cm], -180.0, 180.0) * 0.5)
		map.lon0 = deg_to_rad(wrapf(mid_lon, -180.0, 180.0)); map.lat0 = deg_to_rad(30.0); map._push_view()
		await _frames(90)
		var hits: Array = map.routes._hits
		_check(hits.size() >= 1, "zoom %.1f: the war line was drawn (%d)" % [zoom_f, hits.size()])
		for hit in hits:
			for r in hit["runs"]:
				var pl: PackedVector2Array = r
				var maxstep := 0.0
				for i in range(1, pl.size()): maxstep = maxf(maxstep, pl[i].distance_to(pl[i - 1]))
				_check(maxstep < map.size.x * 0.3, "zoom %.1f: a line never jumps (largest step %.0f px of %.0f)" % [zoom_f, maxstep, map.size.x])
				# straight on the paper: every point lies within 1.5 px of the chord
				var worst := 0.0
				for i in pl.size(): worst = maxf(worst, Geometry2D.get_closest_point_to_segment(pl[i], pl[0], pl[pl.size() - 1]).distance_to(pl[i]))
				_check(worst < 1.5, "zoom %.1f: a war line is straight (off the chord by %.1f px)" % [zoom_f, worst])
		if a.size() > 2 and zoom_f == 1.0: root.get_viewport().get_texture().get_image().save_png(a[2])
	print("ROUTES_FLAT OK" if fails == 0 else "ROUTES_FLAT FAIL %d" % fails)
	quit(fails)
