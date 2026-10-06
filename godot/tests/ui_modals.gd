extends SceneTree
## Screenshot matrix of every modal / screen of the redone interface. Usage (TB_NOANIM=1; optional scale=1.5 for the text-size check):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 -s tests/ui_modals.gd -- <outdir> <lang> <WxH> [WxH ...] [only=name,name]
## Prints findings from the overflow walker (offscreen / clipped text) next to each shot.
var _findings := {}
var _ctx := ""
var text_scale := 1.0

func _walk(n: Node, vp: Rect2, clip_depth: int) -> void:
	for c in n.get_children():
		if not (c is Control) or not c.is_visible_in_tree(): _walk(c, vp, clip_depth); continue
		var ctl := c as Control
		var gr := ctl.get_global_rect()
		var sd := clip_depth + (1 if ctl is ScrollContainer else 0)
		if ctl is Button or ctl is Label:
			if clip_depth == 0 and gr.size.x > 1 and (gr.position.x < vp.position.x - 2 or gr.end.x > vp.end.x + 2 or gr.position.y < vp.position.y - 2 or gr.end.y > vp.end.y + 2):
				_add("offscreen", ctl, str(gr))
			var txt := ""
			if ctl is Label: txt = (ctl as Label).text
			elif ctl is Button: txt = (ctl as Button).text
			if txt != "" and clip_depth == 0:
				var f: Font = ctl.get_theme_font("font"); var fsz: int = ctl.get_theme_font_size("font_size")
				if ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (ctl as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
					var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
					if w > gr.size.x + 2: _add("clipped-label", ctl, "'%s' needs %d has %d" % [txt.left(30), int(w), int(gr.size.x)])
				elif ctl is Button and not (ctl as Button).clip_text:
					var w2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
					if w2 > gr.size.x - 4: _add("clipped-button", ctl, "'%s' needs %d has %d" % [txt.left(30), int(w2), int(gr.size.x)])
		_walk(c, vp, sd)

func _add(kind: String, ctl: Control, extra: String) -> void:
	var key := "%s | %s | %s" % [_ctx, kind, ctl.get_class()]
	var k2 := key + " | " + extra
	if not _findings.has(k2): _findings[k2] = true

func _frames(n: int = 4) -> void:
	for i in n: await process_frame

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var lang: String = a[1] if a.size() > 1 else "en"
	var sizes: Array = []
	var only: Array = []
	for i in range(2, a.size()):
		if a[i].begins_with("only="): only = a[i].substr(5).split(",")
		elif a[i].begins_with("scale="): text_scale = float(a[i].substr(6))
		else:
			var p: PackedStringArray = a[i].split("x"); sizes.append(Vector2i(int(p[0]), int(p[1])))
	if sizes.is_empty(): sizes = [Vector2i(1280, 720)]
	DirAccess.make_dir_recursive_absolute(out)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["theme"] = "standard"
	main.cfg["text_scale"] = text_scale; main._apply_a11y()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	var g: TBGame = main.g
	main._start_game(fr)
	g.pending.clear(); main._clear_overlay()
	g.gold[fr] = 700; g.dp[fr] = 8; g.intel[fr] = 20.0
	for i in 6: g.end_turn()
	g.pending.clear(); g.human_id = fr
	g.stats = g.stats
	var ru_id: int = g.nat_code.find("russian_empire")
	var au_id: int = g.nat_code.find("austrian_empire") if g.nat_code.has("austrian_empire") else 3
	TBSave.save(g, "auto"); TBSave.save(g, "2")
	main.cfg["honours"] = {"first_blood": "1805", "treasure": "1806", "empire_30": "1807"}
	var rand_ev := {"uid": 901, "n": fr, "kind": "rand", "id": "heresy", "icon": "x", "cat": "CRISIS", "count": 2}
	var sched_ev := {"uid": 902, "n": fr, "kind": "sched", "id": "x", "title": {"en": "The Continental Blockade", "ru": "Континентальная блокада"}, "flavor": {"en": "Napoleon closes the ports of Europe to British goods. Merchants grumble; the treasury fills.", "ru": "Наполеон закрывает порты Европы для британских товаров. Купцы ропщут, казна растёт."}, "labels": [{"en": "Enforce it strictly", "ru": "Строго соблюдать"}, {"en": "Look the other way", "ru": "Закрыть глаза"}], "fx": [[{"op": "nation.gold", "delta": 60}, {"op": "nation.happy", "delta": -8}, {"op": "nation.infamy", "delta": 4}], [{"op": "nation.gold", "delta": -20}]], "count": 2, "cat": "", "world": true}
	var ult_ev := {"uid": 903, "n": fr, "kind": "prop", "id": "ultimatum", "from": au_id, "p": g.capital_of[fr], "icon": "x", "cat": "", "count": 2}
	var scenes := {
		"title": func(): main.show_menu(),
		"newgame": func(): main.show_menu(); main._open_era_picker(),
		"pick": func(): main._hot_n = 0; main._begin_pick("napoleonic", "normal"),
		"pick_card": func(): main._hot_n = 0; main._begin_pick("napoleonic", "normal"); main._pick_flow.select_nation(fr, false),
		"pick_list": func(): main._hot_n = 0; main._begin_pick("napoleonic", "normal"); main._open_pick_list(),
		"nations": func(): main._open_nations(ru_id),
		"nations_war": func(): main._open_nations(-1, "war"),
		"rankings": func(): main._open_nations(-1, "", "rank"),
		"council": func(): main._open_council("advice"),
		"goals": func(): main._open_council("goals"),
		"budget": func(): main._open_budget(),
		"decisions": func(): main._open_decisions(),
		"annals": func(): main._open_annals(),
		"hub_save": func(): main._open_menu_hub("saves"),
		"hub_settings": func(): main._open_menu_hub("settings"),
		"hub_howto": func(): main._open_menu_hub("howto"),
		"hub_honours": func(): main._open_menu_hub("honours"),
		"briefing": func(): TBModals.briefing(main._overlay, g, func(): pass),
		"tutorial": func(): TBModals.tutorial(main._overlay, func(): pass),
		"event_rand": func(): TBModals.event_prompt(main._overlay, rand_ev, func(i): pass, g),
		"event_sched": func(): TBModals.event_prompt(main._overlay, sched_ev, func(i): pass, g),
		"ultimatum": func(): TBModals.event_prompt(main._overlay, ult_ev, func(i): pass, g),
		"gameover": func(): g.over = true; g.winner = fr; g.victory_kind = ""; TBModals.game_over(main._overlay, g, func(): pass); g.over = false; g.winner = 0,
		"pass": func(): TBModals.pass_device(main._overlay, g, fr, func(): pass),
		"confirm": func(): TBPanel.confirm(main._overlay, "Declare war on Austria?", "Casus belli: border dispute. It costs 3 diplomacy points and cannot be undone.", "Declare war on Austria", func(): pass, true, "swords"),
	}
	for sz in sizes:
		root.size = sz
		await _frames(3)
		main._update_ui_scale()
		await _frames(3)
		var vp := Rect2(Vector2.ZERO, main.size)
		var tag := "%s_%dx%d%s" % [lang, sz.x, sz.y, "" if text_scale == 1.0 else "_x%d" % int(text_scale * 100)]
		for name in scenes:
			if not only.is_empty() and not only.has(name): continue
			_ctx = "%s %s" % [tag, name]
			main.mode = "game"; main.g = g; main._hot_n = 0
			main._clear_overlay(); main._select(-1)
			if main.mode != "game": main.mode = "game"
			g.human_id = fr
			if not (name in ["title", "newgame", "pick", "pick_card", "pick_list"]): main.hud.visible = true
			scenes[name].call()
			await _frames(5)
			if name in ["pick", "pick_card", "pick_list"]:
				main.map.fly_to(main.world.lon[g.capital_of[fr]], main.world.lat[g.capital_of[fr]], 3.0)
				await _frames(6)
			_walk(main._overlay, vp, 0)
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, name])
			if name in ["pick", "pick_card", "pick_list", "title", "newgame"]:
				main.g = g
				main.mode = "game"; main.map.setup(g); main.hud.visible = true
				main._clear_overlay()
	for k in _findings: print("FINDING ", k)
	print("MODALS DONE findings=", _findings.size())
	quit(0)
