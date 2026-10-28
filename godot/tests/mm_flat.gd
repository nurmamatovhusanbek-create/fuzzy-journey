extends SceneTree
## Flat-map minimap: the main map's own Mercator world fills the round window; a tap flies the main view to exactly the spot under the pointer, and the view frame is drawn in the same coordinates.
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
	for ll in [Vector2(30.0, 50.0), Vector2(-100.0, 35.0), Vector2(120.0, -25.0), Vector2(0.0, 0.0)]:
		var pos: Vector2 = c + Vector2(ll.x / 180.0, -TBMapView.merc(deg_to_rad(ll.y)) / PI) * R
		mm._fly(pos)
		for i in 120: await process_frame
		var lon: float = rad_to_deg(main.map.lon0); var lat: float = rad_to_deg(main.map.lat0)
		var ok: bool = absf(lon - ll.x) < 1.0 and absf(lat - ll.y) < 1.0
		print("tap ", ll, " -> view ", Vector2(lon, lat), " ", "ok" if ok else "FAIL")
		if not ok: failed += 1
	# zoomed in: the footprint rectangle's centre is the view centre in the same coordinates
	main.map.zoom = main.map.flat_fit() * 3.0; main.map.lon0 = deg_to_rad(20.0); main.map.lat0 = deg_to_rad(45.0); main.map._push_view()
	var fp: Array = mm._footprint()
	var mx := 0.0; var my := 0.0
	for q in fp: mx += float((q as Vector2).x); my += TBMapView.merc(float((q as Vector2).y))
	mx /= fp.size(); my /= fp.size()
	var okf: bool = fp.size() > 8 and absf(mx - deg_to_rad(20.0)) < 0.05 and absf(my - TBMapView.merc(deg_to_rad(45.0))) < 0.05
	print("footprint centre ", Vector2(mx, my), " ", "ok" if okf else "FAIL")
	if not okf: failed += 1
	print("MM_FLAT ", "PASS" if failed == 0 else "FAIL %d" % failed)
	quit(failed)
