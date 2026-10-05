extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var f := ConfigFile.new()
	f.set_value("tb", "lang", "ru"); f.set_value("tb", "tutorial", true); f.set_value("tb", "quality", "medium")
	f.save("user://settings.cfg")
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ru_menu.png")
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best])
	main._select(best)
	main.map.fly_to(64.0, 40.0, 2.4)
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ru_game.png")
	f.set_value("tb", "lang", "en"); f.save("user://settings.cfg")
	quit()
