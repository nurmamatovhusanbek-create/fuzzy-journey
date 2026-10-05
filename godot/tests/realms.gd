extends SceneTree
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 3})
	var fails := 0
	var sizes := []
	for i in TBRealms.count(): sizes.append(TBRealms.members(g, i).size())
	print("realm sizes: ", sizes)
	for i in sizes.size(): if sizes[i] < 6: print("tiny realm ", TBRealms.LIST[i][0]); fails += 1
	# hand a nation a realm and tick
	var n := 0
	for k in range(1, g.N1): if k != g.rebel and g.alive[k] != 0: n = k; break
	var idx := 2   # italy
	for p in TBRealms.members(g, idx): g.owner[p] = n
	g.own_dirty = true
	g.turn = 10
	var gold0 := g.gold[n]
	TBRealms.tick(g)
	var done: bool = g.realm_done[n * TBRealms.count() + idx] != 0
	print("unified Italy flagged: ", done, " gold +", g.gold[n] - gold0)
	if not done: fails += 1
	var logged := false
	for e in g.log: if e["kind"] == "realm": logged = true; print("chron: ", TBChron.text(g, e))
	if not logged: fails += 1
	# no double reward
	var gold1 := g.gold[n]; g.turn = 12; TBRealms.tick(g)
	if g.gold[n] != gold1: fails += 1
	print("REALMS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
