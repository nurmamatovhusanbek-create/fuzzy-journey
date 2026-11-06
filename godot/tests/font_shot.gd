extends SceneTree
## Font lab: the same three screens (map with the district ring, the Build picker, the realm page) for a typeface pairing. Usage: -s tests/font_shot.gd -- <w> <h> <outprefix>   (TB_LANG, TB_PHONE_UI)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _shot(path: String) -> void: root.get_texture().get_image().save_png(path)
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
	main._select(p); await _frames(30)
	_shot(pre + "_1map.png")
	var vi := -1
	for i in main.panel._verbs.size(): if String(main.panel._verbs[i]["id"]) == "build": vi = i
	main.panel._press(vi); await _frames(25)
	var pk: TBBuildPicker = main.panel._bpicker
	if pk != null:
		pk._pick(3); await _frames(10)
		_shot(pre + "_2build.png")
		pk.queue_free()
	await _frames(5)
	main._select(-1)
	for id in ["bengal", "malacca", "zayyanid_caliphate", "congo", "benin"]: g.set_rel(me, g.nat_code.find(id), TBData.REL_ALLY)
	for id in ["hausa_states", "alwa", "athabaskan"]: g.set_rel(me, g.nat_code.find(id), TBData.REL_NAP)
	g.set_rel(me, g.nat_code.find("emirate_of_the_white_sheep_turks"), TBData.REL_WAR)
	main._open_realm_page(); await _frames(30)
	_shot(pre + "_3realm.png")
	quit(0)
