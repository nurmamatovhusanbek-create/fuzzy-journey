extends SceneTree
## Numbers behind the levy design: per era, province population and army, and what the nation manpower pool does now. Usage: -s tests/probe_levy.gd
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	for era in ["ancient", "roman", "medieval", "gunpowder", "napoleonic", "ww1", "coldwar"]:
		var g := TBGame.new(w, TBWorld.load_era("res://data", era), {"seed": 8})
		var pops := []; var armies := []
		var tp := 0; var ta := 0; var tm := 0.0; var tinc := 0
		var big := 0; var bigp := 0
		for n in range(1, g.N1):
			if g.alive[n] == 0 or n == g.rebel: continue
			var inc := g.income(n)
			tm += g.manpower[n]; tinc += int(inc["manpower"])
			for p in g.owned(n):
				pops.append(g.pop[p]); armies.append(g.army[p]); tp += g.pop[p]; ta += g.army[p]
		pops.sort(); armies.sort()
		print("%-10s provinces %4d pop sum %7d median %4d max %4d | army sum %6d median %3d max %5d | army/pop %.2f | manpower pools %6.0f gain/turn %5d" % [era, pops.size(), tp, pops[pops.size() / 2], pops[-1], ta, armies[armies.size() / 2], armies[-1], float(ta) / maxf(1.0, float(tp)), tm, tinc])
	quit()
