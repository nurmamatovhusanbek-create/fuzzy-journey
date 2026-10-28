extends SceneTree
## Flat-map minimap: a close window on the main map's Mercator world, centred on the view; a tap flies the main view to exactly the spot under the pointer, and the view frame is drawn in the same coordinates.
var failed := 0
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900)); root.size = Vector2i(1600, 900)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 6: await process_frame
	var mm: TBMinimap = main.hud._minimap
	main.map.set_mode(1)
	for i in 6: await process_frame
	var gm: Array = mm._globe_geom()
	var c: Vector2 = gm[0]; var R: float = gm[1]
	# the window is centred on the view: the view's own lon / lat sits at the circle's centre
	var cen: Vector2 = mm._flat_pos(main.map.lon0, main.map.lat0, c, R)
	var okc: bool = cen.distance_to(c) < 0.5
	print("view centre at window centre: ", cen, " ", "ok" if okc else "FAIL")
	if not okc: failed += 1
	# a tap flies the main view to exactly the spot under the pointer (lon / lat -> pixel -> tap -> view)
	for off in [Vector2(0.4, -0.3), Vector2(-0.6, 0.2), Vector2(0.0, 0.7), Vector2(0.55, 0.55)]:
		var ll := Vector2(main.map.lon0 + off.x * TBMinimap.FLAT_HALF, TBMapView.imerc(mm._flat_cy() - off.y * TBMinimap.FLAT_HALF))
		var pos: Vector2 = mm._flat_pos(ll.x, ll.y, c, R)
		mm._fly(pos)
		for i in 120: await process_frame
		var ok: bool = absf(main.map.lon0 - ll.x) < 0.01 and absf(main.map.lat0 - ll.y) < 0.01
		print("tap ", off, " -> view ", Vector2(rad_to_deg(main.map.lon0), rad_to_deg(main.map.lat0)), " want ", Vector2(rad_to_deg(ll.x), rad_to_deg(ll.y)), " ", "ok" if ok else "FAIL")
		if not ok: failed += 1
	# near the pole the window stays inside the map (the centre is clamped)
	main.map.lat0 = deg_to_rad(80.0); main.map._push_view()
	var cy: float = mm._flat_cy()
	var okp: bool = cy + TBMinimap.FLAT_HALF <= TBMapView.merc(TBMapView.MERC_LIM) + 1e-4
	print("pole clamp cy ", cy, " ", "ok" if okp else "FAIL")
	if not okp: failed += 1
	# zoomed in: the footprint's centre is the view centre, and it lands at the window centre
	main.map.zoom = main.map.flat_fit() * 6.0; main.map.lon0 = deg_to_rad(20.0); main.map.lat0 = deg_to_rad(45.0); main.map._push_view()
	var fp: Array = mm._footprint()
	var mx := 0.0; var my := 0.0
	for q in fp: mx += float((q as Vector2).x); my += TBMapView.merc(float((q as Vector2).y))
	mx /= fp.size(); my /= fp.size()
	var okf: bool = fp.size() > 8 and absf(mx - deg_to_rad(20.0)) < 0.05 and absf(my - TBMapView.merc(deg_to_rad(45.0))) < 0.05
	print("footprint centre ", Vector2(mx, my), " ", "ok" if okf else "FAIL")
	if not okf: failed += 1
	print("MM_FLAT OK" if failed == 0 else "MM_FLAT FAIL %d" % failed)
	quit(failed)
