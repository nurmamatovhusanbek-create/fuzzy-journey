extends SceneTree
## The map shader against a reference version of itself (a file of shader code): how many pixels differ, by how much. Usage: -s tests/shader_compare.gd -- <w> <h> <ref.gdshader> <outdir> [quality]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1]); var refc: String = FileAccess.get_file_as_string(a[2]); var outd: String = a[3]
	var q: int = int(a[4]) if a.size() > 4 else 1
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.visible = false; main.map.labels.visible = false; main.map.routes.visible = false; main.ring.visible = false
	var m: TBMapView = main.map
	m.quality = q; m.render_scale = 1.0
	var cur: Shader = m._mat.shader
	var ref := Shader.new(); ref.code = refc
	var worst := 0.0
	for view in [["globe", 0, 1.0, 9.5, 46.0], ["globe", 0, 2.2, 9.5, 46.0], ["globe", 0, 6.0, 12.0, 45.0], ["globe", 0, 0.7, 150.0, -10.0], ["flat", 1, 1.0, 0.0, 20.0], ["flat", 1, 4.0, 9.5, 46.0], ["flat", 1, 12.0, 2.3, 48.8]]:
		m.set_mode(int(view[1])); m.quality = q; m.render_scale = 1.0
		m.fly_to(float(view[3]), float(view[4]), float(view[2]) if int(view[1]) == 0 else maxf(float(view[2]), m.flat_fit()))
		for i in 30: await process_frame
		m.select(main.g.owned(main.g.human_id)[3])
		for i in 4: await process_frame
		var imgs: Array = []
		for sh in [cur, ref]:
			m._mat.shader = sh
			m._mat.set_shader_parameter("ids", m._ids_tex); m._mat.set_shader_parameter("pal", m._pal_tex)
			m._push_view()
			for i in 5: await process_frame
			imgs.append(m._vp.get_texture().get_image())
		var i0: Image = imgs[0]; var i1: Image = imgs[1]
		var n := 0; var sum := 0.0; var big := 0
		for y in range(0, i0.get_height(), 2):
			for x in range(0, i0.get_width(), 2):
				var c0: Color = i0.get_pixel(x, y); var c1: Color = i1.get_pixel(x, y)
				var d: float = absf(c0.r - c1.r) + absf(c0.g - c1.g) + absf(c0.b - c1.b)
				sum += d; n += 1
				if d > 0.06: big += 1
		print("%s z%.1f: mean diff %.5f, pixels differing > 0.06: %.3f %%" % [view[0], float(view[2]), sum / float(n), 100.0 * float(big) / float(n)])
		worst = maxf(worst, 100.0 * float(big) / float(n))
		i0.save_png("%s/new_%s_%d.png" % [outd, view[0], int(view[2] * 10)]); i1.save_png("%s/old_%s_%d.png" % [outd, view[0], int(view[2] * 10)])
		m._mat.shader = cur
	print("worst ", worst)
	quit(0)
