extends SceneTree
## Command card, orders on the map and marker tiers: screenshots + behavioural checks.
## Usage: -- <outdir> <w> <h> [units] [lang]      (units = 1 px per logical unit, e.g. an 800x360 phone)
var _out := ""
var _tag := ""
var fails := 0

func _shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/cc_%s_%s.png" % [_out, _tag, name])

func _check(cond: bool, what: String) -> void:
	if not cond:
		print("FAIL: ", what); fails += 1

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	var w := int(a[1]); var h := int(a[2])
	var units: bool = a.size() > 3 and a[3] == "1"
	var lang: String = a[4] if a.size() > 4 else "en"
	_tag = "%dx%d%s%s" % [w, h, "u" if units else "", "" if lang == "en" else "_" + lang]
	root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	await process_frame; await process_frame
	main._update_ui_scale()
	await process_frame
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	if units:
		root.size_changed.disconnect(main._update_ui_scale)
		root.content_scale_size = Vector2i(w, h)
		for i in 3: await process_frame
		main.panel.layout_for(main.size); main.hud.layout_for(main.size)
		print("UNITS main.size=", main.size, " profile=", main.panel.profile, " scale=", root.content_scale_size, " win=", root.size)
	var g: TBGame = main.g
	var me := fr
	g.gold[me] = 400; g.mp[me] = 8; g.dp[me] = 8; g.manpower[me] = 300
	# ---- cases: pick provinces
	var own_army := -1; var own_small := -1; var peace_p := -1; var enemy_p := -1; var enemy_src := -1; var neutral_p := -1
	for p in g.owned(me):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[e]
			var o := g.owner[q]
			if g.nb_sea[e] != 0: continue
			if o != 0 and o != me and enemy_p < 0 and g.get_rel(me, o) == 0: enemy_p = q; enemy_src = p
	var eo := g.owner[enemy_p]
	for p in g.owned(me):
		if p == enemy_src or g.capital[p] != 0 or own_army >= 0: continue
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.owner[g.nb[e]] == me and g.nb_sea[e] == 0 and g.nb[e] != enemy_src: own_army = p; break
	for p in g.owned(me):
		if p != enemy_src and p != own_army and own_small < 0 and g.capital[p] == 0: own_small = p
	for e in range(g.nb_off[enemy_p], g.nb_off[enemy_p + 1]):
		var q2: int = g.nb[e]
		if g.owner[q2] != me and g.owner[q2] != eo and g.owner[q2] != 0 and g.nb_sea[e] == 0 and peace_p < 0 and g.get_rel(me, g.owner[q2]) == 0: peace_p = q2
	if peace_p < 0: peace_p = enemy_p
	var pe_owner := g.owner[peace_p]
	# neutral land next to mine: release a border province of mine's neighbour
	neutral_p = -1
	for p in range(g.P):
		if g.owner[p] == 0 and neutral_p < 0:
			neutral_p = p
	g.army[own_army] = 33; g.gen[own_army] = TBGenerals.pack(2, 5, 0)
	g.army[own_small] = 1
	g.army[enemy_src] = 119
	g.army[enemy_p] = 32
	g.army[peace_p] = 20
	var cap: int = g.capital_of[me]
	main.map.fly_to(main.world.lon[enemy_src], main.world.lat[enemy_src], 3.2)
	for i in 8: await process_frame
	main._select(own_army)
	await _shot("1_own_army")
	_check(main.panel.visible, "card visible for own army")
	main.panel.foreign_panel_fn = Callable()                 # the card keeps its diplomacy verbs when the left panel is off
	_check(main.panel._verbs.size() >= 3 and main.panel._verbs[0]["id"] == "move", "case 1 first verb is Move")
	main.panel.set_drawer(true)
	await _shot("1b_drawer")
	main.panel.set_drawer(false)
	main._select(own_small)
	await _shot("2_own_small")
	_check(main.panel._verbs[0]["id"] == "recruit", "case 2 primary verb is Recruit")
	main._select(peace_p)
	await _shot("3_foreign_peace")
	_check(String(main.panel._verbs[0]["id"]).begins_with("f_") and main.panel._verbs.any(func(v): return v["id"] == "f_war"), "case 3 lists the nation actions (pact ... declare war) as rows")
	g.dp[me] = 8
	g.set_rel(me, eo, 1)
	main._select(enemy_p)
	await _shot("4_enemy_war")
	_check(main.panel._verbs[0]["id"] == "attack", "case 4 primary verb is Attack")
	if neutral_p >= 0:
		main._select(neutral_p)
		await _shot("5_neutral")
		_check(main.panel._verbs[0]["id"] == "colonize", "case 5 primary verb is Colonize")
	# held variant: a province of the enemy occupied by me
	g.occupier[enemy_p] = me; g.army[enemy_p] = 40
	main._select(enemy_p)
	await _shot("6_held")
	g.occupier[enemy_p] = 0; g.army[enemy_p] = 32
	# ---- orders: touch flow. Select the own army next to the enemy, tap the enemy -> preview, tap again -> confirm
	main.flow.touch = true
	main._select(enemy_src)
	await process_frame
	_check(main.flow.src == enemy_src and main.flow.targets.has(enemy_p), "selecting an army lights the enemy as a target")
	await _shot("7_armed_targets")
	main.map.last_pick_touch = true
	main.map.fly_to(main.world.lon[enemy_p], main.world.lat[enemy_p], 3.6)
	for i in 5: await process_frame
	main._on_pick(enemy_p, false)
	await _shot("8_preview")
	_check(main.flow.mode == TBOrderFlow.Mode.PREVIEW and main.flow.tgt == enemy_p, "tapping an enemy target opens the preview (no command sent)")
	_check(g.army[enemy_src] == 119, "preview did not move the army")
	main.panel.send_frac = 0.5
	main.flow.share_changed()
	await _shot("9_preview_half")
	main.panel.send_frac = 1.0
	main.flow.share_changed()
	# Esc steps back exactly one layer
	main.panel.back()
	_check(main.flow.mode == TBOrderFlow.Mode.ARMED and main.panel.visible, "Esc leaves the preview, keeps the card")
	# keyboard: Tab cycles to the target, Enter confirms
	main.flow.cycle(1)
	_check(main.flow.mode == TBOrderFlow.Mode.PREVIEW, "Tab previews a target")
	var mp0: float = g.mp[me]
	main.flow.confirm()
	await process_frame
	_check(g.mp[me] < mp0, "confirm sent the attack (moves spent)")
	main.map.fly_to(main.world.lon[enemy_src], main.world.lat[enemy_src], 3.2)
	# explicit Move (M): own armies become targets
	main._select(own_army)
	main._on_move_requested(own_army)
	await _shot("10_move_armed")
	await _shot("10b_after")
	# mouse hover tooltip with the attack outcome
	main._select(enemy_src)
	main.map.fly_to(main.world.lon[enemy_src], main.world.lat[enemy_src], 6.5)
	for i in 5: await process_frame
	main._on_hover(enemy_p)
	main.tip.position = Vector2(w * 0.5 + 60, h * 0.3)
	await _shot("12_hover_tip")
	# war confirm
	g.set_rel(me, eo, 0)
	g.truce[me * g.N1 + eo] = 0; g.truce[eo * g.N1 + me] = 0
	main._select(enemy_p if g.owner[enemy_p] == eo else peace_p)
	main.panel._war_target = g.owner[main.panel.p]
	main.panel.rebuild()
	await _shot("11_war_confirm")
	main.panel._war_target = -1
	# mouse: right-click orders, right-click again confirms; left-click selects (even a lit target)
	g.set_rel(me, eo, 1); g.mp[me] = 8
	g.occupier[enemy_p] = 0; g.army[enemy_p] = 25; g.army[enemy_src] = 90
	if g.owner[enemy_p] == eo and g.controller(enemy_p) == eo:
		main.map.last_pick_touch = false
		main._select(enemy_src)
		main._on_pick(enemy_p, false)
		_check(main.selected == enemy_p and main.flow.mode != TBOrderFlow.Mode.PREVIEW, "mouse left-click selects, it does not order")
		main._select(enemy_src)
		main._on_pick(enemy_p, true)
		_check(main.flow.mode == TBOrderFlow.Mode.PREVIEW, "right-click opens the preview")
		var mp1: float = g.mp[me]
		main._on_pick(enemy_p, true)
		_check(g.mp[me] < mp1, "right-click again confirms")
	# one-tap non-attack move into own land without an army (touch)
	main.flow.touch = true; main.map.last_pick_touch = true
	var dest := -1
	for e in range(g.nb_off[own_army], g.nb_off[own_army + 1]):
		var q3: int = g.nb[e]
		if g.owner[q3] == me and g.nb_sea[e] == 0 and q3 != enemy_src: dest = q3; break
	if dest >= 0:
		g.army[own_army] = 30; g.army[dest] = 0; g.mp[me] = 8
		main._select(own_army)
		main._on_pick(dest, false)
		_check(g.army[dest] > 0 and main.selected == dest, "touch tap on an empty own province moves in one tap and the selection follows")
	# keyboard: Tab with nothing selected cycles own armies
	main._select(-1)
	main.flow.cycle(1)
	_check(main.flow.focus_p >= 0, "Tab focuses an own army")
	# a rejected command shows its reason on the card
	g.gold[me] = 0
	main._select(own_small if g.owner[own_small] == me else own_army)
	main.panel._press(0 if main.panel._verbs.size() > 0 else 0)
	await process_frame
	# marker zoom tiers
	main._select(-1)
	for z in [0.9, 2.0, 4.5]:
		main.map.fly_to(main.world.lon[enemy_src], main.world.lat[enemy_src], z)
		for i in 6: await process_frame
		await _shot("tier_%d" % int(z * 10))
	if fails > 0: push_error("UI_CMDCARD FAIL %s" % _tag)
	print("UI_CMDCARD ", "OK" if fails == 0 else "FAIL", " ", _tag)
	quit(1 if fails > 0 else 0)
