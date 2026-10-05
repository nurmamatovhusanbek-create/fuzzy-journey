extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 4})
	var h := 0
	for k in range(1, g.N1): if k != g.rebel and g.own_count(k) >= 10: h = k; break
	g.set_human(h)
	var offers := 0; var accepted := 0; var kinds := {}
	for t in 200:
		g.end_turn()
		for e in g.pending.duplicate():
			if e["kind"] == "prop":
				offers += 1; kinds[e["id"]] = kinds.get(e["id"], 0) + 1
				var r := g.apply({"cmd": "eventChoice", "n": h, "uid": e["uid"], "i": 0})
				if r["ok"]: accepted += 1
			else: g.apply({"cmd": "eventChoice", "n": h, "uid": e["uid"], "i": 0})
	print("offers to the human in 200 turns: ", offers, " ", kinds, " accepted=", accepted)
	var fails := 0
	if offers == 0: fails += 1
	# a losing AI sues for peace
	var g2 := TBGame.new(w, {}, {"seed": 6})
	var a := 0; var b := 0
	for k in range(1, g2.N1):
		if k == g2.rebel or g2.own_count(k) < 10: continue
		if a == 0: a = k
		elif b == 0: b = k
	g2.set_human(a); g2.set_rel(a, b, 1); g2.truce[a * g2.N1 + b] = 0
	var got := false
	for t in 40:
		g2.war_score[a * g2.N1 + b] = 60; g2.war_turns[b * g2.N1 + a] = 20; g2.grudge[b * g2.N1 + a] = 0
		g2.end_turn()
		for e in g2.pending.duplicate():
			if e["kind"] == "prop" and e["id"] == "peace":
				got = true
				g2.apply({"cmd": "eventChoice", "n": a, "uid": e["uid"], "i": 0})
		if got: break
	print("peace offer received: ", got, " relation now ", g2.get_rel(a, b))
	if not got or g2.get_rel(a, b) == 1: fails += 1
	print("OFFERS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
