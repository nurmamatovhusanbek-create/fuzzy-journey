extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var w := TBWorld.load_from("res://data")
	var failed := 0
	# economic victory: a share of world income AND 5000 gold AND a full trade network AND turn >= 30
	var me := 1
	var big := func(game: TBGame) -> void:                                           # nation 1 is small: give it 12% of the map so its income share is real
		for q in range(0, int(game.P * 0.12)): game.set_owner(q, me)
		game.alive[me] = 1; game.econ_goal = 0.08
	var g := TBGame.new(w, {}, {"seed": 4})
	g.set_human(me); big.call(g); g.gold[me] = 6000
	g.end_turn()
	print("economic early: over=%s" % g.over); if g.over: failed += 1                      # turn 1: too soon, whatever the treasury
	var ge := TBGame.new(w, {}, {"seed": 4}); ge.set_human(me); big.call(ge); ge.turn = 29; ge.gold[me] = 6000; ge.trade_cnt[me] = TBTrade.max_deals(ge, me)
	ge.end_turn()
	print("economic: over=%s winner=%d kind=%s" % [ge.over, ge.winner, ge.victory_kind]); if not (ge.over and ge.winner == me and ge.victory_kind == "economic"): failed += 1
	var gs := TBGame.new(w, {}, {"seed": 4}); gs.set_human(me); big.call(gs); gs.econ_goal = 5.0; gs.turn = 29; gs.gold[me] = 6000; gs.trade_cnt[me] = TBTrade.max_deals(gs, me)
	gs.end_turn()
	print("economic without the income share: over=%s" % gs.over); if gs.over and gs.victory_kind == "economic": failed += 1
	var gr := TBGame.new(w, {}, {"seed": 4}); gr.set_human(me); gr.turn = 29; gr.gold[me] = 6000; gr.econ_goal = 0.001               # no trade network yet
	gr.end_turn()
	print("economic without trade: over=%s" % gr.over); if gr.over and gr.victory_kind == "economic": failed += 1
	# technological race: a late era (everyone near the cap) has none; an early era needs a lead over the second-best nation
	var gt := TBGame.new(w, {}, {"seed": 4}); gt.set_human(me); gt.tech_level[me] = 5.0; gt.turn = 45
	gt.end_turn()
	print("technological in a late era: over=%s" % gt.over); if gt.over and gt.victory_kind == "technological": failed += 1
	var anc := TBWorld.load_era("res://data", "ancient")
	var gt2 := TBGame.new(w, anc, {"seed": 4}); gt2.set_human(me); gt2.turn = 39
	for n in range(1, gt2.N1): gt2.tech_level[n] = minf(gt2.tech_level[n], 3.0)
	gt2.tech_level[me] = 5.0
	gt2.end_turn()
	print("technological early era: over=%s kind=%s" % [gt2.over, gt2.victory_kind]); if not (gt2.over and gt2.victory_kind == "technological"): failed += 1
	var gt3 := TBGame.new(w, anc, {"seed": 4}); gt3.set_human(me); gt3.turn = 39
	for n in range(1, gt3.N1): gt3.tech_level[n] = 4.9
	gt3.tech_level[me] = 5.0
	gt3.end_turn()
	print("technological without a lead: over=%s" % gt3.over); if gt3.over and gt3.victory_kind == "technological": failed += 1
	# domination triggers by giving the human 26% of provinces
	var g2 := TBGame.new(w, {}, {"seed": 4})
	g2.set_human(1)
	for p in range(0, int(g2.P * 0.27)): g2.set_owner(p, 1)
	g2.alive[1] = 1
	g2.end_turn()
	print("domination: over=%s kind=%s progress=%s" % [g2.over, g2.victory_kind, str(TBTurn.victory_progress(g2, 1))]); if not (g2.over and g2.winner == 1): failed += 1
	# no false positive for a normal start
	var g3 := TBGame.new(w, {}, {"seed": 4}); g3.set_human(1)
	for i in 5: g3.end_turn()
	print("normal start: over=%s" % g3.over); if g3.over: failed += 1
	# UI screenshot of the goals modal
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("modern", "normal")
	var best := 0
	for p in main.g.P: if main.g.owner[p] != 0 and main.world.name[p] == "Bukhoro": best = p
	main._start_game(main.g.owner[best]); main._clear_overlay()
	main.hud.goals_pressed.emit()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/goals.png")
	quit(failed)
