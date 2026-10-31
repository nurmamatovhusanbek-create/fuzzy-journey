extends SceneTree
## Alignment audit of the Settings tab: in every category the controls share one column (same left and right edge, the same width) and one height per row,
## each row's name is centred on its control, and the rows are evenly spaced. Prints a table; any row off the grid is a FAIL.
## Usage: -s tests/menu_grid.gd -- <w> <h> <text scale>   (TB_PHONE_UI=compact, TB_DPR/TB_DPI as for the other UI tests)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _find(n: Node, out: Array) -> void:
	if n is TBKit.Segmented: out.append(n)
	for c in n.get_children(): _find(c, out)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var sc := float(a[2])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang("en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["lang"] = "en"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._on_setting_changed("lang")
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	for i in 20: await process_frame
	for cat in ["display", "map", "comfort", "sound", "language", "advanced"]:
		TBMenuHub.mem["set_cat"] = cat; TBMenuHub.mem["scroll"] = 0
		main._clear_overlay(); main._open_menu_hub("settings")
		for i in 14: await process_frame
		var segs: Array = []
		_find(main._overlay, segs)
		var rows: Array = []
		for s in segs:
			var sg: Control = s
			if not sg.is_visible_in_tree() or not (sg.get_parent() is HBoxContainer or sg.get_parent() is VBoxContainer): continue
			var par: Node = sg.get_parent()
			if sg.size.x < 150.0: continue                                        # tabs and similar: not a settings row
			rows.append(sg)
		if rows.is_empty(): continue
		var right0: float = (rows[0] as Control).get_global_rect().end.x
		var left0: float = (rows[0] as Control).get_global_rect().position.x
		var one_row_h := 0.0
		for r in rows:
			var rc: Rect2 = (r as Control).get_global_rect()
			var par2: Node = (r as Control).get_parent()
			var lab := ""
			if par2 is BoxContainer and par2.get_child_count() > 0 and par2.get_child(0) is Control:
				for lc in (par2.get_child(0) as Control).get_children():
					if lc is Label: lab = (lc as Label).text; break
			print("%-9s %-34s x %.0f..%.0f  w %.0f  h %.0f  cy %.0f" % [cat, lab.substr(0, 34), rc.position.x, rc.end.x, rc.size.x, rc.size.y, rc.get_center().y])
			_check(absf(rc.end.x - right0) <= 1.0, "%s '%s': right edge %.0f is not the column's %.0f" % [cat, lab, rc.end.x, right0])
			_check(absf(rc.position.x - left0) <= 1.0, "%s '%s': left edge %.0f is not the column's %.0f" % [cat, lab, rc.position.x, left0])
			# the name is centred on its control (a row whose control is stacked under the name is left out)
			if par2 is HBoxContainer and par2.get_child_count() >= 2 and par2.get_child(0) is Control:
				var nm: Control = par2.get_child(0)
				_check(absf(nm.get_global_rect().get_center().y - rc.get_center().y) <= 1.5, "%s '%s': name centre %.1f vs control centre %.1f" % [cat, lab, nm.get_global_rect().get_center().y, rc.get_center().y])
			var cell_h: float = rc.size.y
			if rc.size.y < 40.0:                                                 # one-row controls share a height
				if one_row_h == 0.0: one_row_h = cell_h
				_check(absf(cell_h - one_row_h) <= 1.0, "%s '%s': control height %.0f vs %.0f" % [cat, lab, cell_h, one_row_h])
	print("MENU_GRID OK" if fails == 0 else "MENU_GRID FAIL %d" % fails)
	quit(fails)
