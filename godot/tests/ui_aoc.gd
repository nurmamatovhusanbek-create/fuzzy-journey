extends SceneTree
## AoC layout looks: map, selected province, realm panel open, lens popover. Usage: -- <outdir> <w> <h>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	for k in 8:
		main.g.turn = 2 + k * 2
		main.g.gold[fr] = 100.0 + 40.0 * sin(k * 0.9) + k * 15.0
		TBStats.record(main.g)
	main.g.turn = 1
	main.hud.refresh()
	main._select(main.g.capital_of[fr])
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/aoc_sel.png" % a[0])
	main.hud._open_realm()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/aoc_realm.png" % a[0])
	main.hud.close_realm()
	main._select(-1)
	main.hud._open_lens_pop(main.hud._tab_maps)
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/aoc_lens.png" % a[0])
	quit(0)
