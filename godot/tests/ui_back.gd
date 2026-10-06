extends SceneTree
## Back / Esc stack (P-20): an unanswered event prompt, game over and the pass-device curtain swallow Back; panels close one step at a time;
## drill-in pages go back before closing; the title needs two presses to quit. Run under xvfb.
func _init() -> void:
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var fails := 0
	var ck := func(ok: bool, what: String) -> void:
		if not ok: print("FAIL ", what)
		fails += 0 if ok else 1
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	# event prompt: locked, still there afterwards
	g.pending.append({"uid": 777, "n": fr, "kind": "rand", "id": "heresy", "icon": "x", "cat": "CRISIS", "count": 2})
	main.show_events()
	await process_frame
	ck.call(TBPanel.top(main._overlay) != null, "event prompt open")
	main._on_back()
	await process_frame
	ck.call(TBPanel.top(main._overlay) != null, "event prompt survives Back")
	ck.call(TBPanel.pop(main._overlay) == "locked", "event prompt reports locked")
	main._clear_overlay(); g.pending.clear()
	# nations panel: Back closes it
	main._open_nations()
	await process_frame
	ck.call(TBPanel.top(main._overlay) != null, "nations open")
	main._on_back()
	await process_frame; await process_frame
	ck.call(TBPanel.top(main._overlay) == null, "nations closed by Back")
	# hub opens from the game, Back closes, a second Back with nothing open opens the hub again (never quits)
	main._on_back()
	await process_frame
	ck.call(TBPanel.top(main._overlay) != null and main.mode == "game", "Back in game with nothing open opens the menu hub")
	main._clear_overlay()
	# title: first Back arms, no quit
	main.show_menu()
	await process_frame
	main._on_back()
	ck.call(main._exit_armed and main.mode == "menu", "title Back arms the exit")
	# pick: Back returns to the New Game page
	main._exit_armed = false
	main._begin_pick("napoleonic", "normal")
	await process_frame
	main._on_back()
	await process_frame; await process_frame
	ck.call(main.mode == "menu" and TBPanel.top(main._overlay) != null, "pick Back opens the New Game page over the title")
	print("UIBACK ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
