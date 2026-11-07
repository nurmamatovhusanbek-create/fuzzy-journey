extends SceneTree
## Every verb of a district carries its requirement list (cost lines with what the player has, and the reason when something else blocks it). Usage: -s tests/needs_lists.gd -- <w> <h>   (TB_SHOT=prefix saves the picture with a blocked verb's tip)
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
	main._apply_quality(); main._update_ui_scale(); main.cfg["phone_ui"] = "desktop"; main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	await _frames(25)
	var p := -1
	for q in g.owned(me): if g.capital[q] == 0 and g.army[q] >= 1: p = q; break
	g.gold[me] = 3.0; g.mp[me] = 0.0; g.manpower[me] = 2.0
	main.map.fly_to(g.world.lon[p], g.world.lat[p], 9.0, 0.0); await _frames(70)
	main._select(p); await _frames(30)
	var with_needs := 0; var blocked := 0
	for v in main.panel._verbs:
		var cn: Dictionary = v["can"]
		if cn.has("needs"): with_needs += 1
		if not bool(cn["ok"]):
			blocked += 1
			var unmet := 0
			for nd in cn.get("needs", []): if not bool(nd[0]): unmet += 1
			_check(unmet >= 1, "blocked verb %s lists what is missing (%d unmet)" % [v["id"], unmet])
	print("verbs ", main.panel._verbs.size(), " with a list ", with_needs, " blocked ", blocked)
	_check(blocked >= 2, "with no gold, moves or men several verbs are blocked (%d)" % blocked)
	if OS.get_environment("TB_SHOT") != "":
		for i in main.panel._verbs.size():
			if not bool(main.panel._verbs[i]["can"]["ok"]) and main.panel._verbs[i]["id"] == "recruit":
				main.ring._hover = i; main.ring._tip_show(i); await _frames(8)
				root.get_texture().get_image().save_png(OS.get_environment("TB_SHOT") + "_needs.png")
	print("NEEDS_LISTS OK" if fails == 0 else "NEEDS_LISTS FAIL %d" % fails)
	quit(fails)
