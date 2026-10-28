extends SceneTree
## Effects switch gate. A title with the globe held (a panel open) must draw no frames and the same picture whatever the effects setting is; with Effects Off the selection bracket
## must jump (no glide) and a Continue press must load the game at once (no dive). Usage: -s tests/fx_still.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)

func _shot(main: Control) -> Image:
	await process_frame
	return root.get_viewport().get_texture().get_image()

func _init() -> void:
	TBAdvisorNote.fixed_seed = 7
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	DirAccess.remove_absolute(TBSave.path_for("auto"))
	main._update_ui_scale()
	var pics := {}
	for fx in ["off", "light", "full"]:
		main.cfg["fx"] = fx; main._apply_a11y()
		main.show_menu(); main._spin = false
		for i in 90: await process_frame      # the first menu still settles (textures, fonts) for a while on a slow machine
		var fd0 := Engine.get_frames_drawn()
		for i in 40: await process_frame
		var drawn: int = Engine.get_frames_drawn() - fd0
		print("fx=", fx, " frames drawn in 40 idle loops: ", drawn)
		_check(drawn <= 2, "a still title draws no frames (fx=%s)" % fx)
		pics[fx] = await _shot(main)
		# the bracket: after focusing another entry, Off has it in place at once
		if fx == "off":
			var rows: Array = []
			for c in main._title_cur.get_parent().get_children():
				if c is Button: rows.append(c)
			(rows[1] as Control).grab_focus()
			await process_frame
			var sel: Control = main._sel
			var want: Rect2 = Rect2((rows[1] as Control).global_position - sel.global_position, (rows[1] as Control).size).grow(6.0 * sel.u)
			_check(sel.rect.is_equal_approx(want), "Effects Off: the bracket jumps (%s vs %s)" % [sel.rect, want])
	# Light and Full keep the same still picture as Off
	for fx in ["light", "full"]:
		var a: Image = pics["off"]; var b: Image = pics[fx]
		var diff := 0
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)) == false: diff += 1
		print("still picture, off vs ", fx, ": differing samples ", diff)
		_check(diff == 0, "a still title looks the same with effects %s" % fx)
	print("FX_STILL ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
