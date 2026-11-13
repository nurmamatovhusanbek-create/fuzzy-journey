extends SceneTree
## Loose ends before End Turn: the engine scan, then the card (Handle them / End turn anyway, once a turn, switchable). Usage: -s tests/loose.gd (TB_NOANIM=1, under xvfb)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _open_handles(main: Node) -> int:
	var n := 0
	for c in main._overlay.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tb_handle"): continue
		var h: TBPanel.Handle = c.get_meta("tb_handle")
		if h.is_open(): n += 1
	return n
func _init() -> void:
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	var items := TBLoose.scan(g, me)
	var ids: Array = []
	for it in items: ids.append(String(it["id"]))
	print("loose ends at the start: ", ids)
	_check(ids.has("spread_army"), "the whole army in the capital is a loose end")
	var g4 := TBGame.new(TBWorld.load_from("res://data"), TBWorld.load_era("res://data", "napoleonic"), {"seed": 3, "rules": 4})
	g4.set_human(g4.nat_code.find("france"))
	_check(TBLoose.scan(g4, g4.human_id).is_empty(), "rules 4: no loose ends (the check is a rules 5 feature)")
	# End turn raises the card, once
	var turn0: int = g.turn
	main.hud.end_turn_pressed.emit()
	for i in 10: await process_frame
	_check(_open_handles(main) == 1 and g.turn == turn0, "End turn shows the card and does not end the turn yet")
	# End turn anyway
	var btns: Array = []
	var stack: Array = [main._overlay]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and String((n as Button).text).to_lower().contains("anyway"): btns.append(n)
		for c in n.get_children(): stack.append(c)
	_check(btns.size() == 1, "the card has End turn anyway (%d)" % btns.size())
	if btns.size() == 1: (btns[0] as Button).pressed.emit()
	for i in 60: await process_frame
	_check(g.turn == turn0 + 1, "End turn anyway ends the turn (%d -> %d)" % [turn0, g.turn])
	# the setting switches it off
	main.cfg["turn_check"] = false
	var t1: int = g.turn
	main.hud.end_turn_pressed.emit()
	var lt0: int = main._loose_turn
	for i in 90: await process_frame
	_check(main._loose_turn == lt0 and g.turn == t1 + 1, "with the setting off the turn just ends (turn %d -> %d)" % [t1, g.turn])
	print("LOOSE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
