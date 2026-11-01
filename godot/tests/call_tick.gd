extends SceneTree
## The call to arms a human ally receives, as the notice-strip row (mock D1): the caller's flag in the medallion, the text and the willingness line, a cross and a tick.
## Checks the row is there, the two round buttons are on its centre line, a tap on the tick joins the war and a tap on the cross refuses. Usage: -s tests/call_tick.gd -- <w> <h> <text scale>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _init() -> void: _run.call_deferred()
func _click(row: Control, at: Vector2) -> void:
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.position = at; ev.pressed = true
	row._gui_input(ev)
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.position = at; up.pressed = false
	row._gui_input(up)
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
	for k in 2:
		g.ev_uid += 1
		g.pending.append({"uid": g.ev_uid, "n": me, "kind": "prop", "id": "call", "from": caller, "e": enemy, "icon": "x", "cat": "", "count": 2})
		if k == 0: break
	main.show_events(); main._after_change()
	for i in 40: await process_frame
	var rows: Array = []; _walk(main, rows, func(x): return x is TBAlertTicker.AlertRow and (x as TBAlertTicker.AlertRow).entry.get("id", "") == "call")
	_check(rows.size() == 1, "one call row in the strip (%d)" % rows.size())
	_check(main._event_dlg.is_empty(), "no dialog pops up for a call")
	if rows.size() != 1:
		print("CALL_TICK FAIL"); quit(1); return
	var row: TBAlertTicker.AlertRow = rows[0]
	var rr := row.get_global_rect()
	print("row ", rr, " text: ", row.text, " | ", row.entry.get("sub", ""))
	_check(row.entry.get("tex") != null, "the medallion carries a flag")
	_check(String(row.entry.get("sub", "")).find("%") >= 0, "the second line gives the willingness")
	var img: Image = root.get_viewport().get_texture().get_image()
	var rs: float = float(img.get_width()) / main.get_global_rect().size.x
	if OS.get_environment("TB_SHOT") != "":
		var cr := Rect2i(int((rr.position.x - 60.0) * rs), int((rr.position.y - 14.0) * rs), int((rr.size.x + 80.0) * rs), int((rr.size.y + 28.0) * rs))
		img.get_region(cr.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(OS.get_environment("TB_SHOT"))
	# the buttons: a tick answers 0 (join), a cross 1 (stay out)
	var d: float = row.btn_d(); var cy: float = row.base_h() * 0.5
	var yes_c := Vector2(row.size.x - 10.0 - d * 0.5, cy); var no_c := Vector2(yes_c.x - d - 6.0, cy)
	_check(absf((rr.position.y + yes_c.y) - (rr.position.y + no_c.y)) < 0.1, "tick and cross share a centre line")
	_check(no_c.x - d * 0.5 > row.size.x * 0.3, "the buttons sit at the right end of the row")
	var got: Array = []
	row.answered.connect(func(uid: int, c: int): got.append(c))
	var gr0: int = g.grudge[caller * g.N1 + me]
	_click(row, no_c)
	for i in 6: await process_frame
	_check(got == [1], "the cross answers 1: %s" % str(got))
	_check(g.get_rel(me, enemy) != TBData.REL_WAR, "refusing keeps you out of the war")
	_check(g.grudge[caller * g.N1 + me] > gr0, "and Spain remembers it (grudge %d -> %d)" % [gr0, g.grudge[caller * g.N1 + me]])
	# a second call: the tick joins
	g.ev_uid += 1
	g.pending.append({"uid": g.ev_uid, "n": me, "kind": "prop", "id": "call", "from": caller, "e": enemy, "icon": "x", "cat": "", "count": 2})
	main._after_change()
	for i in 40: await process_frame
	var rows2: Array = []; _walk(main, rows2, func(x): return x is TBAlertTicker.AlertRow and (x as TBAlertTicker.AlertRow).entry.get("id", "") == "call" and not (x as TBAlertTicker.AlertRow).done)
	_check(rows2.size() >= 1, "the second call shows (%d)" % rows2.size())
	if rows2.size() >= 1:
		var row2: TBAlertTicker.AlertRow = rows2[rows2.size() - 1]
		var got2: Array = []
		row2.answered.connect(func(uid: int, c: int): got2.append(c))
		var yc := Vector2(row2.size.x - 10.0 - d * 0.5, cy)
		_click(row2, yc)
		for i in 6: await process_frame
		_check(got2 == [0], "the tick answers 0: %s" % str(got2))
		_check(g.get_rel(me, enemy) == TBData.REL_WAR, "joining puts you at war with the enemy")
	print("CALL_TICK OK" if fails == 0 else "CALL_TICK FAIL %d" % fails)
	quit(fails)
