extends SceneTree
## Design review part 2: settings, goals, event prompt, tutorial, advisor, game over, save/load; EN + RU. -- <outdir> <prefix> [lang]
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _pre, name])
var _out := ""
var _pre := "u2"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]; _pre = a[1]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if a.size() > 2 and a[2] == "ru":
		main.cfg["lang"] = "ru"; TBI18n.load_lang("ru"); main.show_menu()
		await _shot("0_menu_ru")
	main._begin_pick("ww1", "normal")
	main._start_game(main.g.nat_code.find("german_empire"))
	main.g.pending.clear()
	for t in 60: main.g.end_turn()
	main.hud.build(); main.hud.refresh()
	main._clear_overlay()
	TBModals.statistics(main._overlay, main.g, func(): pass)
	await _shot("0b_stats")
	main._clear_overlay()
	TBModals.settings(main._overlay, main.cfg, func(): pass, func(): pass)
	await _shot("1_settings")
	main._clear_overlay()
	TBModals.goals(main._overlay, main.g)
	await _shot("2_goals")
	main._clear_overlay()
	main.g.pending.append({"uid": 7, "n": main.g.human_id, "kind": "rand", "id": "plague", "icon": "☠", "cat": "CRISIS", "count": 2})
	main.show_events()
	await _shot("3_event")
	main._clear_overlay()
	TBModals.tutorial(main._overlay, func(): pass)
	await _shot("4_tutorial")
	main._clear_overlay()
	main.g.gold[main.g.human_id] = 0
	TBModals.advisor(main._overlay, main.g, main._goto_province)
	await _shot("5_advisor")
	main._clear_overlay()
	TBModals.save_load(main._overlay, true, func(s): pass, func(s): pass)
	await _shot("6_save")
	main._clear_overlay()
	main.g.over = true; main.g.winner = main.g.human_id; main.g.victory_kind = "economic"
	TBModals.game_over(main._overlay, main.g, func(): pass)
	await _shot("7_gameover")
	quit()
