extends SceneTree
## Undo: an order can be taken back (state identical to before), several in a row, never past a roll of the dice, and the game object stays the same one. Usage: -s tests/undo.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _digest(g: TBGame) -> int:
	return hash([g.gold, g.mp, g.army, g.pop, g.levy, g.manpower, g.owner, g.dev, g.b_building, g.rng.s, g.log.size(), g.marches.size()])
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	var n: int = g.nat_code.find("france")
	g.set_human(n); g.gold[n] = 100000.0; g.mp[n] = 20.0
	var u := TBUndo.new()
	var ref := g
	var cap: int = g.capital_of[n]
	var d0 := _digest(g)
	u.push(g); var r1 := g.apply({"cmd": "n", "n": n}); u.drop_last()
	_check(not u.can(), "a refused order leaves nothing to undo")
	# two orders
	u.push(g); var a := g.apply({"cmd": "spread", "n": n, "p": cap})
	_check(bool(a["ok"]), "spread (%s)" % str(a.get("err", "")))
	var d1 := _digest(g)
	u.push(g); var b := g.apply({"cmd": "muster", "n": n, "pct": 25})
	_check(bool(b["ok"]), "muster (%s)" % str(b.get("err", "")))
	_check(_digest(g) != d1 and u.size() == 2, "the second order changed the game and was recorded")
	_check(u.undo(g) and _digest(g) == d1, "undo takes the muster back exactly")
	_check(u.undo(g) and _digest(g) == d0, "and the spread, back to the first state")
	_check(not u.undo(g), "nothing left to undo")
	_check(g == ref, "the same game object is still in use")
	# the game goes on normally from a restored state, and matches a game that never had the orders
	var gb := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	gb.set_human(n); gb.gold[n] = 100000.0; gb.mp[n] = 20.0
	for t in 5: g.end_turn(); gb.end_turn()
	_check(hash([g.gold, g.pop, g.army]) == hash([gb.gold, gb.pop, gb.army]), "five turns after an undo are the turns of a game that never had the orders")
	# the stack is bounded
	for i in 20: u.push(g)
	_check(u.size() == TBUndo.MAX, "at most %d orders can be undone (%d)" % [TBUndo.MAX, u.size()])
	print("UNDO OK" if fails == 0 else "UNDO FAIL %d" % fails)
	quit(fails)
