extends SceneTree
## Soak: a random-command human plays 150 turns in every era; engine invariants must hold throughout.
func _check(g: TBGame, tag: String) -> int:
	var bad := 0
	for p in g.P:
		if g.army[p] < 0 or g.army[p] > 65000: bad += 1; print(tag, " army ", p, g.army[p])
		if g.stab[p] > 100 or g.happy[p] > 100: bad += 1
		if g.owner[p] < 0 or g.owner[p] >= g.N1: bad += 1
	for n in range(1, g.N1):
		if is_nan(g.gold[n]) or is_inf(g.gold[n]) or g.gold[n] < 0.0: bad += 1; print(tag, " gold ", n, g.gold[n])
		if g.manpower[n] < 0.0 or is_nan(g.manpower[n]): bad += 1; print(tag, " manpower ", n)
		if g.infamy[n] < 0.0 or g.infamy[n] > 100.0: bad += 1; print(tag, " infamy ", n)
		if g.alive[n] != 0 and g.r_name[n] == "" and n != g.rebel: bad += 1; print(tag, " no ruler ", n)
		if g.trade_cnt[n] > 0 and TBTrade.partners(g, n).size() != g.trade_cnt[n]: bad += 1; print(tag, " trade count ", n)
	return bad
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var total_bad := 0
	for era_id in ["", "ancient", "medieval", "discovery", "napoleonic", "ww1", "coldwar"]:
		var era := TBWorld.load_era("res://data", era_id) if era_id != "" else {}
		var g := TBGame.new(w, era, {"seed": 12})
		var n := 0
		for k in range(1, g.N1): if k != g.rebel and g.alive[k] != 0 and g.own_count(k) >= 8: n = k; break
		g.set_human(n)
		var cmds := 0; var errs := 0
		for t in 150:
			if g.alive[n] == 0: break
			for i in 6:
				var own := g.owned(n)
				if own.is_empty(): break
				var p := own[rng.randi() % own.size()]
				var o := 1 + rng.randi() % g.N
				var c: Dictionary
				match rng.randi() % 9:
					0: c = {"cmd": "recruit", "p": p, "amount": 15}
					1: c = {"cmd": "build", "p": p, "b": 1 + rng.randi() % 9}
					2: c = {"cmd": "decide", "id": TBDecisions.LIST[rng.randi() % TBDecisions.LIST.size()]["id"]}
					3: c = {"cmd": "trade", "t": o}
					4: c = {"cmd": "declareWar", "t": o}
					5: c = {"cmd": "peace", "t": o, "kind": ["white", "cede", "vassal"][rng.randi() % 3]}
					6: c = {"cmd": "spy", "t": o, "op": ["steal", "sabotage", "incite"][rng.randi() % 3]}
					7: c = {"cmd": "ally", "t": o}
					_: c = {"cmd": "move", "from": p, "to": g.nb[g.nb_off[p]], "troops": maxi(0, g.army[p] - 1)}
				c["n"] = n
				var r := g.apply(c); cmds += 1
				if not r["ok"]: errs += 1
			for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": rng.randi() % maxi(1, int(e["count"]))})
			g.end_turn()
			if t % 25 == 0: total_bad += _check(g, "%s t%d" % [era_id, t])
		total_bad += _check(g, era_id + " end")
		print("%-10s ok: %d commands (%d refused), turn %d, alive %d, over=%s kind=%s winner=%d human_alive=%d" % [era_id if era_id != "" else "modern", cmds, errs, g.turn, g.alive.count(1), str(g.over), g.victory_kind, g.winner, g.alive[n]])
	print("SOAK ", "OK" if total_bad == 0 else "FAIL (%d)" % total_bad)
	quit(1 if total_bad > 0 else 0)
