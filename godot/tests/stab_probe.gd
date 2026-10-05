extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 7})
	var oe := g.nat_code.find("ottoman_empire")
	var prev := 0.0
	for t in range(1, 80):
		g.end_turn()
		var s := 0.0; var c := 0; var occ := 0
		for p in g.owned(oe): s += g.stab[p]; c += 1; if g.occupier[p] != 0: occ += 1
		var avg := s / maxf(1, c)
		var wars := 0
		for o in range(1, g.N1): if g.get_rel(oe, o) == 1: wars += 1
		if t % 4 == 0: print("t=%d avgStab=%.1f d=%.2f provs=%d occupied=%d wars=%d war_cnt=%d tax=%d goods=%d" % [t, avg, avg - prev, c, occ, wars, g.war_cnt[oe], g.budget[oe * 4], g.budget[oe * 4 + 1]])
		prev = avg
	quit()
