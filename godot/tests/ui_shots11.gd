extends SceneTree
## odd screen shapes: usage -- <outdir> <w> <h> <tag>
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(int(a[1]), int(a[2]))
	await process_frame; await process_frame
	main._update_ui_scale()
	await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var cap: int = main.g.capital_of[fr]
	main._select(cap)
	for i in 4: await process_frame
	await _shot("%s_game" % a[3])
	main._clear_overlay()
	TBModals.nation_detail(main._overlay, main.g, main.g.nat_code.find("russian_empire"), main._on_command, main._goto_nation)
	await _shot("%s_nation" % a[3])
	quit(0)
