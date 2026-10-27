extends SceneTree
## A3: the title's ring as the era picker: open, click another era on the ring, arrow keys, Back, Pick a nation; the classic dialog with era_ui = classic; Off jumps. Usage: -s tests/era_ring.gd -- <out dir> (fixed fps 30)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _buttons(n: Node, out: Array) -> void:
	if n is Button: out.append(n)
	for c in n.get_children(): _buttons(c, out)
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "medium"; main.cfg["fx"] = "full"; main.cfg["era_ui"] = "ring"; main.cfg["era"] = "napoleonic"
	main._apply_a11y(); main._update_ui_scale()
	DirAccess.remove_absolute(TBSave.path_for("auto"))
	main.show_menu()
	for i in 20: await process_frame
	_check(main._title_wide, "the title is in the wide layout")
	main._open_era_picker()
	for i in 24: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/era_1_open.png" % out)
	var hd: TBPanel.Handle = TBPanel.top(main._overlay)
	_check(hd != null and hd.form == "page", "the ring screen is the top handle")
	var orr: TBTitleParts.Orrery = main._bezel
	_check(orr.interactive and orr.cur_era == "napoleonic", "the ring is interactive, Napoleonic at the top")
	# click another era
	orr.era_clicked.emit("coldwar")
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/era_2_turning.png" % out)
	for i in 20: await process_frame
	_check(orr.cur_era == "coldwar", "clicking an era turns the ring to it")
	root.get_viewport().get_texture().get_image().save_png("%s/era_3_coldwar.png" % out)
	# arrow key
	var ev := InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_RIGHT
	Input.parse_input_event(ev)
	for i in 3: await process_frame
	_check(orr.cur_era == "modern", "the right arrow steps to the next era (%s)" % orr.cur_era)
	# Back (Esc) returns to the title
	main._on_back()
	for i in 20: await process_frame
	_check(TBPanel.top(main._overlay) == null and main.mode == "menu", "Back closes the ring screen")
	orr = main._bezel
	_check(not orr.interactive and main.map.offset_left == 0.0, "the title is restored (globe back in the middle)")
	root.get_viewport().get_texture().get_image().save_png("%s/era_4_back.png" % out)
	# Pick a nation
	main._open_era_picker()
	for i in 20: await process_frame
	var bs: Array = []
	_buttons(TBPanel.top(main._overlay).root, bs)
	var go: Button = null
	for b in bs: if TBKit.a11y_text(b).to_lower().contains(TBI18n.T("pick_nation_btn").to_lower()): go = b
	_check(go != null, "the Pick a nation button exists")
	if go != null: go.pressed.emit()
	for i in 10: await process_frame
	_check(main.mode == "pick", "Pick a nation starts the nation pick (mode %s)" % main.mode)
	# classic
	main.show_menu(); main.cfg["era_ui"] = "classic"
	for i in 10: await process_frame
	main._open_era_picker()
	for i in 10: await process_frame
	var top2: TBPanel.Handle = TBPanel.top(main._overlay)
	_check(top2 != null and top2.form != "page", "era_ui classic opens the dialog")
	print("ERA_RING ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
