extends SceneTree
# Phone-portrait + landscape layout check at 1080x2400-ish logical sizes.
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var size := Vector2i(int(OS.get_cmdline_user_args()[1]), int(OS.get_cmdline_user_args()[2]))
	root.size = size
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/p_menu.png" % out)
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best])
	main.map.fly_to(64.0, 40.0, 3.0)
	await process_frame
	main._select(main.g.owned(main.g.human_id)[0])
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/p_game.png" % out)
	quit()
