extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["tutorial"] = true
	main._begin_pick("medieval", "normal")
	main._start_game(main.g.nat_code.find("byzantine_empire"))
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/briefing.png")
	quit()
