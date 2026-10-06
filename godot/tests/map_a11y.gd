extends SceneTree
## Map accessibility: colour-vision palettes (adjacency colouring stats), relation patterns, high-contrast map, keyboard cursor, nav pad,
## nation highlight / tap magnet, reduce motion, text scale. Writes screenshots to <outdir> for reading and Machado simulation.
## Usage: -- <outdir>
var _out := ""
var fails := 0

func _shot(name: String) -> void:
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/a11y_%s.png" % [_out, name])

func _check(c: bool, what: String) -> void:
	if not c: print("FAIL: ", what); fails += 1

func _key(code: int, shift: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = true; e.shift_pressed = shift
	root.push_input(e)

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(1280, 720)
	await process_frame; await process_frame
	main._update_ui_scale()
	for k in ["text_scale", "contrast", "reduce_motion", "readable", "touch_large", "cvd"]: main.cfg[k] = {"text_scale": 1.0, "contrast": false, "reduce_motion": false, "readable": false, "touch_large": false, "cvd": "off"}[k]
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main._apply_a11y()      # the settings file is shared between runs: pin the a11y state
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["tutorial"] = true
	# ---- nation pick: highlight + tap magnet
	main._begin_pick("napoleonic", "normal")
	var g: TBGame = main.g
	var fr: int = g.nat_code.find("france")
	var map: TBMapView = main.map
	var cap0: int = g.capital_of[fr]
	map.fly_to(g.world.lon[cap0], g.world.lat[cap0], 2.0)
	for i in 6: await process_frame
	map.highlight_nation(fr)
	await _shot("pick_highlight")
	map.clear_highlight()
	# tap magnet: the smallest nation with >= 1 province, tapped 12 px off its land
	var counts := PackedInt32Array(); counts.resize(g.N1)
	for p in g.P: counts[g.owner[p]] += 1
	var small := -1
	for n in range(1, g.N1):
		if g.alive[n] != 0 and counts[n] > 0 and (small < 0 or counts[n] < counts[small]) and n != g.rebel: small = n
	var sp := -1
	for p in g.P:
		if g.owner[p] == small: sp = p; break
	map.fly_to(g.world.lon[sp], g.world.lat[sp], 6.0)
	for i in 6: await process_frame
	var spt := map.project(g.world.lon[sp], g.world.lat[sp])
	var hit := -1
	for off in [Vector2(10, 0), Vector2(-10, 0), Vector2(0, 10), Vector2(0, -10), Vector2(14, 14)]:
		var q := map._pick_tap(Vector2(spt.x, spt.y) + off)
		if q >= 0 and g.owner[q] == small: hit += 1
	print("magnet: small nation ", g.dname(small), " (", counts[small], " provinces) snapped on ", hit + 1, "/5 off-centre taps")
	_check(hit + 1 >= 3, "tap magnet reaches the smallest nation from off-centre taps")
	# ---- game with wars / allies for the relation patterns
	main._start_game(fr)
	g.pending.clear(); main._clear_overlay()
	map = main.map
	var me := fr
	var spain: int = g.nat_code.find("spain")
	var uk: int = g.nat_code.find("uk")
	var prus: int = g.nat_code.find("prussia")
	var aus: int = g.nat_code.find("austria")
	g.set_rel(me, spain, 1)
	if uk > 0: g.set_rel(me, uk, 3)
	if prus > 0: g.set_rel(me, prus, 2)
	map.repaint_all()
	map.fly_to(2.0, 46.0, 2.6)
	for i in 8: await process_frame
	for lens in ["political", "diplomatic", "stability"]:
		map.set_lens(lens)
		await _shot("%s_off" % lens)
	map.set_lens("political")
	# ---- colour-vision modes: shots + adjacency statistics
	for m in ["deuter", "protan", "tritan"]:
		main.cfg["cvd"] = m; main._on_setting_changed("cvd")
		for i in 3: await process_frame
		var adj := {}
		for p in g.P:
			var o := g.owner[p]
			if o == 0: continue
			for e in range(g.nb_off[p], g.nb_off[p + 1]):
				var oq := g.owner[g.nb[e]]
				if oq != 0 and oq != o: adj[Vector2i(mini(o, oq), maxi(o, oq))] = true
		var ok := 0
		for k in adj:
			if TBLenses.delta_e(map.lenses.nat_rgb[k.x], map.lenses.nat_rgb[k.y], m) >= 8.0: ok += 1
		var frac := float(ok) / float(maxi(1, adj.size()))
		print("cvd ", m, ": adjacent owner pairs with dE>=8 = ", snappedf(frac * 100.0, 0.1), "% of ", adj.size())
		_check(frac >= 0.9, "adjacency colouring separates >= 90 percent of adjacent owners under %s" % m)
		for lens in ["political", "diplomatic", "stability"]:
			map.set_lens(lens)
			await _shot("%s_%s" % [lens, m])
		map.set_lens("political")
	main.cfg["cvd"] = "off"; main._on_setting_changed("cvd")
	# stability ramp monotone in luminance (all modes)
	var last := -1.0; var mono := true
	for i in 4:
		var l := TBLenses.lum(TBLenses.STAB_RAMP[i])
		if l <= last: mono = false
		last = l
	_check(mono, "stability ramp is monotone in luminance")
	# ---- high contrast map
	main.cfg["contrast"] = true; main._on_setting_changed("contrast")
	for i in 4: await process_frame
	await _shot("political_hc")
	map.set_lens("diplomatic"); await _shot("diplomatic_hc"); map.set_lens("political")
	main.cfg["contrast"] = false; main._on_setting_changed("contrast")
	# ---- text scale 2.0 labels
	main.cfg["text_scale"] = 2.0; main._on_setting_changed("text_scale")
	for i in 4: await process_frame
	await _shot("text200")
	main.cfg["text_scale"] = 1.0; main._on_setting_changed("text_scale")
	# ---- selection + hover (art bible 6.2): static cream ring with ink outside, 2 px brass hover
	map.fly_to(2.0, 46.0, 4.0)
	for i in 6: await process_frame
	var sel_p := -1; var hov_p := -1
	for p in g.owned(me):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.owner[g.nb[e]] == me and sel_p < 0: sel_p = p; hov_p = g.nb[e]
	main._select(sel_p)
	map._set_hover(hov_p)
	map._hover_t = 1.0; map._push_view()
	await _shot("selection_hover")
	main._select(-1); map._set_hover(-1)
	# ---- reduce motion
	main.cfg["reduce_motion"] = true; main._on_setting_changed("reduce_motion")
	_check(not TBKit.motion_ok(), "reduce motion turns the kit's motion off")
	var lon_before := map.lon0
	map.fly_to(10.0, 45.0)
	_check(is_equal_approx(map.lon0, deg_to_rad(10.0)), "fly_to is an instant cut under reduce motion")
	main.cfg["reduce_motion"] = false; main._on_setting_changed("reduce_motion")
	# ---- keyboard cursor
	map.fly_to(2.0, 46.0, 3.0)
	for i in 6: await process_frame
	main._select(-1)
	var start: int = g.capital_of[me]
	_key(KEY_RIGHT)
	await process_frame
	var cur: TBMapCursor = null
	for c in main.get_children():
		if c is TBMapCursor: cur = c
	_check(cur != null and cur.active, "arrow key starts the cursor")
	_check(map.focus_province == start, "first arrow press shows the cursor on the capital (%d vs %d)" % [map.focus_province, start])
	var steps := 0
	var moved := false
	for k in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP, KEY_RIGHT]:
		var before := map.focus_province
		_key(k)
		await process_frame
		if map.focus_province != before: moved = true; steps += 1
	_check(moved, "arrow keys move the cursor between neighbouring provinces (%d moves)" % steps)
	await _shot("kbd_cursor")
	var cp := map.focus_province
	_key(KEY_ENTER)
	await process_frame
	_check(main.selected == cp, "Enter selects the cursor province")
	_key(KEY_ESCAPE)
	# a province with no army is reachable and selectable by keyboard alone
	_key(KEY_LEFT)
	await process_frame
	_check(cur.active, "arrows work again from the selection")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not cur.active and map.focus_province < 0, "Esc drops the cursor")
	# ---- nav pad
	TBNavPad.setting = "on"
	for i in 20: await process_frame
	await _shot("navpad")
	var z0 := map.zoom
	map.zoom_by(1.4)
	_check(map.zoom > z0, "zoom button path works")
	# ---- list
	TBMapList.open(main._overlay, g, map, Callable(main, "_goto_province"))
	for i in 4: await process_frame
	await _shot("list")
	var rows := TBMapList.rows(g, "par")
	_check(rows.size() > 0, "list search finds provinces")
	print("MAPA11Y ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
