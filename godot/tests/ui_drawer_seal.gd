extends SceneTree
## A window docked at the right (the province dossier) ends above the End Turn seal and so does a wide one (Nations), at the size given (the screen of the xvfb must be that size).
## Usage: -s tests/ui_drawer_seal.gd -- <w> <h> (xvfb, TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sizes: Array = [Vector2i(int(a[0]), int(a[1]))] if a.size() >= 2 else [Vector2i(1920, 1080)]
	var combos: Array = []
	for ts in [1.0, 1.3]:
		for sz in sizes: combos.append([sz, ts])
	for cb in combos:
		var sz: Vector2i = cb[0]; var ts: float = cb[1]
		DisplayServer.window_set_size(sz); root.size = sz
		var main: Control = load("res://src/ui/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"; main.cfg["fx"] = "off"; main.cfg["text_scale"] = ts
		main._apply_a11y(); main._update_ui_scale()
		main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
		for i in 20: await process_frame
		var cp: int = main.g.capital_of[main.g.human_id]
		main._select(cp)
		var h: TBPanel.Handle = TBDossier.open(main._overlay, main.g, cp, func(_c): pass)
		for i in 30: await process_frame
		var seal: Rect2 = main.hud.end_turn_rect()
		var r: Rect2 = h.card.get_global_rect()
		print(sz, " x", ts, " seal ", seal, " dossier ", r)
		_check(r.end.y <= seal.position.y + 0.5 or r.end.x <= seal.position.x, "%s x%s: the dossier ends above the seal (%s vs %s)" % [sz, ts, r, seal])
		h.close()
		for i in 10: await process_frame
		main._open_nations(-1)
		for i in 30: await process_frame
		var nc: Control = null
		for n in main._overlay.find_children("*", "PanelContainer", true, false):
			if n.get_meta("tb_paper", false) and n.is_visible_in_tree(): nc = n
		if nc != null:
			var nr: Rect2 = nc.get_global_rect()
			print(sz, " nations ", nr)
			_check(not nr.intersects(seal.grow(-2.0)), "%s x%s: the Nations window leaves the End Turn dial free (%s vs %s)" % [sz, ts, nr, seal])
		else: _check(false, "%s: the Nations window opened" % sz)
		main.queue_free()
		await process_frame
	print("UI_DRAWER_SEAL ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
