extends SceneTree
## Bezel look: an event with effects, a proposal, the game-over sheet. Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String) -> void:
	for i in 16: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/be_%s.png" % [_out, name])

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
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 20: await process_frame
	TBModals.event_prompt(main._overlay, {"kind": "rand", "id": "golden_age", "count": 2, "uid": 1, "cat": "culture"}, func(c): pass, g)
	await _shot("event")
	main._clear_overlay()
	var sp: int = g.nat_code.find("spain")
	TBModals.event_prompt(main._overlay, {"kind": "prop", "id": "nap", "from": sp, "count": 2, "uid": 2, "p": g.capital_of[sp]}, func(c): pass, g)
	await _shot("prop")
	main._clear_overlay()
	main._open_decisions()
	await _shot("dec")
	quit(0)
