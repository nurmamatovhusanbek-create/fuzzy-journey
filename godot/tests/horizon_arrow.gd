extends SceneTree
## An attack from a province beyond the globe's horizon shows a red curved arrow coming in from the rim. Usage: -s tests/horizon_arrow.gd -- <out dir> (TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _red(img: Image) -> int:
	var k := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.82 and c.g < 0.40 and c.b < 0.30: k += 1
	return k
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	var tgt := -1
	for p in g.P: if g.owner[p] == me: tgt = p; break
	var src := -1
	for p in g.P:
		if g.owner[p] != 0 and g.owner[p] != me and absf(wrapf(g.world.lon[p] - g.world.lon[tgt], -180.0, 180.0)) > 140.0: src = p; break
	_check(src >= 0, "there is a province on the far side")
	main.map.jump_to(g.world.lon[tgt], g.world.lat[tgt], 1.6)
	for i in 8: await process_frame
	var pf: Vector3 = main.map.project(g.world.lon[src], g.world.lat[src])
	_check(pf.z <= 0.0, "the attacker is beyond the horizon (z %f)" % pf.z)
	var before := _red(root.get_viewport().get_texture().get_image())
	main.map.labels.set_alerts([[src, tgt, 1]])
	for i in 6: await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/horizon_arrow.png" % out)
	var after := _red(img)
	print("red samples before ", before, " after ", after)
	_check(after > before + 40, "a red arrow is drawn for an attacker beyond the horizon")
	print("HORIZON_ARROW ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
