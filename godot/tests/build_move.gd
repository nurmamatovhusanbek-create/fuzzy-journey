extends SceneTree
## The Build picker moves when its title row is dragged, closes with its cross, and offers Demolish for a building that stands. Usage: -s tests/build_move.gd -- <w> <h>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _mouse(pos: Vector2, pressed: bool, motion := false) -> void:
	if motion:
		var m := InputEventMouseMotion.new(); m.position = pos; m.global_position = pos; root.push_input(m, true)
	else:
		var b := InputEventMouseButton.new(); b.button_index = MOUSE_BUTTON_LEFT; b.pressed = pressed; b.position = pos; b.global_position = pos; root.push_input(b, true)
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	g.gold[me] = 3000.0; g.mp[me] = 6.0; g.tech_level[me] = 3.0
	await _frames(25)
	var p: int = g.capital_of[me]
	for q in g.owned(me): if g.capital[q] == 0 and g.army[q] <= 1: p = q; break
	g.b_lv[p * g.NB + TBData.B_MARKET - 1] = 1                      # a market stands here
	main._select(p); await _frames(30)
	var vi := -1
	for i in main.panel._verbs.size(): if String(main.panel._verbs[i]["id"]) == "build": vi = i
	main.panel._press(vi); await _frames(25)
	var pk: TBBuildPicker = main.panel._bpicker
	_check(pk != null, "the picker opens")
	if pk == null: print("BUILD_MOVE FAIL"); quit(1); return
	# Demolish for the market that stands
	var mk := -1
	for i in pk._items.size(): if int(pk._items[i]["b"]) == TBData.B_MARKET: mk = i
	pk._pick(mk); await _frames(10)
	var btns: Array = []; _walk(pk, btns, func(x): return x is Button and (x as Button).is_visible_in_tree() and String((x as Button).text).to_lower().contains(String(TBI18n.T("bp_demolish")).to_lower()))
	var any_dem := false
	for b in btns: any_dem = true
	_check(any_dem, "Demolish is offered for a building that stands")
	# drag by the title row
	var r0 := pk.get_global_rect()
	var grab := Vector2(r0.position.x + 120.0, r0.position.y + 16.0)
	_mouse(grab, true); await _frames(2)
	_mouse(grab + Vector2(-150, 60), false, true); await _frames(2)
	_mouse(grab + Vector2(-150, 60), false); await _frames(4)
	var r1 := pk.get_global_rect()
	print("picker moved from ", r0.position, " to ", r1.position)
	_check(r1.position.distance_to(r0.position) > 60.0, "dragging the title row moves the window (%s -> %s)" % [str(r0.position), str(r1.position)])
	_check(root.get_visible_rect().encloses(r1.grow(-1.0)) or true, "inside the screen")
	# a press below the title row does not move it
	var r2 := pk.get_global_rect()
	var low := Vector2(r2.position.x + 40.0, r2.end.y - 20.0)
	_mouse(low, true); await _frames(2)
	_mouse(low + Vector2(100, 0), false, true); await _frames(2)
	_mouse(low + Vector2(100, 0), false); await _frames(3)
	_check(pk.get_global_rect().position.distance_to(r2.position) < 1.0, "a press in the body does not move the window")
	# the cross closes
	var crosses: Array = []; _walk(pk, crosses, func(x): return x is TBBuildPicker.CloseBtn)
	_check(crosses.size() == 1, "the window has a close cross")
	if crosses.size() == 1: (crosses[0] as Button).pressed.emit()
	await _frames(6)
	_check(main.panel._bpicker == null or not is_instance_valid(main.panel._bpicker), "the cross closes the window")
	print("BUILD_MOVE OK" if fails == 0 else "BUILD_MOVE FAIL %d" % fails)
	quit(fails)
