extends SceneTree
## The tutorial points at the real controls its steps talk about: a ring around the resource gauges and the dock (step 1), the Budget, Nations and Decrees buttons (4, 5, 6), the Council / Annals / Goals buttons (7);
## the ring goes with the dialog. Usage: -s tests/tutorial_spot.gd -- <out dir> (xvfb, TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sz := Vector2i(1920, 1080)
	DisplayServer.window_set_size(sz); root.size = sz
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "flat"; main.cfg["fx"] = "off"; main.cfg["text_scale"] = 1.0; main.cfg["tutorial"] = false; main.cfg["seal_seen"] = true
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	for i in 80: await process_frame
	var spots := _find(main._overlay, func(x): return x is TBSpotlight)
	_check(spots.size() == 1, "the tutorial dialog carries one spotlight (%d)" % spots.size())
	if spots.is_empty(): print("TUTORIAL_SPOT FAIL"); quit(1); return
	var sp: TBSpotlight = spots[0]
	var counts := {}
	for step in [1, 2, 3, 4, 5, 6, 7]:
		var want: int = {1: 7, 2: 0, 3: 0, 4: 1, 5: 1, 6: 1, 7: 3}[step]
		counts[step] = sp.rects.size()
		_check(sp.rects.size() == want, "step %d rings %d control(s) (%d)" % [step, want, sp.rects.size()])
		for r in sp.rects:
			_check((r as Rect2).size.x > 8.0 and (r as Rect2).size.y > 8.0 and Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses((r as Rect2).grow(-1.0)), "step %d: the ring is on screen and not empty (%s)" % [step, str(r)])
		if step == 4 or step == 1: root.get_viewport().get_texture().get_image().save_png("%s/tut_%d.png" % [out, step])
		var nx := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower() in ["next", "start playing"])
		if nx.is_empty(): break
		(nx[0] as Button).pressed.emit()
		for i in 6: await process_frame
	await process_frame
	var left := _find(main._overlay, func(x): return x is TBSpotlight)
	_check(left.is_empty() or not is_instance_valid(left[0]) or (left[0] as Node).is_queued_for_deletion(), "the ring goes with the tutorial")
	print("TUTORIAL_SPOT ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(fails)
