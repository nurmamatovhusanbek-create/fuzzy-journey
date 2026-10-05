extends SceneTree
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
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
	main.cfg["honours"] = {"first_blood": "1804"}
	main.show_menu()
	await _shot("q1_menu")
	TBModals.codex(main._overlay)
	await _shot("q2_codex")
	main._clear_overlay()
	TBModals.honours(main._overlay, main.cfg)
	await _shot("q3_honours")
	main._clear_overlay()
	TBModals.hotseat_setup(main._overlay, func(k): pass)
	await _shot("q4_hot")
	main._clear_overlay()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	g.gold[fr] = 800; g.dp[fr] = 8
	TBModals.briefing(main._overlay, g, func(): pass)
	await _shot("q5_briefing")
	quit(0)
