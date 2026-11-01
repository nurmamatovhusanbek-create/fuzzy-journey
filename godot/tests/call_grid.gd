extends SceneTree
## The call-to-arms sheet that opens after you declare war: rows (tap to choose), flags and the two plates;
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
	get_root().set_meta("done", false)
	_run.call_deferred()
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
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	var g: TBGame = main.g
	var me: int = g.human_id
	var en: int = g.nat_code.find("uk")
	g.set_rel(me, en, TBData.REL_WAR)
	var names := ["spain", "prussia", "russia"]
	for nm in names:
		var o: int = g.nat_code.find(nm)
		if o < 1: continue
		g.set_rel(me, o, TBData.REL_ALLY); g.set_rel(o, en, TBData.REL_PEACE)
	g.dp[me] = 5.0
	var list: Array = TBCallSheet.callable_allies(g, me, en)
	print("callable: ", list)
	_check(list.size() >= 2, "at least two allies can be called (%d)" % list.size())
	var cmds: Array = []
	var hd: TBPanel.Handle = TBCallSheet.open(main, g, en, func(c: Dictionary) -> void: cmds.append(c))
	for i in 30: await process_frame
	var card: Control = hd.card
	var cr := card.get_global_rect(); var hr := main.get_global_rect()
	_check(cr.position.x >= hr.position.x and cr.end.x <= hr.end.x and cr.position.y >= hr.position.y and cr.end.y <= hr.end.y, "the sheet is inside the screen (%s in %s)" % [str(cr), str(hr)])
	var tgs: Array = []; _walk(hd.body, tgs, func(x): return x is TBCallSheet.Row)
	var meds: Array = []; _walk(hd.body, meds, func(x): return x is TBNationParts.FlagMedal)
	print("rows: toggles %d  flags %d" % [tgs.size(), meds.size()])
	_check(tgs.size() == list.size() and meds.size() == list.size(), "one flag and one row per ally")
	# each flag is on its switch's centre line, and all flags/switches share their left edges
	for i in mini(tgs.size(), meds.size()):
		var tr := (tgs[i] as Control).get_global_rect(); var mr := (meds[i] as Control).get_global_rect()
		_check(absf(tr.get_center().y - mr.get_center().y) <= 1.0, "row %d: flag and row share a centre line (%.1f vs %.1f)" % [i, mr.get_center().y, tr.get_center().y])
		_check(absf(mr.position.x - (meds[0] as Control).get_global_rect().position.x) <= 0.6, "row %d: flags share a left edge" % i)
		_check(absf(tr.position.x - (tgs[0] as Control).get_global_rect().position.x) <= 0.6 and absf(tr.end.x - (tgs[0] as Control).get_global_rect().end.x) <= 0.6, "row %d: rows share both edges" % i)
		_check(tr.position.x <= mr.position.x - 4.0 and tr.end.x >= mr.end.x + 4.0, "row %d: the flag sits inside its row" % i)
	var btn: Array = []; _walk(card, btn, func(x): return x is TBBz.Btn and (x as Button).is_visible_in_tree())
	_check(btn.size() == 2, "two plates (%d)" % btn.size())
	btn.sort_custom(func(x, y): return (x as Control).get_global_rect().position.x < (y as Control).get_global_rect().position.x)
	var ok: Button = btn[btn.size() - 1]; var later: Button = btn[0]
	_check(ok.disabled, "Call allies is off while nothing is chosen")
	var okr0 := ok.get_global_rect(); var lr := later.get_global_rect()
	_check(absf(okr0.get_center().y - lr.get_center().y) <= 1.0 and absf(okr0.size.y - lr.size.y) <= 0.6, "the plates share a row and a height")
	_check(okr0.end.x <= cr.end.x - 8.0 and lr.position.x >= cr.position.x + 8.0, "the plates are inside the card with padding")
	# switching two allies on
	(tgs[0] as Button).pressed.emit(); (tgs[1] as Button).pressed.emit()
	_check((tgs[0] as TBCallSheet.Row).on and (tgs[1] as TBCallSheet.Row).on, "a tap on a country chooses it")
	for i in 6: await process_frame
	_check(not ok.disabled, "Call allies lights up once two are chosen")
	_check(ok.text.find("2") >= 0, "the plate says how many (%s)" % ok.text)
	var img: Image = root.get_viewport().get_texture().get_image()
	var rs: float = float(img.get_width()) / hr.size.x
	var worst := 0.0
	for pair in [[ok, "Call allies"], [later, "Not now"]]:
		var bb := pair[0] as Button
		var e := _content_error(img, bb.get_global_rect(), rs, Vector2(10.0, 5.0), 0.2)
		print("  %s: off the middle by %s" % [pair[1], str(e)])
		if e != Vector2.INF: worst = maxf(worst, maxf(absf(e.x), absf(e.y)))
	_check(worst <= 1.2, "the words are in the middle of their plates (worst %.2f)" % worst)
	if OS.get_environment("TB_SHOT") != "":
		var crop := img.get_region(Rect2i(int((cr.position.x - 20.0) * rs), int((cr.position.y - 20.0) * rs), int((cr.size.x + 40.0) * rs), int((cr.size.y + 40.0) * rs)))
		crop.save_png(OS.get_environment("TB_SHOT"))
	# sending
	ok.pressed.emit()
	for i in 4: await process_frame
	_check(cmds.size() == 2 and String(cmds[0]["cmd"]) == "callAlly" and int(cmds[0]["e"]) == en, "two callAlly commands go out (%d)" % cmds.size())
	print("CALL_GRID OK" if fails == 0 else "CALL_GRID FAIL %d" % fails)
	quit(fails)
