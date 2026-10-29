extends SceneTree
## Windows stay on the screen and can be resized by a finger. Usage: -s tests/win_fit.gd -- <w> <h> [pictures dir]   (TB_DPR / TB_DPI emulate a phone)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1
	else: print("  ok   ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(20)
	var vs: Vector2 = root.get_visible_rect().size
	print("stage ", vs)
	var shots := {"nations": func(): main._open_nations(fr), "budget": func(): main._open_budget(), "decrees": func(): main._open_decisions(), "council": func(): main._open_council(), "annals": func(): main._open_annals()}
	for k in shots:
		main._clear_overlay(); await _frames(4)
		(shots[k] as Callable).call(); await _frames(14)
		var hd: TBPanel.Handle = null
		for c in main._overlay.get_children():
			if c.has_meta("tb_handle") and (c.get_meta("tb_handle") as TBPanel.Handle).is_open(): hd = c.get_meta("tb_handle")
		if hd == null: print("  skip ", k, " (no window)"); continue
		var r: Rect2 = hd.card.get_global_rect()
		print("  ", k, " window ", r, " stage ", vs, " form ", hd.form, " dock ", hd.dock, " bz_pos ", hd.bz_pos, " top_y ", TBPanel._top_y(hd), " avail ", TBPanel.avail_h(hd), " local ", hd.card.position, " holder ", hd.holder.position, " root ", hd.root.global_position, " movable ", hd.movable, " user_pos ", hd.user_pos)
		_check(r.end.y <= vs.y - 6.0, "%s: the window's bottom edge (%.0f) is on the screen (%.0f)" % [k, r.end.y, vs.y])
		_check(r.end.x <= vs.x - 2.0 and r.position.x >= 0.0 and r.position.y >= 0.0, "%s: inside the screen horizontally and at the top" % k)
		if a.size() > 2: root.get_viewport().get_texture().get_image().save_png("%s/win_%s.png" % [a[2], k])
		if hd.movable:
			var hit := 0.0
			for rz in hd.resizers: hit = maxf(hit, minf((rz as Control).size.x, (rz as Control).size.y))
			var phys: float = hit * (root.get_viewport().get_final_transform().get_scale().x)
			print("    resize handle thickness ", hit, " units = ", snappedf(phys, 0.1), " px")
	print("WIN_FIT OK" if fails == 0 else "WIN_FIT FAIL %d" % fails)
	quit(fails)
