extends SceneTree
## The Realm page lists the four estates with a Court button; pressing it grants the privilege and rebuilds the page in place. Usage: -s tests/estates_ui.gd -- <out dir> (TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 800)); root.size = Vector2i(1280, 800)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"; main.cfg["fx"] = "off"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	g.gold[me] = 1e9; g.mp[me] = 10.0
	for i in 20: await process_frame
	main._open_realm_page()
	for i in 20: await process_frame
	var courts := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower().begins_with("court") and not (x as Button).disabled)
	print("open Court buttons: ", courts.size())
	_check(courts.size() == 4, "four estates, four Court buttons")
	var why := _find(main._overlay, func(x): return x is Control and String((x as Control).tooltip_text).begins_with("Drifting toward"))
	_check(why.size() == 4, "every estate row says why its loyalty moves (%d of 4)" % why.size())
	if why.size() > 0: print("tooltip: ", String((why[0] as Control).tooltip_text).replace("\n", " | "))
	for sc in _find(main._overlay, func(x): return x is ScrollContainer): (sc as ScrollContainer).scroll_vertical = 500
	for i in 6: await process_frame
	var sv0 := 0
	for sc in _find(main._overlay, func(x): return x is ScrollContainer): sv0 = (sc as ScrollContainer).scroll_vertical; break
	root.get_viewport().get_texture().get_image().save_png("%s/est_0.png" % out)
	var l0 := TBEstates.loyalty(g, me, 2)
	(courts[2] as Button).pressed.emit()
	for i in 20: await process_frame
	_check(TBEstates.privileges(g, me, 2) == 1 and TBEstates.loyalty(g, me, 2) > l0, "pressing Court grants the privilege and pleases the estate")
	var open_realm := 0
	for c in main._overlay.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tb_handle"): continue
		if (c.get_meta("tb_handle") as TBPanel.Handle).mem_key == "realm": open_realm += 1
	_check(open_realm == 1, "the Realm page is still open, once (%d)" % open_realm)
	var sv1 := 0
	for sc in _find(main._overlay, func(x): return x is ScrollContainer): sv1 = (sc as ScrollContainer).scroll_vertical; break
	_check(absi(sv1 - sv0) <= 4, "and it stayed where it was scrolled (%d -> %d)" % [sv0, sv1])
	root.get_viewport().get_texture().get_image().save_png("%s/est_1.png" % out)
	print("ESTATES_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
