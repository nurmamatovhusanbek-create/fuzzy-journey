extends SceneTree
## animation review: camera flight, plaque fade-in, pop + delta text, hover fade. Run without TB_NOANIM.
func _shot(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en")
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g
	await create_timer(1.6).timeout
	var cap: int = g.capital_of[fr]
	main.map.fly_to(main.world.lon[cap], main.world.lat[cap], 3.2)
	await create_timer(0.18).timeout
	await _shot("an1_flight")
	await create_timer(1.2).timeout
	await _shot("an2_settled")
	# change an own army: +24 here
	var mine := g.owned(fr)
	var p := mine[3]
	g.army[p] += 24
	main.map.labels.queue_redraw()
	await create_timer(0.25).timeout
	await _shot("an3_pop")
	await create_timer(1.4).timeout
	# hover a neighbouring province
	var q := mine[8]
	main.map._set_hover(q)
	await create_timer(0.08).timeout
	await _shot("an4_hover_in")
	await create_timer(0.5).timeout
	await _shot("an5_hover_full")
	main.map.select(q)
	await create_timer(0.1).timeout
	await _shot("an6_select")
	quit(0)
