extends SceneTree
## B8: toasts enter like notices (slide + fade), a replaced or expired toast fades out where it stood, the HUD tooltip fades in and rises; Effects Off keeps the old behaviour.
## Usage: -s tests/toast_fx.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _rows(t: Node) -> int:
	var n := 0
	for c in t.get_children(): if c is TBAlertTicker.InfoRow: n += 1
	return n
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	var hud = main.hud
	var tk: TBAlertTicker = hud._ticker
	# --- Full: slide + fade in
	hud.toast("First message", false)
	_check(tk.info != null and tk.info.ap < 0.5 and tk.info.modulate.a < 0.5, "Full: the toast starts off to the right and transparent (ap %.2f)" % tk.info.ap)
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/toast_mid.png" % out)
	for i in 14: await process_frame
	_check(is_equal_approx(tk.info.ap, 1.0) and tk.info.modulate.a > 0.99, "Full: the toast has arrived")
	# --- a second toast replaces the first: the old one fades out as a ghost
	var first: Node = tk.info
	hud.toast("Second message", true)
	_check(tk.info != first and _rows(tk) == 2, "Full: replaced toast stays one more moment (%d rows)" % _rows(tk))
	for i in 12: await process_frame
	_check(_rows(tk) == 1 and not is_instance_valid(first), "Full: the old toast is gone after its fade (%d rows)" % _rows(tk))
	tk.hide_info()
	_check(tk.info == null and _rows(tk) == 1, "Full: an expired toast fades out instead of vanishing")
	for i in 12: await process_frame
	_check(_rows(tk) == 0, "Full: and is removed afterwards")
	# --- tooltip: fades in and rises
	hud._tip_show(hud._menu_btn, ["Menu", "Settings and saves"])
	_check(hud._tip != null and hud._tip.modulate.a < 0.5, "Full: the tooltip starts transparent")
	for i in 8: await process_frame
	_check(hud._tip.modulate.a > 0.99, "Full: the tooltip is fully shown after 0.12 s")
	hud._tip_hide()
	# --- Off: as before
	main.cfg["fx"] = "off"; main._apply_a11y()
	hud = main.hud; tk = hud._ticker
	hud.toast("Third", false)
	var t1: Node = tk.info
	hud.toast("Fourth", false)
	_check(tk.info == t1 and _rows(tk) == 1, "Off: the toast row is reused, no ghost (%s %d lvl %d)" % [str(tk.info == t1), _rows(tk), TBFx.level])
	hud._tip_show(hud._menu_btn, ["Menu", "x"])
	_check(hud._tip.modulate.a > 0.99, "Off: the tooltip appears at once")
	tk.hide_info()
	_check(_rows(tk) == 0 or not is_instance_valid(t1) or t1.is_queued_for_deletion(), "Off: the toast is removed at once")
	print("TOAST_FX ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
