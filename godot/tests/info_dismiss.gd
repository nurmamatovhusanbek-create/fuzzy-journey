extends SceneTree
## The information of a clicked district (its ring, its card, the tip) is one thing at a time: any other call (a rail button, a window, a menu, another district or country, end turn, a shortcut)
## clears it, and the next district shows only its own. Usage: -s tests/info_dismiss.gd -- <w> <h>   (TB_DPR / TB_DPI emulate a phone)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1
	else: print("  ok   ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame

func _count(n: Node, cls: String) -> int:
	var c := 0
	if n.get_script() != null and String(n.get_script().get_global_name()) == cls: c += 1
	for k in n.get_children(): c += _count(k, cls)
	return c

## what is showing about a district right now
func _info(main: Control) -> String:
	var tags := _count(main, "TBTagCard")
	return "selected %d, ring %s, tag cards %d, tip %s, inspector %s" % [main.selected, str(main.ring.visible), tags, str(main.tip.visible), str(main.panel.visible)]
func _showing(main: Control) -> bool:
	return main.selected >= 0 or main.ring.visible or _count(main, "TBTagCard") > 0 or main.tip.visible

func _click(main: Control, ctrl: Control) -> void:
	var p: Vector2 = ctrl.get_viewport().get_final_transform() * ctrl.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new(); mv.position = p; mv.global_position = p; Input.parse_input_event(mv)
	var d := InputEventMouseButton.new(); d.button_index = MOUSE_BUTTON_LEFT; d.pressed = true; d.position = p; d.global_position = p; Input.parse_input_event(d)
	var u := InputEventMouseButton.new(); u.button_index = MOUSE_BUTTON_LEFT; u.pressed = false; u.position = p; u.global_position = p; Input.parse_input_event(u)

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
	var fr: int = main.g.nat_code.find("france"); var sp: int = main.g.nat_code.find("spain")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(25)
	var mine: int = g.capital_of[fr]
	var other: int = g.owned(fr)[1] if g.owned(fr).size() > 1 else mine
	var foreign: int = g.capital_of[sp]
	var cases := {
		"a rail button (Budget)": func(): _click(main, main.hud._dock[1]),
		"the Nations window (rail)": func(): _click(main, main.hud._dock[0]),
		"the gear menu": func(): _click(main, main.hud._menu_btn),
		"a gauge (Treasury)": func(): _click(main, main.hud._chips["gold"]),
		"the crest (your realm)": func(): _click(main, main.hud._nat),
		"End Turn": func(): main.hud._seal_pressed(),
		"a keyboard shortcut (Budget)": func(): main.hud._screen("budget"),
		"opening Nations on a country": func(): main._open_nation(g.owner[foreign]),
	}
	for k in cases:
		main._clear_overlay(); main.hud._close_pop(); main._select(-1); await _frames(6)
		main._on_pick(mine, false); await _frames(14)
		_check(_showing(main), "%s: first a district is selected and its info shows (%s)" % [k, _info(main)])
		(cases[k] as Callable).call(); await _frames(20)
		_check(not _showing(main), "%s: afterwards no district info is left (%s)" % [k, _info(main)])
	# another district / a country replaces the info: exactly one card
	main._clear_overlay(); main.hud._close_pop(); main._select(-1); await _frames(6)
	main._on_pick(mine, false); await _frames(14)
	main._on_pick(other, false); await _frames(14)
	_check(main.selected == other and _count(main, "TBTagCard") <= 1, "another district replaces the first (%s)" % _info(main))
	main._on_pick(foreign, false); await _frames(14)
	_check(main.selected == foreign and _count(main, "TBTagCard") <= 1, "a foreign country replaces it (%s)" % _info(main))
	# the long-press tip goes with the next call
	main._select(-1); await _frames(4)
	main._on_peek(foreign); await _frames(6)
	_check(main.tip.visible, "a long press shows the tip")
	main.hud._screen("budget"); await _frames(14)
	_check(not main.tip.visible, "the tip is gone after a button was pressed (%s)" % _info(main))
	# the camera and the zoom keep the info (they are the same map)
	main._clear_overlay(); main._select(-1); await _frames(6)
	main._on_pick(mine, false); await _frames(10)
	_click(main, main.hud._zin); await _frames(10)
	_check(main.selected == mine, "zooming keeps the selected district (%s)" % _info(main))
	print("INFO_DISMISS OK" if fails == 0 else "INFO_DISMISS FAIL %d" % fails)
	quit(fails)
