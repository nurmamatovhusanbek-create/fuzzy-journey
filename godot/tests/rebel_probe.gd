extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", a[1]), {"seed": int(a[0])})
	for t in range(1, int(a[2]) + 1):
		g.end_turn()
		if t % 10 == 0:
			var worst := 0; var wn := 0
			for n in range(1, g.N1):
				if g.alive[n] == 0 or n == g.rebel: continue
				var low := 0
				for p in g.owned(n): if g.stab[p] < 30: low += 1
				if low > worst: worst = low; wn = n
			print("t=%d rebelProv=%d worst low-stab nation=%s (%d provs <30 of %d) gold=%d regime=%d" % [t, g.own_count(g.rebel), g.nat_name[wn], worst, g.own_count(wn), int(g.gold[wn]), g.regime[wn]])
	quit()
