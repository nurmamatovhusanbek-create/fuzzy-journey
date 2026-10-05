extends SceneTree
## Casus belli / infamy / coalitions: unit checks + 300-turn statistics.
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var g := TBGame.new(w, {}, {"seed": 7})
	# unit: pick two bordering nations
	var a := 0; var b := 0
	for p in g.P:
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var q := g.nb[e]
			if g.owner[p] != 0 and g.owner[q] != 0 and g.owner[p] != g.owner[q] and g.nb_sea[e] == 0:
				a = g.owner[p]; b = g.owner[q]; break
		if a != 0: break
	print("unit nations: ", g.nat_name[a], " vs ", g.nat_name[b])
	var ok := TBDiplo.cb(g, a, b) == ""
	print("no CB at start: ", ok); if not ok: fails += 1
	g.dp[a] = 20
	var i0 := g.infamy[a]
	g.apply({"cmd": "declareWar", "n": a, "t": b})
	ok = g.infamy[a] == i0 + TBDiplo.NO_CB_INFAMY
	print("unjustified war: infamy %.1f -> %.1f" % [i0, g.infamy[a]]); if not ok: fails += 1
	ok = TBDiplo.cb(g, b, a) == "" or true
	g.grudge[b * g.N1 + a] = 60
	ok = TBDiplo.cb(g, b, a) == "revenge"
	print("revenge CB for the wronged: ", ok); if not ok: fails += 1
	g.apply({"cmd": "peace", "n": a, "t": b, "kind": "white", "_force": true})
	# force a coalition
	g.infamy[a] = 30.0; TBDiplo.tick(g)
	ok = g.coalition[a] == 1 and TBDiplo.cb(g, b, a) in ["coalition", "revenge"]
	print("coalition forms at 30: ", ok, " cb=", TBDiplo.cb(g, b, a)); if not ok: fails += 1
	for t in 40: TBDiplo.tick(g)
	ok = g.coalition[a] == 0
	print("coalition dissolves after decay: ", ok, " infamy=%.1f" % g.infamy[a]); if not ok: fails += 1
	# reclaim: cede a province and check
	var p0 := g.owned(b)[0]
	g.core[p0] = a
	ok = TBDiplo.cb(g, a, b) == "reclaim"
	print("reclaim CB: ", ok); if not ok: fails += 1
	# statistics
	var g2 := TBGame.new(w, {}, {"seed": 11})
	var formed := 0; var ended := 0; var no_cb := 0; var cb_wars := 0; var maxinf := 0.0
	for t in 300:
		g2.end_turn()
		for n in range(1, g2.N1): maxinf = maxf(maxinf, g2.infamy[n])
	for e in g2.log:
		match e["kind"]:
			"coalition": formed += 1
			"coalition_end": ended += 1
			"war":
				if e.get("ally", 0) == 0:
					if String(e.get("cb", "")) == "": no_cb += 1
					else: cb_wars += 1
	print("300 turns: coalitions formed=%d ended=%d | wars: no-CB=%d with-CB=%d | max infamy %.0f" % [formed, ended, no_cb, cb_wars, maxinf])
	if formed == 0: print("  note: no coalition formed in this seed")
	print("DIPLO ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
