extends SceneTree
## Bezel look: title (must stay as it was), pick screen, gear menu, legend, game over. Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String) -> void:
	for i in 16: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bm_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	DisplayServer.window_set_size(Vector2i(int(a[1]), int(a[2]))); root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	await _shot("title")
	main._begin_pick("napoleonic", "normal")
	for i in 20: await process_frame
	await _shot("pick")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 20: await process_frame
	main.map.fly_to(10.0, 46.0, 2.6)
	main.hud._pick_lens("diplomatic")
	await _shot("lens")
	main.hud._pick_lens("political")
	main.hud._open_menu(main.hud._menu_btn, false)
	await _shot("menu")
	main.hud._close_pop()
	TBModals.game_over(main._overlay, g, func(): pass)
	await _shot("over")
	quit(0)
