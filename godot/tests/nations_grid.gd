extends SceneTree
## Nations window: the diplomacy actions form one grid (equal widths per column, one height, even gaps, the war button spanning both columns at the same height). Usage: -s tests/nations_grid.gd -- <w> <h> <text scale> <lang> [out png]
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _acts(n: Node, out: Array) -> void:
	if n is GridContainer and n.get_child_count() >= 2 and n.get_child(0) is TBBz.Btn: out.append(n)
	for c in n.get_children(): _acts(c, out)
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
	main.g.gold[main.g.human_id] = 500.0; main.g.dp[main.g.human_id] = 8.0
	main._open_nations(main.g.nat_code.find("spain"))
	for i in 20: await process_frame
	var grids: Array = []
	_acts(main._overlay, grids)
	_check(grids.size() >= 1, "the diplomacy grid was found (%d)" % grids.size())
	if grids.size() >= 1:
		var gr: GridContainer = grids[0]
		var btns: Array = []
		for c in gr.get_children(): if c is Control and (c as Control).visible: btns.append(c)
		var r0: Rect2 = (btns[0] as Control).get_global_rect()
		for i in btns.size():
			var r: Rect2 = (btns[i] as Control).get_global_rect()
			print("btn %d  x %.0f..%.0f w %.0f  y %.0f h %.0f" % [i, r.position.x, r.end.x, r.size.x, r.position.y, r.size.y])
			_check(absf(r.size.y - r0.size.y) <= 1.0, "button %d height %.0f vs %.0f" % [i, r.size.y, r0.size.y])
			_check(absf(r.size.x - r0.size.x) <= 1.5, "button %d width %.0f vs %.0f" % [i, r.size.x, r0.size.x])
			var col: int = i % gr.columns
			var first_in_col: Rect2 = (btns[col] as Control).get_global_rect()
			_check(absf(r.position.x - first_in_col.position.x) <= 1.0, "button %d is off its column (x %.0f vs %.0f)" % [i, r.position.x, first_in_col.position.x])
		# the war button lines up with the grid's left and right edges
		var gr_rect: Rect2 = gr.get_global_rect()
		var wars: Array = []
		var p: Node = gr.get_parent()
		for c in p.get_children():
			var bs: Array = []
			_wars(c, bs)
			wars.append_array(bs)
		for wb in wars:
			var wr: Rect2 = (wb as Control).get_global_rect()
			_check(absf(wr.position.x - gr_rect.position.x) <= 2.0 and absf(wr.end.x - gr_rect.end.x) <= 2.0, "the war button (x %.0f..%.0f) does not span the grid (%.0f..%.0f)" % [wr.position.x, wr.end.x, gr_rect.position.x, gr_rect.end.x])
	if a.size() > 4: root.get_viewport().get_texture().get_image().save_png(a[4])
	print("NATIONS_GRID OK" if fails == 0 else "NATIONS_GRID FAIL %d" % fails)
	quit(fails)
func _wars(n: Node, out: Array) -> void:
	if n is TBBz.Btn and (n as TBBz.Btn).variant == TBBz.V.DNG: out.append(n)
	for c in n.get_children(): _wars(c, out)
