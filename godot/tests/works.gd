extends SceneTree
## State works (rules 5): each level costs turns of the realm's own output (half as much again for the next), changes the thing it promises, is refused without gold or moves,
## and the AI buys them: the biggest treasuries shrink. Usage: -s tests/works.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	var n: int = g.nat_code.find("france")
	g.set_human(n)
	var inc: int = int(g.income(n)["gold"])
	for i in TBWorks.LIST.size():
		var c: int = TBWorks.cost(g, n, i)
		print("%-10s first level costs %d (%.1f turns of income)" % [TBWorks.LIST[i]["id"], c, float(c) / float(inc)])
		_check(c > inc * 2 and c < inc * 40, "%s costs several turns of income, not one and not a lifetime" % TBWorks.LIST[i]["id"])
	g.gold[n] = 0.0; g.mp[n] = 10.0
	_check(not bool(g.can({"cmd": "works", "n": n, "id": "academy"})["ok"]) and g.can({"cmd": "works", "n": n, "id": "academy"})["reason"] == "gold", "no gold, no works")
	g.gold[n] = 9.0e6
	g.gold[n] = 9.0e6
	var c1 := TBWorks.cost(g, n, 0)
	var res0 := TBWorks.research_mul(g, n); var cap0 := g.pop_cap(g.capital_of[n]); var adm0 := TBWorks.admin_mul(g, n)
	var r := g.apply({"cmd": "works", "n": n, "id": "academy"})
	_check(bool(r["ok"]) and TBWorks.level(g, n, 0) == 1, "a level is built")
	_check(absf(g.gold[n] - (9.0e6 - c1)) < 1.0, "and charged")
	_check(TBWorks.research_mul(g, n) > res0, "research is faster")
	var c2 := TBWorks.cost(g, n, 0)
	_check(float(c2) / float(c1) > 1.45 and float(c2) / float(c1) < 1.55, "the next level costs half as much again (%.2f)" % (float(c2) / float(c1)))
	g.apply({"cmd": "works", "n": n, "id": "granaries"})
	_check(g.pop_cap(g.capital_of[n]) > cap0, "the land feeds more")
	g.apply({"cmd": "works", "n": n, "id": "roads"})
	_check(TBWorks.admin_mul(g, n) < adm0, "administration is cheaper")
	for k in 6: g.mp[n] = 10.0; g.apply({"cmd": "works", "n": n, "id": "academy"})
	for k in 10: g.mp[n] = 10.0; g.apply({"cmd": "works", "n": n, "id": "academy"})
	_check(TBWorks.level(g, n, 0) == int(TBWorks.LIST[0]["max"]), "a work stops at its top level (%d)" % TBWorks.level(g, n, 0))
	var sv: Dictionary = TBSave.to_dict(g)
	var g2: TBGame = TBSave.from_dict(w, sv)
	_check(g2 != null and TBWorks.level(g2, n, 0) == 5, "levels survive a save")
	# the AI buys them
	var ga := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "difficulty": "normal", "rules": 5})
	for t in 60: ga.end_turn()
	var bought := 0
	for k in range(1, ga.N1):
		if ga.alive[k] == 0 or k == ga.rebel: continue
		for i in TBWorks.COUNT: bought += TBWorks.level(ga, k, i)
	print("AI works bought in 60 turns: ", bought)
	_check(bought >= 20, "the AI builds state works (%d levels)" % bought)
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "difficulty": "normal", "rules": 4})
	_check(not bool(g4.can({"cmd": "works", "n": 1, "id": "academy"})["ok"]), "rules 4 has none")
	print("WORKS OK" if fails == 0 else "WORKS FAIL %d" % fails)
	quit(fails)
