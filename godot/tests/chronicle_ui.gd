extends SceneTree
## Chronicle + advisor: engine log kinds and alerts, then screenshots of both modals.
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("medieval", "normal")
	var g: TBGame = main.g
	var best := -1; var cnt := 0
	for n in range(1, g.N1):
		if g.own_count(n) > cnt and n != g.rebel: cnt = g.own_count(n); best = n
	main._start_game(best)
	var me := g.human_id
	var kinds := {}
	for t in 80:
		g.end_turn()
		for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
	for e in g.log: kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
	print("log kinds after 80 turns: ", kinds)
	var al := TBAdvisor.alerts(g, me)
	print("alerts: ", al.map(func(a): return a["id"] + ":" + str(a["sev"])))
	var empty_text := 0
	for e in g.log:
		if TBChron.text(g, e) == "" and e["kind"] != "event_choice": empty_text += 1
	print("entries with empty text (excluding event_choice): ", empty_text)
	# force crises so every alert text renders
	g.gold[me] = 0.0; g.budget[me * 4] = 0
	main.hud.refresh()
	TBModals.chronicle(main._overlay, g, main._goto_province)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/chronicle.png")
	main._clear_overlay()
	main.g.gold[me] = 400.0
	TBModals.advisor(main._overlay, g, main._goto_province)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/advisor.png")
	# RU
	TBI18n.load_lang("ru")
	main._clear_overlay()
	TBModals.chronicle(main._overlay, g, main._goto_province)
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/chronicle_ru.png")
	quit()
