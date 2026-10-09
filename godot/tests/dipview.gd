extends SceneTree
## TBDipView mirrors the engine's diplomacy decisions: `ok` equals accepts_pact / accepts_peace / TBTrade.accepts on random positions.
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 11})
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var checks := 0; var fails := 0
	var ids: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel: ids.append(n)
	for it in 4000:
		var t: int = ids[rng.randi() % ids.size()]; var p: int = ids[rng.randi() % ids.size()]
		if t == p: continue
		g.grudge[t * g.N1 + p] = rng.randi_range(0, 60)
		g.infamy[p] = rng.randf_range(0.0, 40.0)
		g.war_score[t * g.N1 + p] = rng.randi_range(0, 60); g.war_score[p * g.N1 + t] = rng.randi_range(0, 60)
		g.war_turns[t * g.N1 + p] = rng.randi_range(0, 40)
		for rel in [TBData.REL_NAP, TBData.REL_ALLY]:
			var v: Dictionary = TBDipView.pact(g, t, p, rel)
			if bool(v["ok"]) != TBAI.accepts_pact(g, t, p, rel): fails += 1; print("FAIL pact ", t, " ", p, " ", rel, " ", v)
			checks += 1
		for kind in ["white", "cede", "vassal"]:
			var v2: Dictionary = TBDipView.peace(g, t, p, kind)
			if bool(v2["ok"]) != TBAI.accepts_peace(g, t, p, kind): fails += 1; print("FAIL peace ", t, " ", p, " ", kind, " ", v2)
			checks += 1
		var v3: Dictionary = TBDipView.trade(g, t, p)
		if bool(v3["ok"]) != TBTrade.accepts(g, t, p) and String(v3["blocked"]) != "war": fails += 1; print("FAIL trade ", t, " ", p, " ", v3)
		checks += 1
	print("%d checks, %d fails" % [checks, fails])
	print("DIPVIEW PASS" if fails == 0 else "DIPVIEW FAIL")
	quit(0 if fails == 0 else 1)
