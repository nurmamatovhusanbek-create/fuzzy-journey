extends SceneTree
## Decrees window alignment: the decree cards form one grid (same width per column, same height per row, same x for the Enact buttons and the cost chips), and the doctrine cells are equal. Usage: -s tests/decrees_grid.gd -- <w> <h> <text scale> <lang> [out png]
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls or (n.get_script() != null and String(n.get_script().get_global_name()) == cls): out.append(n)
	for c in n.get_children(): _find(c, cls, out)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var sc := float(a[2]); var lang := a[3]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(lang)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["lang"] = lang; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._on_setting_changed("lang")
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	for i in 20: await process_frame
	main._open_decisions()
	for i in 16: await process_frame
	var cards: Array = []
	_find(main._overlay, "PanelContainer", cards)
	var dec: Array = []
	for c in cards:
		if (c as Control).get_script() != null and String((c as Control).get_script().resource_path).ends_with("modals.gd"): dec.append(c)
	print("decree cards: %d" % dec.size())
	_check(dec.size() >= 6, "the decree cards were found (%d)" % dec.size())
	var cols := {}                                               # x of the card -> list of cards
	for c in dec:
		var r: Rect2 = (c as Control).get_global_rect()
		var key := int(round(r.position.x))
		var placed := false
		for k in cols.keys():
			if absi(int(k) - key) <= 1: (cols[k] as Array).append(c); placed = true; break
		if not placed: cols[key] = [c]
	for k in cols.keys():
		var list: Array = cols[k]
		var w0: float = (list[0] as Control).get_global_rect().size.x
		for c in list: _check(absf((c as Control).get_global_rect().size.x - w0) <= 1.0, "column x=%d: card widths differ (%.0f vs %.0f)" % [k, (c as Control).get_global_rect().size.x, w0])
	# cards in one grid row share a height
	var rows := {}
	for c in dec:
		var key2 := int(round((c as Control).get_global_rect().position.y))
		var placed2 := false
		for k in rows.keys():
			if absi(int(k) - key2) <= 1: (rows[k] as Array).append(c); placed2 = true; break
		if not placed2: rows[key2] = [c]
	for k in rows.keys():
		var list2: Array = rows[k]
		var h0: float = (list2[0] as Control).get_global_rect().size.y
		for c in list2: _check(absf((c as Control).get_global_rect().size.y - h0) <= 1.0, "row y=%d: card heights differ (%.0f vs %.0f)" % [k, (c as Control).get_global_rect().size.y, h0])
	# the Enact buttons: one size, one distance from the card's right edge
	var gap0 := -1.0; var bw0 := -1.0; var bh0 := -1.0
	for c in dec:
		var btns: Array = []
		_find(c, "Button", btns)
		for b in btns:
			var bb: Rect2 = (b as Control).get_global_rect(); var cr: Rect2 = (c as Control).get_global_rect()
			if not (b as Control).is_visible_in_tree() or bb.size.x < 40.0: continue
			var gap: float = cr.end.x - bb.end.x
			if gap0 < 0.0: gap0 = gap; bw0 = bb.size.x; bh0 = bb.size.y
			_check(absf(gap - gap0) <= 1.0, "an Enact button is %.0f from the card edge, others %.0f" % [gap, gap0])
			_check(absf(bb.size.y - bh0) <= 1.0, "Enact button heights %.0f vs %.0f" % [bb.size.y, bh0])
	# doctrine cells: equal widths
	var segs: Array = []
	_find(main._overlay, "Segmented", segs)
	for s in segs:
		var sg: Control = s
		if not sg.is_visible_in_tree(): continue
		var cw := -1.0
		for b in sg.get_children():
			if b is Button and (b as Control).visible:
				var bwid: float = (b as Control).get_global_rect().size.x
				if cw < 0.0: cw = bwid
				_check(absf(bwid - cw) <= 1.5, "doctrine cells differ in width (%.0f vs %.0f)" % [bwid, cw])
	if a.size() > 4: root.get_viewport().get_texture().get_image().save_png(a[4])
	print("DECREES_GRID OK" if fails == 0 else "DECREES_GRID FAIL %d" % fails)
	quit(fails)
