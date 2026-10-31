extends SceneTree
## Rules 4 battles: three rounds, deterministic, a range around the expected result, survivors retreat. Usage: -s tests/battle.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	# the pure function
	var a := TBBattle.fight(100, 1.0, 100, 1.0)
	_check(a == TBBattle.fight(100, 1.0, 100, 1.0), "the same battle always ends the same way")
	_check(not bool(a["win"]), "equal strength: the defender holds (a tie goes to the one who was attacked)")
	var even: Dictionary = TBBattle.fight(100, 1.0, 100, 1.0)
	_check(int(even["a_lost"]) >= 30 and int(even["a_lost"]) <= 60, "an even fight costs about a third to a half of the men (%d)" % int(even["a_lost"]))
	var two: Dictionary = TBBattle.fight(200, 1.0, 100, 1.0)
	_check(bool(two["win"]), "two to one wins")
	_check(int(two["a_lost"]) * 2 < int(two["d_lost"]) * 1.0 + 1.0, "concentration pays: at two to one the winner loses far fewer than the loser (%d vs %d)" % [int(two["a_lost"]), int(two["d_lost"])])
	var big: Dictionary = TBBattle.fight(400, 1.0, 100, 1.0)
	_check(int(big["d_left"]) > 0, "even a crushing army does not annihilate in one battle (%d defenders left)" % int(big["d_left"]))
	var hopeless: Dictionary = TBBattle.fight(50, 1.0, 200, 1.0)
	_check(not bool(hopeless["win"]) and int(hopeless["a_left"]) > 0 and int(hopeless["a_left"]) < 50, "a hopeless attack leaves survivors who can retreat (%d of 50)" % int(hopeless["a_left"]))
	# monotone: more attackers never makes it worse
	var prev := -1.0e9
	for m in [60, 80, 100, 120, 160, 220]:
		var r := TBBattle.fight(m, 1.0, 100, 1.0)
		var score: float = float(r["a_left"]) - float(r["d_left"])
		_check(score >= prev, "more men never hurt (%d men: %.0f after %.0f)" % [m, score, prev])
		prev = score
	var rg := TBBattle.ranged(100, 1.0, 100, 1.0)
	_check(int(rg["best"]["a_left"]) >= int(rg["expected"]["a_left"]) and int(rg["worst"]["a_left"]) <= int(rg["expected"]["a_left"]), "best case >= expected >= worst case")
	# the game
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("france"); g.set_human(me)
	var foe := -1; var from := -1; var to := -1
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.owner[q] != 0 and g.owner[q] != me and g.nb_sea[i] == 0 and foe < 0: foe = g.owner[q]; from = p; to = q
	_check(foe > 0, "an enemy border exists")
	g.set_rel(me, foe, 1); g.mp[me] = 10.0
	g.army[from] = 500; g.army[to] = 100; g.terrain[to] = 0
	var pv := g.combat_preview(me, from, to, 400)
	_check(pv.has("range") and bool(pv["win"]), "the preview carries a range and says win at 4 to 1 (%s)" % str(pv.get("win")))
	var prev_hold: int = int(pv["hold"])
	var home_after: int = g.army[from] - 400
	var r2 := g.resolve_combat(me, from, to, 400)
	_check(r2 == "win" and g.controller(to) == me, "the province is taken")
	_check(g.army[to] == prev_hold, "what the preview said holds the province (%d vs %d)" % [g.army[to], prev_hold])
	_check(g.army[from] == home_after, "the men that stayed home are untouched")
	# a failed attack: survivors come home
	g.occupier[to] = 0; g.army[from] = 300; g.army[to] = 400
	var before_home: int = g.army[from] - 250
	var r3 := g.resolve_combat(me, from, to, 250)
	_check(r3 == "loss" and g.army[from] > before_home and g.army[from] < 300, "a failed attack brings the survivors home (%d of %d)" % [g.army[from] - before_home, 250])
	_check(g.army[to] > 0, "the defender keeps the field")
	# rules 3 is unchanged: its preview has no range
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var m3 := g3.nat_code.find("france"); g3.set_human(m3)
	var p3: int = g3.owned(m3)[0]
	var q3 := -1
	for i in range(g3.nb_off[p3], g3.nb_off[p3 + 1]): if g3.nb_sea[i] == 0 and q3 < 0: q3 = g3.nb[i]
	_check(not g3.combat_preview(m3, p3, q3, 5).has("range"), "rules 3 keeps the old single verdict")
	print("BATTLE OK" if fails == 0 else "BATTLE FAIL %d" % fails)
	quit(fails)
