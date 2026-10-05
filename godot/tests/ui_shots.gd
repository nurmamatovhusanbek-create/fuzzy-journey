extends SceneTree
## Design review screenshots: menu, era picker, HUD + province, modals, portrait. Usage: -- <outdir> [prefix]
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _pre, name])
var _out := ""
var _pre := "ui"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]; if a.size() > 1: _pre = a[1]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await _shot("1_menu")
	main._open_era_picker()
	await _shot("2_era")
	main._begin_pick("napoleonic", "normal")
	await _shot("3_pick")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear()
	for t in 6: main.g.end_turn()
	main._clear_overlay()
	main.hud.refresh()
	var cap: int = main.g.capital_of[fr]
	main._select(cap)
	main.map.fly_to(main.world.lon[cap], main.world.lat[cap], 3.0)
	for i in 6: await process_frame
	main.hud.toast("Russian Empire declared war on Prussia", true)
	main.hud.toast("Emperor Napoleon is 34 years old", false)
	await _shot("4_game")
	main._select(-1)
	TBModals.nations(main._overlay, main.g, func(n): pass)
	await _shot("5b_nations")
	main._clear_overlay()
	TBModals.nation_detail(main._overlay, main.g, main.g.nat_code.find("russian_empire"), main._on_command, main._goto_nation)
	await _shot("5_nation")
	main._clear_overlay()
	TBModals.decisions(main._overlay, main.g, main._on_command)
	await _shot("6_decisions")
	main._clear_overlay()
	TBModals.chronicle(main._overlay, main.g, main._goto_province)
	await _shot("7_chronicle")
	main._clear_overlay()
	TBModals.budget(main._overlay, main.g, func(): pass)
	await _shot("8_budget")
	main._clear_overlay()
	# portrait
	root.size = Vector2i(540, 960)
	await process_frame
	main._update_ui_scale()
	main._select(cap)
	await _shot("9_portrait")
	print("ribbon ", main.hud._ribbon.size, " toasts top ", main.hud._toasts.offset_top, " portrait ", main.hud._portrait)
	quit()
