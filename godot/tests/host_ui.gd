extends SceneTree
## Rules 5: the province ring has no Spread / Muster / General; the Host panel (F8) holds them, lists the armies and runs the orders. Usage: -s tests/host_ui.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
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
	g.gold[me] = 5e6; g.mp[me] = 10.0
	var cap: int = g.capital_of[me]
	main.map.jump_to(g.world.lon[cap], g.world.lat[cap], 4.0)
	for i in 10: await process_frame
	main._select(cap)
	for i in 20: await process_frame
	var ids: Array = []
	for v in main.panel._verbs: ids.append(String(v["id"]))
	print("capital ring: ", ids)
	_check(not ids.has("spread") and not ids.has("muster") and not ids.has("general"), "Spread, Muster and General are not in the province ring")
	_check(ids.has("move") and ids.has("raise") and ids.has("improve"), "the ring keeps Move, Raise troops and Improve")
	main._select(-1)
	for i in 6: await process_frame
	# the panel
	var d := TBHostPanel.data(g, me)
	_check((d["armies"] as Array).size() >= 1 and int(d["men"]) > 0, "the data lists the army (%d men)" % int(d["men"]))
	_check(bool(d["spread"]["ok"]), "Spread is open from the capital army")
	var hp := TBHostPanel.open(main._overlay, g, main._goto_province, func(c: Dictionary): main._on_command(c, false), func(pp: int): main._open_amount("disband", pp))
	for i in 10: await process_frame
	_check(hp != null and hp.is_open(), "the Host panel opens")
	if OS.get_environment("TB_SHOT") != "": root.get_viewport().get_texture().get_image().save_png(OS.get_environment("TB_SHOT") + "_host.png")
	var btns := _find(hp.body, func(x): return x is Button and String((x as Button).text).to_lower().begins_with("spread"))
	print("spread buttons: ", btns.size())
	var army0: int = g.army[cap]
	var spread_btn: Button = null
	for b in _find(hp.body, func(x): return x is Button): if String((b as Button).text).to_lower().contains("spread"): spread_btn = b
	if spread_btn == null:
		for b in _find(hp.body, func(x): return x is Button): print("button text: ", (b as Button).text)
	_check(spread_btn != null and not spread_btn.disabled, "the Spread button is there and open")
	if spread_btn != null: spread_btn.pressed.emit()
	for i in 10: await process_frame
	_check(g.army[cap] < army0, "Spread marched the army out (%d -> %d)" % [army0, g.army[cap]])
	# Disband from the panel: the card opens for the army and sends the command
	hp = TBHostPanel.open(main._overlay, g, main._goto_province, func(c: Dictionary): main._on_command(c, false), func(pp: int): main._open_amount("disband", pp))
	for i in 6: await process_frame
	var dis_btn: Button = null
	for b in _find(hp.body, func(x): return x is Button): if String((b as Button).text).to_lower().contains("disband"): dis_btn = b
	_check(dis_btn != null, "an army row has a Disband button")
	if dis_btn != null:
		dis_btn.pressed.emit()
		for i in 8: await process_frame
		var dcard: TBRecruitCard = main._amount_card
		_check(dcard != null and dcard.visible and dcard.kind == "disband", "Disband opens the amount card")
		g.mp[me] = 10.0
		var dp: int = dcard.p
		var a1: int = g.army[dp]
		dcard.picker.set_value(500); dcard._on_amount(500)
		dcard._confirm()
		for i in 6: await process_frame
		_check(g.army[dp] == a1 - 500, "500 men were disbanded (%d -> %d)" % [a1, g.army[dp]])
	# F8 opens and closes it
	main._overlay.get_children().map(func(c): if c.has_meta("tb_handle") and (c.get_meta("tb_handle") as TBPanel.Handle).is_open(): (c.get_meta("tb_handle") as TBPanel.Handle).close())
	for i in 6: await process_frame
	main.hud.host_pressed.emit()
	for i in 10: await process_frame
	var open_n := 0
	for c in main._overlay.get_children():
		if c.has_meta("tb_handle") and (c.get_meta("tb_handle") as TBPanel.Handle).is_open() and (c.get_meta("tb_handle") as TBPanel.Handle).mem_key == "host": open_n += 1
	_check(open_n == 1, "the HUD signal opens the Host panel (%d)" % open_n)
	print("HOST_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
