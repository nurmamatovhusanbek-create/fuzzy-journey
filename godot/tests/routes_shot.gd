extends SceneTree
## A picture of the routes lens with a standing march order (arrowhead and turns to go) and a trade route that is about to lapse (amber, "!"). Usage: -s tests/routes_shot.gd -- <w> <h> <out.png>
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var me: int = main.g.nat_code.find("france")
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(220)
	var uk: int = g.nat_code.find("uk"); var sp: int = g.nat_code.find("spain")
	for o in [uk, sp]:
		if o > 0: TBTrade.set_deal(g, me, o, true)
	g.gold[sp] = 0.0
	g.mp[me] = 6.0
	var from := -1; var to := -1
	for p in g.owned(me):
		if g.army[p] > 4 and from < 0: from = p
	var best := 0
	for q in g.owned(me):
		if q == from: continue
		var pl := TBMarch.plan(g, me, from, q)
		if bool(pl["ok"]) and (pl["path"] as PackedInt32Array).size() > best: best = (pl["path"] as PackedInt32Array).size(); to = q
	var r := g.apply({"cmd": "move", "n": me, "from": from, "to": to})
	print("march order: ", r, " marches ", g.marches.size())
	main.map.set_lens("routes")
	main.map.set_mode(0)
	main.map.zoom = 2.4; main.map.lon0 = deg_to_rad(2.0); main.map.lat0 = deg_to_rad(46.0); main.map._push_view()
	await _frames(60)
	root.get_viewport().get_texture().get_image().save_png(a[2])
	print("risk with Spain: ", TBTrade.risk(g, me, sp), " with UK: ", TBTrade.risk(g, me, uk))
	quit()
