extends SceneTree
## B7: the game-over finale (victory and defeat), its sequence, the two buttons, Effects Off. Usage: -s tests/finale.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, cls: String) -> Array:
	var out: Array = []
	if n.get_class() == cls or (n.get_script() != null and n.get_script().get_global_name() == cls): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, cls))
	return out
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "medium"; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for t in 8: main.g.end_turn()
	main.g.pending.clear()
	var me: int = main.g.human_id
	var menu_hit := [false]
	for case in ["won", "lost"]:
		main.g.over = true; main.g.winner = me if case == "won" else main.g.nat_code.find("russian_empire"); main.g.victory_kind = "domination" if case == "won" else ""
		var hd: TBPanel.Handle = TBModals.game_over(main._overlay, main.g, func(): menu_hit[0] = true)
		for k in [2, 20, 50, 90, 120]:
			for i in (k if k == 2 else 0): await process_frame
		var f := 2
		for k in [20, 50, 90, 125]:
			while f < k: await process_frame; f += 1
			root.get_viewport().get_texture().get_image().save_png("%s/finale_%s_%03d.png" % [out, case, k])
		_check(hd.is_open() and not hd.dismissable, "the finale is up and locked (%s)" % case)
		_check(TBPanel.top(main._overlay) == hd, "it is the top modal (%s)" % case)
		var menu_btn: Button = hd.focus_target as Button
		if case == "won":
			menu_btn.pressed.emit()
			await process_frame
			_check(menu_hit[0], "Main menu calls back")
		else:
			hd.close()
			for i in 12: await process_frame
	# Off: complete at once
	main.cfg["fx"] = "off"; main._apply_a11y()
	main.g.winner = me
	var h3: TBPanel.Handle = TBModals.game_over(main._overlay, main.g, func(): pass)
	await process_frame
	var any_hidden := false
	for c in _find(h3.root, "Label"): if (c as CanvasItem).get_parent() != null and (c as CanvasItem).modulate.a < 0.99 and (c as CanvasItem).is_visible_in_tree(): any_hidden = true
	_check(not any_hidden and h3.root.modulate.a > 0.99, "Off: complete in the opening frame")
	h3.close()
	print("FINALE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
