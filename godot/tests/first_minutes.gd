extends SceneTree
## The first minutes: the tutorial, the briefing and the first turn's screen, as a new player meets them. Usage: -s tests/first_minutes.gd -- <w> <h> <out dir> [hc]
var _out := ""
func _shot(name: String) -> void:
	for i in 24: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/fm_%s.png" % [_out, name])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[2]
	DisplayServer.window_set_size(Vector2i(int(a[0]), int(a[1]))); root.size = Vector2i(int(a[0]), int(a[1]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = false; main.cfg["tutorial"] = false; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	if a.size() > 3: main.cfg["hc"] = a[3]; main.theme = TBKit.apply_settings(main.cfg)
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("modern", "normal")
	var me: int = 1
	for n in range(1, main.g.N1):
		if main.g.dname(n) == "Uzbekistan": me = n; break
	main._start_game(me)
	for i in 60: await process_frame
	await _shot("1_tutorial")
	main._clear_overlay()
	TBModals.briefing(main._overlay, main.g, func(): pass)
	await _shot("2_briefing")
	main._clear_overlay()
	await _shot("3_first_turn")
	main.hud.end_turn_pressed.emit()
	for i in 200: await process_frame
	await _shot("4_after_end_turn")
	quit(0)
