extends SceneTree
## Rules 5: Raise troops = the levy pool first, the rest hired, one move point; can() and apply() agree; the old commands and rules < 5 are untouched. Usage: -s tests/raise.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 11, "rules": 5})
	var me := g.nat_code.find("france"); g.set_human(me); g.pending.clear()
	var p := -1
	for q in g.P: if g.owner[q] == me and (p < 0 or g.levy[q] > g.levy[p]): p = q
	g.gold[me] = 1e7; g.mp[me] = 10.0
	var pool: int = TBRaise.pool(g, p)
	_check(pool > 500, "a province with a levy pool (%d)" % pool)
	# inside the pool: all levy, no hired men
	var c1 := g.can({"cmd": "raise", "p": p, "amount": 300})
	_check(bool(c1["ok"]) and int(c1["levy"]) == 300 and int(c1["hired"]) == 0 and int(c1["hire_gold"]) == 0, "300 men come from the pool, none hired")
	_check(int(c1["gold"]) == TBCan.recruit_gold(g, p, 300, TBData.REGIMES[g.regime[me]]), "the price is the levy price")
	# past the pool: the rest is hired
	var over := pool + 193
	var c2 := g.can({"cmd": "raise", "p": p, "amount": over})
	_check(bool(c2["ok"]) and int(c2["levy"]) == pool and int(c2["hired"]) == 193, "%d men = the whole pool and 193 hired (%d + %d)" % [over, c2["levy"], c2["hired"]])
	_check(int(c2["gold"]) == int(c2["levy_gold"]) + int(c2["hire_gold"]) and int(c2["saved"]) > 0, "the total is the two parts, and it beats hiring all (saves %d)" % int(c2["saved"]))
	_check(int(c2["moves"]) == 1, "one move point")
	# apply does what can said
	var gold0: float = g.gold[me]; var mp0: float = g.mp[me]; var army0: int = g.army[p]; var levy0: int = g.levy[p]; var man0: float = g.manpower[me]
	var r := g.apply({"cmd": "raise", "n": me, "p": p, "amount": over})
	_check(bool(r.get("ok", false)), "apply accepts it")
	_check(absf((gold0 - g.gold[me]) - float(c2["gold"])) < 0.5, "gold taken = the quoted total (%.1f)" % (gold0 - g.gold[me]))
	_check(is_equal_approx(mp0 - g.mp[me], 1.0), "one move point taken")
	_check(g.army[p] == army0 + over, "the men stand in the province")
	_check(g.levy[p] == levy0 - pool, "the pool is emptied by the levy part only (%d)" % g.levy[p])
	_check(g.manpower[me] <= man0, "the people left the fields")
	# refusals
	g.gold[me] = 1.0
	_check(g.can({"cmd": "raise", "p": p, "amount": 500})["reason"] == "gold", "not enough gold is said")
	g.gold[me] = 1e7; g.mp[me] = 0.0
	_check(g.can({"cmd": "raise", "p": p, "amount": 5})["reason"] == "mp", "no move points is said")
	g.mp[me] = 10.0
	var other := -1
	for q in g.P: if g.owner[q] != me and g.owner[q] != 0: other = q; break
	_check(g.can({"cmd": "raise", "p": other, "amount": 5})["reason"] == "notyours", "not your land")
	# the cap
	var full := -1
	for q in g.P: if g.owner[q] == me and q != p: full = q; break
	g.army[full] = g.army_cap(full)
	_check(g.can({"cmd": "raise", "p": full, "amount": 5})["reason"] == "full", "a full province says so")
	# the old commands still work, and rules 4 does not know the new one
	_check(bool(g.can({"cmd": "hire", "p": p, "amount": g.au(40.0)})["ok"]) or g.can({"cmd": "hire", "p": p, "amount": g.au(40.0)})["reason"] == "", "hire is still there")
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 11, "rules": 4})
	g4.set_human(g4.nat_code.find("france"))
	_check(g4.can({"cmd": "raise", "p": 0, "amount": 5})["reason"] == "unknown", "rules 4: no raise")
	print("RAISE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
