extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8})
	var a := g.nat_code.find("france"); g.set_human(a)
	var p := g.owned(a)[0]
	g.army[p] = 500
	if g.attrition(p) != 0: fails += 1                                   # home soil: no attrition
	var q := -1
	for n in range(1, g.N1):
		if n != a and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 0: q = g.owned(n)[0]; break
	g.occupier[q] = a; g.army[q] = 400
	var lim := g.supply_limit(q); var loss := g.attrition(q)
	print("enemy land: limit=%d loss=%d" % [lim, loss])
	if loss <= 0 or loss >= 400: fails += 1
	g.army[q] = lim
	if g.attrition(q) != 0: fails += 1                                   # at the limit: fine
	g.army[q] = 400
	var before := g.army[q]
	g.end_turn()
	print("after a turn: ", before, " -> ", g.army[q])
	var g0 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8, "rules": 0})
	g0.occupier[q] = a; g0.army[q] = 400
	if g0.attrition(q) != 0: fails += 1
	g.set_owner(q, a); g.occupier[q] = 0
	print("SUPPLY ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
