extends SceneTree
## Atlas Ledger deliverable shots at one window size: map, inspector, drawer (+ inspector), tooltip, dialog. Usage: -- <outdir> <w> <h>
var _out := ""
var _tag := ""
func _shot(name: String) -> void:
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/dl_%s_%s.png" % [_out, _tag, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	var w := int(a[1]); var h := int(a[2])
	_tag = "%dx%d" % [w, h]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	main.hud.set_seal_pulse(false)
	for i in 3: await process_frame
	main._update_ui_scale()
	for i in 6: await process_frame
	var cp: int = g.capital_of[fr]
	main.map.fly_to(main.world.lon[cp], main.world.lat[cp], maxf(1.5, (float(h) / PI) / (float(w) / TAU)))
	await _shot("1_map")
	main._select(cp)
	await _shot("2_inspector")
	main._select(-1)
	main._open_budget()
	await _shot("3_drawer")
	main._clear_overlay()
	main._select(cp)
	var k0: String = main.hud._chips.keys()[0]
	main.hud._tip_show(main.hud._chips[k0], main.hud._tip_chip(k0))
	await _shot("4_tooltip")
	main.hud._tip_hide()
	main._select(-1)
	var eo := 0
	for p in g.owned(fr):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var o: int = g.owner[g.nb[e]]
			if o != 0 and o != fr and eo == 0: eo = o
	TBPanel.confirm(main._overlay, "Declare war on %s?" % g.dname(eo), "Casus belli: border dispute. It costs 3 diplomacy points and cannot be undone.", "Declare war", func(): pass, true, "swords")
	await _shot("5_dialog")
	quit(0)
