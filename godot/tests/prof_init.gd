extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_usec()
	var w := TBWorld.load_from("res://data")
	var t1 := Time.get_ticks_usec()
	var g := TBGame.new(w, {}, {"seed": 1})
	var t2 := Time.get_ticks_usec()
	var t3 := Time.get_ticks_usec(); g.add_sea_links(); var t4 := Time.get_ticks_usec()
	print("world load %.0f ms | new game %.0f ms (of which add_sea_links %.0f ms)" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t4 - t3) / 1000.0])
	quit()
