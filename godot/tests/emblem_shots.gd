extends SceneTree
## diagnostic: screens that carry icons, as pictures. Usage: -s tests/emblem_shots.gd -- <out dir> [icons mode]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	if a.size() > 1: main.cfg["icons"] = a[1]
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	var shots := {"budget": "_open_budget", "nations": "_open_nations", "council": "_open_council", "realm": "_open_realm_page"}
	for k in shots:
		main.call(shots[k]); for i in 25: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/emb_%s.png" % [out, k])
		main._clear_overlay(); for i in 5: await process_frame
	var cap := g.capital_of[g.human_id]
	main.map.jump_to(g.world.lon[cap], g.world.lat[cap], 6.0); for i in 10: await process_frame
	main._select(cap); for i in 25: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/emb_province.png" % out)
	print("EMBLEM_SHOTS ok")
	quit(0)
