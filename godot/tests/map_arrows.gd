extends SceneTree
## Orders arrow visibility: armed / preview / committed arrows between neighbouring provinces at every zoom tier.
## Usage: -- <outdir> [w h]. Asserts the visible shaft is >= 20 px; writes crops for reading.
var _out := ""
var fails := 0

func _shot(name: String) -> void:
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/arrow_%s.png" % [_out, name])

func _check(c: bool, what: String) -> void:
	if not c: print("FAIL: ", what); fails += 1

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	var w := int(a[1]) if a.size() > 2 else 1280
	var h := int(a[2]) if a.size() > 2 else 720
	root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	await process_frame; await process_frame
	main._update_ui_scale()
	for k in ["text_scale", "contrast", "reduce_motion", "readable", "touch_large", "cvd"]: main.cfg[k] = {"text_scale": 1.0, "contrast": false, "reduce_motion": false, "readable": false, "touch_large": false, "cvd": "off"}[k]
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main._apply_a11y()      # the settings file is shared between runs: pin the a11y state
	main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	var me := fr
	g.gold[me] = 400; g.mp[me] = 8
	var pairs: Array = []
	for p in g.owned(me):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[e]
			var o := g.owner[q]
			if g.nb_sea[e] == 0 and o != 0 and o != me and g.get_rel(me, o) == 0:
				pairs.append([TBGame.gc_dist(main.world.lon[p], main.world.lat[p], main.world.lon[q], main.world.lat[q]), p, q])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var chosen: Array = [pairs[0], pairs[pairs.size() / 2], pairs[pairs.size() - 1]]        # the closest centres (worst case), a typical pair and the widest
	var src := -1; var tgt := -1; var friend := -1
	for pr in chosen:
		src = pr[1]; tgt = pr[2]
		var eo := g.owner[tgt]
		g.set_rel(me, eo, 1)
		friend = -1
		for e in range(g.nb_off[src], g.nb_off[src + 1]):
			var q2: int = g.nb[e]
			if g.owner[q2] == me and g.nb_sea[e] == 0 and friend < 0: friend = q2
		g.army[src] = 119; g.army[tgt] = 32
		if friend >= 0: g.army[friend] = 0
		main.map.repaint_all()
		var tag := "pair%d" % chosen.find(pr)
		for z in [1.2, 2.0, 3.2, 5.0]:
			main.map.fly_to(main.world.lon[src], main.world.lat[src], z)
			for i in 8: await process_frame
			main._select(src)
			main.flow.preview_to(tgt)
			for i in 4: await process_frame
			var lb: TBMapLabels = main.map.labels
			var shaft: float = lb.last_shaft
			print(tag, " zoom ", z, " prov_px ", lb.prov_px(), " shaft ", shaft, " push ", lb._push_v, lb._push_sv, " path ", lb._path[0], lb._path[lb._path.size() - 1], " mapzoom ", main.map.zoom)
			if z >= 2.0: _check(shaft >= 20.0, "%s preview shaft visible at zoom %s (%s px)" % [tag, z, shaft])
			await _shot("%s_preview_z%d" % [tag, int(z * 10)])
			main.flow.cancel()
			main.flow.hover(tgt)
			for i in 3: await process_frame
			if z >= 2.0 and chosen.find(pr) == 1: _check(lb.last_shaft >= 20.0, "%s hover (armed) shaft visible at zoom %s" % [tag, z])
			await _shot("%s_armed_z%d" % [tag, int(z * 10)])
			main.flow.hover(-1)
	# move arrow (friendly empty province) and committed (march fx)
	main.map.fly_to(main.world.lon[src], main.world.lat[src], 3.2)
	for i in 8: await process_frame
	main._select(src)
	main.flow.hover(friend)
	for i in 3: await process_frame
	_check(main.map.labels.last_shaft >= 20.0, "move arrow shaft visible")
	await _shot("move_hover")
	main.map.labels.add_fx("march", src, friend, TBTokens.c("brass_lt"))
	main.map.labels.add_fx("atk", src, tgt, TBTokens.c("neg_bar"))
	for i in 3: await process_frame
	await _shot("committed_fx")
	print("ARROWS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
