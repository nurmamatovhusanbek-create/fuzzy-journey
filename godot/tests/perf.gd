extends SceneTree
# GPU-shader cost per quality tier under software GL (relative numbers only; real GPUs are far faster).
func _init() -> void:
	root.size = Vector2i(1280, 720)
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 7})
	g.set_human(g.owner[1000])
	var mv := TBMapView.new(); mv.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(mv)
	mv.setup(g)
	await process_frame
	mv.size = Vector2(1280, 720)
	for cfg in [[2, 1.0], [2, 0.85], [1, 0.85], [1, 0.6], [0, 0.6], [0, 0.45]]:
		mv.quality = cfg[0]; mv.render_scale = cfg[1]; mv.zoom = 1.0; mv.lat0 = 0.4; mv._push_view()
		await process_frame
		var n := 20
		var t0 := Time.get_ticks_usec()
		for i in n:
			mv.lon0 += 0.02; mv._push_view()
			await process_frame
		print("quality=%d scale=%.2f  ms/frame=%.1f" % [cfg[0], cfg[1], (Time.get_ticks_usec() - t0) / 1000.0 / n])
	quit()
