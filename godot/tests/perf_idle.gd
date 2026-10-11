extends SceneTree
## Frame cost with a province selected (idle: no frame may be drawn at all), while dragging, and after settling. Usage: -s tests/perf_idle.gd -- <w> <h> <lod 0|1> [globe]
func _walk(n: Node, out: Array) -> void:
	if n.is_processing() and n.is_visible_in_tree() if n is CanvasItem else n.is_processing(): out.append(str(n.get_class()) + ":" + str(n.name) + ":" + str((n.get_script() as Script).resource_path.get_file() if n.get_script() != null else ""))
	for c in n.get_children(): _walk(c, out)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1]); var lod: bool = a[2] == "1"
	var globe: bool = a.size() > 3
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe" if globe else "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("ww1", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_quality()
	for i in 20: await process_frame
	main.map.fly_to(9.5, 46.0, 2.0)
	for i in 40: await process_frame
	var t00 := Time.get_ticks_msec()
	var fd1 := Engine.get_frames_drawn()
	for i in 40: await process_frame
	print("idle, nothing selected frames drawn: ", Engine.get_frames_drawn() - fd1)
	print("idle, nothing selected: %.1f ms/frame  draw calls %d" % [(Time.get_ticks_msec() - t00) / 40.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	main.hud.visible = false
	t00 = Time.get_ticks_msec()
	for i in 40: await process_frame
	print("idle, HUD hidden: %.1f ms/frame  draw calls %d" % [(Time.get_ticks_msec() - t00) / 40.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	main.map.labels.visible = false; main.map.routes.visible = false
	t00 = Time.get_ticks_msec()
	for i in 40: await process_frame
	print("idle, HUD+labels+routes hidden: %.1f ms/frame  draw calls %d" % [(Time.get_ticks_msec() - t00) / 40.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	main.hud.visible = true; main.map.labels.visible = true; main.map.routes.visible = true
	var sel := -1
	for p in main.g.owned(fr): sel = p; break
	main._select(sel)
	for i in 120: await process_frame
	var t0 := Time.get_ticks_msec()
	var fd0 := Engine.get_frames_drawn()
	for i in 40: await process_frame
	var drawn: int = Engine.get_frames_drawn() - fd0
	print("idle+selected: frames drawn in 40 loops: ", drawn)
	var procs: Array = []
	_walk(main, procs)
	print("processing nodes: ", procs)
	print("idle+selected: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	main.map.labels.visible = false
	t0 = Time.get_ticks_msec()
	for i in 40: await process_frame
	print("selected, labels hidden: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	main.map.labels.visible = true; main.panel.visible = false
	t0 = Time.get_ticks_msec()
	for i in 40: await process_frame
	print("selected, panel hidden: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	main.panel.visible = true
	t0 = Time.get_ticks_msec()
	for i in 40:
		main.map.drag_by(Vector2(14, 5)); await process_frame
	print("dragging: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	for i in 30: await process_frame
	main.map.labels.visible = false; main.map.routes.visible = false; main.ring.visible = false; main.hud.visible = false; main.panel.visible = false
	t0 = Time.get_ticks_msec()
	for i in 40:
		main.map.drag_by(Vector2(14, 5)); await process_frame
	print("dragging, map shader only: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	main.map._vig.visible = false
	t0 = Time.get_ticks_msec()
	for i in 40:
		main.map.drag_by(Vector2(14, 5)); await process_frame
	print("dragging, no vignette: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	main.map.quality = 0; main.map.render_scale = 0.5
	t0 = Time.get_ticks_msec()
	for i in 40:
		main.map.drag_by(Vector2(14, 5)); await process_frame
	print("dragging, scale .5: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	t0 = Time.get_ticks_msec()
	for i in 40: await process_frame
	print("settled: %.1f ms/frame" % ((Time.get_ticks_msec() - t0) / 40.0))
	print("IDLE ", "OK" if drawn <= 2 else "FAIL (a selected province must not redraw the screen every frame)")
	quit(0 if drawn <= 2 else 1)
