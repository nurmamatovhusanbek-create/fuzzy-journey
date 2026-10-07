extends SceneTree
## looks: title, plain map, selected province. Usage: -- <outdir> <w> <h>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/title.png" % a[0])
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/map.png" % a[0])
	main._select(main.g.capital_of[fr])
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/sel.png" % a[0])
	quit(0)
