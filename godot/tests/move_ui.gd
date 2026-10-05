extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best])
	main._clear_overlay()
	main._select(best)
	main._on_move_requested(best)
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/move_targets.png")
	quit()
