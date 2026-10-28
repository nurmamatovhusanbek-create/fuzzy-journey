extends SceneTree
## A5b: Play on the nation-pick screen dissolves the pick UI, flies to the capital, fades the HUD in and opens the briefing when the camera arrives; Effects Off / Reduce motion: all at once as before.
## Usage: -s tests/begin_dive.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _modals(main: Node) -> int:
	var n := 0
	for c in main._overlay.get_children():
		if c.is_queued_for_deletion() or c.has_meta("tb_closing"): continue
		n += 1
	return n
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "high"; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	# --- Full
	main._begin_pick("napoleonic", "normal")
	for i in 20: await process_frame
	var pick_nodes: int = main._overlay.get_child_count()
	_check(pick_nodes > 0, "the pick screen is up (%d)" % pick_nodes)
	main._start_game(main.g.nat_code.find("france"))
	_check(main.hud.modulate.a < 0.05, "Full: the HUD starts transparent")
	_check(main._overlay.get_child_count() == pick_nodes and _modals(main) == 0, "Full: the pick screen is still there, dissolving, and no longer counts as a modal")
	for i in 3: await process_frame
	var fl: float = float(main.map._fly.get("dur", 0.0))
	_check(fl >= 1.29, "Full: the camera move lasts at least 1.3 s (%.2f)" % fl)
	_check(_modals(main) == 0, "the briefing waits for the camera")
	for i in 12: await process_frame
	_check(main._overlay.get_child_count() == 0, "the dissolved pick screen is freed after 0.3 s (%d)" % main._overlay.get_child_count())
	root.get_viewport().get_texture().get_image().save_png("%s/begin_mid.png" % out)
	for i in 50: await process_frame
	_check(main.hud.modulate.a > 0.99, "the HUD has faded in (%.2f)" % main.hud.modulate.a)
	_check(_modals(main) >= 1, "the briefing opened when the camera arrived")
	# --- a clear while it flies cancels the briefing
	main._clear_overlay()
	main._begin_pick("napoleonic", "normal")
	for i in 10: await process_frame
	main._start_game(main.g.nat_code.find("france"))
	for i in 3: await process_frame
	main._clear_overlay()
	for i in 60: await process_frame
	_check(_modals(main) == 0, "something cleared the screen meanwhile: no late briefing")
	# --- Off
	main.cfg["fx"] = "off"; main._apply_a11y()
	main._begin_pick("napoleonic", "normal")
	for i in 10: await process_frame
	main._start_game(main.g.nat_code.find("france"))
	_check(main.hud.modulate.a > 0.99, "Off: the HUD is there at once")
	_check(_modals(main) >= 1, "Off: the briefing opens at once")
	print("BEGIN_DIVE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
