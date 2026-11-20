extends SceneTree
## The Realm page's name to proclaim says which provinces it asks for and who holds them (like the formable screens of Age of Civilizations 2): a disclosure with one group per holder,
## the land lit on the map, a name that frames its province. Usage: -s tests/formable_ui.gd -- <out dir> (xvfb, TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var lang: String = a[1] if a.size() > 1 else "en"
	var tscale: float = float(a[2]) if a.size() > 2 else 1.0
	var sz := Vector2i(1920, 1080)
	DisplayServer.window_set_size(sz); root.size = sz
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"; main.cfg["fx"] = "off"; main.cfg["text_scale"] = tscale
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("russian_empire"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	var cur := TBLineage.current(g, me)
	var opts: Array = TBLineage.options(g, me)
	opts.sort_custom(func(a: int, b: int) -> bool:                                   # the order the card lists them in
		var la: bool = TBLineage.line_of(a) == TBLineage.line_of(cur); var lb: bool = TBLineage.line_of(b) == TBLineage.line_of(cur)
		if la != lb: return la
		return int(TBLineage.STAGES[a]["order"]) < int(TBLineage.STAGES[b]["order"]))
	var ussr: int = opts[0]
	# the land of the USSR: a third held by the player, a neighbour holds some, the rest is where it is
	var core: Array = TBLineage.STAGES[ussr]["core"]
	var neighbour := -1
	for n in range(1, g.N1): if n != me and n != g.rebel and g.alive[n] != 0: neighbour = n; break
	for i in core.size():
		if i % 3 == 0: g.set_owner(int(core[i]), me)
		elif i % 3 == 1: g.set_owner(int(core[i]), neighbour)
	g.occupier[int(core[0])] = neighbour
	for i in 20: await process_frame
	main._open_realm_page()
	for i in 25: await process_frame
	var tog := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower() == String(TBI18n.T.call("lg_prov_show")).to_lower())
	_check(tog.size() >= 1, "the card for a name to proclaim has the disclosure (%d)" % tog.size())
	if tog.is_empty(): print("FORMABLE_UI FAIL"); quit(1); return
	var rep := TBLineage.core_report(g, me, ussr)
	var groups_before := _find(main._overlay, func(x): return x is TBLineageView.NameLink)
	(tog[0] as Button).pressed.emit()
	for i in 25: await process_frame
	var links := _find(main._overlay, func(x): return x is TBLineageView.NameLink and (x as Button).is_visible_in_tree())
	_check(links.size() > 0, "the province names show once it is open (%d)" % links.size())
	_check(main.map._targets.size() == (rep["missing"] as Array).size(), "the land still to win is lit on the map (%d of %d)" % [main.map._targets.size(), (rep["missing"] as Array).size()])
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/formable_0.png" % out)
	# nothing sticks out of the window at this text size and language
	var win_card: Control = null
	for c in main._overlay.get_children():
		if c.has_meta("tb_handle") and (c.get_meta("tb_handle") as TBPanel.Handle).mem_key == "realm": win_card = (c.get_meta("tb_handle") as TBPanel.Handle).card
	if win_card != null:
		var wr: Rect2 = win_card.get_global_rect()
		var worst := 0.0
		for l in links:
			var lr: Rect2 = (l as Control).get_global_rect()
			worst = maxf(worst, maxf(wr.position.x - lr.position.x, lr.end.x - wr.end.x))
		_check(worst <= 1.0, "every province name is inside the window (sticks out by %.1f)" % worst)
	# a group's header lights its provinces
	var heads := _find(main._overlay, func(x): return x is HBoxContainer and (x as HBoxContainer).mouse_filter == Control.MOUSE_FILTER_STOP and x.get_child_count() >= 2 and x.get_child(x.get_child_count() - 1) is Button)
	_check(heads.size() >= int((rep["rows"] as Array).size()), "one header per holder (%d for %d)" % [heads.size(), (rep["rows"] as Array).size()])
	if heads.size() > 1:
		(heads[1] as Control).mouse_entered.emit()
		var row1: Dictionary = (rep["rows"] as Array)[1]
		_check(main.map._targets.size() == (row1["ps"] as Array).size(), "hovering a holder lights its provinces (%d of %d)" % [main.map._targets.size(), (row1["ps"] as Array).size()])
		(heads[1] as Control).mouse_exited.emit()
		_check(main.map._targets.size() == (rep["missing"] as Array).size(), "leaving it goes back to the land still to win")
	# a name frames its province
	if links.size() > 0:
		(links[0] as Button).pressed.emit()
		for i in 15: await process_frame
		_check(main.map._targets.size() == 1, "a pressed name lights that province alone (%d)" % main.map._targets.size())
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/formable_1.png" % out)
	# closing the window puts the map back
	main._toggle_window("realm")
	for i in 10: await process_frame
	_check(main.map._targets.size() == 0, "closing the Realm page clears the map (%d)" % main.map._targets.size())
	print("FORMABLE_UI ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(fails)
