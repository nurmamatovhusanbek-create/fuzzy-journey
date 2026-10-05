extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	TBI18n.load_lang("en")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8})
	var a := g.nat_code.find("france"); g.set_human(a); g.dp[a] = 10
	var base_gold: float = g.income(a)["gold"]; var base_cm := g.combat_mul(a)
	var r := g.apply({"cmd": "doctrine", "n": a, "id": "mercantile"})
	print("adopt mercantile: ", r, " dp=", g.dp[a], " gold ", base_gold, " -> ", g.income(a)["gold"])
	if not r["ok"] or g.doctrine[a] != 2 or g.dp[a] != 10.0 - TBDoctrine.ADOPT_DP: fails += 1
	if g.income(a)["gold"] <= base_gold: fails += 1
	if g.apply({"cmd": "doctrine", "n": a, "id": "mercantile"})["ok"]: fails += 1            # already adopted
	r = g.apply({"cmd": "doctrine", "n": a, "id": "martial"})                                  # switching costs more
	if not r["ok"] or g.doctrine[a] != 1 or g.dp[a] != 10.0 - TBDoctrine.ADOPT_DP - TBDoctrine.SWITCH_DP: fails += 1
	if g.combat_mul(a) <= base_cm: fails += 1
	g.dp[a] = 0
	if g.apply({"cmd": "doctrine", "n": a, "id": "administrative"})["ok"]: fails += 1          # no points
	if g.apply({"cmd": "doctrine", "n": a, "id": "bogus"})["ok"]: fails += 1
	var g0 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8, "rules": 0}); g0.set_human(a); g0.dp[a] = 10
	if g0.apply({"cmd": "doctrine", "n": a, "id": "martial"})["ok"]: fails += 1
	# AI nations adopt on their own
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 3})
	for t in 30: g2.end_turn()
	var counts := [0, 0, 0, 0]
	for n in range(1, g2.N1):
		if g2.alive[n] != 0 and n != g2.rebel: counts[g2.doctrine[n]] += 1
	print("AI doctrines after 30 turns (none/martial/mercantile/admin): ", counts)
	if counts[1] + counts[2] + counts[3] < 10: fails += 1
	for lang in ["en", "ru", "uz"]:
		TBI18n.load_lang(lang)
		for id in ["martial", "mercantile", "administrative"]:
			for k in ["doc_" + id, "doc_%s_d" % id]:
				if not TBI18n.has_key(k): print("missing ", k); fails += 1
	print("DOCTRINE ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
