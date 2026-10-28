extends SceneTree
## The minimap on a phone held sideways in the COMPACT layout (cfg phone_ui = compact; the default desktop layout is tested by phone_desktop.gd): it is shown, inside the screen, and clear of the rail buttons, the lens tuner, End Turn, the zoom buttons, the crest / gauges and the inspector area.
## Usage: -s tests/mm_phone.gd -- <w> <h> [text_scale]     (units = 1 px per logical unit; TB_NOANIM=1)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var ts: float = float(a[2]) if a.size() > 2 else 1.0
	root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	await process_frame; await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["tutorial"] = true; main.cfg["text_scale"] = ts
	main.cfg["phone_ui"] = "compact"; main._update_ui_scale()                                  # this test is about the compact 390 unit phone layout (a window this small counts as a phone)
	main._apply_a11y()
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay()
	root.size_changed.disconnect(main._update_ui_scale)
	for i in 6: await process_frame
	var hud = main.hud
	var mm: TBMinimap = hud._minimap
	var vp: Vector2 = hud._vp
	_check(hud._prof != 0 and hud._prof != 3, "a phone held sideways (profile %d)" % hud._prof)
	_check(mm.visible, "the minimap is shown")
	var r: Rect2 = mm.get_global_rect() if mm.visible else Rect2()
	var ring := Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 20))              # the bezel itself (10 units of shadow room round it)
	_check(Rect2(Vector2.ZERO, vp).encloses(ring), "inside the screen: %s" % ring)
	var others: Array = [["tuner", hud._mode], ["zoom in", hud._zin], ["zoom out", hud._zout], ["lens button", hud._lens_btn], ["crest", hud._nat]]
	for b in hud._dock + [hud._dock_more]: others.append(["rail " + str((b as Control).name), b])
	for o in others:
		var c: Control = o[1]
		if c != null and c.visible: _check(not ring.intersects(c.get_global_rect()), "clear of %s: %s vs %s" % [o[0], ring, c.get_global_rect()])
	var sr: Rect2 = hud._seal_rect(); sr.position += hud.global_position
	_check(not ring.intersects(sr), "clear of End Turn")
	_check(not ring.intersects(Rect2(hud._insp.position + hud.global_position, hud._insp.size)), "clear of the inspector area")
	# a tap on the minimap turns the main view (touch)
	var l0: float = main.map.lon0
	main.map.set_mode(1); hud._minimap.refresh()
	for i in 4: await process_frame
	var gm: Array = mm._globe_geom()
	mm._fly((gm[0] as Vector2) + Vector2(float(gm[1]) * 0.6, 0.0))
	for i in 90: await process_frame
	_check(absf(main.map.lon0 - l0) > 0.1, "a tap turns the main view")
	print("MM_PHONE OK %dx%d s%d" % [w, h, int(ts * 100.0)] if fails == 0 else "MM_PHONE FAIL %d" % fails)
	quit(fails)
