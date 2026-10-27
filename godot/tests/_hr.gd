extends SceneTree
func _init() -> void:
	root.size = Vector2i(1280, 720); DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_quality(); main._update_ui_scale()
	for i in 20: main.g.end_turn()
	for i in 30: await process_frame
	var g: TBGame = main.g; var me := g.human_id
	var tm := func(label: String, f: Callable, n: int = 30) -> void:
		var t0 := Time.get_ticks_usec()
		for i in n: f.call()
		print("%-34s %.2f ms" % [label, (Time.get_ticks_usec() - t0) / 1000.0 / n])
	tm.call("TBAdvisor.alerts", func(): TBAdvisor.alerts(g, me))
	tm.call("TBAdvisor.ticker", func(): TBAdvisor.ticker(g, me))
	tm.call("g.income(me)", func(): g.income(me))
	tm.call("TBAdvisor.breakdown", func(): TBAdvisor.breakdown(g, me))
	tm.call("hud.refresh", func(): main.hud.refresh())
	tm.call("TBVision.sync (forced)", func(): TBVision._sig = -1; TBVision.sync(g))
	tm.call("TBTurn.victory_progress", func(): TBTurn.victory_progress(g, me))
	main._select(g.owned(me)[0])
	for i in 6: await process_frame
	tm.call("panel.rebuild", func(): main.panel.rebuild())
	tm.call("flow.refresh", func(): main.flow.refresh())
	tm.call("show_events", func(): main.show_events())
	quit()
