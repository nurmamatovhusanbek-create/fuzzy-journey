extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	# --- engine-level: scheduled events fire in the Roman era, humans get prompts
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", "roman")
	var g := TBGame.new(w, era, {"seed": 3})
	var hp := 0
	for p in g.P: if g.owner[p] != 0: hp = p; break
	g.set_human(g.owner[hp])
	var fired: Array = []; var prompts := 0
	for t in 60:
		g.end_turn()
		for e in g.log: if e["kind"] == "event" and not fired.has(e["id"]): fired.append(e["id"])
		prompts += g.pending.size()
		for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
	print("roman year=%d fired=%s prompts=%d" % [g.year, str(fired), prompts])
	# random events over 150 turns of a modern game
	var g2 := TBGame.new(w, {}, {"seed": 5})
	g2.set_human(g2.owner[1000])
	var rand_seen := {}
	for t in 150:
		g2.end_turn()
		for e in g2.pending.duplicate():
			rand_seen[e["id"]] = rand_seen.get(e["id"], 0) + 1
			g2.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
	print("random events seen (150 turns, 1 human): ", rand_seen)
	# --- UI: prompt screenshot
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var best := -1
	for p in main.g.P: if main.g.owner[p] != 0: best = p; break
	main._start_game(main.g.owner[best])
	var me: int = main.g.human_id
	main.g.pending.append({"uid": 999, "n": me, "kind": "rand", "id": "plague", "icon": "☠", "cat": "CRISIS", "count": 2})
	main.show_events()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/event_prompt.png")
	var gold0: float = main.g.gold[me]
	main._on_command({"cmd": "eventChoice", "uid": 999, "i": 0})
	print("after choice: gold %.0f -> %.0f (expect -45), pending=%d" % [gold0, main.g.gold[me], main.g.pending.size()])
	quit()
