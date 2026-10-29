extends SceneTree
## How smoothly do the names move while the globe glides? A constant camera speed moves every name at an (almost) constant speed; a name that jumps, trails the map in steps, changes size or
## blinks is unsteady. Usage: -s tests/label_stability.gd -- <w> <h> <zoom> [expect]   (TB_DPR / TB_DPI emulate a phone). Prints per kind: names measured, share of frames off the smooth path,
## the worst jump in px, size changes, and names that blinked; with `expect` the run fails when the numbers are worse than the limits.
var fails := 0
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var zoom := float(a[2]); var expect := a.size() > 3
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main._apply_quality()
	main._begin_pick("modern", "normal")
	var kz: int = main.g.nat_code.find("kazakhstan")
	main._start_game(kz if kz > 0 else 1)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 220: await process_frame                                      # the start-up dive (a camera animation) has to be over
	var map = main.map
	map.set_mode(0)
	map.zoom = zoom
	map.lon0 = deg_to_rad(40.0); map.lat0 = deg_to_rad(35.0); map._push_view()
	for i in 40: await process_frame
	if OS.get_environment("TB_COST") != "": TBMapLabels.force_cost_ms = float(OS.get_environment("TB_COST"))
	print("zoom now ", map.zoom, " (asked ", zoom, ")")
	TBMapLabels.names_us = 0.0; TBMapLabels.names_draws = 0
	TBMapLabels.trace.clear(); TBMapLabels.tracing = true
	var frames := 150
	for i in frames:
		map.lon0 += deg_to_rad(float(OS.get_environment("TB_STEP")) if OS.get_environment("TB_STEP") != "" else 0.12); map._push_view()
		await process_frame
	TBMapLabels.tracing = false
	print("names drawn %d times, %.2f ms each" % [TBMapLabels.names_draws, TBMapLabels.names_us / maxf(1.0, float(TBMapLabels.names_draws)) / 1000.0])
	# the frames a layout was drawn on (any name); a name missing from a layout it should be in blinks; between layouts the picture stays as drawn (what the player sees)
	var layout_frames := {}
	var seen_trace: Array = []
	for e in TBMapLabels.trace:
		if float(e[5]) >= 0.35: seen_trace.append(e)                       # a name that is still fading in or out is not counted as shown
	for e in seen_trace: layout_frames[e[0]] = true
	var lf: Array = layout_frames.keys(); lf.sort()
	var by := {}
	var all_by := {}
	for e in TBMapLabels.trace:
		var kk: String = "%s|%s" % [e[1], e[2]]
		if not all_by.has(kk): all_by[kk] = {}
		all_by[kk][e[0]] = e
	for e in seen_trace:
		var k: String = "%s|%s" % [e[1], e[2]]
		if not by.has(k): by[k] = {}
		by[k][e[0]] = e
	var stats := {"n": [0, 0, 0.0, 0, 0, 0], "p": [0, 0, 0.0, 0, 0, 0]}     # names, frame pairs, worst jump, off-path pairs, size changes, blinks
	var last_frame: int = int(lf[lf.size() - 1]) if lf.size() > 0 else 0
	var worst: Array = []                                                  # [jump, name, frame] of the biggest jumps, for the report
	print("layouts drawn: %d of %d frames" % [lf.size(), frames])
	for k in by:
		var kind: String = String(k).get_slice("|", 0)
		var st: Array = stats[kind]
		var pres: Dictionary = by[k]
		if pres.size() < 6: continue
		# a per frame series: the position of the last layout the name was in
		var series := []                                                   # [frame, Vector2, size] for every frame from the first layout to the last, only while shown
		var gap := false
		var seg_start := -1
		var cur: Array = []
		for li in lf.size():
			var f: int = int(lf[li])
			var nxt: int = int(lf[li + 1]) if li + 1 < lf.size() else last_frame + 1
			if pres.has(f):
				var e: Array = pres[f]
				if seg_start < 0: seg_start = f
				for ff in range(f, nxt): cur.append([ff, e[3], e[4]])
			elif seg_start >= 0:
				series.append(cur); cur = []; seg_start = -1                     # it left the picture (a name may leave for good: that is not a blink)
		if cur.size() > 0: series.append(cur)
		var counted := false
		if series.size() > 1: st[5] += series.size() - 1                      # a name that left and came back within a short glide: a blink
		for seg in series:
			if (seg as Array).size() < 12: continue
			if not counted: st[0] += 1; counted = true
			var ds: Array = []
			for i in range(1, seg.size()):
				if seg[i][2] != seg[i - 1][2]: st[4] += 1
				ds.append((seg[i][1] as Vector2) - (seg[i - 1][1] as Vector2))
			var xs := []; var ys := []
			for d in ds: xs.append((d as Vector2).x); ys.append((d as Vector2).y)
			xs.sort(); ys.sort()
			# the smooth path: the average speed over the whole segment (the camera does not change speed)
			var avg := ((seg[seg.size() - 1][1] as Vector2) - (seg[0][1] as Vector2)) / float(seg.size() - 1)
			for d in ds:
				var dev: float = ((d as Vector2) - avg).length()
				st[1] += 1
				if dev > 2.5: st[3] += 1
				st[2] = maxf(st[2], dev)
				if dev > 8.0: worst.append([dev, k, int(seg[0][0])])
	var dump := OS.get_environment("TB_DUMP")
	if dump != "" and all_by.has("n|" + dump):
		var fr: Array = (all_by["n|" + dump] as Dictionary).keys(); fr.sort()
		for f in fr: print("  dump ", dump, " frame ", f, " pos ", (all_by["n|" + dump][f][3] as Vector2), " a ", snappedf(float(all_by["n|" + dump][f][5]), 0.01))
	worst.sort_custom(func(x, y): return x[0] > y[0])
	for i in mini(8, worst.size()): print("  jump %.0f px  %s (segment from frame %d)" % [worst[i][0], worst[i][1], worst[i][2]])
	for kind in stats:
		var st: Array = stats[kind]
		var off: float = float(st[3]) / maxf(1.0, float(st[1])) * 100.0
		print("LABELS %s: %d names, %d frame pairs, off the smooth path %.1f %%, worst jump %.1f px, size changes %d, blinks %d" % ["nations" if kind == "n" else "districts", st[0], st[1], off, st[2], st[4], st[5]])
		if expect and st[1] > 0:
			var lim: Array = {"n": [12.0, 80.0, 3, 40], "p": [3.0, 10.0, 3, 20]}[kind]            # off-path %, worst jump px, size changes, blinks (a long hop is a cross-fade, which counts as one)
			if off > float(lim[0]): fails += 1; print("FAIL: %s: %.1f %% of frames off the smooth path (limit %d)" % [kind, off, int(lim[0])])
			if st[2] > float(lim[1]): fails += 1; print("FAIL: %s: a name jumped %.1f px (limit %d)" % [kind, st[2], int(lim[1])])
			if st[4] > int(lim[2]): fails += 1; print("FAIL: %s: %d size changes (limit %d)" % [kind, st[4], int(lim[2])])
			if st[5] > int(lim[3]): fails += 1; print("FAIL: %s: %d names blinked (limit %d)" % [kind, st[5], int(lim[3])])
	print("LABEL_STABILITY OK" if fails == 0 else "LABEL_STABILITY FAIL %d" % fails)
	quit(fails)
