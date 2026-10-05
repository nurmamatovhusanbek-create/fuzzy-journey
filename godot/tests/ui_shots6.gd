extends SceneTree
## ruler portraits for every regime, young to old. Usage: -- <outdir>
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	var bg := ColorRect.new(); bg.color = Color(0.03, 0.05, 0.1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var grid := GridContainer.new(); grid.columns = 6; grid.position = Vector2(30, 30)
	grid.add_theme_constant_override("h_separation", 24); grid.add_theme_constant_override("v_separation", 24)
	root.add_child(grid)
	for reg in 10:
		g.regime[fr] = reg
		g.r_born[fr] = g.turn - (28 + reg * 5) * 2
		g.r_name[fr] = "rn:%d" % (reg * 5 + 3); g.r_num[fr] = 1 + reg % 3
		grid.add_child(TBPortrait.new().setup(g, fr, 170))
	await _shot("portraits")
	quit(0)
