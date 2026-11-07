extends SceneTree
## Country-grade backdrop for the country ring mocks: the real map zoomed to country level, no selection, and the real figures of the countries in view. Usage: -s tests/country_backdrop.gd -- <w> <h> <out.png> <out.json>
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main.cfg["phone_ui"] = "desktop"; main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	await _frames(25)
	var cp: int = g.capital_of[me]
	main.map.fly_to(g.world.lon[cp], g.world.lat[cp], 2.4, 0.0)
	await _frames(90)
	root.get_texture().get_image().save_png(a[2])
	# the countries whose capital is on screen
	var out := []
	var st: Dictionary = TBNationsScreen.compute(g)
	var nids: int = (st["ids"] as Array).size()
	for n in range(1, g.N1):
		if g.alive[n] == 0: continue
		var c: int = g.capital_of[n]
		if c < 0: continue
		var pt: Vector3 = main.map.project(g.world.lon[c], g.world.lat[c])
		if pt.z <= 0.0 or pt.x < 60 or pt.x > w - 60 or pt.y < 120 or pt.y > h - 90: continue
		out.append({"n": n, "code": g.nat_code[n], "name": g.dname(n), "x": pt.x, "y": pt.y, "army": int(st["army"][n]), "prov": int(st["prov"][n]), "rank_p": int(st["rank_p"].get(n, 0)), "rank_a": int(st["rank_a"].get(n, 0)), "rank_t": int(st["rank_t"].get(n, 0)), "of": nids, "tech": snappedf(g.tech_level[n], 0.1), "gold": int(g.income(n)["gold"]), "rel": g.get_rel(me, n) if n != me else -1, "ruler": TBRulers.display_name(g, n) if g.rules >= 1 else "", "title": T_title(g, n)})
	var f := FileAccess.open(a[3], FileAccess.WRITE); f.store_string(JSON.stringify({"me": me, "zoom": main.map.zoom, "countries": out}, "  ")); f.close()
	print("countries in view: ", out.size())
	quit(0)
func T_title(g: TBGame, n: int) -> String:
	return TBI18n.T(TBRulers.title_key(g, n)) if g.rules >= 1 else ""
