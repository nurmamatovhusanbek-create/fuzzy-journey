extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 1})
	var nb1 := g.nb.duplicate(); var sea1 := g.nb_sea.duplicate(); var off1 := g.nb_off.duplicate()
	g.add_sea_links()
	print("precomputed == computed: off ", off1 == g.nb_off, " nb ", nb1 == g.nb, " sea ", sea1 == g.nb_sea, " sizes ", nb1.size(), "/", g.nb.size(), " seaSum ", Array(sea1).reduce(func(a, b): return a + b, 0), "/", Array(g.nb_sea).reduce(func(a, b): return a + b, 0))
	quit()
