extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 7})
	var t_ai := 0; var t_tick := 0; var t_reb := 0
	for i in 20:
		var a := Time.get_ticks_usec(); TBAI.run(g)
		var b := Time.get_ticks_usec(); TBTurn._tick(g)
		var c := Time.get_ticks_usec(); TBTurn.rebel_turn(g); g.turn += 1
		var d := Time.get_ticks_usec()
		t_ai += b - a; t_tick += c - b; t_reb += d - c
	print("per turn ms  ai=", t_ai / 20000.0, " tick=", t_tick / 20000.0, " rebel=", t_reb / 20000.0)
	# micro: income, owned, at_war
	var t := Time.get_ticks_usec()
	for n in range(1, g.N1): g.income(n)
	print("income all nations ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for n in range(1, g.N1): g.at_war(n)
	print("at_war all ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for n in range(1, g.N1): g.owned(n)
	print("owned all ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for n in range(1, g.N1): TBAI._frontier(g, n)
	print("frontier all ms ", (Time.get_ticks_usec() - t) / 1000.0)
	quit()
