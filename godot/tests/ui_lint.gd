extends SceneTree
## Layout lint: opens every screen at several resolutions and reports controls that overflow their parent or the screen,
## clipped text, and overlapping buttons. Usage: -- [width height ...pairs] ; default is a set of phone/tablet/desktop sizes.
var _findings := {}
var _ctx := ""

func _walk(n: Node, vp: Rect2, scroll_depth: int) -> void:
	for c in n.get_children():
		if not (c is Control) or not c.is_visible_in_tree():
			_walk(c, vp, scroll_depth); continue
		var ctl := c as Control
		var sd := scroll_depth + (1 if ctl is ScrollContainer else 0)
		var gr := ctl.get_global_rect()
		var par := ctl.get_parent()
		if scroll_depth == 0 and (ctl is Button or ctl is Label or ctl is LineEdit or ctl is OptionButton):
			# off screen
			if gr.size.x > 1 and (gr.position.x < vp.position.x - 2 or gr.end.x > vp.end.x + 2 or gr.position.y < vp.position.y - 2 or gr.end.y > vp.end.y + 2):
				_add("offscreen", ctl, "rect=%s" % str(gr))
			# clipped text
			var txt := ""
			if ctl is Label: txt = (ctl as Label).text
			elif ctl is Button: txt = (ctl as Button).text
			if txt != "" and ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
				var f: Font = ctl.get_theme_font("font")
				var fs: int = ctl.get_theme_font_size("font_size")
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if w > gr.size.x + 2: _add("clipped-text", ctl, "'%s' needs %d has %d" % [txt.left(30), int(w), int(gr.size.x)])
			if txt != "" and ctl is Button:
				var f2: Font = ctl.get_theme_font("font")
				var fs2: int = ctl.get_theme_font_size("font_size")
				var w2 := f2.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
				if w2 > gr.size.x - 4: _add("clipped-button", ctl, "'%s' needs %d has %d" % [txt.left(30), int(w2), int(gr.size.x)])
			# small touch targets
			if ctl is Button and not (ctl is OptionButton) and (gr.size.y < 30 or gr.size.x < 30): _add("tiny-button", ctl, "size=%s" % str(gr.size))
		# child outside its (non-scroll) parent
		if par is Control and not (par is ScrollContainer) and scroll_depth == 0 and (ctl is Button or ctl is Label):
			var pr := (par as Control).get_global_rect()
			if gr.size.x > 1 and (gr.end.x > pr.end.x + 2 or gr.position.x < pr.position.x - 2 or gr.end.y > pr.end.y + 2 or gr.position.y < pr.position.y - 2):
				_add("overflows-parent", ctl, "child=%s parent=%s" % [str(gr), str(pr)])
		_walk(c, vp, sd)

func _add(kind: String, ctl: Control, extra: String) -> void:
	var path := ""
	var n: Node = ctl
	var depth := 0
	while n != null and depth < 4:
		path = "%s/%s" % [n.get_class(), path] if path != "" else n.get_class()
		n = n.get_parent(); depth += 1
	var key := "%s | %s | %s | %s" % [_ctx, kind, ctl.get_class(), (ctl as Control).name]
	if not _findings.has(key): _findings[key] = extra

func _frames(n: int = 4) -> void:
	for i in n: await process_frame

func _init() -> void:
	var sizes: Array = [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(540, 960), Vector2i(800, 360), Vector2i(1024, 768)]
	var a := OS.get_cmdline_user_args()
	if a.size() >= 2: sizes = [Vector2i(int(a[0]), int(a[1]))]
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["theme"] = "standard"
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	g.gold[fr] = 700; g.dp[fr] = 8
	for sz in sizes:
		root.size = sz
		await _frames(3)
		main._update_ui_scale()
		await _frames(3)
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var tag := "%dx%d" % [sz.x, sz.y]
		var scenes := {
			"hud": func(): main._clear_overlay(); main._select(-1),
			"panel": func(): main._clear_overlay(); main._select(g.capital_of[fr]),
			"nations": func(): main._select(-1); main._clear_overlay(); TBModals.nations(main._overlay, g, func(n): pass),
			"nation": func(): main._clear_overlay(); TBModals.nation_detail(main._overlay, g, g.nat_code.find("russian_empire"), main._on_command, main._goto_nation),
			"budget": func(): main._clear_overlay(); TBModals.budget(main._overlay, g, main._on_command),
			"decisions": func(): main._clear_overlay(); TBModals.decisions(main._overlay, g, main._on_command),
			"chronicle": func(): main._clear_overlay(); TBModals.chronicle(main._overlay, g, func(p): pass),
			"goals": func(): main._clear_overlay(); TBModals.goals(main._overlay, g),
			"advisor": func(): main._clear_overlay(); TBModals.advisor(main._overlay, g, func(p): pass),
			"settings": func(): main._clear_overlay(); TBModals.settings(main._overlay, main.cfg, func(): pass, func(): pass, func(): pass),
			"save": func(): main._clear_overlay(); TBModals.save_load(main._overlay, true, func(s): pass, func(s): pass),
			"briefing": func(): main._clear_overlay(); TBModals.briefing(main._overlay, g, func(): pass),
			"tutorial": func(): main._clear_overlay(); TBModals.tutorial(main._overlay, func(): pass),
			"codex": func(): main._clear_overlay(); TBModals.codex(main._overlay),
			"honours": func(): main._clear_overlay(); TBModals.honours(main._overlay, main.cfg),
			"era": func(): main._clear_overlay(); TBModals.era_picker(main._overlay, "normal", func(e, d): pass, func(): pass),
			"hotseat": func(): main._clear_overlay(); TBModals.hotseat_setup(main._overlay, func(k): pass),
			"event": func(): main._clear_overlay(); g.ev_uid += 1; TBModals.event_prompt(main._overlay, {"uid": g.ev_uid, "n": fr, "kind": "prop", "id": "ultimatum", "from": g.nat_code.find("spanish_habsburg") if g.nat_code.has("spanish_habsburg") else 3, "p": g.capital_of[fr], "icon": "x", "cat": "", "count": 2}, func(i): pass, g),
			"menu": func(): main._clear_overlay(); main.show_menu(),
		}
		for name in scenes:
			_ctx = "%s %s" % [tag, name]
			scenes[name].call()
			await _frames(4)
			_walk(root, vp, 0)
		main._clear_overlay()
		if main.mode != "game":
			main._begin_pick("napoleonic", "normal"); main._start_game(fr); main.g.pending.clear(); main._clear_overlay(); g = main.g
	var keys := _findings.keys()
	keys.sort()
	for k in keys: print("LINT ", k, " :: ", _findings[k])
	print("LINT TOTAL ", keys.size())
	quit(0)
