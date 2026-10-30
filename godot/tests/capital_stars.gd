extends SceneTree
## Capital stars by zoom: none when a continent is in view, the big countries' at country level (plus your own), every capital close in. Usage: -s tests/capital_stars.gd -- <w> <h> [out dir] [expect]
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
	var me: int = main.g.nat_code.find("france")
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(250)                                                   # the start-up dive settles first
	var map = main.map
	map.set_mode(0)
	var labels = map.labels
	var counts := {}
	var fails := 0
	for z in [0.5, 2.2, 5.0]:
		map.zoom = z; map.lon0 = deg_to_rad(10.0); map.lat0 = deg_to_rad(48.0); map._push_view()
		await _frames(40)
		var shown := 0; var big_ok := true; var small_seen := 0
		for p in labels._stars:
			var st: Dictionary = labels._stars[p]
			if float(st["a"]) > 0.5:
				shown += 1
				var o: int = g.owner[p]
				if not labels._is_big_nation(o) and o != me: small_seen += 1
		counts[z] = [shown, small_seen, labels.prov_px()]
		print("zoom %.1f: province %.1f px, %d capital stars shown, %d of them belong to small countries" % [z, labels.prov_px(), shown, small_seen])
		if a.size() > 2 and a[2] != "expect": root.get_viewport().get_texture().get_image().save_png("%s/stars_z%d.png" % [a[2], int(z * 10)])
	var c1: Array = counts[0.5]; var c2: Array = counts[2.2]; var c3: Array = counts[5.0]
	if float(c1[2]) < 14.0 and int(c1[0]) != 0: fails += 1; print("FAIL: stars on the continent view")
	if float(c2[2]) >= 14.0 and float(c2[2]) < 40.0 and int(c2[1]) != 0: fails += 1; print("FAIL: small countries starred at country level")
	if float(c3[2]) >= 40.0 and int(c3[0]) < 1: fails += 1; print("FAIL: no stars close in")
	var expect: bool = a[a.size() - 1] == "expect"
	print("CAPITAL_STARS OK" if fails == 0 else "CAPITAL_STARS FAIL %d" % fails)
	quit(1 if (expect and fails > 0) else 0)
