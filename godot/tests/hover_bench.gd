extends SceneTree
## Hovering over the map: how many redraws are partial, and what a hover costs. Usage: -s tests/hover_bench.gd -- <w> <h> <globe|flat> <zoom>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1]); var globe: bool = a[2] == "globe"; var zoom: float = float(a[3])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe" if globe else "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	var m: TBMapView = main.map
	m.set_mode(0 if globe else 1)
	m.fly_to(9.5, 46.0, zoom if globe else maxf(zoom, m.flat_fit()))
	for i in 40: await process_frame
	# provinces visible around the middle of the screen
	var seen: Array = []
	for i in 400:
		var pos := Vector2(m.size.x * randf_range(0.2, 0.8), m.size.y * randf_range(0.2, 0.8))
		var p := m.pick_at(pos)
		if p >= 0 and not seen.has(p): seen.append(p)
		if seen.size() >= 40: break
	m.partial_ok = a.size() < 5 or a[4] != "off"
	var f0 := m.full_redraws; var p0 := m.partial_redraws
	var t0 := Time.get_ticks_msec()
	for p in seen:
		m._set_hover(p)
		for i in 8: await process_frame
	var ms := float(Time.get_ticks_msec() - t0) / float(seen.size())
	print("%s z%.1f: %d hovers: %d full redraws, %d partial; %.1f ms per hover (8 frames)" % [a[2], zoom, seen.size(), m.full_redraws - f0, m.partial_redraws - p0, ms])
	quit(0)
