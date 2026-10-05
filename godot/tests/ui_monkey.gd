extends SceneTree
## UI monkey: random taps, panel buttons, dock screens, moves and turns; the run fails on any script error (read from stderr by the caller).
## Usage: -- <iterations> <seed>
func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled: out.append(c)
		_buttons(c, out)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var iters := int(a[0]) if a.size() > 0 else 200
	var rng := RandomNumberGenerator.new(); rng.seed = int(a[1]) if a.size() > 1 else 1
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = ["en", "ru", "uz"][rng.randi() % 3]; TBI18n.load_lang(main.cfg["lang"])
	main._begin_pick("napoleonic", "normal")
	var g: TBGame = main.g
	var me := rng.randi_range(1, g.N)
	while g.owned(me).is_empty() or me == g.rebel: me = rng.randi_range(1, g.N)
	main._start_game(me)
	g.pending.clear(); main._clear_overlay()
	var turns := 0
	for i in iters:
		match rng.randi() % 9:
			0, 1, 2:
				var p := rng.randi() % g.P
				main._on_pick(p, rng.randf() < 0.15)
			3:
				var bs: Array = []
				_buttons(main.panel, bs)
				if not bs.is_empty(): (bs[rng.randi() % bs.size()] as Button).pressed.emit()
			4:
				var bs2: Array = []
				_buttons(main.hud, bs2)
				if not bs2.is_empty(): (bs2[rng.randi() % bs2.size()] as Button).pressed.emit()
			5:
				var bs3: Array = []
				_buttons(main._overlay, bs3)
				if not bs3.is_empty(): (bs3[rng.randi() % bs3.size()] as Button).pressed.emit()
				elif rng.randf() < 0.3: main._clear_overlay()
			6:
				var mine := g.owned(g.human_id)
				if not mine.is_empty():
					var p2 := mine[rng.randi() % mine.size()]
					main._select(p2); main._on_move_requested(p2)
					var nbp := g.nb[g.nb_off[p2] + rng.randi() % maxi(1, g.nb_off[p2 + 1] - g.nb_off[p2])] if g.nb_off[p2 + 1] > g.nb_off[p2] else p2
					main._on_pick(nbp, false); main._on_pick(nbp, false)
			7:
				main.map.fly_to(rng.randf_range(-180, 180), rng.randf_range(-60, 70), rng.randf_range(0.8, 8.0))
				main.map._set_hover(rng.randi() % g.P)
				main._on_hover(rng.randi() % g.P)
			8:
				if rng.randf() < 0.4:
					main._clear_overlay(); g.pending.clear()
					main.end_turn()
					var guard := 0
					while main._busy and guard < 400: await create_timer(0.05).timeout; guard += 1
					turns += 1
		await process_frame
	print("MONKEY done: iterations=%d turns=%d lang=%s nation=%s alive=%s" % [iters, turns, main.cfg["lang"], g.nat_name[me], g.alive[me]])
	quit(0)
