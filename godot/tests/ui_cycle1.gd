extends SceneTree
## UI cycle 1: the Nations list lights a country's border on the map while a row is hovered and goes back to the pinned one; the Council groups matters by minister with a severity bar;
## the Raise bar keeps its text in at most two lines. Usage: -s tests/ui_cycle1.gd (xvfb, TB_NOANIM=1)
const K = preload("res://src/ui/ui_kit.gd")
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080)); root.size = Vector2i(1920, 1080)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"; main.cfg["fx"] = "off"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	for i in 12: g.end_turn(); g.pending.clear()
	g.gold[g.human_id] = 1e9
	main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	# ---- nations: hover lights the border, leaving restores the pinned one
	main._open_nations(-1)
	for i in 20: await process_frame
	var rows := _find(main._overlay, func(x): return x is TBNationsScreen.NationRow)
	_check(rows.size() > 5, "the list has its rows (%d)" % rows.size())
	var r: TBNationsScreen.NationRow = rows[3]
	var pinned: int = main._pinned_outline
	r.hovered.emit(r.n)
	_check(main.map._outline_owner == r.n, "hovering a row outlines its country (%d)" % main.map._outline_owner)
	r.hovered.emit(-1)
	_check(main.map._outline_owner == pinned, "leaving it restores the pinned outline (%d vs %d)" % [main.map._outline_owner, pinned])
	main._clear_overlay()
	# ---- outliner: hovering a row lights its province on the map, leaving puts it out
	var capp: int = g.capital_of[g.human_id]
	g.proj_kind[capp] = 1; g.proj_left[capp] = 3                              # something under way, so the list has a row
	main.hud.outliner_pressed.emit()
	for i in 20: await process_frame
	var orows := _find(main._overlay, func(x): return x is K.ListRow)
	_check(orows.size() >= 1, "the Outliner has rows (%d)" % orows.size())
	if orows.size() >= 1:
		(orows[0] as Control).mouse_entered.emit()
		_check(main.map.hover >= 0, "hovering an Outliner row lights a province (%d)" % main.map.hover)
		(orows[0] as Control).mouse_exited.emit()
		_check(main.map.hover == -1, "leaving the row puts it out (%d)" % main.map.hover)
	main._clear_overlay()
	# ---- council: one heading per minister
	main._open_council()
	for i in 20: await process_frame
	var al := TBAlertPrefs.filter(TBAdvisor.alerts(g, g.human_id))
	var mins := {}
	for a in al: mins[String((TBModals.MINISTERS.get(String(a["id"]), ["info", "min_police", "", ""]) as Array)[1])] = true
	var groups := _find(main._overlay, func(x): return x is VBoxContainer and (x as VBoxContainer).get_child_count() >= 2 and (x.get_child(0) is MarginContainer) and x.get_parent() is VBoxContainer and (x.get_parent() as VBoxContainer).get_child_count() == mins.size() or false)
	var bars := _find(main._overlay, func(x): return x is PanelContainer and (x as PanelContainer).get_theme_stylebox("panel") is StyleBoxFlat and ((x as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 3)
	_check(bars.size() == al.size(), "every matter has its severity bar (%d bars, %d matters)" % [bars.size(), al.size()])
	_check(not groups.is_empty() or mins.size() <= 1, "the matters are grouped under %d ministers" % mins.size())
	main._clear_overlay()
	# ---- raise bar: the text column is wide enough for two lines
	var cp: int = g.capital_of[g.human_id]
	main._select(cp); main._open_amount("raise", cp)
	for i in 25: await process_frame
	var cards := _find(main, func(x): return x is TBRecruitCard and (x as TBRecruitCard).visible)
	_check(cards.size() == 1, "the Raise bar is open")
	if cards.size() == 1:
		var c: TBRecruitCard = cards[0]
		_check(c._split.get_line_count() <= 2, "its explanation sits in at most two lines (%d)" % c._split.get_line_count())
	print("UI_CYCLE1 ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
