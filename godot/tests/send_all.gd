extends SceneTree
## Rules 4 moves: the whole army may go (nothing is left behind by rule), from any province of yours, an army of one can move, and the army that took a province can go on or back.
## Rules < 4 keep the one man left behind. Usage: -s tests/send_all.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _pair(g: TBGame, me: int) -> Vector2i:
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.nb_sea[i] == 0 and g.owner[q] == me and g.controller(q) == me: return Vector2i(p, q)
	return Vector2i(-1, -1)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("france"); g.set_human(me); g.pending.clear()
	var pq := _pair(g, me)
	var p := pq.x; var q := pq.y
	g.mp[me] = 50.0
	g.army[p] = 12; g.army[q] = 3
	_check(g.keep() == 0, "rules 4 keeps nobody behind")
	var r := g.apply({"cmd": "move", "n": me, "from": p, "to": q, "troops": 12})
	_check(bool(r["ok"]) and g.army[p] == 0 and g.army[q] == 15, "the whole army goes (%s: %d left, %d there)" % [str(r.get("err", "ok")), g.army[p], g.army[q]])
	# an army of one can move
	g.army[q] = 1; g.army[p] = 0
	var r2 := g.apply({"cmd": "move", "n": me, "from": q, "to": p, "troops": 1})
	_check(bool(r2["ok"]) and g.army[q] == 0 and g.army[p] == 1, "an army of one moves (%s)" % str(r2.get("err", "ok")))
	_check(g.move_check(me, p, q) == "move", "the check agrees (%s)" % g.move_check(me, p, q))
	# nobody there: nothing to send
	g.army[q] = 0
	_check(g.move_check(me, q, p) == "!noarmy", "an empty province has nothing to send")
	# the army that took a province can go on or back: a lone survivor in a conquered land
	var en := -1
	for n in range(1, g.N1):
		if n != me and n != g.rebel and g.alive[n] != 0 and g.human[n] == 0 and g.own_count(n) > 3: en = n; break
	g.set_rel(me, en, TBData.REL_WAR)
	var tgt := -1; var src := -1
	for e in g.owned(en):
		for i in range(g.nb_off[e], g.nb_off[e + 1]):
			var nb: int = g.nb[i]
			if g.nb_sea[i] == 0 and g.owner[nb] == me: tgt = e; src = nb; break
		if tgt >= 0: break
	if tgt >= 0:
		g.army[src] = 60; g.army[tgt] = 2; g.mp[me] = 50.0
		var r3 := g.apply({"cmd": "move", "n": me, "from": src, "to": tgt, "troops": 60})
		_check(bool(r3["ok"]) and g.controller(tgt) == me, "the attack takes the province (%s)" % str(r3.get("result", r3.get("err", ""))))
		g.army[tgt] = 1                                                                    # a lone survivor
		var back := g.apply({"cmd": "move", "n": me, "from": tgt, "to": src, "troops": 1})
		_check(bool(back["ok"]), "the lone survivor can go back into your land (%s)" % str(back.get("err", "ok")))
		g.army[src] = 30
		var r4 := g.apply({"cmd": "move", "n": me, "from": src, "to": tgt, "troops": 30})
		g.army[tgt] = 1
		for i in range(g.nb_off[tgt], g.nb_off[tgt + 1]):
			var nx: int = g.nb[i]
			if g.nb_sea[i] == 0 and g.controller(nx) == en:
				g.army[nx] = 2
				var fwd := g.apply({"cmd": "move", "n": me, "from": tgt, "to": nx, "troops": 1})
				_check(bool(fwd["ok"]), "the lone survivor can attack on (%s)" % str(fwd.get("err", "ok")))
				break
	# the old rules keep one man behind
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var m3 := g3.nat_code.find("france"); g3.set_human(m3)
	var pq3 := _pair(g3, m3)
	_check(g3.keep() == 1, "rules 3 keeps one man behind")
	g3.army[pq3.x] = 10; g3.mp[m3] = 50.0
	g3.apply({"cmd": "move", "n": m3, "from": pq3.x, "to": pq3.y, "troops": 10})
	_check(g3.army[pq3.x] == 1, "rules 3: one stays (%d)" % g3.army[pq3.x])
	print("SEND_ALL OK" if fails == 0 else "SEND_ALL FAIL %d" % fails)
	quit(fails)
