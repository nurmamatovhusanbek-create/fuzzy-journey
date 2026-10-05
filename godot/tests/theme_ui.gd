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
	main._start_game(main.g.owner[best]); main._clear_overlay()
	main.cfg["theme"] = "parchment"; main._apply_quality()
	main.map.zoom = 1.2; main.map.lon0 = 0.5; main.map.lat0 = 0.55; main.map._push_view()
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/parchment.png")
	quit()
