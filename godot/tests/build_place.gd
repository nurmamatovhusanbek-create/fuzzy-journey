extends SceneTree
## Where the Build picker opens: inside the safe area (clear of a phone's camera cutout), beside the district's ring, never behind the left rail. Usage: -s tests/build_place.gd -- <w> <h> <out.png> [expect]
## Run with TB_SAFE="58,0,0,0" TB_DPR=2.66 TB_DPI=425 to emulate the S22 with its camera at the left edge.
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
	main._apply_quality(); main._update_ui_scale(); main._apply_safe_area()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	g.gold[me] = 700.0; g.mp[me] = 6.0
	main.hud.set_seal_pulse(false)
	await _frames(25)
	var p: int = g.capital_of[me]
	for q in g.owned(me): if g.capital[q] == 0 and g.army[q] <= 1: p = q; break
	main._select(p); await _frames(25)
	var vi := -1
	for i in main.panel._verbs.size(): if String(main.panel._verbs[i]["id"]) == "build": vi = i
	print("build verb index ", vi)
	main.panel._press(vi); await _frames(20)
	var pk: Control = main.panel._bpicker
	var dump := func(n: Node, d: int, f: Callable) -> void:
		if n is Control and d < 4: print("  ".repeat(d), n.get_class(), " ", n.name, " min ", (n as Control).get_combined_minimum_size(), " size ", (n as Control).size)
		if d < 4: for k in n.get_children(): f.call(k, d + 1, f)
	if OS.get_environment("TB_DUMP") != "": dump.call(pk, 0, dump)
	var safe_l: float = main.offset_left
	var r := pk.get_global_rect()
	var bad := 0
	print("picker rect ", r, " main offset_left ", safe_l, " viewport ", main.get_viewport_rect().size)
	if r.position.x < safe_l + 8.0: bad += 1; print("FAIL: the picker starts at ", r.position.x, " inside the unsafe strip (", safe_l, ")")
	if r.end.x > main.get_viewport_rect().size.x - 8.0 or r.end.y > main.get_viewport_rect().size.y or r.position.y < 0.0: bad += 1; print("FAIL: the picker leaves the screen")
	var hud: TBHud = main.hud
	for c in hud.keepouts():
		if (c as Rect2).intersects(r): bad += 1; print("FAIL: the picker covers a HUD part ", c)
	root.get_viewport().get_texture().get_image().save_png(a[2])
	var expect: bool = a[a.size() - 1] == "expect"
	print("BUILD_PLACE OK" if bad == 0 else "BUILD_PLACE FAIL %d" % bad)
	quit(1 if (expect and bad > 0) else 0)
