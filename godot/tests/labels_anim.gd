extends SceneTree
## logic test of the plaque animation state machine (no rendering needed)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8})
	var fails := 0
	var L := TBMapLabels.new()
	L.g = g
	var p := 10
	g.owner[p] = 1; g.army[p] = 30
	var st := L._state(p)
	st["t"] = 1.0
	for i in 20: L._process(0.05)
	print("faded in: a=", st["a"])
	if absf(st["a"] - 1.0) > 0.001: fails += 1
	g.army[p] = 54
	L._process(0.016)
	print("after change: pop=", st["pop"], " dn=", st["dn"], " shown=", st["shown"])
	if st["pop"] < 0.9 or st["dn"] != 24: fails += 1
	for i in 6: L._process(0.05)
	print("0.3s later: shown=", st["shown"], " pop=", st["pop"])
	if st["shown"] <= 30.0 or st["shown"] >= 54.0: fails += 1                # rolling, not snapped
	for i in 30: L._process(0.05)
	print("1.5s later: shown=", st["shown"], " dt=", st["dt"])
	if int(round(st["shown"])) != 54 or st["dt"] != 0.0: fails += 1
	# fade out and removal
	st["t"] = 0.0
	for i in 20: L._process(0.05)
	print("faded out, state removed: ", not L._pl.has(p))
	if L._pl.has(p): fails += 1
	# tiers
	if L._tier(10) != 0 or L._tier(30) != 1 or L._tier(100) != 2 or L._tier(500) != 3: fails += 1
	L.free()
	print("LABELS_ANIM ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
