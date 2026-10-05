extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8})
	var a := g.nat_code.find("france"); var b := g.nat_code.find("spanish_habsburg")
	g.set_human(a); g.dp[a] = 10
	print("can marry: ", TBDiplo.can_marry(g, a, b), " regimes ", g.regime[a], g.regime[b])
	var r := g.apply({"cmd": "marry", "n": a, "t": b}); print("marry: ", r)
	if r["ok"] and g.get_rel(a, b) != 4: fails += 1
	var marriages := 0; var unions := 0; var lapsed := 0
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 3})
	for t in 250: g2.end_turn()
	for e in g2.log:
		match e["kind"]:
			"marriage": marriages += 1
			"union": unions += 1
			"marriage_end": lapsed += 1
	print("250 turns: marriages=%d lapsed=%d unions=%d" % [marriages, lapsed, unions])
	if marriages == 0: fails += 1
	print("MARRIAGE ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
