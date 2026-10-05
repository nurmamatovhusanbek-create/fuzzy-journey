extends SceneTree
# Drop the client socket mid-game; the controller must rejoin the same room/nation with its token.
func wait(cond: Callable, ms: int = 30000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await create_timer(0.05).timeout
		if Time.get_ticks_msec() - t0 > ms: return false
	return true
func _init() -> void:
	var port := int(OS.get_cmdline_user_args()[0])
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.mp.url = "ws://127.0.0.1:%d" % port
	main.mp._connect(func(): main.mp.net.create_room("Tester", "modern", "normal", 60))
	await wait(func(): return main.mode == "mp_lobby" and main.mp.net.game != null)
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0: best = p; break
	main._on_pick(best, false)
	await wait(func(): return main.mp.net.my_nation != 0)
	var nation: int = main.mp.net.my_nation
	main.mp.net.start_game()
	await wait(func(): return main.mp.in_game)
	var code: String = main.mp.net.my_room
	print("in game as nation ", nation, " room ", code)
	main.mp.net._peer.close()           # simulate a network drop
	main.mp._on_disconnected()
	var ok: bool = await wait(func(): return main.mp.net.my_room == code and main.mp.net.game != null and main.mp.net.my_nation == nation and main.mp.net.multiplayer.multiplayer_peer != null and main.mp.net.multiplayer.get_unique_id() > 1, 40000)
	await create_timer(1.5).timeout
	var mine: PackedInt32Array = main.mp.net.game.owned(nation)
	var before: float = main.mp.net.game.army[mine[0]]
	main._on_command({"cmd": "recruit", "p": mine[0], "amount": 15})
	await create_timer(1.0).timeout
	print("rejoined=", ok, " same nation=", main.mp.net.my_nation == nation, " command after rejoin works: army ", before, " -> ", main.mp.net.game.army[mine[0]])
	quit()
