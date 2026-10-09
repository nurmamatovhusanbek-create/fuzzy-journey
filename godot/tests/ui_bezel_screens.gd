extends SceneTree
## Bezel look: the screens. Usage: -- <outdir> <w> <h> [which,...]
var _out := ""
func _shot(name: String) -> void:
	for i in 16: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bs_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	DisplayServer.window_set_size(Vector2i(int(a[1]), int(a[2]))); root.size = Vector2i(int(a[1]), int(a[2]))
	var which: PackedStringArray = (a[3] if a.size() > 3 else "nations,budget,decisions,council,annals,menu,dialog").split(",")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 20: await process_frame
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 1.6)
	for w in which:
		main._clear_overlay()
		match w:
			"nations": main._open_nations()
			"budget": main._open_budget()
			"decisions": main._open_decisions()
			"council": main._open_council()
			"annals": main._open_annals()
			"menu": main._open_menu_hub("")
			"settings": main._open_menu_hub("settings")
			"goals": main._open_council("goals")
			"annals_mine": main._open_annals()
			"dialog":
				TBPanel.confirm(main._overlay, "Declare war on Austria?", "Casus belli: border dispute. It costs 3 diplomacy points and cannot be undone.", "Declare war", func(): pass, true, "swords")
		await _shot(w)
	quit(0)
