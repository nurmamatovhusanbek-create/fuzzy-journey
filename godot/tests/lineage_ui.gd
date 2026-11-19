extends SceneTree
## The Realm page shows the lineage and its stages with their conditions; Proclaim forms the new identity, shows the ceremony and refreshes the names. Usage: -s tests/lineage_ui.gd -- <out dir> (TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _find(n: Node, test: Callable) -> Array:
	var out: Array = []
	if test.call(n): out.append(n)
	for c in n.get_children(): out.append_array(_find(c, test))
	return out
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("russian_empire"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	for i in 20: await process_frame
	main._open_realm_page()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/lineage_1_realm.png" % out)
	var pro := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower() == "form")
	print("proclaim buttons: ", pro.size())
	_check(pro.size() >= 1, "the Realm page offers names to proclaim")
	for b in pro: _check((b as Button).disabled, "closed doors say so (disabled)")
	# make the Russian Republic possible and press it
	var rs := TBLineage.index_of("russia")
	g.year = 1918; g.regime[me] = 3; g.gold[me] = 1e9; g.mp[me] = 10.0
	for p in TBLineage.STAGES[rs]["core"]: g.set_owner(int(p), me)
	main._toggle_window("realm"); for i in 6: await process_frame
	main._open_realm_page()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/lineage_2_open.png" % out)
	var pro2 := _find(main._overlay, func(x): return x is Button and String((x as Button).text).to_lower() == "form" and not (x as Button).disabled)
	_check(pro2.size() >= 1, "with the land, the government and the year a door is open")
	var before: String = g.nat_name[me]
	if pro2.size() >= 1: (pro2[0] as Button).pressed.emit()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/lineage_3_ceremony.png" % out)
	print("name: ", before, " -> ", g.nat_name[me])
	_check(g.nat_name[me] != before and TBLineage.current(g, me) >= 0, "the nation has a new name")
	_check(main.hud.get_child_count() > 0, "the HUD is alive")
	print("LINEAGE_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
