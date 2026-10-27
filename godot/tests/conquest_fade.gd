extends SceneTree
## C2: a province that changes owner dissolves into its new colour (Full, medium+ tier); Light / Off change at once. Usage: -s tests/conquest_fade.gd -- <out dir> (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _rgb(m: TBMapView, p: int) -> Array:
	var o: int = (p + 1) * 4
	return [m._pal[o], m._pal[o + 1], m._pal[o + 2]]
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "high"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1); main._apply_quality()
	var m: TBMapView = main.map
	var g: TBGame = main.g
	var me: int = g.human_id
	var aus: int = g.nat_code.find("austrian_empire")
	var p: int = -1
	for q in g.owned(aus): p = q; break
	m.jump_to(float(main.world.lon[p]), float(main.world.lat[p]), 6.0)
	for i in 20: await process_frame
	for fx in ["full", "light", "off"]:
		main.cfg["fx"] = fx; main._apply_a11y()
		var from_n: int = g.owner[p]
		var to_n: int = me if from_n != me else aus
		var before := _rgb(m, p)
		g.owner[p] = to_n
		m.repaint(PackedInt32Array([p]))
		var now := _rgb(m, p)
		if fx == "full":
			_check(m._fade.has(p), "Full: the province is fading")
			_check(now == before, "Full: the first frame still shows the old colour")
			for k in [3, 8, 14]:
				for i in 3: await process_frame
				root.get_viewport().get_texture().get_image().save_png("%s/fade_%02d.png" % [out, k])
			for i in 30: await process_frame
			_check(m._fade.is_empty(), "Full: the fade has ended")
			_check(_rgb(m, p) != before, "Full: the new colour is in place")
		else:
			_check(not m._fade.has(p), "%s: no fade" % fx)
			_check(now != before, "%s: the colour changes at once" % fx)
		g.owner[p] = from_n
		m.repaint(PackedInt32Array([p]))
		for i in 40: await process_frame
	print("CONQUEST_FADE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
