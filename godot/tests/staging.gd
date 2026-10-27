extends SceneTree
## B1 dialog staging gate. Full: a dialog starts hidden, completes on its own within ~0.4 s, a click completes it at once, closing is immediate for the game (no handle, no modal)
## and the node fades for 0.15 s. Off: the dialog is complete in the frame it opens and close frees it. Usage: -s tests/staging.gd -- <out dir>   (run with --fixed-fps 30)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["quality"] = "medium"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 10: await process_frame
	# ---- Full
	main.cfg["fx"] = "full"; main._apply_a11y()
	var hd: TBPanel.Handle = TBPanel.confirm(main._overlay, "Declare war on Austrian Empire?", "You have no casus belli, neighbours may form a coalition against you.", "Hold to declare war", func(): pass)
	await process_frame
	_check(hd.holder.modulate.a < 0.05, "Full: the card starts hidden (alpha %.2f)" % hd.holder.modulate.a)
	_check(not hd.stage.is_empty(), "Full: the entrance is running")
	var frames := [0, 2, 4, 6, 9, 12, 18]
	var f := 0
	for k in frames:
		while f < k: await process_frame; f += 1
		root.get_viewport().get_texture().get_image().save_png("%s/stage_%02d.png" % [out, k])
	for i in 10: await process_frame
	_check(hd.holder.modulate.a > 0.99 and absf(hd.holder.position.y) < 0.5, "Full: complete after 0.6 s")
	# a click completes it
	var hd2: TBPanel.Handle = TBPanel.confirm(main._overlay, "Second", "Text", "Yes", func(): pass)
	await process_frame
	var ev := InputEventMouseButton.new(); ev.pressed = true; ev.button_index = MOUSE_BUTTON_LEFT; ev.position = Vector2(5, 5)
	Input.parse_input_event(ev)
	await process_frame; await process_frame
	_check(hd2.stage.is_empty() and hd2.holder.modulate.a > 0.99, "Full: a click completes the entrance")
	# closing
	hd2.close()
	_check(not hd2.is_open(), "closing: not open for the game at once")
	_check(not main._modal_open() or TBPanel.top(main._overlay) == hd, "closing: the fading node is not a modal")
	_check(is_instance_valid(hd2.root), "closing Full: the node is still fading")
	for i in 12: await process_frame
	_check(not is_instance_valid(hd2.root), "closing Full: freed after the fade")
	hd.close()
	for i in 12: await process_frame
	# ---- Off
	main.cfg["fx"] = "off"; main._apply_a11y()
	var hd3: TBPanel.Handle = TBPanel.confirm(main._overlay, "Third", "Text", "Yes", func(): pass)
	await process_frame
	_check(hd3.stage.is_empty() and hd3.holder.modulate.a > 0.99, "Off: complete in the frame it opens")
	hd3.close()
	await process_frame; await process_frame
	_check(not is_instance_valid(hd3.root) or hd3.root.is_queued_for_deletion(), "Off: close frees at once")
	print("STAGING ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
