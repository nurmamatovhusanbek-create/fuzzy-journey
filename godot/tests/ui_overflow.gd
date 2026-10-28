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
		# a word wider than its wrapping box is broken in the middle (or squeezed): the label / button needs room for its longest word
		if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and c.size.x > 1.0 and (c as Label).text != "":
			var lf: Font = c.get_theme_font("font"); var ls: int = c.get_theme_font_size("font_size")
			for wd in (c as Label).text.split(" ", false):
				var ww: float = lf.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
				if ww > c.size.x + 1.0: _bad.append("%s word broken (%.0f > %.0f): '%s' in '%s' (%s)" % [tag, ww, c.size.x, wd, (c as Label).text.left(30), c.get_path()]); break
		elif c is Button and (c as Button).autowrap_mode != TextServer.AUTOWRAP_OFF and c.size.x > 1.0 and (c as Button).text != "":
			var bf: Font = c.get_theme_font("font"); var bs: int = c.get_theme_font_size("font_size")
			var sbn: StyleBox = c.get_theme_stylebox("normal")
			var room: float = c.size.x - (sbn.get_margin(SIDE_LEFT) + sbn.get_margin(SIDE_RIGHT) if sbn != null else 0.0)
			for wd2 in (c as Button).text.split(" ", false):
				var bw: float = bf.get_string_size(wd2, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
				if room > 8.0 and bw > room + 1.0: _bad.append("%s button word broken (%.0f > %.0f): '%s' in '%s' (%s)" % [tag, bw, room, wd2, (c as Button).text.left(30), c.get_path()]); break
		var par := c.get_parent()
		if par is Control and not (par is ScrollContainer) and not (par is Container) and c.size.x > 4.0:
			var pr := Rect2(Vector2.ZERO, (par as Control).size)
			if c.position.x > -5000.0 and (c.position.x < -2.0 or c.position.x + c.size.x > pr.size.x + 2.0) and not (par as Control).clip_contents and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_bad.append("%s sticks out of its parent: %s (%.0f..%.0f in %.0f) widest: %s" % [tag, c.get_path(), c.position.x, c.position.x + c.size.x, pr.size.x, _widest(c)])
	for k in n.get_children(): _walk(k, tag)


## the rectangle (global coordinates) that a label's text really occupies: its own width when it does not wrap, placed by the alignment
func _text_rect(c: Label) -> Rect2:
	var f: Font = c.get_theme_font("font"); var fs: int = c.get_theme_font_size("font_size")
	var gr := c.get_global_rect()
	var w: float; var hgt: float
	if c.autowrap_mode != TextServer.AUTOWRAP_OFF:
		w = gr.size.x; hgt = f.get_multiline_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, gr.size.x, fs).y
	else:
		var sz: Vector2 = f.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs); w = minf(sz.x, gr.size.x); hgt = sz.y
	var x: float = gr.position.x
	if c.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x += (gr.size.x - w) * 0.5
	elif c.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x += gr.size.x - w
	var y: float = gr.position.y
	if c.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: y += (gr.size.y - hgt) * 0.5
	elif c.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: y += gr.size.y - hgt
	return Rect2(x, y, w, hgt)

func _visible_part(c: Control, r: Rect2) -> Rect2:
	var cur: Node = c.get_parent()
	while cur != null:
		if cur is ScrollContainer: r = r.intersection((cur as Control).get_global_rect())
		elif cur is Control and (cur as Control).clip_contents: r = r.intersection((cur as Control).get_global_rect())
		cur = cur.get_parent()
	return r

func _labels(n: Node, acc: Array) -> void:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.strip_edges() != "" and (n as Label).modulate.a > 0.2 and (n as Label).self_modulate.a > 0.2:
		acc.append(n)
	for k in n.get_children(): _labels(k, acc)

## two labels whose text lies on top of each other (not nested, both on screen): wrong spacing / a misplaced item
func _overlaps(root_n: Node, tag: String) -> void:
	var ls: Array = []
	_labels(root_n, ls)
	var rects: Array = []
	for l in ls:
		var tr: Rect2 = _visible_part(l, _text_rect(l))
		rects.append(tr)
	for i in ls.size():
		var ri: Rect2 = rects[i]
		if ri.size.x < 4.0 or ri.size.y < 4.0: continue
		for j in range(i + 1, ls.size()):
			var rj: Rect2 = rects[j]
			if rj.size.x < 4.0 or rj.size.y < 4.0: continue
			if ls[i].is_ancestor_of(ls[j]) or ls[j].is_ancestor_of(ls[i]): continue
			var ov: Rect2 = ri.intersection(rj)
			if ov.size.x <= 1.5 or ov.size.y <= 2.0: continue
			if ov.get_area() > 0.2 * minf(ri.get_area(), rj.get_area()):
				_bad.append("%s text overlaps text: '%s' x '%s' (%.0f x %.0f px)" % [tag, (ls[i] as Label).text.left(24), (ls[j] as Label).text.left(24), ov.size.x, ov.size.y])

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
	tests["pick"] = func(): main._clear_overlay(); main._begin_pick("napoleonic", "normal"); main._pick_flow.select_nation(fr, false)
	for k in tests:
		main._clear_overlay(); main._select(-1)
		g.set_rel(fr, au, TBData.REL_PEACE)
		(tests[k] as Callable).call()
		for i in 14: await process_frame
		_walk(main, "%s@%dx%d s%.2f %s" % [k, w, h, sc, lang])
		_overlaps(main, "%s@%dx%d s%.2f %s" % [k, w, h, sc, lang])
		if a.size() > 4: root.get_viewport().get_texture().get_image().save_png("%s/%s_%dx%d.png" % [a[4], k, w, h])      # optional 5th argument: a folder for a picture of every screen
	var seen := {}
	for b in _bad:
		var key: String = String(b).substr(String(b).find(" ") + 1)
		if seen.has(key): continue
		seen[key] = true
		print("OVERFLOW ", b)
	print("OVERFLOW_AUDIT %d findings %dx%d s%.2f %s" % [seen.size(), w, h, sc, lang])
	quit(0)
