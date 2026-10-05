extends SceneTree
## hot-seat flow: two humans take turns on one device. Run under xvfb.
func _init() -> void:
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var fails := 0
	main._hot_n = 2; main._hot_list = PackedInt32Array()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france"); var pr: int = main.g.nat_code.find("prussia")
	main._confirm_pick(fr)
	if main._hot_list.size() != 1: fails += 1
	main._confirm_pick(pr)
	await process_frame
	var g: TBGame = main.g
	print("humans: ", g.humans(), " current ", g.human_id, " hotseat=", main._is_hotseat())
	if g.humans().size() != 2 or not main._is_hotseat() or g.human_id != fr: fails += 1
	main.g.pending.clear(); main._clear_overlay()
	var t0 := g.turn
	main.end_turn()                                   # player 1 done -> curtain for player 2, no turn processed
	await process_frame
	print("after P1 end: human=", g.human_id, " turn=", g.turn)
	if g.human_id != pr or g.turn != t0: fails += 1
	main._clear_overlay()
	main.end_turn()                                   # player 2 done -> real turn runs
	var guard := 0
	while g.turn == t0 and guard < 600: await create_timer(0.05).timeout; guard += 1
	await process_frame; await process_frame
	print("after round: human=", g.human_id, " turn=", g.turn)
	if g.turn != t0 + 1 or g.human_id != fr: fails += 1
	print("HOTSEAT ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
