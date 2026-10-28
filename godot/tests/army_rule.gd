extends SceneTree
## The army-number rule: army pills show while the province borders show and not otherwise, globe and flat, at a desktop and at a phone's pixel density.
## Usage: -s tests/army_rule.gd -- <w> <h>      (TB_UI_SCALE=2 with a 1688x780 window = a 844x390 phone)
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
			print("mode ", mode, " zoom ", snappedf(map.zoom, 0.01), " tpp ", snappedf(map.prov_tpp(), 0.01), " lines_shown ", shown, " army pills ", n)
			_check((n > 0) == shown, "mode %d zoom %.2f: pills %d but lines_shown %s" % [mode, map.zoom, n, str(shown)])
			if zf == 0.0: shown_at_far = shown
			else: shown_at_near = shown
		_check(not shown_at_far, "mode %d: the whole-world view shows no army numbers" % mode)
		_check(shown_at_near, "mode %d: a close view shows them" % mode)
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
