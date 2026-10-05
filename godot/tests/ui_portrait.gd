extends SceneTree
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/pp_%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(540, 960)
	await process_frame; await process_frame
	main._update_ui_scale()
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.show_menu()
	await _shot("1_menu")
	main._open_era_picker()
	await _shot("2_era")
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr); main.g.pending.clear(); main._clear_overlay()
	for t in 6: main.g.end_turn()
	main.hud.build(); main.hud.refresh()
	TBModals.nation_detail(main._overlay, main.g, main.g.nat_code.find("russian_empire"), main._on_command, main._goto_nation)
	await _shot("3_nation")
	main._clear_overlay()
	TBModals.decisions(main._overlay, main.g, main._on_command)
	await _shot("4_decisions")
	main._clear_overlay()
	TBModals.statistics(main._overlay, main.g, func(): pass)
	await _shot("5_stats")
	main._clear_overlay()
	main.g.pending.append({"uid": 5, "n": fr, "kind": "rand", "id": "royal_wedding", "icon": "💍", "cat": "DIPLOMACY", "count": 2})
	main.show_events()
	await _shot("6_event")
	quit()
