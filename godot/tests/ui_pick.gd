extends SceneTree
## nation-pick screen and confirm dialog. Usage: -- <outdir> [w h]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(int(a[1]) if a.size() > 2 else 1280, int(a[2]) if a.size() > 2 else 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en")
	main._begin_pick("napoleonic", "normal")
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/pick1.png" % a[0])
	var fr: int = main.g.nat_code.find("france")
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 3.0)
	for i in 8: await process_frame
	main._on_pick(main.g.capital_of[fr], false)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/pick2.png" % a[0])
	quit(0)
