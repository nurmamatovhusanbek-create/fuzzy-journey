extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 3})
	g.set_human(g.owner[1000])
	var worst := 0.0; var tot := 0.0
	for t in 120:
		var t0 := Time.get_ticks_usec()
		g.end_turn()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		tot += ms; worst = maxf(worst, ms)
	print("end_turn: avg %.1f ms, worst %.1f ms (headless x86; phones are ~3-6x slower; runs on a worker thread)" % [tot / 120.0, worst])
	quit()
