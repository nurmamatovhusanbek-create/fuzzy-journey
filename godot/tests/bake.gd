extends SceneTree
## The HUD bitmap cache (src/ui/bake.gd) must not change a pixel: the same screen with the cache on and with every piece drawing itself, plus what it saves.
##   xvfb-run godot --path godot --rendering-driver opengl3 -s tests/bake.gd -- <w> <h> [dir for the two pictures]
func _objs() -> int: return int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280
	var h := int(a[1]) if a.size() > 1 else 720
	var dir := String(a[2]) if a.size() > 2 else ""
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main._update_ui_scale()
	main.map.fly_to(9.5, 46.0, 5.3)
	var fails := 0
	var states := ["plain", "selected", "lens", "alerts", "globe", "globe-near"]
	for st in states:
		match st:
			"globe":
				main.map.set_lens("political"); main.g.gold[fr] = 300.0; main.hud.refresh(); main._select(-1)
				main.map.set_mode(0); main.map.fly_to(9.5, 46.0, 1.4)
			"globe-near": main.map.fly_to(9.5, 46.0, 4.5)
			"selected":
				for p in main.g.P:
					if main.world.name[p] == "Bas-Rhin": main._select(p)
			"lens": main.map.set_lens("military"); main._select(-1)
			"alerts":
				main.map.set_lens("political")
				main.g.gold[fr] = 3.0
				main.hud.refresh()
		for i in 70: await process_frame
		var nb := TBBake.baked()
		var o_on := _objs()
		var img_on: Image = root.get_viewport().get_texture().get_image()
		TBBake.flush()
		for i in 3: await process_frame
		var o_off := _objs()
		var img_off: Image = root.get_viewport().get_texture().get_image()
		var bad := 0; var worst := 0; var minx := 9999; var maxx := -1; var miny := 9999; var maxy := -1
		for y in img_on.get_height():
			for x in img_on.get_width():
				var c1 := img_on.get_pixel(x, y); var c2 := img_off.get_pixel(x, y)
				var d := maxi(maxi(absi(int(round((c1.r - c2.r) * 255.0))), absi(int(round((c1.g - c2.g) * 255.0)))), absi(int(round((c1.b - c2.b) * 255.0))))
				if d > 0: worst = maxi(worst, d)
				if d > 3:
					bad += 1; minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
		print("%-9s baked %d pieces, objects %d -> %d (live %d), pixels differing by >3: %d (worst %d)%s" % [st, nb, o_on, o_on, o_off, bad, worst, (" in x %d..%d y %d..%d" % [minx, maxx, miny, maxy]) if bad > 0 else ""])
		if dir != "":
			img_on.save_png("%s/bake_%s_on.png" % [dir, st]); img_off.save_png("%s/bake_%s_off.png" % [dir, st])
		if bad > 400 or worst > 60 or nb < 10: fails += 1
	# hover: a baked piece draws itself live while it is hovered, is the live picture, and is baked again when the pointer leaves
	for i in 40: await process_frame
	var inst: TBBake = TBBake._inst
	var target: Control = null
	for e in inst._entries:
		if e.st == 2 and e.c.has_signal("pressed") and e.c.mouse_filter != Control.MOUSE_FILTER_IGNORE and e.c.size.x > 100: target = e.c; break
	if target == null: print("no hoverable baked piece"); fails += 1
	else:
		var ent: TBBake.Entry
		for e in inst._entries: if e.c == target: ent = e
		var img_before: Image = root.get_viewport().get_texture().get_image()
		target.notification(Control.NOTIFICATION_MOUSE_ENTER)
		for i in 3: await process_frame
		var live_now: bool = ent.st == 0
		var img_hover: Image = root.get_viewport().get_texture().get_image()
		var changed := false
		var r := Rect2i(Vector2i(target.get_global_rect().position * root.get_final_transform().get_scale()), Vector2i(target.get_global_rect().size * root.get_final_transform().get_scale()))
		for y in range(r.position.y, mini(r.end.y, h)):
			for x in range(r.position.x, mini(r.end.x, w)):
				if img_before.get_pixel(x, y) != img_hover.get_pixel(x, y): changed = true
		target.notification(Control.NOTIFICATION_MOUSE_EXIT)
		for i in 60: await process_frame
		print("hover: live while hovered %s, picture changed %s, baked again after leaving %s" % [str(live_now), str(changed), str(ent.st == 2)])
		if not live_now or not changed or ent.st != 2: fails += 1
	print("BAKE ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
