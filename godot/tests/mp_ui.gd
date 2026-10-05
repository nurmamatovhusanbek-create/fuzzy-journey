extends SceneTree
# UI-level multiplayer smoke: real Main scene -> create room on a local server -> lobby -> start -> command + end turn.
func shot(name: String, out: String) -> void:
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func wait(cond: Callable, ms: int = 20000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await create_timer(0.05).timeout
		if Time.get_ticks_msec() - t0 > ms: return false
	return true
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]; var port := int(a[1])
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.mp.url = "ws://127.0.0.1:%d" % port
	main.mp._connect(func(): main.mp.net.create_room("Tester", "modern", "normal", 30))
	var ok: bool = await wait(func(): return main.mode == "mp_lobby" and main.mp.net.game != null)
	print("lobby reached: ", ok)
	await shot("mp1_lobby", out)
	var best := -1; var bd := 1e9
	for p in main.g.P:
		var d := absf(main.world.lon[p] - 2.0) + absf(main.world.lat[p] - 47.0)
		if main.g.owner[p] != 0 and d < bd: bd = d; best = p
	main._on_pick(best, false)
	await wait(func(): return main.mp.net.my_nation != 0)
	print("picked nation: ", main.g.nat_name[main.mp.net.my_nation])
	main.mp.net.start_game()
	ok = await wait(func(): return main.mp.in_game)
	print("in game: ", ok, " mode=", main.mode)
	await create_timer(0.6).timeout
	var mine: PackedInt32Array = main.g.owned(main.mp.net.my_nation)
	main._select(mine[0])
	main._on_command({"cmd": "recruit", "p": mine[0], "amount": 15})
	await create_timer(0.6).timeout
	await shot("mp2_game", out)
	var t0: int = main.g.turn
	main.end_turn()
	ok = await wait(func(): return main.g.turn > t0)
	print("turn advanced: ", ok, " turn=", main.g.turn)
	await create_timer(0.4).timeout
	await shot("mp3_after_turn", out)
	quit()
