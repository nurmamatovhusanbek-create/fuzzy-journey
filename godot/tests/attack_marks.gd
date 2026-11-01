extends SceneTree
## An attack on you (or one you can see) moves the camera to the province attacked and leaves a red arrow from the attacker that stays until your next action. Usage: -s tests/attack_marks.gd -- <w> <h>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 800
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang("en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	# an enemy province next to one of mine
	var src := -1; var tgt := -1; var en := -1
	for p in range(g.P):
		var o: int = g.owner[p]
		if o == 0 or o == me or o == g.rebel or g.human[o] != 0: continue
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.nb_sea[i] == 0 and g.owner[q] == me and g.controller(q) == me: src = p; tgt = q; en = o; break
		if src >= 0: break
	_check(src >= 0, "found an attacker next to my land")
	g.set_rel(me, en, TBData.REL_WAR)
	g.army[src] = 300; g.army[tgt] = 5; g.mp[en] = 20.0
	g.battle_fx.clear()
	var r := g.move_or_attack(en, src, tgt, 250)
	print("attack result: ", r, "  battle_fx: ", g.battle_fx.size())
	_check(g.battle_fx.size() >= 1, "the attack is recorded for the interface")
	main._replay_battles()
	for i in 6: await process_frame
	_check(main.map.labels.has_alerts(), "a red arrow is left on the map")
	var lon: float = rad_to_deg(main.map.lon0) if main.map.mode == 0 else g.world.lon[tgt]
	# the camera: the attacked province is on screen after the fly
	for i in 60: await process_frame
	var pt: Vector3 = main.map.project(g.world.lon[tgt], g.world.lat[tgt])
	var vis: Vector2 = main.get_viewport_rect().size
	_check(pt.z > 0.0 and pt.x > 0.0 and pt.y > 0.0 and pt.x < vis.x and pt.y < vis.y, "the attacked province is in view (%s)" % str(pt))
	if OS.get_environment("TB_SHOT") != "": root.get_viewport().get_texture().get_image().save_png(OS.get_environment("TB_SHOT"))
	# it stays through frames and a pan, and goes with the player's next action
	for i in 20: await process_frame
	_check(main.map.labels.has_alerts(), "it stays while nothing is done")
	main._select(g.owned(me)[0])
	for i in 4: await process_frame
	_check(not main.map.labels.has_alerts(), "the next action (selecting a province) clears it")
	# a fight in sight of the player but between two others is shown too (rules 4)
	var o1 := -1; var o2 := -1; var fa := -1; var fb := -1
	for p in range(g.P):
		var oa: int = g.owner[p]
		if oa == 0 or oa == me or oa == g.rebel: continue
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			var ob: int = g.owner[q]
			if g.nb_sea[i] == 0 and ob != 0 and ob != oa and ob != me and ob != g.rebel and TBVision.sees(g, q) and TBVision.sees(g, p): o1 = oa; o2 = ob; fa = p; fb = q; break
		if fa >= 0: break
	if fa >= 0:
		g.set_rel(o1, o2, TBData.REL_WAR); g.army[fa] = 400; g.army[fb] = 3; g.battle_fx.clear()
		g.move_or_attack(o1, fa, fb, 300)
		_check(g.battle_fx.size() >= 1, "a fight in sight between two others is recorded too")
	else:
		print("(no visible AI-vs-AI border found: skipped)")
	print("ATTACK_MARKS OK" if fails == 0 else "ATTACK_MARKS FAIL %d" % fails)
	quit(fails)
