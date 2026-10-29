extends SceneTree
## Every HUD button that opens something closes it again when pressed a second time (real clicks through the interface). Usage: -s tests/toggle_close.gd -- <w> <h>   (TB_DPR / TB_DPI emulate a phone)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1
	else: print("  ok   ", what)

func _open_windows(main: Control) -> int:
	var n := 0
	for c in main._overlay.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tb_handle"): continue
		if (c.get_meta("tb_handle") as TBPanel.Handle).is_open(): n += 1
	return n

func _state(main: Control) -> String:
	return "windows %d, popover %s, modal %s" % [_open_windows(main), str(main.hud.is_popover_open()), str(main._modal_open())]

func _click(ctrl: Control) -> void:
	var p: Vector2 = ctrl.get_viewport().get_final_transform() * ctrl.get_global_rect().get_center()     # window pixels: the stage is scaled to the window
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = p; down.global_position = p
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = p; up.global_position = p
	var mv := InputEventMouseMotion.new(); mv.position = p; mv.global_position = p
	Input.parse_input_event(mv)
	Input.parse_input_event(down)
	Input.parse_input_event(up)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france"); var au: int = main.g.nat_code.find("austrian_empire")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	g.set_rel(fr, au, TBData.REL_WAR)
	main.hud.set_seal_pulse(false)
	await _frames(25)
	var hud = main.hud
	var targets := {}
	for i in hud._rail_n: targets["rail %d" % i] = hud._dock[i]
	targets["rail More"] = hud._dock_more
	targets["gear"] = hud._menu_btn
	targets["lens button"] = hud._lens_btn
	targets["crest"] = hud._nat
	for k in ["gold", "man", "mp", "dp"]: targets["chip " + k] = hud._chips[k]
	targets["wars chip"] = hud._war
	for name in targets:
		var ctrl: Control = targets[name]
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree() or ctrl.size.x < 4.0:
			print("  skip ", name, " (not shown)"); continue
		main._clear_overlay(); hud._close_pop(); await _frames(6)
		var s0 := _state(main)
		_click(ctrl); await _frames(14)
		var s1 := _state(main)
		_click(ctrl); await _frames(14)
		var s2 := _state(main)
		_check(s1 != s0, "%s opens something (%s -> %s)" % [name, s0, s1])
		_check(s2 == s0, "%s: a second press closes it again (%s)" % [name, s2])
	print("TOGGLE_CLOSE OK" if fails == 0 else "TOGGLE_CLOSE FAIL %d" % fails)
	quit(fails)
