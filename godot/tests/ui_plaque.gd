extends SceneTree
## army standards at several zoom levels (set TB_PLAQUE=0/1 to compare styles). Usage: -- <outdir> <tag>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en")
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	var cap: int = main.g.capital_of[fr]
	for z in [1.6, 3.0, 6.0, 12.0]:
		main.map.fly_to(main.world.lon[cap] + 4.0, main.world.lat[cap] + 2.0, z)
		for i in 10: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/pl_%s_%d.png" % [a[0], a[1], int(z * 10)])
	quit(0)
