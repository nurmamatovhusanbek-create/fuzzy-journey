extends SceneTree
## The title must actually MOVE on screen: the pictures of both stages, a few seconds apart, differ where the globe is (the project runs in low-processor mode, which redraws only
## what asks for it). Usage: -s tests/title_motion.gd -- <w> <h> <outprefix>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _diff(a: Image, b: Image, r: Rect2i) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y, 3):
		for x in range(r.position.x, r.end.x, 3):
			var c1 := a.get_pixel(x, y); var c2 := b.get_pixel(x, y)
			if absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b) > 0.03: n += 1
	return n
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var pre: String = a[2]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	TBI18n.load_lang("en")
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["comfort_seen"] = true
	main.cfg["fx"] = OS.get_environment("TB_FX") if OS.get_environment("TB_FX") != "" else "light"; main._apply_a11y()
	print("low processor mode: ", OS.low_processor_usage_mode, "   motion ok: ", TBKit.motion_ok(), "   fx level: ", TBFx.level)
	var area := Rect2i(int(w * 0.35), 0, int(w * 0.65), h)
	main.show_front()
	await _frames(30)
	var i1: Image = root.get_viewport().get_texture().get_image()
	await create_timer(3.0).timeout
	var i2: Image = root.get_viewport().get_texture().get_image()
	var d1 := _diff(i1, i2, area)
	print("first stage: %d sample pixels changed in 3 s" % d1)
	i2.save_png(pre + "_front.png")
	_check(d1 > 40, "the first stage moves on screen (%d)" % d1)
	main.show_menu()
	await _frames(30)
	var j1: Image = root.get_viewport().get_texture().get_image()
	await create_timer(3.0).timeout
	var j2: Image = root.get_viewport().get_texture().get_image()
	var d2 := _diff(j1, j2, area)
	print("second stage: %d sample pixels changed in 3 s" % d2)
	j2.save_png(pre + "_stage2.png")
	_check(d2 > 40, "the second stage moves on screen (%d)" % d2)
	print("TITLE_MOTION OK" if fails == 0 else "TITLE_MOTION FAIL %d" % fails)
	quit(fails)
