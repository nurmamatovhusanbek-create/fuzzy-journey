extends SceneTree
## The command ring and the words around it stay on the screen and clear of the turn dial, the minimap, the zoom buttons and the rail, wherever the province is.
## Usage: -s tests/ring_clear.gd -- <w> <h>        (phone: TB_DPR=2.66 TB_DPI=425 TB_PHONE_UI=compact with 2340 1080)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 800
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	var g: TBGame = main.g
	var me: int = g.human_id
	var p: int = g.owned(me)[0]
	for q in g.owned(me): g.army[q] = maxi(g.army[q], 20)
	main.map.set_mode(1)
	main.map.zoom = 6.0
	main.map.jump_to(g.world.lon[p], g.world.lat[p], 6.0)
	var worst := 0
	var hr: Rect2 = main.get_global_rect()
	var vis: Rect2 = Rect2(Vector2.ZERO, main.get_viewport_rect().size)
	print("main rect ", hr, " viewport ", vis)
	var spots := [Vector2(0.5, 0.5), Vector2(0.9, 0.85), Vector2(0.95, 0.7), Vector2(0.9, 0.95), Vector2(0.1, 0.9), Vector2(0.5, 0.95), Vector2(0.95, 0.5), Vector2(0.05, 0.5)]
	for sp in spots:
		main._select(-1)
		main.map.jump_to(g.world.lon[p], g.world.lat[p], 6.0)
		for i in 4: await process_frame
		var cur3: Vector3 = main.map.project(g.world.lon[p], g.world.lat[p]); var cur := Vector2(cur3.x, cur3.y)
		main.map.drag_by(hr.position + hr.size * sp - cur)
		for i in 4: await process_frame
		main._select(p)
		for i in 30: await process_frame
		var lr: Rect2 = main.ring.label_rect()
		if lr.size == Vector2.ZERO: continue
		var bad := ""
		if lr.position.x < vis.position.x - 1.0 or lr.end.x > vis.end.x + 1.0 or lr.end.y > vis.end.y + 1.0: bad = "off the screen"
		var seal: Rect2 = main.hud.end_turn_rect()
		seal.position += main.hud.global_position
		if lr.intersects(seal): bad = "over the turn dial"
		for kr in main.hud.keepouts():
			var rr: Rect2 = kr
			if rr.size.y < 140.0 and rr.get_center().y < 150.0: continue
			if lr.intersects(rr.grow(-1.0)): bad = "over the HUD %s" % str(rr)
		if OS.get_environment("TB_SHOT_DIR") != "": root.get_viewport().get_texture().get_image().save_png("%s/ring_%d.png" % [OS.get_environment("TB_SHOT_DIR"), int(sp.x * 100) * 1000 + int(sp.y * 100)])
		print("anchor %s: ring box %s %s" % [str(sp), str(lr), bad if bad != "" else "clear"])
		if bad != "": worst += 1
		_check(bad == "", "anchor %s: the ring and its words are %s" % [str(sp), bad])
	print("RING_CLEAR OK" if fails == 0 else "RING_CLEAR FAIL %d" % fails)
	quit(fails)
