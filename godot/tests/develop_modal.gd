extends SceneTree
## The Develop choice (rules 4): the verb opens a list of projects, one is chosen, Start runs it; a blocked project says why; the window drags and closes. Usage: -s tests/develop_modal.gd -- <w> <h>   (TB_SHOT=prefix saves pictures)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lg: String = OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en"
	main.cfg["lang"] = lg; TBI18n.load_lang(lg); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	g.gold[me] = 400.0 if g.rules < 5 else 5.0e6; g.mp[me] = 6.0
	await _frames(25)
	var p := -1
	for q in g.owned(me): if g.world.id[q] == "uzb_samarkand": p = q
	g.pop[p] = 165; g.econ[p] = 3; g.dev[p] = 1; g.stab[p] = 84
	main._select(p); await _frames(30)
	var vi := -1
	var via_improve := false
	for i in main.panel._verbs.size():
		if String(main.panel._verbs[i]["id"]) == "develop": vi = i
		if String(main.panel._verbs[i]["id"]) == "improve": vi = i; via_improve = true
	_check(vi >= 0, "the Develop verb (rules 5: Improve) is there")
	if vi < 0: print("DEVELOP_MODAL FAIL"); quit(1); return
	main.panel._press(vi); await _frames(30)
	if via_improve:                                                      # rules 5: Improve opens a list; its Projects door is the project window
		var lab: Array = []
		for r in main.panel._verbs[vi]["rows"]: lab.append(String(r["label"]))
		main.panel._popover.picked.emit(lab.find("Projects")); await _frames(30)
	var md: TBDevelopModal = main.panel._dmodal
	_check(md != null, "Develop opens the choice")
	if md == null: print("DEVELOP_MODAL FAIL"); quit(1); return
	_check(md._rows.size() == 4, "four projects are listed")
	_check(not bool(md._cans[3]["ok"]) and String(md._cans[3]["reason"]) == "calm", "public order says why it cannot (%s)" % str(md._cans[3]["reason"]))
	if OS.get_environment("TB_SHOT") != "": root.get_texture().get_image().save_png(OS.get_environment("TB_SHOT") + "_develop.png")
	var r0 := md.get_global_rect()
	# drag by the title row
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true; ev.position = Vector2(r0.position.x + 140.0, r0.position.y + 16.0); ev.global_position = ev.position; root.push_input(ev, true); await _frames(2)
	var mv := InputEventMouseMotion.new(); mv.position = ev.position + Vector2(-120, 50); mv.global_position = mv.position; root.push_input(mv, true); await _frames(2)
	ev = InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = false; ev.position = mv.position; ev.global_position = mv.position; root.push_input(ev, true); await _frames(3)
	_check(md.get_global_rect().position.distance_to(r0.position) > 50.0, "the window drags by its title row")
	# choose settlement, start it
	md._pick(2); await _frames(10)
	var gold0: float = g.gold[me]
	md._do(); await _frames(10)
	_check(g.proj_kind[p] == 3 and g.gold[me] < gold0, "Start runs the project and takes its price (kind %d)" % g.proj_kind[p])
	_check(main.panel._dmodal == null or not is_instance_valid(main.panel._dmodal), "the window closes after Start")
	print("DEVELOP_MODAL OK" if fails == 0 else "DEVELOP_MODAL FAIL %d" % fails)
	quit(fails)
