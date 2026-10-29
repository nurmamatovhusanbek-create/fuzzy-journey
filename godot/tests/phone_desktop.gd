extends SceneTree
## A phone held sideways gets the desktop interface (cfg phone_ui = "desktop", the default): a 1000 unit stage, the desktop HUD profile, every desktop part, hit areas that grow for fingers;
## "compact" brings the 390 unit phone layout back. Needs the phone's density emulated: TB_DPR=1.67 TB_DPI=420 with a 1600x720 window (a 2.2:1 screen).
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 720)); root.size = Vector2i(1600, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main.cfg["phone_ui"] = "desktop"; main._apply_quality(); main._update_ui_scale()       # explicit: an earlier test may have saved "compact" into the shared settings file
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 20: await process_frame
	var hud = main.hud
	var vs: Vector2 = root.get_visible_rect().size
	print("desktop layout on a phone: logical ", vs, " profile ", hud._prof, " minimap r ", hud._minimap.round_r, " rail ", hud._rail_n, " touch_phys ", TBHudParts.touch_phys)
	_check(absf(vs.y - main.phone_stage()) < 2.0, "the stage is %d units tall (%s)" % [int(main.phone_stage()), str(vs)])
	_check(hud._prof == 0, "the HUD takes the desktop profile")
	_check(not TBKit.is_phone(main), "no screen takes the compact phone paths")
	_check(hud._minimap.visible and hud._minimap.round_r >= 70.0, "the full-size minimap with its caption")
	_check(hud._rail_n >= 4 and (hud._rail_n >= 6 or hud._dock_more.visible), "the desktop rail (%d buttons, the rest behind More)" % hud._rail_n)
	_check(hud._mode.items.size() >= 9, "the lens bar lists all the lenses (%d)" % hud._mode.items.size())
	_check(TBHudParts.touch_phys > 48.0, "the hit area grows on a touch screen (%.0f units)" % TBHudParts.touch_phys)
	var b: Control = hud._dock[0]
	_check(b.hit_rect().size.y > b.size.y + 10.0 and b.hit_rect().size.y <= b.size.y * 1.5 + 0.5, "a rail button's hit area is bigger than it looks, at most 1.5 x (%s vs %s)" % [str(b.hit_rect().size), str(b.size)])
	# nothing of the HUD off the screen, minimap clear of the rail
	var ring := Rect2(hud._minimap.get_global_rect().position + Vector2(10, 10), hud._minimap.get_global_rect().size - Vector2(20, 34))
	_check(Rect2(Vector2.ZERO, vs).encloses(ring), "minimap on screen")
	for i in hud._rail_n:
		var c: Control = hud._dock[i]
		if c.visible: _check(not ring.intersects(c.get_global_rect()), "rail button %d clear of the minimap" % i)
	# the off switch
	main.cfg["phone_ui"] = "compact"; main._update_ui_scale()                  # not _on_setting_changed: that would save the choice into the settings file
	for i in 10: await process_frame
	vs = root.get_visible_rect().size
	print("compact: logical ", vs, " profile ", hud._prof)
	_check(absf(vs.y - 390.0) < 2.0 and hud._prof != 0, "compact brings the 390 unit phone layout back")
	print("PHONE_DESKTOP OK" if fails == 0 else "PHONE_DESKTOP FAIL %d" % fails)
	quit(fails)
