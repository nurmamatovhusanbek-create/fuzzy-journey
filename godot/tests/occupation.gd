extends SceneTree
## Rules 4 occupation: the occupier collects half the tax, the people resist (a thin garrison loses ground, a strong one gains it), a province that rises returns to its owner, and land never changes hands without a treaty.
## Usage: -s tests/occupation.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var a := g.nat_code.find("france"); var b := -1
	for n in range(1, g.N1):
		if n != a and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 5: b = n; break
	g.set_human(a); g.pending.clear()
	g.set_rel(a, b, TBData.REL_WAR)
	var bl: Array = g.owned(b)
	var p: int = bl[0]
	for q0 in bl: if g.pop[q0] > g.pop[p]: p = q0
	var inc0 := g.income(a)
	_check(int(inc0["occTax"]) == 0, "nothing occupied, nothing collected")
	g.occupier[p] = a; g.occ_rev += 1; g.unrest[p] = TBWar.RES_START; g.siege[p] = 0
	var inc1 := g.income(a)
	var expect := int(floor(float(g.pop[p]) / 20.0 * (float(g.budget[a * 4]) / 100.0) * (float(g.happy[p]) / 100.0) * float(TBData.REGIMES[g.regime[a]]["incTax"]) * TBWar.OCC_SHARE))
	_check(int(inc1["occTax"]) == expect and expect > 0, "the occupier collects half the tax (%d, expected %d)" % [int(inc1["occTax"]), expect])
	g.siege[p] = 2; g.occ_rev += 1
	_check(int(g.income(a)["occTax"]) == 0, "a province still under siege pays the occupier nothing")
	g.siege[p] = 0; g.occ_rev += 1
	# a thin garrison: resistance climbs by 3 a turn
	g.army[p] = 1
	var turns := 0
	var rose := false
	while turns < 40 and not rose:
		turns += 1
		var before: int = g.unrest[p]
		rose = TBWar.resist(g, p)
		if not rose: _check(g.unrest[p] == before + TBWar.RES_UP, "resistance climbs %d a turn (%d)" % [TBWar.RES_UP, g.unrest[p]])
	_check(rose and turns == int(ceil(float(100 - TBWar.RES_START) / float(TBWar.RES_UP))), "the province rises after %d turns" % turns)
	_check(g.occupier[p] == 0 and g.owner[p] == b, "it returns to its owner")
	_check(g.war_pts[b * g.N1 + a] >= TBWar.RES_POINTS, "the owner gains war score from the uprising")
	# a strong garrison: resistance falls
	g.occupier[p] = a; g.occ_rev += 1; g.unrest[p] = 60
	g.army[p] = int(float(g.pop[p]) * TBWar.RES_GARRISON) + 5
	TBWar.resist(g, p)
	_check(g.unrest[p] == 60 - TBWar.RES_DOWN, "a strong garrison calms the people (%d)" % g.unrest[p])
	# no annexation without a treaty
	var q: int = bl[1] if bl[1] != p else bl[2]
	g.occupier[q] = a; g.occ_rev += 1; g.occ_turns[q] = 200; g.army[q] = 2000
	for i in 3: g.end_turn()
	_check(g.owner[q] == b, "land is not annexed by sitting on it (owner %d)" % g.owner[q])
	# the older rules still annex
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	_check(g3.unrest.size() == g3.P and g3.income(1).get("occTax", 0) == 0, "rules 3 has no occupation income")
	print("OCCUPATION OK" if fails == 0 else "OCCUPATION FAIL %d" % fails)
	quit(fails)
