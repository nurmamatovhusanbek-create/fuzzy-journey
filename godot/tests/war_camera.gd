extends SceneTree
## The camera draws out for the FIRST battle of a war (an attack on you), not for every battle after it: the zoom stays where the player put it. Usage: -s tests/war_camera.gd (TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _init() -> void:
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	var aus: int = g.nat_code.find("austrian_empire")
	var tgt := -1
	for p in g.P: if g.owner[p] == me: tgt = p; break
	var src := -1
	for p in g.P: if g.owner[p] == aus: src = p; break
	for i in 5: await process_frame
	var close := 6.0
	main.map.jump_to(g.world.lon[tgt], g.world.lat[tgt], close)
	for i in 5: await process_frame
	g.battle_fx.append([src, tgt, 0, aus, me])
	main._replay_battles()
	for i in 5: await process_frame
	var z1: float = main.map.zoom
	print("zoom before ", close, " after the first battle ", z1)
	_check(z1 < close * 0.7, "the first battle of the war draws the camera out")
	main.map.jump_to(g.world.lon[tgt], g.world.lat[tgt], close)
	for i in 5: await process_frame
	g.battle_fx.append([src, tgt, 0, aus, me])
	main._replay_battles()
	for i in 5: await process_frame
	print("zoom after the second battle ", main.map.zoom)
	_check(absf(main.map.zoom - close) < 0.01, "the second battle of the same war leaves the zoom alone")
	print("WAR_CAMERA ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
