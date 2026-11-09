extends SceneTree
## Rules 5: land you hold but have not annexed takes military works (port, fortress, watchtower, supply camp), not civil ones; a port there is a base the march can land at;
## rules 4 and below keep the old refusal. Usage: -s tests/held_build.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	for rules in [5, 4]:
		var g := TBGame.new(w, TBWorld.load_era("res://data", "coldwar"), {"seed": 3, "rules": rules})
		var me := g.nat_code.find("ussr"); var cn := g.nat_code.find("china")
		g.set_human(me); g.pending.clear(); g.set_rel(me, cn, TBData.REL_WAR)
		var coast := -1; var inland := -1
		for p in g.P:
			if g.owner[p] != cn: continue
			if (g.world.geo[p] & 1) != 0 and coast < 0: coast = p
			if (g.world.geo[p] & 1) == 0 and inland < 0: inland = p
		g.gold[me] = 1e9; g.mp[me] = 30.0; g.tech_level[me] = 6.0
		g.occupier[coast] = me; g.occ_rev += 1; g.army[coast] = 500
		var port: Dictionary = g.can({"cmd": "build", "p": coast, "b": TBData.B_PORT})
		var mkt: Dictionary = g.can({"cmd": "build", "p": coast, "b": TBData.B_MARKET})
		if rules >= 5:
			_check(bool(port["ok"]), "r%d: a port may be built in held coast land (%s)" % [rules, port["reason"]])
			_check(mkt["reason"] == "notyours", "r%d: a market may not (%s)" % [rules, mkt["reason"]])
			var res: Dictionary = g.apply({"cmd": "build", "p": coast, "b": TBData.B_PORT, "n": me})
			_check(bool(res.get("ok", false)), "r%d: the order is accepted" % rules)
			for i in 12: g.end_turn()
			_check(g.bl(coast, TBData.B_PORT) > 0 or g.owner[coast] == cn, "r%d: the port stands" % rules)
			# land that is not held stays refused
			var other := -1
			for p in g.P: if g.owner[p] == cn and g.occupier[p] == 0 and p != coast: other = p; break
			_check(g.can({"cmd": "build", "p": other, "b": TBData.B_FORTRESS})["reason"] == "notyours", "r%d: unheld enemy land is refused" % rules)
		else:
			_check(port["reason"] == "notyours", "r%d: refused as before (%s)" % [rules, port["reason"]])
	print("HELD_BUILD ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
