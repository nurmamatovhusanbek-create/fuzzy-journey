extends SceneTree
## Alignment of the "How many?" card (Recruit / Hire) with its troop picker: every row on the card's own left and right edge, the stepper plates clear of the slider thumb, the share buttons equal,
## and what is written on a button or in the number field in the middle of it (measured on the picture). Usage: -s tests/recruit_grid.gd -- <w> <h> <text scale>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
## where the writing inside `r` sits relative to the middle of `r`: Vector2 error in units, or INF when nothing was found
func _content_error(img: Image, r: Rect2, rs: float, inset: Vector2) -> Vector2:
	var x0 := int((r.position.x + inset.x) * rs); var x1 := int((r.end.x - inset.x) * rs)
	var y0 := int((r.position.y + inset.y) * rs); var y1 := int((r.end.y - inset.y) * rs)
	if x0 < 0 or y0 < 0 or x1 >= img.get_width() or y1 >= img.get_height() or x1 <= x0 or y1 <= y0: return Vector2.INF
	var lum := PackedFloat32Array()
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			var c: Color = img.get_pixel(xx, yy); lum.append(c.r * 0.3 + c.g * 0.59 + c.b * 0.11)
	var sorted := lum.duplicate(); sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	var w := x1 - x0
	var cx0 := 1 << 30; var cx1 := -1; var cy0 := 1 << 30; var cy1 := -1
	for i in lum.size():
		if absf(lum[i] - med) > 0.22:
			var xx2: int = x0 + i % w; var yy2: int = y0 + i / w
			cx0 = mini(cx0, xx2); cx1 = maxi(cx1, xx2); cy0 = mini(cy0, yy2); cy1 = maxi(cy1, yy2)
	if cx1 < 0: return Vector2.INF
	return Vector2((float(cx0 + cx1 + 1) * 0.5) / rs - r.get_center().x, (float(cy0 + cy1 + 1) * 0.5) / rs - r.get_center().y)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 800; var sc := float(a[2]) if a.size() > 2 else 1.0
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	var g: TBGame = main.g
	var home: int = -1
	for p in g.owned(g.human_id): if g.levy[p] > 20: home = p; break
	g.gold[g.human_id] = 3000.0
	main._open_amount("recruit", home)
	for i in 30: await process_frame
	var card: TBRecruitCard = main._amount_card
	var box: Control = card._box
	var br := box.get_global_rect()
	print("card %s  box x %.1f..%.1f" % [str(card.get_global_rect()), br.position.x, br.end.x])
	var n := 0
	for c in box.get_children():
		if not (c is Control) or not (c as Control).visible: continue
		var r := (c as Control).get_global_rect()
		print("  row %d %-18s x %.1f..%.1f  y %.1f h %.1f  min %s" % [n, c.get_class(), r.position.x, r.end.x, r.position.y, r.size.y, str((c as Control).get_combined_minimum_size())])
		_check(absf(r.position.x - br.position.x) < 0.6, "row %d starts at the card's content edge (%.1f vs %.1f)" % [n, r.position.x, br.position.x])
		_check(absf(r.end.x - br.end.x) < (1.5 if c is Label else 0.6), "row %d ends at the card's content edge (%.1f vs %.1f)" % [n, r.end.x, br.end.x])          # a tracked title carries one letter-space after its last letter
		n += 1
	# the picker's row: stepper plates, slider, number
	var sl: Array = []; _walk(card, sl, func(x): return x is HSlider)
	var btn: Array = []; _walk(card, btn, func(x): return x is Button and (x as Button).is_visible_in_tree())
	_check(sl.size() == 1, "one slider")
	var minus_r := Rect2(); var plus_r := Rect2()
	for b in btn:
		if (b as Button).text == "−": minus_r = (b as Control).get_global_rect()
		elif (b as Button).text == "+": plus_r = (b as Control).get_global_rect()
	if sl.size() == 1 and minus_r.size.x > 0.0 and plus_r.size.x > 0.0:
		var srect := (sl[0] as Control).get_global_rect()
		print("  slider x %.1f..%.1f  minus ..%.1f  plus %.1f.." % [srect.position.x, srect.end.x, minus_r.end.x, plus_r.position.x])
		_check(srect.position.x - 14.5 >= minus_r.end.x - 1.0, "the thumb at the bottom does not reach the minus plate")
		_check(srect.end.x + 14.5 <= plus_r.position.x + 1.0, "the thumb at the top does not reach the plus plate")
	# the share buttons: equal cells in one band, equal heights
	var cells: Array = []
	for b in btn:
		var t: String = (b as Button).text
		if t.ends_with("%"): cells.append(b)
	if cells.size() >= 2:
		var w0: float = (cells[0] as Control).size.x; var h0: float = (cells[0] as Control).size.y
		for cc in cells:
			_check(absf((cc as Control).size.x - w0) < 1.0 and absf((cc as Control).size.y - h0) < 1.0, "share cells are the same size (%s)" % (cc as Button).text)
	# the two buttons: same height; writing centred; the number field's figure centred
	for i in 3: await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var rs: float = float(img.get_width()) / main.get_global_rect().size.x
	var worst := 0.0
	var allow := 2.0
	for b in btn:
		var bb := b as Button
		if bb.text == "" or bb.text == "−" or bb.text == "+" or bb.disabled: continue
		var e := _content_error(img, bb.get_global_rect(), rs, Vector2(10.0, 5.0))
		if e == Vector2.INF: continue
		worst = maxf(worst, maxf(absf(e.x), absf(e.y)) - maxf(0.0, 0.06 * bb.size.y - 2.0))                 # up to 6 % of the button's height: the kit centres the line box, capitals sit a little high
		print("  button '%s' %.0fx%.0f: content off the middle by (%.2f, %.2f)" % [bb.text, bb.size.x, bb.size.y, e.x, e.y])
	_check(worst <= 2.0, "what is written on a button is centred on it (worst %.2f)" % worst)
	var segs: Array = []; _walk(card, segs, func(x): return x is Control and x.get_script() != null and x.has_signal("chosen") and x.has_method("set_current"))
	_check(segs.size() == 1, "the share presets are there")
	if segs.size() == 1:
		var sg := (segs[0] as Control).get_global_rect()
		print("  presets x %.1f..%.1f (card content %.1f..%.1f) h %.1f" % [sg.position.x, sg.end.x, br.position.x, br.end.x, sg.size.y])
		_check(absf(sg.position.x - br.position.x) < 0.6 and absf(sg.end.x - br.end.x) < 0.6, "the presets span the card's content width")
		var cw: float = (sg.size.x - 6.0) / 4.0
		var cworst := 0.0
		for q in 4:
			var cell := Rect2(sg.position.x + 3.0 + q * cw, sg.position.y + 3.0, cw, sg.size.y - 6.0)
			var e3 := _content_error(img, cell, rs, Vector2(4.0, 3.0))
			if e3 == Vector2.INF: continue
			cworst = maxf(cworst, maxf(absf(e3.x), absf(e3.y)))
			print("  preset %d: figure off the cell's middle by (%.2f, %.2f)" % [q, e3.x, e3.y])
		_check(cworst <= 1.3, "the figures stand in the middle of their cells (worst %.2f)" % cworst)
	var edits: Array = []; _walk(card, edits, func(x): return x is LineEdit)
	for ed in edits:
		var er := (ed as LineEdit).get_global_rect()
		var e2 := _content_error(img, er, rs, Vector2(8.0, 6.0))
		print("  number field %.0fx%.0f: figure off the middle by %s" % [er.size.x, er.size.y, str(e2)])
		if e2 != Vector2.INF: _check(absf(e2.y) <= maxf(1.5, 0.03 * er.size.y), "the figure in the number field is centred vertically (%.2f)" % e2.y)
	if OS.get_environment("TB_SHOT") != "":
		var cr := card.get_global_rect()
		var crop := img.get_region(Rect2i(int((cr.position.x - 20.0) * rs), int((cr.position.y - 20.0) * rs), int((cr.size.x + 40.0) * rs), int((cr.size.y + 40.0) * rs)))
		crop.save_png(OS.get_environment("TB_SHOT"))
	print("RECRUIT_GRID OK" if fails == 0 else "RECRUIT_GRID FAIL %d" % fails)
	quit(fails)
