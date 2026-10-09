extends SceneTree
## Overflow audit: opens the main screens and lists labels / buttons that are wider than the room they were given and children that stick
## out of their panel. Usage: -- <w> <h> <text_scale> <lang>
var _bad := []
func _walk(n: Node, tag: String) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		var c := n as Control
		if c is Label and c.size.x > 1.0 and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (c as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			var need: float = c.get_minimum_size().x
			if need > c.size.x + 1.5 and not c.clip_contents: _bad.append("%s label overflows %.0f > %.0f: '%s' (%s)" % [tag, need, c.size.x, (c as Label).text.left(40), c.get_path()])
		elif c is Button and c.size.x > 1.0 and not c.clip_contents and not (c as Button).clip_text:
			var need2: float = c.get_minimum_size().x
			if need2 > c.size.x + 1.5: _bad.append("%s button overflows %.0f > %.0f: '%s' (%s)" % [tag, need2, c.size.x, (c as Button).text.left(30), c.get_path()])
		var par := c.get_parent()
		if par is Control and not (par is ScrollContainer) and not (par is Container) and c.size.x > 4.0:
			var pr := Rect2(Vector2.ZERO, (par as Control).size)
			if (c.position.x < -2.0 or c.position.x + c.size.x > pr.size.x + 2.0) and not (par as Control).clip_contents and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_bad.append("%s sticks out of its parent: %s (%.0f..%.0f in %.0f) widest: %s" % [tag, c.get_path(), c.position.x, c.position.x + c.size.x, pr.size.x, _widest(c)])
	for k in n.get_children(): _walk(k, tag)

func _widest(c: Control) -> String:
	var best: Control = c
	var guard := 0
	while guard < 40:
		guard += 1
		var nxt: Control = null; var nw := 0.0
		for k in best.get_children():
			if k is Control and (k as Control).visible:
				var kw: float = (k as Control).get_combined_minimum_size().x
				if kw > nw: nw = kw; nxt = k
		if nxt == null or nw < best.get_combined_minimum_size().x * 0.6: break
		best = nxt
	var t := ""
	if best is Label: t = (best as Label).text.left(30)
	elif best is Button: t = (best as Button).text.left(30)
	return "%s '%s' min %.0f" % [best.get_class(), t, best.get_combined_minimum_size().x]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var sc := float(a[2]); var lang := a[3]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(lang)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["lang"] = lang; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	for i in 20: await process_frame
	var sp: int = g.nat_code.find("spain"); var au: int = g.nat_code.find("austrian_empire")
	var tests := {
		"hud": func(): main._select(-1),
		"inspect": func(): main._select(g.capital_of[fr]),
		"nations_self": func(): main._open_nations(fr),
		"nations_foreign": func(): main._open_nations(sp),
		"nations_war": func(): g.set_rel(fr, au, TBData.REL_WAR); main._open_nations(au),
		"budget": func(): main._open_budget(),
		"decisions": func(): main._open_decisions(),
		"council": func(): main._open_council(),
		"goals": func(): main._open_council("goals"),
		"annals": func(): main._open_annals(),
		"menu": func(): main._open_menu_hub(""),
		"settings": func(): main._open_menu_hub("settings"),
		"event": func(): TBModals.event_prompt(main._overlay, {"kind": "rand", "id": "golden_age", "count": 2, "uid": 1, "cat": "culture"}, func(c): pass, g),
		"prop": func(): TBModals.event_prompt(main._overlay, {"kind": "prop", "id": "nap", "from": sp, "count": 2, "uid": 2, "p": g.capital_of[sp]}, func(c): pass, g),
	}
	for k in tests:
		main._clear_overlay(); main._select(-1)
		g.set_rel(fr, au, TBData.REL_PEACE)
		(tests[k] as Callable).call()
		for i in 14: await process_frame
		_walk(main, "%s@%dx%d s%.2f %s" % [k, w, h, sc, lang])
	var seen := {}
	for b in _bad:
		var key: String = String(b).substr(String(b).find(" ") + 1)
		if seen.has(key): continue
		seen[key] = true
		print("OVERFLOW ", b)
	print("OVERFLOW_AUDIT %d findings %dx%d s%.2f %s" % [seen.size(), w, h, sc, lang])
	quit(0)
