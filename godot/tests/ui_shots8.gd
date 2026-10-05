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
	TBModals.hotseat_setup(main._overlay, func(k): pass)
	await _shot("hot1_setup")
	main._clear_overlay()
	main._hot_n = 2
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france"); var pr: int = main.g.nat_code.find("prussia")
	main._confirm_pick(fr)
	main._on_pick(main.g.capital_of[pr], false)
	await _shot("hot2_pick")
	main._confirm_pick(pr)
	main.g.pending.clear(); main._clear_overlay()
	main._hot_switch(pr, false)
	await _shot("hot3_curtain")
	quit(0)
