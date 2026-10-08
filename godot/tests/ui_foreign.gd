extends SceneTree
## foreign-nation left panel: select a neighbour's province. Usage: -- <outdir> <w> <h>
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
	for i in 10: await process_frame
	var g: TBGame = main.g
	var tgt := -1
	for p in g.owned(fr):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.owner[q] != 0 and g.owner[q] != fr: tgt = q; break
		if tgt >= 0: break
	main._select(tgt)
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/foreign.png" % a[0])
	quit(0)
