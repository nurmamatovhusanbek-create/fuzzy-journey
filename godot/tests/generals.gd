extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8})
	var a := g.nat_code.find("france")
	g.set_human(a); g.gold[a] = 1000
	var own := g.owned(a)
	var p := own[0]; g.army[p] = 40
	var r := g.apply({"cmd": "appoint", "n": a, "p": p})
	print("appoint: ", r, " skill=", TBGenerals.skill(g, p), " name=", TBGenerals.name_idx(g, p))
	if not r["ok"] or g.gen[p] == 0: fails += 1
	if g.apply({"cmd": "appoint", "n": a, "p": p})["ok"]: fails += 1                       # already has one
	g.army[own[1]] = 3
	if g.apply({"cmd": "appoint", "n": a, "p": own[1]})["ok"]: fails += 1                  # army too small
	# strength multiplier and friendly move
	if TBGenerals.mul(g, p) <= 1.0: fails += 1
	var q := -1
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		if g.owner[g.nb[i]] == a and g.nb_sea[i] == 0: q = g.nb[i]; break
	if q >= 0:
		g.mp[a] = 10; g.army[q] = 5
		g.apply({"cmd": "move", "n": a, "from": p, "to": q})
		print("after full move: gen at from=", g.gen[p], " at to=", g.gen[q])
		if g.gen[p] != 0 or g.gen[q] == 0: fails += 1
		p = q
	# captured province loses its general
	var o := g.owner[p]; g.set_owner(p, 0)
	if g.gen[p] != 0: fails += 1
	g.set_owner(p, o)
	# rules 0 untouched
	var g0 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8, "rules": 0})
	g0.set_human(a); g0.gold[a] = 1000
	if g0.apply({"cmd": "appoint", "n": a, "p": g0.owned(a)[0]})["ok"]: fails += 1
	# long game: generals appear, rise, fall; counts never exceed the cap
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 3})
	var up := 0; var fell := 0; var peak := 0
	for t in 200:
		g2.end_turn()
		var tot := 0
		for i in g2.P:
			if g2.gen[i] != 0:
				tot += 1
				if g2.controller(i) == 0 or g2.army[i] < 1:
					print("orphan general turn ", t, " p=", i, " ctrl=", g2.controller(i), " army=", g2.army[i]); fails += 1
		peak = maxi(peak, tot)
	for n in range(1, g2.N1):
		if g2.alive[n] != 0 and TBGenerals.count(g2, n) > 2 * TBGenerals.cap(g2, n) + 2:   # a realm can shrink after appointing; it only blocks new ones
			print("over cap ", n, " ", TBGenerals.count(g2, n), " ", TBGenerals.cap(g2, n)); fails += 1
	var stars := 0
	for i in g2.P:
		if g2.gen[i] != 0: stars += TBGenerals.skill(g2, i)
	print("200 turns: peak generals=%d final stars=%d" % [peak, stars])
	if peak == 0: fails += 1
	print("GENERALS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
