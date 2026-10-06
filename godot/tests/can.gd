extends SceneTree
## TBGame.can(): read-only (state checksum unchanged) and in step with TBGame.apply() (same ok / error code, same costs)
## on random commands over several eras. "refused" (the AI's answer to a proposal) is the only outcome can() does not predict.
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var fails := 0
	var checked := 0
	var oks := 0
	var seen := {}
	for era in ["ancient", "medieval", "napoleonic", "modern"]:
		var era_pack: Dictionary = TBWorld.load_era("res://data", era) if era != "modern" else {}
		var g := TBGame.new(w, era_pack, {"seed": 3 + rng.randi() % 50})
		var me := rng.randi_range(1, g.N)
		while g.owned(me).is_empty() or me == g.rebel: me = rng.randi_range(1, g.N)
		g.set_human(me)
		for step in 400:
			if step % 28 == 0:
				g.gold[me] = rng.randf_range(0, 900); g.mp[me] = rng.randi_range(0, 9); g.dp[me] = rng.randi_range(0, 8); g.manpower[me] = rng.randf_range(0, 400)
			if step % 50 == 49: g.end_turn(); g.set_human(me)
			if g.alive[me] == 0: break
			var own := g.owned(me)
			var cmd := _random_cmd(g, me, own, rng)
			var sum0 := g.state_checksum()
			var pre := g.can(cmd)
			if g.state_checksum() != sum0:
				print("FAIL can() changed the state: ", cmd); fails += 1; break
			var gold0 := g.gold[me]; var mp0 := g.mp[me]; var man0 := g.manpower[me]; var dp0 := g.dp[me]
			var r := g.apply(cmd)
			checked += 1
			var key: String = "%s:%s" % [cmd["cmd"], pre["reason"]]
			seen[key] = true
			if r["ok"] != pre["ok"]:
				if not r["ok"] and r["err"] == "refused" and pre["ok"]: continue      # the AI said no: not predictable
				if r["ok"] and not pre["ok"] and cmd["cmd"] == "peace": pass
				print("FAIL ok mismatch: ", cmd, " can=", pre, " apply=", r); fails += 1
				continue
			if not r["ok"]:
				if r["err"] != pre["reason"] and r["err"] != "refused":
					print("FAIL reason mismatch: ", cmd, " can=", pre["reason"], " apply=", r["err"]); fails += 1
				continue
			oks += 1
			var d_gold := gold0 - g.gold[me]; var d_mp := mp0 - g.mp[me]; var d_man := man0 - g.manpower[me]; var d_dp := dp0 - g.dp[me]
			match String(cmd["cmd"]):
				"recruit", "hire", "build", "colonize", "develop":
					if absf(d_gold - float(pre["gold"])) > 0.05 or absf(d_mp - float(pre["moves"])) > 0.05 or absf(d_man - float(pre["men"])) > 0.05:
						print("FAIL cost mismatch: ", cmd, " can=", pre, " dgold=", d_gold, " dmp=", d_mp, " dman=", d_man); fails += 1
				"move":
					if absf(d_mp - float(pre["moves"])) > 0.05: print("FAIL move cost: ", cmd, pre, d_mp); fails += 1
				"nap", "ally", "marry", "trade":
					if absf(d_dp - float(pre["dp"])) > 0.05: print("FAIL dp cost: ", cmd, pre, d_dp); fails += 1
				"declareWar":
					if absf(d_dp - float(pre["dp"])) > 0.05: print("FAIL war dp: ", cmd, pre, d_dp); fails += 1
	print("checked=%d ok-applied=%d distinct(cmd:reason)=%d" % [checked, oks, seen.size()])
	if oks < 80 or seen.size() < 25: print("FAIL too little coverage"); fails += 1
	# a dead / unknown nation and a malformed command are refused, not crashed on
	var g2 := TBGame.new(w, {}, {"seed": 1})
	if g2.can({"cmd": "recruit", "n": 0, "p": 0})["ok"]: fails += 1
	if g2.can({"cmd": "nonsense", "n": 1})["reason"] != "unknown": fails += 1
	print("CAN ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)

func _random_cmd(g: TBGame, me: int, own: PackedInt32Array, rng: RandomNumberGenerator) -> Dictionary:
	var p: int = own[rng.randi() % own.size()]
	var q: int = rng.randi() % g.P
	var t: int = rng.randi_range(1, g.N)
	match rng.randi() % 16:
		0: return {"cmd": "recruit", "n": me, "p": p if rng.randf() < 0.85 else q, "amount": [5, 15, 30][rng.randi() % 3]}
		1: return {"cmd": "hire", "n": me, "p": p if rng.randf() < 0.85 else q, "amount": [10, 40, 60][rng.randi() % 3]}
		2: return {"cmd": "appoint", "n": me, "p": p}
		3: return {"cmd": "build", "n": me, "p": p, "b": rng.randi_range(0, 9)}
		4: return {"cmd": "colonize", "n": me, "p": q}
		5: return {"cmd": "develop", "n": me, "p": p}
		6: return {"cmd": "declareWar", "n": me, "t": t}
		7: return {"cmd": "peace", "n": me, "t": t, "kind": ["white", "cede", "vassal"][rng.randi() % 3]}
		8: return {"cmd": "ally", "n": me, "t": t}
		9: return {"cmd": "nap", "n": me, "t": t}
		10: return {"cmd": "breakPact", "n": me, "t": t}
		11: return {"cmd": "ultimatum", "n": me, "t": t, "p": q}
		12: return {"cmd": "marry", "n": me, "t": t}
		13: return {"cmd": "trade", "n": me, "t": t}
		_:
			var from := p
			var to := q
			if g.nb_off[from + 1] > g.nb_off[from] and rng.randf() < 0.9:
				to = g.nb[g.nb_off[from] + rng.randi() % (g.nb_off[from + 1] - g.nb_off[from])]
			if rng.randf() < 0.5: g.army[from] = maxi(g.army[from], rng.randi_range(2, 60))
			return {"cmd": "move", "n": me, "from": from, "to": to, "troops": [0, 5, 20][rng.randi() % 3]}
