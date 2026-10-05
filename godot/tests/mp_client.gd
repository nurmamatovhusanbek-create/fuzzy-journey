extends SceneTree
# Integration client:  godot --headless --path godot -s tests/mp_client.gd -- <host|join> <port> <nation>
# Prints per-turn checksums of the MIRRORED game so two clients can be compared.
var net: TBNet
var role := "host"
var port := 8090
var nation := 100
var world: TBWorld
var turns_seen: Array = []

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0]; port = int(a[1]); nation = int(a[2])
	world = TBWorld.load_from("res://data")
	net = TBNet.new(); net.name = "Net"
	root.add_child(net)
	await process_frame
	net.error_received.connect(func(m): print("[%s] ERROR %s" % [role, m]))
	net.connect_to(world, "ws://127.0.0.1:%d" % port)
	await net.connected
	print("[%s] connected" % role)
	if role == "host":
		net.create_room("Host", "modern", "normal", 60)
		await _wait(func(): return net.my_room != "" and net.game != null)
		FileAccess.open("/tmp/mp_code.txt", FileAccess.WRITE).store_string(net.my_room)
		print("[host] room ", net.my_room)
		net.pick_nation(nation)
		await _wait(func(): return net.room_info.get("players", []).size() >= 2 and _all_picked())
		net.start_game()
	else:
		var code := ""
		for i in 100:
			if FileAccess.file_exists("/tmp/mp_code.txt"):
				code = FileAccess.get_file_as_string("/tmp/mp_code.txt")
				if code.length() == 5: break
			await create_timer(0.1).timeout
		net.join_room(code, "Guest")
		await _wait(func(): return net.my_room != "" and net.game != null)
		net.pick_nation(nation)
	await _wait(func(): return net.room_info.get("state", "") == "playing")
	print("[%s] playing; nation=%d  human flags: %s" % [role, net.my_nation, net.game.humans()])
	for t in 4:
		var mine: PackedInt32Array = net.game.owned(net.my_nation)
		net.send_command({"cmd": "recruit", "p": mine[0], "amount": 15})
		await create_timer(0.5).timeout
		var tn := net.game.turn
		net.end_turn()
		await _wait(func(): return net.game.turn > tn)
		await create_timer(0.3).timeout
		print("[%s] turn=%d checksum=%d army(mine0)=%d gold=%.1f" % [role, net.game.turn, net.game.state_checksum() & 0xFFFFFFFF, net.game.army[mine[0]], net.game.gold[net.my_nation]])
	await create_timer(0.5).timeout
	print("[%s] DONE" % role)
	quit()

func _all_picked() -> bool:
	for p in net.room_info["players"]:
		if p["nation"] == 0: return false
	return true

func _wait(cond: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await create_timer(0.05).timeout
		if Time.get_ticks_msec() - t0 > 30000: print("[%s] TIMEOUT" % role); quit(2); return
