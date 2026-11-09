extends SceneTree
## Release a vassal on purpose; a united historic region becomes home land and pays more; the new lenses answer for every province. Usage: -s tests/n8.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	var n: int = g.nat_code.find("france"); var t: int = g.nat_code.find("spain")
	g.set_human(n)
	_check(not bool(g.can({"cmd": "release", "n": n, "t": t})["ok"]), "a nation that is not your vassal cannot be released")
	g.overlord[t] = n; g.tribute[t] = 30; g.liberty[t] = 40.0; g.infamy[n] = 10.0
	_check(bool(g.can({"cmd": "release", "n": n, "t": t})["ok"]), "a vassal can")
	var r := g.apply({"cmd": "release", "n": n, "t": t})
	_check(bool(r["ok"]) and g.overlord[t] == 0 and g.tribute[t] == 0 and g.infamy[n] < 10.0, "it goes free and the liberator's name improves")
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 4})
	_check(not bool(g4.can({"cmd": "release", "n": 1, "t": 2})["ok"]), "rules 4 has no release")
	# a united region
	var R := TBRealms.count()
	var ri := -1
	for i in R: if TBRealms.members(g, i).size() >= 6 and TBRealms.share(g, n, i) < 0.5: ri = i; break
	_check(ri >= 0, "a region to unite exists")
	var mem := TBRealms.members(g, ri)
	for p in mem: if g.owner[p] != n: g.set_owner(p, n)
	var inc0: int = int(g.income(n)["gold"]); var cnt0 := TBRealms.done_count(g, n)
	g.realm_done[n * R + ri] = 0
	g.turn = 2
	TBRealms.tick(g)
	_check(TBRealms.done_count(g, n) == cnt0 + 1, "the region counts as united")
	var homes := 0
	for p in mem: if g.core[p] == n: homes += 1
	_check(homes == mem.size(), "all its provinces are home land (%d of %d)" % [homes, mem.size()])
	_check(int(g.income(n)["gold"]) > inc0, "and the realm pays more (%d -> %d)" % [inc0, int(g.income(n)["gold"])])
	# the lenses
	var L := TBLenses.new(g)
	for lens in ["growth", "levy", "burden"]:
		L.mode = lens; L.prepare()
		var colours := {}
		for p in g.P: colours[L.color(p)] = true
		_check(colours.size() >= 2, "the %s lens has more than one colour (%d)" % [lens, colours.size()])
		_check(L.describe(g.capital_of[n]) != "", "and a tooltip for a province")
	print("N8 OK" if fails == 0 else "N8 FAIL %d" % fails)
	quit(fails)
