extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("medieval", "normal")
	TBModals.nations(main._overlay, main.g, func(n: int): main._pick_nation_from_list(n), false, false)
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/pick_list.png")
	main._clear_overlay(); main._add_pick_buttons()
	main._pick_nation_from_list(main.g.nat_code.find("byzantine_empire"))
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/pick_after.png")
	print("mode=", main.mode, " modal children=", main._overlay.get_child_count())
	quit()
