extends SceneTree
## Bezel parity shots: the same France-1804 states the HTML demo shows (docs/ui_variants/shoot_bezel.mjs), at the same window size.
## Usage: -s tests/parity.gd -- <outdir> <w> <h> [state,...]      states: map nations budget decrees council annals goals menu select
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var w: int = int(a[1]); var h: int = int(a[2])
	var states: PackedStringArray = (a[3] if a.size() > 3 else "map,nations,budget,decrees,council,annals,goals,menu").split(",")
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
	main.map.fly_to(8.0, 47.0, 2.0)                       # Europe, like the demo's framing
	for i in 30: await process_frame
	for s in states:
		main._clear_overlay(); main._select(-1)
		match s:
			"nations": main._open_nations()
			"budget": main._open_budget()
			"decrees": main._open_decisions()
			"council": main._open_council()
			"annals": main._open_annals()
			"goals": main._open_council("goals")
			"menu": main._open_menu_hub("")
			"select":
				for p in main.g.P:
					if main.world.name[p] == "Bas-Rhin": main._select(p)
		for i in 14: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/gd_%s.png" % [dir, s])
		print("shot ", s, " logical ", root.content_scale_size)
	quit(0)
