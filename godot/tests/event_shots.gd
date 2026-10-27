extends SceneTree
## B2: the event prompt with its class band: an ultimatum (strength bar), a plague (crisis, rust), a royal wedding (diplomacy, blue). Usage: -s tests/event_shots.gd -- <out dir> (fixed fps 30)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
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
	main.map.jump_to(6.0, 47.0, 3.0)
	var me: int = main.g.human_id
	var aus: int = main.g.nat_code.find("austrian_empire")
	var prov: int = main.g.owned(me)[0]
	var evs := [
		{"uid": 1, "n": me, "kind": "prop", "id": "ultimatum", "from": aus, "p": prov, "count": 2},
		{"uid": 2, "n": me, "kind": "rand", "id": "plague", "icon": "☠", "cat": "CRISIS", "count": 2},
		{"uid": 3, "n": me, "kind": "rand", "id": "royal_wedding", "icon": "💍", "cat": "DIPLOMACY", "count": 2}]
	var i := 0
	for e in evs:
		var hd: TBPanel.Handle = TBModals.event_prompt(main._overlay, e, func(_i): pass, main.g, func(): pass)
		for k in 20: await process_frame
		_check(hd.is_open() and hd.stage.is_empty(), "the prompt is up and staged (%d)" % i)
		root.get_viewport().get_texture().get_image().save_png("%s/event_%d.png" % [out, i])
		hd.close()
		for k in 12: await process_frame
		i += 1
	print("EVENT_SHOTS ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
