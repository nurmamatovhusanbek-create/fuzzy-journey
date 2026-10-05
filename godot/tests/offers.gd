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
	print("OFFERS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
