extends SceneTree
## Screenshots of the colonize verb: possible, and blocked with its list of requirements. Usage: -s tests/colony_shot.gd -- <w> <h> <outprefix>
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var pre: String = a[2]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lg: String = OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en"
	main.cfg["lang"] = lg; TBI18n.load_lang(lg); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("discovery", "normal")
	var g0: TBGame = main.g
	var me: int = 1
	for n in range(1, g0.N1):
		var hit := false
		for p in g0.owned(n):
			for i in range(g0.nb_off[p], g0.nb_off[p + 1]):
				if g0.owner[g0.nb[i]] == 0 and g0.nb_sea[i] == 0: hit = true; break
			if hit: break
		if hit and g0.own_count(n) >= 3: me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	await _frames(25)
	var target := -1
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.owner[q] == 0 and g.nb_sea[i] == 0: target = q; break
		if target >= 0: break
	print("target ", target)
	if target < 0: quit(1); return
	g.gold[me] = 30.0; g.mp[me] = 1.0; g.manpower[me] = 10.0
	main._select(target); await _frames(35)
	var rg = main.get("ring")
	if rg == null: rg = main.get("map_ring")
	print("ring ", rg)
	if rg != null:
		rg._hover = 0; rg._tip_show(0); await _frames(6)
	root.get_texture().get_image().save_png(pre + "_blocked.png")
	g.gold[me] = 900.0; g.mp[me] = 6.0; g.manpower[me] = 400.0
	main._select(-1); await _frames(5); main._select(target); await _frames(35)
	if rg != null:
		rg._hover = 0; rg._tip_show(0); await _frames(6)
	root.get_texture().get_image().save_png(pre + "_ok.png")
	quit(0)
