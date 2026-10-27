extends SceneTree
## B3: the war declaration card, the seal, the "War" moment. Usage: -s tests/war_moment.gd -- <out dir>   (run with --fixed-fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find_seal(n: Node) -> Node:
	if n is TBWarParts.Seal: return n
	for c in n.get_children():
		var r := _find_seal(c)
		if r != null: return r
	return null
func _moments(main: Node) -> int:
	var k := 0
	for c in main._overlay.get_children(): if c is TBWarParts.Moment and not c.is_queued_for_deletion(): k += 1
	return k

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "medium"; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.g.dp[main.g.human_id] = 20.0
	var me: int = main.g.human_id
	var aus: int = main.g.nat_code.find("austrian_empire")
	main.map.jump_to(6.0, 47.0, 3.0)
	for fx in ["full", "off"]:
		main.cfg["fx"] = fx; main._apply_a11y()
		for i in 20: await process_frame
		var hd: TBPanel.Handle = TBModals.war_confirm(main._overlay, main.g, aus, func(): main.g.set_rel(me, aus, TBData.REL_WAR) if main.g.has_method("set_rel") else null)
		for i in 14: await process_frame
		var seal: Node = _find_seal(hd.root)
		_check(seal != null, "the seal is in the card (%s)" % fx)
		if fx == "full":
			root.get_viewport().get_texture().get_image().save_png("%s/war_1_rest.png" % out)
			seal.progress.emit(0.6)
			await process_frame; await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/war_2_hold.png" % out)
		seal.progress.emit(0.0)
		var fired := [false]
		seal.confirmed.connect(func(): fired[0] = true)
		seal.confirmed.emit()
		await process_frame
		_check(fired[0], "confirmed fires (%s)" % fx)
		_check(not hd.is_open(), "the card is closed (%s)" % fx)
		if fx == "full":
			var shots := {6: "war_3_a", 14: "war_3_b", 24: "war_3_c", 40: "war_3_d"}
			var f := 1
			_check(_moments(main) == 1, "the War moment plays (Full)")
			for k in [6, 14, 24, 40]:
				while f < k: await process_frame; f += 1
				root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, shots[k]])
			for i in 50: await process_frame
			_check(_moments(main) == 0, "the moment ends by itself")
			# skip
			var hd2: TBPanel.Handle = TBModals.war_confirm(main._overlay, main.g, aus, func(): pass)
			for i in 10: await process_frame
			_find_seal(hd2.root).confirmed.emit()
			await process_frame; await process_frame
			_check(_moments(main) == 1, "second moment")
			var ev := InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_SPACE
			for c in main._overlay.get_children(): if c is TBWarParts.Moment: c._gui_input(ev)
			await process_frame; await process_frame
			_check(_moments(main) == 0, "a key skips the moment")
		else:
			_check(_moments(main) == 0, "Off: no moment")
	print("WAR_MOMENT ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
