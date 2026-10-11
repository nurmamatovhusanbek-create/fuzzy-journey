extends SceneTree
## The lite shader (tiers 0 and 1) must draw exactly what the full shader draws at the same tier. Usage: -s tests/lite_shader.gd -- <w> <h>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w: int = int(a[0]); var h: int = int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_quality()
	var bad := 0
	for mode in [0, 1]:
		for q in [0, 1]:
			main.map.set_mode(mode); main.map.quality = q
			main.map.lod_motion = false
			main.map.fly_to(9.5, 46.0, 3.0)
			for i in 20: await process_frame
			main.map.select(main.g.owned(fr)[3])
			main.map.hover = main.g.owned(fr)[5]
			for i in 6: await process_frame
			var imgs: Array = []
			for sh in [main.map.SHADER, main.map.SHADER_LITE]:
				main.map._mat.shader = sh
				main.map._lite = sh == main.map.SHADER_LITE
				main.map._pal_dirty_swap()
				main.map._push_view()
				for i in 6: await process_frame
				imgs.append(main.map._vp.get_texture().get_image())
			var d := 0
			var im0: Image = imgs[0]; var im1: Image = imgs[1]
			for y in range(0, im0.get_height(), 3):
				for x in range(0, im0.get_width(), 3):
					var c0: Color = im0.get_pixel(x, y); var c1: Color = im1.get_pixel(x, y)
					if absf(c0.r - c1.r) + absf(c0.g - c1.g) + absf(c0.b - c1.b) > 0.02: d += 1
			if d > 0:
				im0.save_png("/tmp/lite_full_%d_%d.png" % [mode, q]); im1.save_png("/tmp/lite_lite_%d_%d.png" % [mode, q])
			print("mode %d quality %d: %d differing pixels of %d" % [mode, q, d, im0.get_width() * im0.get_height()])
			bad += d
	print("LITE ", "OK" if bad == 0 else "FAIL")
	quit(0 if bad == 0 else 1)
