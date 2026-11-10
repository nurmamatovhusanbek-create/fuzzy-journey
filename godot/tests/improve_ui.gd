extends SceneTree
## Rules 5: Build, Develop and Veteran colony are one verb, Improve; it opens a short list whose doors lead to the Blueprint picker and the project window. Usage: -s tests/improve_ui.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _init() -> void:
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	g.gold[me] = 5e6; g.mp[me] = 10.0
	var p := -1
	for q in g.P: if g.owner[q] == me and g.army[q] == 0: p = q; break
	main.map.jump_to(g.world.lon[p], g.world.lat[p], 4.0)
	for i in 10: await process_frame
	main._select(p)
	for i in 20: await process_frame
	var ids: Array = []
	for v in main.panel._verbs: ids.append(String(v["id"]))
	print("verbs: ", ids)
	_check(ids.has("improve"), "Improve is a verb")
	_check(not ids.has("build") and not ids.has("develop") and not ids.has("settle"), "Build, Develop and Veteran colony are folded into it")
	var idx := ids.find("improve")
	_check(idx >= 0 and bool(main.panel._verbs[idx]["can"]["ok"]), "Improve is open with gold in the treasury")
	main.panel._press(idx)
	for i in 8: await process_frame
	_check(main.panel._popover != null, "Improve opens a list")
	if OS.get_environment("TB_SHOT") != "": root.get_viewport().get_texture().get_image().save_png(OS.get_environment("TB_SHOT") + "_improve.png")
	var rows: Array = main.panel._verbs[idx]["rows"]
	var labels: Array = []
	for r in rows: labels.append(String(r["label"]))
	print("rows: ", labels)
	_check(labels.has("Buildings") and labels.has("Projects"), "the list has Buildings and Projects")
	main.panel._popover.picked.emit(labels.find("Buildings"))
	for i in 8: await process_frame
	_check(main.panel._bpicker != null, "Buildings opens the Blueprint picker")
	main.panel._close_popover()
	main.panel._press(idx)
	for i in 8: await process_frame
	main.panel._popover.picked.emit(labels.find("Projects"))
	for i in 8: await process_frame
	_check(main.panel._dmodal != null, "Projects opens the project window")
	main.panel._close_popover()
	# with no gold the verb says so
	g.gold[me] = 0.0
	main._select(-1); for i in 4: await process_frame
	main._select(p); for i in 12: await process_frame
	var ids2: Array = []
	for v in main.panel._verbs: ids2.append(String(v["id"]))
	var i2 := ids2.find("improve")
	var bad := 0
	for r in main.panel._verbs[i2]["rows"]:
		if (String(r["label"]) == "Buildings" or String(r["label"]) == "Projects") and not bool(r["ok"]): bad += 1
	_check(i2 >= 0 and bad == 2, "with no gold the Buildings and Projects doors are shut and say why (%d)" % bad)
	print("IMPROVE_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
