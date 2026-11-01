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
func _content_error(img: Image, r: Rect2, rs: float, inset: Vector2, thr: float = 0.22) -> Vector2:
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
		if absf(lum[i] - med) > thr:
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
	var bar: TBRecruitCard = main._amount_card
	var br := bar.get_global_rect()
	var hr := main.get_global_rect()
	print("bar %s  host %s" % [str(br), str(hr)])
	_check(absf(br.get_center().x - hr.get_center().x) <= 1.0, "the bar is centred on the screen")
	_check(br.end.y <= hr.end.y - 60.0 and br.end.y >= hr.end.y - 120.0, "the bar sits above the lens bar (bottom edge %.0f of %.0f)" % [br.end.y, hr.end.y])
	_check(br.position.x >= hr.position.x and br.end.x <= hr.end.x, "the bar is inside the screen")
	var btn: Array = []; _walk(bar, btn, func(x): return x is Button and (x as Button).is_visible_in_tree())
	var sl: Array = []; _walk(bar, sl, func(x): return x is HSlider)
	var ed: Array = []; _walk(bar, ed, func(x): return x is LineEdit)
	_check(sl.size() == 1 and ed.size() == 1, "one slider and one number field")
	var minus: Button = null; var plus: Button = null; var okb: Button = bar._ok; var nob: Button = bar._cancel
	for b in btn:
		if (b as Button).text == "−": minus = b
		elif (b as Button).text == "+": plus = b
	_check(minus != null and plus != null, "both steppers are there")
	# one row: every part centred on one line
	var parts := {"province block": (bar._price.get_parent() as Control), "minus": minus, "slider": sl[0], "plus": plus, "number": ed[0], "confirm": okb, "cancel": nob}
	var cy0: float = (parts["minus"] as Control).get_global_rect().get_center().y
	for k in parts:
		var r2 := (parts[k] as Control).get_global_rect()
		print("  %-14s x %.1f..%.1f  y %.1f..%.1f  centre y %.1f" % [k, r2.position.x, r2.end.x, r2.position.y, r2.end.y, r2.get_center().y])
		if k != "slider": _check(absf(r2.get_center().y - cy0) <= 1.0, "%s is on the row's centre line (%.1f vs %.1f)" % [k, r2.get_center().y, cy0])
	for k2 in parts:
		var r4 := (parts[k2] as Control).get_global_rect()
		_check(r4.position.x >= br.position.x and r4.end.x <= br.end.x - 8.0, "%s is inside the bar with its padding (%.1f..%.1f in %.1f..%.1f)" % [k2, r4.position.x, r4.end.x, br.position.x, br.end.x])
	var okr := okb.get_global_rect(); var nor := nob.get_global_rect()
	_check(absf(okr.size.x - nor.size.x) < 0.6 and absf(okr.size.y - nor.size.y) < 0.6 and okr.size.x >= 40.0, "the two plates are the same size and wide enough for an icon (%s / %s)" % [str(okr.size), str(nor.size)])
	var srect := (sl[0] as Control).get_global_rect()
	var minus_r := minus.get_global_rect(); var plus_r := plus.get_global_rect()
	_check(srect.position.x - 14.5 >= minus_r.end.x - 1.0 and srect.end.x + 14.5 <= plus_r.position.x + 1.0, "the thumb stays clear of both steppers")
	_check(srect.size.x >= (220.0 if sc < 1.5 else 150.0), "the slider is long (%.0f units)" % srect.size.x)
	# the preset marks stay between the steppers
	var slb := sl[0] as TBBzParts.BzSlider
	_check(slb.labels.size() >= 3, "preset marks are there (%d)" % slb.labels.size())
	var lf: Font = TBKit.cinzel(500); var lz: float = TBKit.fsf(10.5)
	var first: Dictionary = slb.labels[0]; var last: Dictionary = slb.labels[slb.labels.size() - 1]
	var tw1: float = TBBz.tw(lf, String(first["t"]), lz, 0.0); var tw2: float = TBBz.tw(lf, String(last["t"]), lz, 0.0)
	var fx: float = srect.position.x + clampf(srect.size.x * float(first["r"]) - tw1 * 0.5, -10.0, srect.size.x + 12.0 - tw1)          # the slider pulls its end marks inside the same limits
	var lx: float = srect.position.x + clampf(srect.size.x * float(last["r"]) - tw2 * 0.5, -10.0, srect.size.x + 12.0 - tw2) + tw2
	_check(fx >= minus_r.end.x + 2.0 and lx <= plus_r.position.x - 2.0, "the first and last marks stay clear of the steppers (%.1f..%.1f vs %.1f..%.1f)" % [fx, lx, minus_r.end.x, plus_r.position.x])
	# tapping a mark jumps the number
	var before: int = bar.picker.value
	var hi: int = bar.picker.hi
	slb.label_picked.emit(slb.labels.size() - 1)
	await process_frame
	_check(bar.picker.value == hi, "tapping the last mark takes everything (%d of %d)" % [bar.picker.value, hi])
	slb.label_picked.emit(2)
	await process_frame
	_check(bar.picker.value == int(slb.labels[2]["n"]), "tapping a middle mark jumps to it (%d)" % bar.picker.value)
	bar.picker.set_value(before)
	# the pictures
	for i in 6: await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var rs: float = float(img.get_width()) / hr.size.x
	var worst := 0.0
	for pair in [[minus, "minus sign"], [plus, "plus sign"]]:
		var bb := pair[0] as Button
		var e := _content_error(img, bb.get_global_rect(), rs, Vector2(8.0, 8.0), 0.12)
		print("  %s in its ring: off the middle by %s" % [pair[1], str(e)])
		if e != Vector2.INF: worst = maxf(worst, maxf(absf(e.x), absf(e.y)))
	_check(worst <= 0.9, "the stepper signs are in the middle of their rings (worst %.2f)" % worst)
	worst = 0.0
	for pair in [[okb, "check"], [nob, "cross"]]:
		var bb2 := pair[0] as Button
		var e2 := _content_error(img, bb2.get_global_rect(), rs, Vector2(10.0, 5.0))
		print("  %s on its plate: off the middle by %s" % [pair[1], str(e2)])
		if e2 != Vector2.INF: worst = maxf(worst, maxf(absf(e2.x), absf(e2.y)))
	_check(worst <= 0.9, "the icons are in the middle of their plates (worst %.2f)" % worst)
	var er := (ed[0] as LineEdit).get_global_rect()
	var e3 := _content_error(img, er, rs, Vector2(6.0, 5.0))
	print("  number in its field %.0fx%.0f: off the middle by %s" % [er.size.x, er.size.y, str(e3)])
	if e3 != Vector2.INF: _check(absf(e3.x) <= 1.0 and absf(e3.y) <= maxf(1.0, 0.03 * er.size.y), "the number is in the middle of its field (%s)" % str(e3))
	if OS.get_environment("TB_SHOT") != "":
		var crop := img.get_region(Rect2i(int((br.position.x - 20.0) * rs), int((br.position.y - 20.0) * rs), int((br.size.x + 40.0) * rs), int((br.size.y + 40.0) * rs)))
		crop.save_png(OS.get_environment("TB_SHOT"))
	print("RECRUIT_GRID OK" if fails == 0 else "RECRUIT_GRID FAIL %d" % fails)
	quit(fails)
