extends SceneTree
## Land you hold but have not annexed: the verb ring opens on it (not the foreign-nation ring), your army shows there with your flag, you can put a port (or another military work) up
## in it, and an army in it can be ordered on like one at home. Usage: -s tests/held_land.gd -- <out dir>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "medium"; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("coldwar", "normal"); main._start_game(main.g.nat_code.find("ussr"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	var cn: int = g.nat_code.find("china")
	g.set_rel(me, cn, TBData.REL_WAR)
	# a Chinese province next to the USSR, ideally on a coast (for the port)
	var held := -1; var home := -1; var coast := -1; var inland := -1
	for p in g.P:
		if g.owner[p] != cn: continue
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.owner[q] == me and home < 0: home = q; inland = p
	for p in g.P:
		if g.owner[p] == cn and (g.world.geo[p] & 1) != 0: coast = p; break
	held = coast if coast >= 0 else inland
	g.occupier[held] = me; g.occ_rev += 1; g.army[held] = g.au(40.0); g.gold[me] = 5e8; g.mp[me] = 20.0
	g.touch(held)
	main.map.jump_to(g.world.lon[held], g.world.lat[held], 8.0)
	for i in 30: await process_frame
	main._select(held)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/held_0.png" % out)
	var ring: TBMapRing = main.ring
	_check(ring.visible, "the ring opens on land you hold")
	_check(not ring._nation_mode(), "it is the verb ring, not the foreign-nation ring")
	var ids: Array = []
	for v in ring.verbs: ids.append(String(v["id"]))
	print("verbs: ", ids)
	_check(ids.has("move"), "Move is on the ring of held land")
	_check(not ids.has("recruit") and not ids.has("hire"), "no recruit or hire on land that is not yours")
	_check(ids.has("build"), "Build is on the ring of held coastal land")
	var cn1: Dictionary = g.can({"cmd": "build", "p": held, "b": TBData.B_PORT})
	_check(bool(cn1["ok"]) or cn1["reason"] in ["gold", "mp", "tech", "slots"], "a port may be put up in held land (%s)" % cn1["reason"])
	var cn2: Dictionary = g.can({"cmd": "build", "p": held, "b": TBData.B_MARKET})
	_check(cn2["reason"] == "notyours", "a market may not (%s)" % cn2["reason"])
	var r: Dictionary = g.apply({"cmd": "build", "p": held, "b": TBData.B_PORT, "n": me}) if g.has_method("apply") else {}
	print("build result: ", r)
	# the army marker: your flag, your side (the ring shows it while the land is selected)
	main._select(-1)
	for i in 40: await process_frame
	var pl: Dictionary = main.map.labels._pl
	_check(pl.has(held) and float(pl[held]["t"]) > 0.5, "the army of the holder shows on held land")
	root.get_viewport().get_texture().get_image().save_png("%s/held_1.png" % out)
	root.get_viewport().get_texture().get_image().save_png("%s/held_2.png" % out)
	print("prov_px ", main.map.labels.prov_px(), " lines ", main.map.prov_lines_shown(), " fit ", main.map.labels.pills_fit(), " lens ", main.map.labels.armies_shown(), " zoom ", main.map.zoom)
	var shown: int = 0
	for q in pl: if float(pl[q]["t"]) > 0.5: shown += 1
	print("markers on screen: ", shown, " held province in _pl: ", pl.has(held))
	# order the army on: from held land into the next enemy province (the same flow as at home)
	main.flow.g = g
	var tg: PackedInt32Array = main.flow.compute_targets() if main.flow.src == held else PackedInt32Array()
	main.flow.on_select(held)
	tg = main.flow.compute_targets()
	print("targets from held land: ", tg.size())
	_check(tg.size() > 0, "an army on held land has targets")
	print("HELD_LAND ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
