extends SceneTree
## C6: a new selection flashes the province once (cream, fading in 0.55 s), then the map is still again; Effects Off: no flash.
## Usage: -s tests/sel_pulse.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _lum(img: Image, r: Rect2) -> float:
	var s := 0.0; var n := 0
	for y in range(int(r.position.y), int(r.end.y), 3):
		for x in range(int(r.position.x), int(r.end.x), 3):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): continue
			var c := img.get_pixel(x, y); s += c.r + c.g + c.b; n += 1
	return s / maxf(1.0, float(n))
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "high"; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1); main._apply_quality()
	print("started")
	var g: TBGame = main.g
	var m: TBMapView = main.map
	var a: int = -1; var b: int = -1; var best := 0.0
	for q in g.owned(g.human_id):                           # the biggest province of the player: easy to hit and it sits under the screen centre after jump_to
		var bb: float = float(m._pbb[q * 4 + 2] - m._pbb[q * 4]) * float(m._pbb[q * 4 + 3] - m._pbb[q * 4 + 1])
		if bb > best: best = bb; b = a; a = q
	if b < 0: b = g.owned(g.human_id)[1]
	m.jump_to(float(main.world.lon[a]), float(main.world.lat[a]), 5.0)
	for i in 30: await process_frame
	print("jumped")
	var vpc: Vector2 = Vector2(m._vp.size) * 0.5
	var r := Rect2(vpc - Vector2(10, 10), Vector2(20, 20))       # the map's own render target (no HUD on it); jump_to centres the province
	main._select(a)
	_check(m._sel_pulse > 0.99, "Full: a new selection starts the pulse (%.2f)" % m._sel_pulse)
	for i in 2: await process_frame
	m._vp.get_texture().get_image().save_png("%s/selpulse_early.png" % out)
	var early := _lum(m._vp.get_texture().get_image(), r)
	for i in 40: await process_frame
	_check(m._sel_pulse == 0.0, "the pulse has ended")
	var late := _lum(m._vp.get_texture().get_image(), r)
	_check(early > late + 0.02, "the province is brighter at the start than after it settles (%.3f vs %.3f)" % [early, late])
	m._vp.get_texture().get_image().save_png("%s/selpulse_late.png" % out)
	var fd0 := Engine.get_frames_drawn()
	for i in 40: await process_frame
	_check(Engine.get_frames_drawn() - fd0 <= 2, "a still map draws no frames afterwards (%d)" % (Engine.get_frames_drawn() - fd0))
	main._select(a)
	_check(m._sel_pulse == 0.0, "selecting the same province again does not pulse")
	main._select(b)
	for i in 3: await process_frame
	_check(m._sel_pulse > 0.6, "another province pulses again")
	main.cfg["fx"] = "off"; main._apply_a11y()
	for i in 40: await process_frame
	main._select(a)
	_check(m._sel_pulse == 0.0, "Off: no pulse")
	print("SEL_PULSE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
