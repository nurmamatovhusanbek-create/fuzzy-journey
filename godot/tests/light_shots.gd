extends SceneTree
## High-contrast light mode (cfg hc = "light") on the screens that mix the Bezel look with paper dialogs. Usage: -s tests/light_shots.gd -- <w> <h> <out dir> [hc: light | dark | off]
var _out := ""
var bad := 0
## every Bezel label inside a card must read on the surface under it (3:1 at least)
func _contrast(tag: String, n: Node) -> void:
	if n is TBBz.TLabel and (n as TBBz.TLabel).is_visible_in_tree() and (n as TBBz.TLabel).text != "":
		var tl := n as TBBz.TLabel
		var bg: Color = tl._surface()
		if bg.a > 0.5:                                                          # in a card: the ink it draws, against the surface it is drawn on (3:1 at least)
			var ink: Color = tl._ink()
			var worst: float = TBTokens.contrast(ink, bg)
			if worst < 3.0: bad += 1; print("LOW CONTRAST %.1f: %s: '%s'" % [worst, tag, tl.text.left(40)])
	for c in n.get_children(): _contrast(tag, c)
func _shot(name: String) -> void:
	for i in 20: await process_frame
	if TBTokens.on_paper(): _contrast(name, root)
	root.get_viewport().get_texture().get_image().save_png("%s/lm_%s.png" % [_out, name])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[2]
	var hc: String = a[3] if a.size() > 3 else "light"
	DisplayServer.window_set_size(Vector2i(int(a[0]), int(a[1]))); root.size = Vector2i(int(a[0]), int(a[1]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = false; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"; main.cfg["hc"] = hc
	main.theme = TBKit.apply_settings(main.cfg)
	main._apply_quality(); main._update_ui_scale()
	await _shot("title")
	main._begin_pick("modern", "normal")
	await _shot("pick")
	var me: int = 1
	for n in range(1, main.g.N1):
		if main.g.dname(n) == "Russia": me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.map.fly_to(main.world.lon[g.capital_of[me]], main.world.lat[g.capital_of[me]], 1.6)
	for i in 60: await process_frame
	var from_n: int = 1
	for n in range(1, g.N1):
		if g.dname(n) == "Ukraine": from_n = n; break
	main._clear_overlay()
	TBModals.event_prompt(main._overlay, {"kind": "prop", "id": "nap", "from": from_n, "uid": 1, "n": me, "p": 0}, func(i): pass, g, func(): pass)
	await _shot("event_prop")
	main._clear_overlay()
	TBModals.event_prompt(main._overlay, {"kind": "prop", "id": "ultimatum", "from": from_n, "uid": 2, "n": me, "p": g.owned(me)[0]}, func(i): pass, g, func(): pass)
	await _shot("event_ult")
	main._clear_overlay()
	TBPanel.confirm(main._overlay, "Declare war on Ukraine?", "Casus belli: border dispute. It costs 3 diplomacy points and cannot be undone.", "Declare war", func(): pass, true, "swords")
	await _shot("confirm")
	main._clear_overlay()
	main._select(g.capital_of[me])
	await _shot("province")
	main._select(-1); main._clear_overlay(); main._open_nations()
	await _shot("nations")
	main._clear_overlay(); main._open_budget()
	await _shot("budget")
	main._clear_overlay(); main._open_council("goals")
	await _shot("goals")
	main._clear_overlay(); main._open_menu_hub("settings")
	await _shot("settings")
	main._clear_overlay(); main._open_decisions()
	await _shot("decrees")
	main._clear_overlay(); main._open_council()
	await _shot("council")
	main._clear_overlay(); main._open_annals()
	await _shot("annals")
	main._clear_overlay(); TBModals.war_confirm(main._overlay, g, from_n, func(): pass)
	await _shot("war")
	main._clear_overlay(); main._open_menu_hub("")
	await _shot("menu")
	main._clear_overlay(); main._open_dossier(g.capital_of[me])
	await _shot("dossier")
	main._clear_overlay(); main.hud.toast("Pact with Ukraine ends next turn"); main.hud.toast("Ukraine refused your trade deal", true)
	await _shot("toasts")
	main._clear_overlay(); g.over = true; g.winner = me; g.victory_kind = "domination"
	TBModals.game_over(main._overlay, g, func(): pass)
	await _shot("game_over")
	g.over = false
	print("LIGHT_CONTRAST OK" if bad == 0 else "LIGHT_CONTRAST FAIL %d" % bad)
	quit(1 if (bad > 0 and a.size() > 4 and a[4] == "expect") else 0)
