extends SceneTree
## The relations part of the country card (mock R1): groups with a count, two columns of flag rows (flag, name, how near), the nearest first, "+n more" for the rest. Measures the rows on the real layout:
## equal heights, each flag on its row's centre line, names inside their rows, the nearness words on one right edge. Usage: -s tests/rel_card.gd -- <w> <h> <text scale>   (TB_SHOT=file.png saves the picture)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 800; var sc := float(a[2]) if a.size() > 2 else 1.0
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("discovery", "normal")
	var me: int = TBGame.new(main.world, {}, {"seed": 1}).nat_code.find("timurid_emirates") if false else main.g.nat_code.find("timurid_emirates")
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1); main._apply_a11y()
	var al := ["bengal", "malacca", "malaysian_islamic_states", "zayyanid_caliphate", "mi_kma_ki", "congo", "benin", "delaware", "andean_hunter_gatherers"]
	var nap := ["hausa_states", "alwa", "athabaskan", "madagascar", "khoiasan"]
	for id in al: g.set_rel(me, g.nat_code.find(id), TBData.REL_ALLY)
	for id in nap: g.set_rel(me, g.nat_code.find(id), TBData.REL_NAP)
	g.set_rel(me, g.nat_code.find("chagatai_khanate"), TBData.REL_MARRIAGE)
	g.set_rel(me, g.nat_code.find("emirate_of_the_white_sheep_turks"), TBData.REL_WAR); g.set_rel(me, g.nat_code.find("sultanate_of_delhi"), TBData.REL_WAR)
	main._open_realm_page()
	for i in 30: await process_frame
	var rows: Array = []; _walk(main, rows, func(x): return x is TBRealmScreen.RelRow and (x as Control).is_visible_in_tree())
	print("rows visible: ", rows.size())
	_check(rows.size() >= 8, "the groups show their countries (%d rows)" % rows.size())
	var hs := {}
	var edges := {}
	for r in rows:
		var rr := (r as Control).get_global_rect()
		hs[snappedf(rr.size.y, 0.5)] = 1
		var fls: Array = []; _walk(r, fls, func(x): return x is TBNationParts.FlagMedal)
		var nms: Array = []; _walk(r, nms, func(x): return x is TBBz.TLabel)
		var labs: Array = []; _walk(r, labs, func(x): return x is Label and not x is TBBz.TLabel)
		if fls.size() == 1:
			var fr := (fls[0] as Control).get_global_rect()
			_check(absf(fr.get_center().y - rr.get_center().y) <= 1.0, "a flag is on its row's centre line (%.1f vs %.1f)" % [fr.get_center().y, rr.get_center().y])
			_check(fr.position.x >= rr.position.x - 0.5, "a flag is inside its row")
		for nl in nms:
			var nr := (nl as Control).get_global_rect()
			_check(nr.end.x <= rr.end.x + 0.5 and nr.position.y >= rr.position.y - 0.5 and nr.end.y <= rr.end.y + 0.5, "a name stays inside its row %s in %s" % [str(nr), str(rr)])
			_check(absf(nr.get_center().y - rr.get_center().y) <= 1.5, "a name is centred on its row (%.1f vs %.1f)" % [nr.get_center().y, rr.get_center().y])
		for lb in labs:
			var lr := (lb as Control).get_global_rect()
			edges[int(roundf(lr.end.x / 4.0))] = 1; print("  tag right edge %.1f (row %s)" % [lr.end.x, str(rr)])
			_check(absf(lr.get_center().y - rr.get_center().y) <= 1.0, "the nearness word is centred on its row")
	_check(hs.size() == 1, "all rows are one height (%s)" % str(hs.keys()))
	_check(edges.size() <= 2, "the nearness words stand on two right edges (%d)" % edges.size())
	if OS.get_environment("TB_SHOT") != "":
		var scs: Array = []; _walk(main, scs, func(x): return x is ScrollContainer and (x as Control).is_visible_in_tree())
		for sc2 in scs: (sc2 as ScrollContainer).scroll_vertical = 100000
		for i in 6: await process_frame
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("TB_SHOT"))
	print("REL_CARD OK" if fails == 0 else "REL_CARD FAIL %d" % fails)
	quit(fails)
