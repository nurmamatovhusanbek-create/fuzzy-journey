extends SceneTree
## The Realm page lists the institutions that exist (with shares and an Embrace button); pressing it embraces. Usage: -s tests/institutions_ui.gd -- <out dir> (TB_NOANIM=1)
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
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	g.gold[me] = 1e9; g.mp[me] = 10.0
	var ind := TBInstitutions.index_of("industry")
	for p in g.owned(me): g.inst[p] |= (1 << ind)
	for i in 20: await process_frame
	main._open_realm_page()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/inst_0.png" % out)
	for sc in _find(main._overlay, func(x): return x is ScrollContainer): (sc as ScrollContainer).scroll_vertical = 360
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/inst_1.png" % out)
	var btns := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower().begins_with("embrace") and not (x as Button).disabled)
	print("open embrace buttons: ", btns.size())
	_check(btns.size() >= 1, "an Embrace button is open for an institution that spread over our land")
	var n0 := 0
	for i in TBInstitutions.count(): if TBInstitutions.embraced(g, me, i): n0 += 1
	if btns.size() >= 1: (btns[0] as Button).pressed.emit()
	for i in 10: await process_frame
	var n1 := 0
	for i in TBInstitutions.count(): if TBInstitutions.embraced(g, me, i): n1 += 1
	_check(n1 == n0 + 1, "pressing it embraces (%d -> %d)" % [n0, n1])
	print("INSTITUTIONS_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
