extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("napoleonic", "normal")
	var g: TBGame = main.g
	var fr := g.nat_code.find("france")
	main._start_game(fr)
	main._open_nations(g.nat_code.find("russian_empire"))
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ruler_card.png")
	main._clear_overlay()
	TBI18n.load_lang("ru")
	main._open_nations(fr)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ruler_card_ru.png")
	quit()
