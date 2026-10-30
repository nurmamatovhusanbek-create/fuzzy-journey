extends SceneTree
const K = preload("res://src/ui/ui_kit.gd")
## The announcement dialogs: each one fits the screen, its medallion, title, rule and buttons sit on the card's axis, and nothing is cut. Usage: -s tests/dialogs_shot.gd -- <w> <h> <out dir> [expect]
var fails := 0
func _check(c: bool, what: String) -> void:
	if c: print("  ok   ", what)
	else: fails += 1; print("  FAIL ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _find_all(n: Node, pred: Callable, out: Array) -> void:
	if pred.call(n): out.append(n)
	for k in n.get_children(): _find_all(k, pred, out)

func _audit(name: String, h: TBPanel.Handle, vs: Vector2) -> void:
	await _frames(14)
	var r: Rect2 = h.card.get_global_rect()
	var cx: float = r.position.x + r.size.x * 0.5
	_check(r.position.x >= 0.0 and r.end.x <= vs.x and r.position.y >= 0.0 and r.end.y <= vs.y, "%s: the card is inside the screen (%s of %s)" % [name, str(r), str(vs)])
	if not h.announce: return
	var rings: Array = []
	_find_all(h.head, func(n: Node) -> bool: return n is TBKit.RingIcon, rings)
	if not rings.is_empty():
		var rr: Rect2 = (rings[0] as Control).get_global_rect()
		_check(absf((rr.position.x + rr.size.x * 0.5) - cx) <= 1.5, "%s: the medallion is on the card's axis (%.1f px off)" % [name, (rr.position.x + rr.size.x * 0.5) - cx])
	var tl: Control = h.title_label
	var tr: Rect2 = tl.get_global_rect()
	_check(absf((tr.position.x + tr.size.x * 0.5) - cx) <= 1.5, "%s: the title's box is centred (%.1f px off)" % [name, (tr.position.x + tr.size.x * 0.5) - cx])
	if h.footer.get_child_count() > 0:
		var l := 1.0e9; var rt := -1.0e9
		for b in h.footer.get_children():
			if b is Control and (b as Control).visible:
				var br: Rect2 = (b as Control).get_global_rect(); l = minf(l, br.position.x); rt = maxf(rt, br.end.x)
		_check(absf((l + rt) * 0.5 - cx) <= 2.0, "%s: the buttons sit on the axis (%.1f px off)" % [name, (l + rt) * 0.5 - cx])
	if h.scroll != null:
		var sb: VScrollBar = h.scroll.get_v_scroll_bar()
		_check(not sb.visible or sb.max_value <= sb.page + 1.0, "%s: nothing is cut off (no scroll needed)" % name)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var hgt := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, hgt)); root.size = Vector2i(w, hgt)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = a[3] if a.size() > 3 and a[3] != "expect" else "en"; TBI18n.load_lang(main.cfg["lang"]); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france"); var sp: int = main.g.nat_code.find("spain")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(20)
	var vs: Vector2 = main._overlay.size
	var out: String = a[2]
	var shots := {}
	# 1. Multiplayer coming soon
	main._multiplayer_entry(); await _frames(4)
	var h1: TBPanel.Handle = TBPanel.top(main._overlay)
	await _audit("coming soon", h1, vs); root.get_viewport().get_texture().get_image().save_png(out + "/dlg_comingsoon.png"); h1.close(); await _frames(4)
	# 2. a confirmation (break the alliance)
	var h2 := TBPanel.confirm(main._overlay, TBI18n.T("confirm_break_t", {"a": main.g.dname(sp)}), TBI18n.T("confirm_break_b"), TBI18n.T("break_pact"), func(): pass, true, "warning", "",
		TBPanel.fact_row("warn", TBI18n.T("break_costs_h"), TBI18n.T("break_costs", {"a": main.g.dname(sp), "inf": 6}), "warn", K.is_phone(main._overlay)))
	await _audit("confirm", h2, vs); root.get_viewport().get_texture().get_image().save_png(out + "/dlg_confirm.png"); h2.close(); await _frames(4)
	# 3. war declaration
	var h3 := TBModals.war_confirm(main._overlay, main.g, sp, func(): pass)
	await _audit("war", h3, vs); root.get_viewport().get_texture().get_image().save_png(out + "/dlg_war.png"); h3.close(); await _frames(4)
	# 4. the tutorial
	var h4 := TBModals.tutorial(main._overlay, func(): pass)
	await _audit("tutorial", h4, vs); root.get_viewport().get_texture().get_image().save_png(out + "/dlg_tutorial.png"); h4.close(); await _frames(4)
	# 5. comfort and access
	var h5 := TBMenuHub.comfort(main._overlay, main.cfg, func(_k): pass)
	await _audit("comfort", h5, vs); root.get_viewport().get_texture().get_image().save_png(out + "/dlg_comfort.png"); h5.close(); await _frames(4)
	var expect: bool = a.size() > 0 and a[a.size() - 1] == "expect"
	print("DIALOGS OK" if fails == 0 else "DIALOGS FAIL %d" % fails)
	quit(1 if (expect and fails > 0) else 0)
