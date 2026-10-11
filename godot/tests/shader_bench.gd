extends SceneTree
## Where does a map render spend its time? Renders the map shader N times per variant (a view change each time) and prints ms per render.
## Usage: -s tests/shader_bench.gd -- <w> <h> <quality> <globe|flat> [zoom]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1]); var q: int = int(a[2]); var globe: bool = a[3] == "globe"
	var zoom: float = float(a[4]) if a.size() > 4 else 1.0
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe" if globe else "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.visible = false; main.map.labels.visible = false; main.map.routes.visible = false; main.ring.visible = false
	var m: TBMapView = main.map
	m.quality = q; m.render_scale = 1.0; m.set_mode(0 if globe else 1)
	m.fly_to(9.5, 46.0, zoom)
	for i in 40: await process_frame
	var base: String = TBMapView.SHADER.code
	var variants := {"baseline": [],
		"floor (id only)": [["		vec3 col;\n		vec3 acc", "		COLOR = vec4(float(id) / 2000.0, 0.2, 0.3, 1.0);\n		if (id < 100000) { return_dummy(); }\n		vec3 col;\n		vec3 acc"]],
		"no sea gradient": [["col = sea_grad(lp, sz);", "col = vec3(0.04, 0.06, 0.08);"]],
		"no graticule": [["col = mix(col, vec3(0.788, 0.635, 0.294), gcov);", ""]],
		"no coast glow": [["col = mix(col, vec3(0.431, 0.561, 0.639), 0.06 * (1.0 - smoothstep(5.0 * ms - 0.5, 5.0 * ms + 0.5, dpx)));", ""], ["col = mix(col, vec3(0.561, 0.690, 0.761), 0.09 * (1.0 - smoothstep(2.0 * ms - 0.5, 2.0 * ms + 0.5, dpx)));", ""]],
		"no borders": [["if (atlas == 1) {\n\t\t\tif (!atlas_done) {", "if (false) {\n\t\t\tif (!atlas_done) {"]],
		"no globe lighting": [["col *= (theme == 1) ? (0.80 + 0.3 * nl) : (0.50 + 0.62 * nl);", ""], ["col *= hc == 1 ? 1.0 : mix(0.78, 1.0, n.z);", ""]],
		"no pal row 2/3 reads": [["vec4 occ = texelFetch(pal, ivec2(id, 2), 0);", "vec4 occ = vec4(0.0);"], ["float my_tgt = id == 0 ? 0.0 : texelFetch(pal, ivec2(id, 3), 0).r;", "float my_tgt = 0.0;"], ["bool is_tgt = texelFetch(pal, ivec2(id, 3), 0).r > 0.5;", "bool is_tgt = false;"]],
	}
	var n := 24
	for name in variants:
		var code := base
		var ok := true
		for r in variants[name]:
			if not code.contains(r[0]): ok = false; print("  (pattern missing for ", name, ")")
			code = code.replace(r[0], r[1])
		if not ok: continue
		var sh := Shader.new(); sh.code = code
		m._mat.shader = sh
		m._mat.set_shader_parameter("ids", m._ids_tex); m._mat.set_shader_parameter("pal", m._pal_tex)
		m._push_view()
		for i in 4: await process_frame
		var times: Array = []
		for i in n:
			m.lon0 += 0.01 * float(i % 3 + 1)
			var t0 := Time.get_ticks_usec()
			m._push_view()
			await RenderingServer.frame_post_draw
			times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		times.sort()
		print("%-34s median %.1f ms  (min %.1f)" % [name, times[n / 2], times[0]])
	quit(0)
