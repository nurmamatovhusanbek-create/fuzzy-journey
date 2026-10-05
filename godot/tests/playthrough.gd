extends SceneTree
# Scripted playthrough of the real Main scene under Xvfb; saves screenshots + asserts no crashes.
#   xvfb-run -a godot --path godot --rendering-driver opengl3 -s tests/playthrough.gd -- /tmp/out
var out := "/tmp"

func shot(name: String) -> void:
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await shot("1_menu")
	main._open_era_picker()
	await shot("2_era")
	main._clear_overlay()
	main._begin_pick("modern", "normal")
	main.map.fly_to(60.0, 40.0, 2.0)
	await shot("3_pick")
	# pick Uzbekistan-ish: the owner of the province nearest lon 64, lat 41
	var best := -1; var bd := 1e9
	for p in main.g.P:
		var d := absf(main.world.lon[p] - 64.0) + absf(main.world.lat[p] - 41.0)
		if main.g.owner[p] != 0 and d < bd: bd = d; best = p
	main._on_pick(best, false)
	await shot("4_confirm")
	main._start_game(main.g.owner[best])
	await shot("5_game")
	var mine: PackedInt32Array = main.g.owned(main.g.human_id)
	main._select(mine[0])
	await shot("6_province")
	main._on_command({"cmd": "recruit", "p": mine[0], "amount": 15})
	main.map.set_lens("military")
	await shot("7_military")
	var t0 := Time.get_ticks_msec()
	for i in 8:
		main.end_turn()
		while main._busy: await process_frame
	print("8 turns via worker thread ms: ", Time.get_ticks_msec() - t0, " turn=", main.g.turn)
	main.map.set_lens("political")
	await shot("8_after")
	main._save_slot("1")
	var m := TBSave.meta("1"); print("save meta: ", m)
	main._load_slot("1"); print("loaded turn=", main.g.turn)
	await shot("9_loaded")
	quit()
