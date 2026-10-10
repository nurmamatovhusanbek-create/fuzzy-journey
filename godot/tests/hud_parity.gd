extends SceneTree
## HUD parity extras (the states tests/parity.gd cannot show): notices and toasts, a hovered rail button and gauge, a tooltip, the lens popover.
## Usage: -s tests/hud_parity.gd -- <outdir> <w> <h> [state,...]      states: notice hover hoverg tip lens
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var w: int = int(a[1]); var h: int = int(a[2])
	var states: PackedStringArray = (a[3] if a.size() > 3 else "notice,hover,hoverg,tip").split(",")
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main._update_ui_scale()
	for i in 8: await process_frame
	main.map.fly_to(8.0, 47.0, 2.0)
	for i in 30: await process_frame
	var hud: TBHud = main.hud
	for s in states:
		main._clear_overlay(); main._select(-1)
		hud.dismiss_floating()
		match s:
			"notice":
				var e1 := {"key": "a:war", "cls": "war", "sev": 2, "id": "war", "p": 0, "n": 0, "k": 1, "uid": -1, "ps": [0], "ult": false, "text": "Austria masses troops on your border", "tip": ["War", "x"]}
				var e2 := {"key": "o:1", "cls": "offer", "sev": 1, "id": "nap", "p": -1, "n": 2, "k": 0, "uid": 1, "ps": [], "ult": false, "text": "Spain proposes a pact", "tip": ["Offer", "x"]}
				hud._ticker.update([e1, e2], main.g.turn)
				hud._ticker.show_info("Map lens: Political", "info", 60.0)
			"hover":
				var rb: TBHudParts.IconBtn = hud._dock[0]
				rb.hover = true; rb.queue_redraw()
			"hoverg":
				var gc: TBHudParts.Chip = hud._chips["gold"]
				gc.hover = true; gc.queue_redraw()
			"tip":
				hud._tip_show(hud._chips["gold"], hud._chip_text("gold"))
			"lens":
				hud._open_lens_pop(hud._lens_btn)
		for i in 14: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/gd_%s.png" % [dir, s])
		print("shot ", s, " logical ", root.content_scale_size)
		(hud._dock[0] as TBHudParts.IconBtn).hover = false
		(hud._chips["gold"] as TBHudParts.Chip).hover = false
	quit(0)
