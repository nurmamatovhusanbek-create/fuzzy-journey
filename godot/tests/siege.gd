extends SceneTree
## Rules 4 sieges and supply reach: a field win over a fortified province starts a siege (the owner keeps paying taxes until it falls, a bigger fort and the capital hold longer, a relieving victory ends it),
## and an army four provinces from friendly land starves faster. Usage: -s tests/siege.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var a := g.nat_code.find("france"); var b := -1
	for n in range(1, g.N1):
		if n != a and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 3: b = n; break
	g.set_human(a); g.pending.clear()
	var p: int = -1
	for q in g.owned(b):
		if g.capital[q] == 0 and g.nb_off[q + 1] - g.nb_off[q] >= 2: p = q; break
	var x: int = -1
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		if g.nb_sea[i] == 0: x = g.nb[i]; break
	g.set_owner(x, a); g.occupier[x] = 0
	g.set_rel(a, b, TBData.REL_WAR)
	_check(g.siege_len(p) == 0, "an unfortified province has no siege")
	g.set_bl(p, TBData.B_FORTRESS, 1)
	_check(g.siege_len(p) == 2, "a level 1 fort holds for two turns")
	g.set_bl(p, TBData.B_FORTRESS, 2)
	_check(g.siege_len(p) == 3, "a level 2 fort holds for three turns")
	g.set_bl(p, TBData.B_FORTRESS, 1)
	g.army[x] = 6000; g.army[p] = 30; g.mp[a] = 30.0
	var tax_b0 := int(g.income(b)["tax"])
	var res := g.move_or_attack(a, x, p, 0)
	_check(res == "win", "the field battle is won (%s)" % res)
	_check(g.occupier[p] == a and g.owner[p] == b, "the host stands in the province, the owner is still the owner")
	_check(g.siege[p] == 2, "the siege begins (%d turns)" % g.siege[p])
	var tax_b1 := int(g.income(b)["tax"])
	_check(tax_b1 >= tax_b0 - 1, "a besieged province still pays its owner (%d -> %d)" % [tax_b0, tax_b1])
	var held: int = 0
	for q in g.owned(b): if g.occupier[q] == a and g.siege[q] == 0: held += 1
	_check(held == 0, "a besieged province does not count as taken for the war score")
	g.army[p] = 10                                                       # a thin host works slowly
	g.set_rel(a, b, TBData.REL_WAR)
	g.end_turn()
	_check(g.siege[p] == 1 and g.occupier[p] == a, "one turn later the siege has a turn to go (%d)" % g.siege[p])
	g.army[p] = 6000                                                     # a strong host is quicker: two turns' work at once
	g.set_rel(a, b, TBData.REL_WAR)
	g.end_turn()
	_check(g.siege[p] == 0 and g.occupier[p] == a and g.owner[p] == b, "the fort falls: the province is occupied")
	var tax_b2 := int(g.income(b)["tax"])
	_check(tax_b2 < tax_b0, "an occupied province no longer pays its owner (%d -> %d)" % [tax_b0, tax_b2])
	# the owner relieves a siege
	g.occupier[p] = 0
	g.set_rel(a, b, TBData.REL_WAR)
	g.set_owner(x, a); g.occupier[x] = 0
	g.army[x] = 6000; g.army[p] = 30
	g.move_or_attack(a, x, p, 0)
	_check(g.siege[p] > 0 and g.occupier[p] == a, "a second siege begins")
	g.army[p] = 500
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		var y: int = g.nb[i]
		if g.nb_sea[i] == 0 and y != x and g.owner[y] == b and g.occupier[y] == 0:
			g.army[y] = 20000; g.mp[b] = 30.0
			var rr := g.move_or_attack(b, y, p, 0)
			_check(rr == "win" and g.occupier[p] == 0 and g.siege[p] == 0, "a relieving army that wins ends the siege (%s)" % rr)
			break
	# supply reach
	var deep: int = -1
	var depth := -1
	for q in g.P:
		if g.owner[q] != 0 and g.owner[q] != a and not g.friendly(a, g.owner[q]):
			var d := g.supply_depth(q, a)
			if d >= TBGame.SUPPLY_REACH: deep = q; depth = d; break
	_check(deep >= 0, "some province lies out of reach of friendly land")
	if deep >= 0:
		g.occupier[deep] = a; g.occupier[deep] = 0
		g.army[deep] = 1000
		_check(g.attrition(deep) == 0 or g.controller(deep) != a, "an army that is not the controller's is not starved")
		g.occupier[deep] = a
		var near := g.attrition(deep)
		_check(near >= int(ceil(1000 * TBGame.SUPPLY_FAR)), "four provinces from home an army starves faster (%d)" % near)
		g.occupier[deep] = 0
	var home: int = -1
	for q in g.owned(a): if g.occupier[q] == 0: home = q; break
	_check(g.supply_depth(home, a) == 0, "own land is supplied")
	var old := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	_check(old.attrition(0) == 0 and old.siege_len(0) >= 0, "rules 3 unchanged")
	print("SIEGE OK" if fails == 0 else "SIEGE FAIL %d" % fails)
	quit(fails)
