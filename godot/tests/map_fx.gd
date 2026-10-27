extends SceneTree
## C1 / C3: an army glides from one province to the next, a clash marker shows the battle; both are gone with Effects Off, and a still map draws no frame once they end.
## Usage: -s tests/map_fx.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "high"; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1); main._apply_quality()
	var g: TBGame = main.g
	var me: int = g.human_id
	var mine: Array = g.owned(me)
	var a: int = mine[0]; var b: int = -1
	for i in range(g.nb_off[a], g.nb_off[a + 1]):
		var q: int = g.nb[i]
		if g.owner[q] != 0: b = q; break
	main.map.jump_to(float(main.world.lon[a]), float(main.world.lat[a]), 5.0)
	for i in 20: await process_frame
	var L: TBMapLabels = main.map.labels
	L.add_glide(a, b, me, 120)
	L.add_clash(b, true, "−2,310")
	_check(L._fx.size() == 2, "Full: both effects queued (%d)" % L._fx.size())
	for k in [4, 10, 16]:
		for i in 6: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/mapfx_%02d.png" % [out, k])
	for i in 60: await process_frame
	_check(L._fx.is_empty(), "the effects end by themselves")
	var fd0 := Engine.get_frames_drawn()
	for i in 40: await process_frame
	_check(Engine.get_frames_drawn() - fd0 <= 2, "a still map draws no frames afterwards (%d)" % (Engine.get_frames_drawn() - fd0))
	main.cfg["fx"] = "off"; main._apply_a11y()
	L.add_glide(a, b, me, 120); L.add_clash(b, true, "−1")
	_check(L._fx.is_empty(), "Off: nothing queued")
	print("MAP_FX ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
