extends SceneTree
## B4: the battle report with both armies' bars (victory and defeat), the old layout without the new keys. Usage: -s tests/battle_ui.gd -- <out dir> (fixed fps 30, TB_NOANIM empty)
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
	var cases := [
		["win", {"win": true, "name": "Bas-Rhin", "claimed": true, "my_loss": 7150, "foe_loss": 14000, "left": 11250, "my0": 18400, "foe0": 14000, "me_n": me, "foe_n": aus, "g": main.g}],
		["loss", {"win": false, "name": "Bas-Rhin", "claimed": false, "my_loss": 9000, "foe_loss": 4100, "left": 5900, "my0": 9000, "foe0": 10000, "me_n": me, "foe_n": aus, "g": main.g}],
		["old", {"win": true, "name": "Bas-Rhin", "claimed": true, "my_loss": 12, "foe_loss": 20, "left": 30}]]
	for c in cases:
		var hd: TBPanel.Handle = TBModals.battle_report(main._overlay, c[1])
		var f := 0
		for k in [6, 18, 36, 60]:
			while f < k: await process_frame; f += 1
			root.get_viewport().get_texture().get_image().save_png("%s/battle_%s_%02d.png" % [out, c[0], k])
		_check(hd.is_open(), "the report is open (%s)" % c[0])
		hd.close()
		for i in 10: await process_frame
	main.cfg["fx"] = "off"; main._apply_a11y()
	var h2: TBPanel.Handle = TBModals.battle_report(main._overlay, cases[0][1])
	await process_frame
	_check(h2.is_open(), "Off: opens")
	h2.close()
	print("BATTLE_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
