extends SceneTree
## diagnostic: frames of the Play morph, every N frames, saved as <out>/m_XX.png. Usage: -s tests/morph_sheet.gd -- <out dir> <every n frames> (run with --fixed-fps 30)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]; var every: int = int(a[1])
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 3: await process_frame
	main._update_ui_scale()
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["comfort_seen"] = true
	main.cfg["fx"] = "full"; main._apply_a11y()
	main.show_front()
	for i in 90: await process_frame
	var oc: Control = main._title_col
	print("old wm ", oc.get_child(0).get_global_rect(), " orn ", oc.get_child(1).get_global_rect(), " tag ", oc.get_child(2).get_global_rect(), " play ", oc.get_child(4).get_global_rect())
	main._front_play()
	var nc: Control = main._title_col
	await process_frame
	print("new wm ", nc.get_child(0).get_global_rect(), " orn ", nc.get_child(1).get_global_rect(), " tag ", nc.get_child(2).get_global_rect(), " play ", nc.get_child(4).get_global_rect())
	var k := 0; var f := 0
	while main._morph != null and k < 60:
		await process_frame; f += 1
		if f % every == 0:
			root.get_viewport().get_texture().get_image().save_png("%s/m_%02d.png" % [out, k]); k += 1
	print("MORPH_SHEET frames ", f, " shots ", k)
	quit(0)
