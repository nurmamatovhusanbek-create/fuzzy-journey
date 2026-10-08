extends SceneTree
## Atlas Ledger look: map, selection + inspector, zoomed borders, drawer. Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/at_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 1.6)
	await _shot("map")
	main._select(main.g.capital_of[fr])
	await _shot("sel")
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 6.0)
	await _shot("zoom")
	main._select(-1)
	main.map.fly_to(10.0, 48.0, 3.0)
	await _shot("zoom_eu")
	quit(0)
