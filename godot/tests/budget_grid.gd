extends SceneTree
## Budget window alignment: the four policy rows share one grid (same icon, slider, value and stepper columns, same row height, even spacing). Usage: -s tests/budget_grid.gd -- <w> <h> <text scale> <lang>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _find(n: Node, out: Array) -> void:
	if n is TBBudgetRow: out.append(n)
	for c in n.get_children(): _find(c, out)
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
	main._open_budget()
	for i in 16: await process_frame
	var rows: Array = []
	_find(main._overlay, rows)
	_check(rows.size() == 4, "four policy rows (%d)" % rows.size())
	var r0: TBBudgetRow = rows[0]
	var s0: Rect2 = r0.slider.get_global_rect(); var v0: Rect2 = r0.val.get_global_rect()
	var wide: bool = absf(s0.position.y - r0.val.get_global_rect().position.y) < 40.0      # one line per policy; a narrow window stacks the slider under the name
	var pitch := 0.0
	for i in rows.size():
		var r: TBBudgetRow = rows[i]
		var sr: Rect2 = r.slider.get_global_rect(); var vr: Rect2 = r.val.get_global_rect(); var rr: Rect2 = r.get_global_rect()
		print("row %d  slider x %.0f..%.0f w %.0f  value right %.0f  row y %.0f h %.0f" % [i, sr.position.x, sr.end.x, sr.size.x, vr.end.x, rr.position.y, rr.size.y])
		_check(absf(sr.position.x - s0.position.x) <= 1.0 and absf(sr.end.x - s0.end.x) <= 1.0, "row %d: slider columns differ (%.0f..%.0f vs %.0f..%.0f)" % [i, sr.position.x, sr.end.x, s0.position.x, s0.end.x])
		_check(absf(vr.end.x - v0.end.x) <= 1.0, "row %d: value right edge %.0f vs %.0f" % [i, vr.end.x, v0.end.x])
		_check(absf(sr.get_center().y - vr.get_center().y) <= 14.0 or not wide, "row %d: slider and value are on one line" % i)
		if i > 0:
			var step: float = rr.position.y - (rows[i - 1] as TBBudgetRow).get_global_rect().position.y
			if pitch == 0.0: pitch = step
			if wide: _check(absf(step - pitch) <= 2.0, "row %d: spacing %.0f vs %.0f" % [i, step, pitch])
		var win: Rect2 = r.get_viewport().get_visible_rect()
		_check(rr.end.x <= win.size.x + 1.0 and sr.end.x <= win.size.x + 1.0, "row %d is inside the screen" % i)
	print("BUDGET_GRID OK" if fails == 0 else "BUDGET_GRID FAIL %d" % fails)
	quit(fails)
