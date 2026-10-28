extends SceneTree
## The army-number rule: army pills show while the province borders show and not otherwise, globe and flat, at a desktop and at a phone's pixel density.
## Usage: -s tests/army_rule.gd -- <w> <h> [screenshot dir]   (the zoom sweep is saved as pictures when a dir is given)      (TB_UI_SCALE=2 with a 1688x780 window = a 844x390 phone)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1

func _active(main: Control) -> int:
	var n := 0
	for p in main.map.labels._pl:
		if float(main.map.labels._pl[p]["a"]) > 0.3 and float(main.map.labels._pl[p]["t"]) > 0.5: n += 1
	return n

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main._apply_quality()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 8: await process_frame
	var g: TBGame = main.g
	var map = main.map
	var own: Array = g.owned(fr)
	var p0: int = own[0]
	for q in own: g.army[q] = maxi(g.army[q], 5)
	for mode in [0, 1]:
		map.set_mode(mode)
		var shown_at_far := false; var shown_at_near := false
		for zf in [0.0, 1.0]:                                                    # 0: the whole world in view, 1: until the lines are surely in
			map.zoom = map.flat_fit() if mode == 1 else 1.0
			if zf > 0.0: map.zoom = (map.flat_fit() if mode == 1 else 1.0) * 14.0
			map.lon0 = deg_to_rad(g.world.lon[p0]); map.lat0 = deg_to_rad(g.world.lat[p0]); map._push_view()
			for i in 12: await process_frame
			map.labels.queue_redraw()
			for i in 90: await process_frame
			var shown: bool = map.prov_lines_shown()
			var n := _active(main)
			print("mode ", mode, " zoom ", snappedf(map.zoom, 0.01), " deg/px ", snappedf(map.prov_dpp(), 0.01), " lines_shown ", shown, " army pills ", n)
			_check((n > 0) == shown, "mode %d zoom %.2f: pills %d but lines_shown %s" % [mode, map.zoom, n, str(shown)])
			if zf == 0.0: shown_at_far = shown
			else: shown_at_near = shown
		_check(not shown_at_far, "mode %d: the whole-world view shows no army numbers" % mode)
		_check(shown_at_near, "mode %d: a close view shows them" % mode)
	# the marker gets smaller as you close in past province scale
	map.set_mode(0)
	var base_z := 1.0
	map.lon0 = deg_to_rad(g.world.lon[p0]); map.lat0 = deg_to_rad(g.world.lat[p0])
	var prev := 2.0
	for zf in [1.0, 2.0, 3.0, 4.5, 7.0, 12.0, 24.0]:
		map.zoom = base_z * zf; map._push_view()
		var sc: float = map.army_scale()
		print("globe x", zf, " radius ", snappedf(map.radius_px(), 1.0), " lines ", snappedf(map.prov_lines_alpha(), 0.01), " shown ", map.prov_lines_shown(), " marker scale ", snappedf(sc, 0.01))
		_check(sc <= prev + 1e-4 and sc >= 0.61 and sc <= 1.0, "the marker scale only shrinks as you zoom in (%.2f)" % sc)
		prev = sc
		if a.size() > 2:
			for i in 40: await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/zoom_%02d.png" % [a[2], int(zf * 10.0)])
	_check(map.army_scale() < 0.7, "much closer in, the marker is about 62 %")
	map.zoom = 1.0; map._push_view()
	# where the numbers switch on, per view mode (zoom factor of the whole-world view)
	for mode in [0, 1]:
		map.set_mode(mode)
		var z0: float = map.flat_fit() if mode == 1 else 1.0
		var f := 1.0
		while f < 30.0:
			map.zoom = z0 * f; map._push_view()
			if map.prov_lines_shown(): break
			f *= 1.05
		print("mode ", mode, ": borders and army numbers appear from zoom x", snappedf(f, 0.01), " of the whole-world view (buffer ", map._vp.size, ")")
	print("ARMY_RULE OK" if fails == 0 else "ARMY_RULE FAIL %d" % fails)
	quit(fails)
