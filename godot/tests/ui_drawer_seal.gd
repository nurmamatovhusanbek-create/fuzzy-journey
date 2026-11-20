extends SceneTree
## A window docked at the right (the province dossier) ends above the End Turn seal at the common desktop sizes.
## Usage: -s tests/ui_drawer_seal.gd (xvfb, TB_NOANIM=1)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	for sz in [Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(2560, 1440)]:
		DisplayServer.window_set_size(sz); root.size = sz
		var main: Control = load("res://src/ui/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"; main.cfg["fx"] = "off"
		main._apply_a11y(); main._update_ui_scale()
		main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
		for i in 20: await process_frame
		var cp: int = main.g.capital_of[main.g.human_id]
		main._select(cp)
		var h: TBPanel.Handle = TBDossier.open(main._overlay, main.g, cp, func(_c): pass)
		for i in 30: await process_frame
		var seal: Rect2 = main.hud.end_turn_rect()
		var r: Rect2 = h.card.get_global_rect()
		print(sz, " seal ", seal, " dossier ", r)
		_check(r.end.y <= seal.position.y + 0.5 or r.end.x <= seal.position.x, "%s: the dossier ends above the seal (%s vs %s)" % [sz, r, seal])
		h.close()
		main.queue_free()
		await process_frame
	print("UI_DRAWER_SEAL ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
