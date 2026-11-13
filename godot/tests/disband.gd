extends SceneTree
## Rules 5: Disband sends men home (half back to the levy pool and the nation's manpower), costs one move point, keeps the garrison minimum, is refused without an army, and is unknown before rules 5. Usage: -s tests/disband.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 11, "rules": 5})
	var me := g.nat_code.find("france"); g.set_human(me); g.pending.clear()
	var cap: int = g.capital_of[me]
	g.mp[me] = 10.0
	g.levy[cap] = 0                                                    # room in the pool for the men who come back
	var army0: int = g.army[cap]; var man0: float = g.manpower[me]
	var c := g.can({"cmd": "disband", "p": cap, "amount": 2000})
	_check(bool(c["ok"]) and int(c["gain"]) == 2000 and int(c["levy"]) == 1000 and int(c["moves"]) == 1, "2000 leave, 1000 go back to the pool, one move (%s)" % str(c["reason"]))
	var r := g.apply({"cmd": "disband", "n": me, "p": cap, "amount": 2000})
	_check(bool(r.get("ok", false)), "apply accepts it")
	_check(g.army[cap] == army0 - 2000, "the army is smaller by 2000 (%d)" % (army0 - g.army[cap]))
	_check(g.levy[cap] == 1000, "half are back in the levy pool (%d)" % g.levy[cap])
	_check(g.manpower[me] >= man0, "the nation's manpower did not drop")
	_check(is_equal_approx(g.mp[me], 9.0), "one move point")
	# the garrison minimum stays
	var hi := TBRaise.disband_max(g, cap)
	g.apply({"cmd": "disband", "n": me, "p": cap, "amount": 99999999})
	_check(g.army[cap] == g.keep(), "never below the garrison minimum (%d)" % g.army[cap])
	_check(g.can({"cmd": "disband", "p": cap, "amount": 5})["reason"] == "noarmy", "nothing left to disband says so")
	# another nation's province, and the old rules
	var other := -1
	for q in g.P: if g.owner[q] != me and g.owner[q] != 0: other = q; break
	_check(g.can({"cmd": "disband", "p": other, "amount": 5})["reason"] == "notyours", "not your army")
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 11, "rules": 4})
	g4.set_human(g4.nat_code.find("france"))
	_check(g4.can({"cmd": "disband", "p": 0, "amount": 5})["reason"] == "unknown", "rules 4: unknown")
	print("DISBAND ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
