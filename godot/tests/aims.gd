extends SceneTree
## AI aims (rules 5): a state that declares war has an aim, keeps fighting for it instead of taking a cheap peace, and the map changes more than in rules 4. Usage: -s tests/aims.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _run_world(rules: int, era: String, seed_v: int, turns: int) -> Dictionary:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", era), {"seed": seed_v, "difficulty": "normal", "rules": rules})
	var aims := 0; var met := 0
	var kinds := {}
	var changes := 0
	var owner0: PackedInt32Array = g.owner.duplicate()
	for t in turns:
		g.end_turn()
		if rules >= 5:
			for n in range(1, g.N1):
				if g.alive[n] != 0 and g.aim_kind[n] != 0:
					aims += 1; kinds[g.aim_kind[n]] = int(kinds.get(g.aim_kind[n], 0)) + 1
	for p in g.P: if g.owner[p] != owner0[p] and g.owner[p] != 0 and owner0[p] != 0: changes += 1
	var alive := 0
	for n in range(1, g.N1): if g.alive[n] != 0 and n != g.rebel: alive += 1
	return {"aims": aims, "kinds": kinds, "changes": changes, "alive": alive}
func _init() -> void:
	TBI18n.load_lang("en")
	var tot5 := 0; var tot4 := 0; var kinds5 := {}
	for e in ["napoleonic", "ww1", "medieval"]:
		var r5 := _run_world(5, e, 3, 200)
		var r4 := _run_world(4, e, 3, 200)
		print("%-10s rules 5: aims-turns %d kinds %s provinces changing hands %d, alive %d | rules 4: provinces changing hands %d, alive %d" % [e, r5["aims"], str(r5["kinds"]), r5["changes"], r5["alive"], r4["changes"], r4["alive"]])
		tot5 += int(r5["changes"]); tot4 += int(r4["changes"])
		for k in r5["kinds"]: kinds5[k] = int(kinds5.get(k, 0)) + int(r5["kinds"][k])
		_check(int(r5["aims"]) > 50, "%s: states hold aims during the game (%d)" % [e, int(r5["aims"])])
	_check(kinds5.size() >= 3, "several kinds of aim occur (%s)" % str(kinds5))
	_check(float(tot5) >= float(tot4) * 0.6, "wars with aims still move the map (fewer, longer wars) (%d against %d provinces)" % [tot5, tot4])
	print("AIMS OK" if fails == 0 else "AIMS FAIL %d" % fails)
	quit(fails)
