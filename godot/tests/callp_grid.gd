extends SceneTree
## The call to arms a human ally receives: the medallion holds the enemy's flag, the two plates answer, and the words sit in the middle of their plates;
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
	var caller: int = g.nat_code.find("spain"); var enemy: int = g.nat_code.find("uk")
	g.set_rel(me, caller, TBData.REL_ALLY); g.set_rel(caller, enemy, TBData.REL_WAR)
	g.ev_uid += 1
	var ev := {"uid": g.ev_uid, "n": me, "kind": "prop", "id": "call", "from": caller, "e": enemy, "icon": "x", "cat": "", "count": 2}
	g.pending.append(ev)
	var answers: Array = []
	var hd: TBPanel.Handle = TBCallPrompt.open(main, g, ev, func(i: int): answers.append(i), func(): pass)
	for i in 30: await process_frame
	var card: Control = hd.card
	var cr := card.get_global_rect(); var hr := main.get_global_rect()
	_check(cr.position.x >= hr.position.x and cr.end.x <= hr.end.x and cr.position.y >= hr.position.y and cr.end.y <= hr.end.y, "the card is inside the screen (%s in %s)" % [str(cr), str(hr)])
	var meds: Array = []; _walk(card, meds, func(x): return x is TBNationParts.FlagMedal)
	_check(meds.size() == 1, "one flag medallion in the header (%d)" % meds.size())
	var btn: Array = []; _walk(card, btn, func(x): return x is TBBz.Btn and (x as Button).is_visible_in_tree() and (x as Button).text != "")
	_check(btn.size() == 2, "the two answer plates are there (%d)" % btn.size())
	btn.sort_custom(func(x, y): return (x as Control).get_global_rect().position.x < (y as Control).get_global_rect().position.x)
	var img: Image = root.get_viewport().get_texture().get_image()
	var rs: float = float(img.get_width()) / hr.size.x
	if btn.size() == 2:
		var r0 := (btn[0] as Control).get_global_rect(); var r1 := (btn[1] as Control).get_global_rect()
		_check(absf(r0.get_center().y - r1.get_center().y) <= 1.0, "both plates share a centre line")
		_check(absf((r0.position.x + r1.end.x) * 0.5 - cr.get_center().x) <= 2.0, "the plates sit on the card's axis (%.1f vs %.1f)" % [(r0.position.x + r1.end.x) * 0.5, cr.get_center().x])
		var worst := 0.0
		for b in btn:
			var e := _content_error(img, (b as Control).get_global_rect(), rs, Vector2(10.0, 5.0), 0.2)
			print("  %s: off the middle by %s" % [(b as Button).text, str(e)])
			if e != Vector2.INF: worst = maxf(worst, maxf(absf(e.x), absf(e.y)))
		_check(worst <= 1.5, "the words are in the middle of their plates (worst %.2f)" % worst)
	if meds.size() == 1:
		var mr := (meds[0] as Control).get_global_rect()
		_check(absf(mr.get_center().x - cr.get_center().x) <= 1.5, "the medallion is on the card's axis (%.1f vs %.1f)" % [mr.get_center().x, cr.get_center().x])
	if OS.get_environment("TB_SHOT") != "":
		var crop := img.get_region(Rect2i(int((cr.position.x - 20.0) * rs), int((cr.position.y - 20.0) * rs), int((cr.size.x + 40.0) * rs), int((cr.size.y + 40.0) * rs)))
		crop.save_png(OS.get_environment("TB_SHOT"))
	if btn.size() == 2:
		for b3 in btn: if (b3 as Button).text.to_lower() == TBI18n.T("callp_join").to_lower(): (b3 as Button).pressed.emit()
		for i in 4: await process_frame
		_check(answers == [0], "the Join plate answers 0: %s" % str(answers))
	print("CALLP_GRID OK" if fails == 0 else "CALLP_GRID FAIL %d" % fails)
	quit(fails)
