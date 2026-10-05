extends SceneTree
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "uz"; TBI18n.load_lang("uz"); main.show_menu()
	await _shot("uz1_menu")
	main._clear_overlay()
	main._open_era_picker()
	await _shot("uz2_era")
	main._clear_overlay()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	main._select(main.g.capital_of[fr])
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 3.0)
	for i in 6: await process_frame
	await _shot("uz3_game")
	main._select(-1)
	TBModals.nation_detail(main._overlay, main.g, main.g.nat_code.find("russian_empire"), main._on_command, main._goto_nation)
	await _shot("uz4_nation")
	main._clear_overlay()
	TBModals.decisions(main._overlay, main.g, main._on_command)
	await _shot("uz5_decrees")
	quit(0)
