extends SceneTree
## Bezel look in high contrast (light and dark). Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String) -> void:
	for i in 16: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bh_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	DisplayServer.window_set_size(Vector2i(int(a[1]), int(a[2]))); root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for hc in ["light", "dark"]:
		main.cfg["hc"] = hc
		main._apply_a11y()
		for i in 20: await process_frame
		main._clear_overlay()
		main._select(main.g.capital_of[fr])
		await _shot("sel_" + hc)
		main._select(-1)
		main._open_nations(main.g.nat_code.find("spain"))
		await _shot("nat_" + hc)
	main.cfg["hc"] = "off"
	quit(0)
