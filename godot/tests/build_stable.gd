extends SceneTree
## The Build picker keeps its place when another building is chosen: the rail's buttons do not move under the finger, the panel's top edge stays, the page only grows. Usage: -s tests/build_stable.gd -- <w> <h>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
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
	main.hud.set_seal_pulse(false)
	await _frames(25)
	var p: int = g.capital_of[me]
	for q in g.owned(me): if g.capital[q] == 0 and g.army[q] <= 1: p = q; break
	main._select(p); await _frames(25)
	var vi := -1
	for i in main.panel._verbs.size(): if String(main.panel._verbs[i]["id"]) == "build": vi = i
	main.panel._press(vi); await _frames(20)
	var pk: TBBuildPicker = main.panel._bpicker
	_check(pk != null and pk._rail_btns.size() >= 3, "the picker is open with a rail (%d)" % (pk._rail_btns.size() if pk != null else -1))
	if pk == null: print("BUILD_STABLE FAIL"); quit(1); return
	var base_btn: Vector2 = (pk._rail_btns[0] as Control).get_global_rect().position
	var base_top: float = pk.get_global_rect().position.y
	var last_h := pk.get_global_rect().size.y
	for i in pk._rail_btns.size():
		pk._pick(i); await _frames(6)
		var bp: Vector2 = (pk._rail_btns[0] as Control).get_global_rect().position
		var r := pk.get_global_rect()
		print("pick %d: first rail button %s, panel top %.1f height %.1f" % [i, str(bp), r.position.y, r.size.y])
		_check(bp.distance_to(base_btn) < 0.6, "pick %d: the rail does not move (%s vs %s)" % [i, str(bp), str(base_btn)])
		_check(absf(r.position.y - base_top) < 0.6, "pick %d: the panel's top edge stays (%.1f vs %.1f)" % [i, r.position.y, base_top])
		_check(r.size.y >= last_h - 0.6, "pick %d: the panel never shrinks (%.1f < %.1f)" % [i, r.size.y, last_h])
		last_h = maxf(last_h, r.size.y)
	print("BUILD_STABLE OK" if fails == 0 else "BUILD_STABLE FAIL %d" % fails)
	quit(fails)
