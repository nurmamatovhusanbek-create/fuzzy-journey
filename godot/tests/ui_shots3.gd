extends SceneTree
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _pre, name])
var _out := ""
var _pre := ""
func _init() -> void:
	var a := OS.get_cmdline_user_args(); _out = a[0]; _pre = a[1]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var us: int = main.g.nat_code.find("USA")
	if us < 0: us = main.g.nat_name.find("United States of America")
	main._start_game(us)
	main.g.pending.clear(); main._clear_overlay()
	main.hud.refresh()
	main.map.fly_to(-95.0, 40.0, 1.0)
	for i in 8: await process_frame
	await _shot("globe")
	main.map.fly_to(2.0, 47.0, 5.0)
	for i in 10: await process_frame
	await _shot("zoomed")
	main.cfg["theme"] = "parchment"; main._apply_quality()
	await _shot("parchment")
	main.cfg["theme"] = "standard"; main.map.set_mode(1); main._apply_quality()
	main.map.zoom = 1.0
	await _shot("flat")
	main.map.set_lens("military"); main.hud.set_lens_legend("military")
	await _shot("lens_mil")
	main.map.set_lens("diplomatic"); main.hud.set_lens_legend("diplomatic")
	await _shot("lens_dip")
	quit()
