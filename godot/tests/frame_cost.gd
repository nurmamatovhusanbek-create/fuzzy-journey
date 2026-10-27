extends SceneTree
## Where a frame goes in the real game: the camera drags (a full map render each frame) and parts are switched off one at a time.
##   xvfb-run godot --path godot --rendering-driver opengl3 -s tests/frame_cost.gd -- <w> <h> <quality 0|1|2> [globe|flat]
## Software GL stands in for the GPU: the shader share is inflated, the script / layout shares are about what a weak CPU sees.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280
	var h := int(a[1]) if a.size() > 1 else 720
	var q := int(a[2]) if a.size() > 2 else 1
	var view := String(a[3]) if a.size() > 3 else "globe"
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = view; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main.cfg["quality"] = ["low", "medium", "high"][q]
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main._apply_quality(); main._update_ui_scale()
	main.map.set_mode(0 if view == "globe" else 1)
	main.map.fly_to(9.5, 46.0, 3.2 if view == "globe" else 5.3)
	for i in 40: await process_frame
	var map: TBMapView = main.map
	print("quality=%d scale=%.2f  %dx%d  %s  render %s" % [map.quality, map.render_scale, w, h, view, str(map._vp.size)])
	var cases := [
		["everything", func(): pass],
		["map render skipped", func(): map._vp.render_target_update_mode = SubViewport.UPDATE_DISABLED],
		["  + labels hidden", func(): map.labels.visible = false],
		["  + hud hidden", func(): main.hud.visible = false],
		["  + routes hidden", func(): if map.routes != null: map.routes.visible = false],
	]
	for c in cases:
		(c[1] as Callable).call()
		var n := 40
		var ms: Array = []
		for i in n:
			var t0 := Time.get_ticks_usec()
			map.lon0 += 0.004; map._push_view()
			if String(c[0]).begins_with("map render skipped") or String(c[0]).begins_with("  +"): map._vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			await process_frame
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		ms.sort()
		print("  %-22s median %.1f ms   p90 %.1f ms" % [c[0], ms[n / 2], ms[int(n * 0.9)]])
	# a still screen
	var t0 := Time.get_ticks_usec(); var f0 := Engine.get_frames_drawn()
	for i in 30: await process_frame
	print("  still: %d frames drawn in 30" % (Engine.get_frames_drawn() - f0))
	quit()
