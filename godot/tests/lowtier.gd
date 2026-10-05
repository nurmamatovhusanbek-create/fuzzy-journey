extends SceneTree
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 7}); g.set_human(g.owner[1000])
	var mv := TBMapView.new(); mv.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(mv)
	mv.setup(g); await process_frame
	mv.size = Vector2(1280, 720)
	mv.quality = 0; mv.render_scale = 0.6; mv.zoom = 1.6; mv.lat0 = 0.7; mv.lon0 = 0.5; mv._push_view()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lowtier.png")
	quit()
