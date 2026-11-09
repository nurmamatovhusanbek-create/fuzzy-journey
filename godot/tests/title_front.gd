extends SceneTree
## The first title stage: Play, Settings, How to play and Honours, the globe in the lower right with its ring, then the morph into the second stage. Usage: -s tests/title_front.gd -- <w> <h> <outprefix>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var pre: String = a[2]
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	for i in 3: await process_frame
	main._update_ui_scale()
	var lg: String = OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en"
	main.cfg["lang"] = lg; TBI18n.load_lang(lg); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["comfort_seen"] = true
	main.cfg["fx"] = OS.get_environment("TB_FX") if OS.get_environment("TB_FX") != "" else "light"; main._apply_a11y()
	main.show_front()
	await _frames(20)
	_check(main._front and main.mode == "menu", "the first stage is up")
	var btns: Array = []; _walk(main._overlay, btns, func(x): return (x is TBTitleParts.CardBtn or x is TBTitleParts.RowBtn) and (x as Button).is_visible_in_tree())
	print("buttons: ", btns.size())
	_check(btns.size() == 4, "four buttons: Play, Settings, How to play, Honours (%d)" % btns.size())
	var gl: TBTitleGlobe = main._front_globe
	_check(gl != null and gl.centre.x > w * 0.85 and gl.centre.y > h * 0.9, "the globe stands in the lower right corner (%s)" % str(gl.centre))
	root.get_viewport().get_texture().get_image().save_png(pre + "_1front.png")
	var t0: float = gl.turn
	await _frames(40)
	_check(gl.turn != t0 or not TBKit.motion_ok(), "the globe turns slowly (%.4f -> %.4f)" % [t0, gl.turn])
	# the morph
	main._front_play()
	_check(main._morph != null, "Play starts the morph")
	var shots := [0.25, 0.5, 0.75]
	var secs: float = 1.8 if TBFx.on(TBFx.FULL) else 1.1
	for i in shots.size():
		await create_timer(secs * (shots[i] - (shots[i - 1] if i > 0 else 0.0)) + 0.02).timeout
		root.get_viewport().get_texture().get_image().save_png(pre + "_2morph%d.png" % (i + 1))
	await create_timer(secs * 0.4).timeout
	await _frames(10)
	_check(main._morph == null and not main._front, "the morph ends on the second stage")
	_check(is_equal_approx(main.map.modulate.a, 1.0) and is_equal_approx(main._overlay.modulate.a, 1.0), "the second stage is fully shown")
	root.get_viewport().get_texture().get_image().save_png(pre + "_3stage2.png")
	# Back returns to the first stage; Settings opens over it
	main.show_front(); await _frames(12)
	main._open_menu_hub("settings"); await _frames(20)
	_check(main._front and TBPanel.any_open(main._overlay), "Settings opens over the first stage")
	root.get_viewport().get_texture().get_image().save_png(pre + "_4settings.png")
	main._clear_overlay(); main.show_front(); await _frames(8)
	for hub in ["honours", "howto"]:
		main._open_menu_hub(hub); await _frames(20)
		_check(main._front and TBPanel.any_open(main._overlay), "%s opens over the first stage" % hub)
		root.get_viewport().get_texture().get_image().save_png(pre + "_5" + hub + ".png")
		main._on_back(); await _frames(8)
		_check(main._front and not TBPanel.any_open(main._overlay), "Esc closes %s and stays on the first stage" % hub)
	# Esc on the second stage backs out to the first
	main.show_menu(); await _frames(20)
	_check(not main._front, "the second stage is up")
	main._on_back(); await _frames(12)
	_check(main._front, "Esc on the second stage returns to the first")
	# the title texture: memory it holds
	var mem0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("texture memory MB: ", snappedf(mem0 / 1048576.0, 0.1))
	main.show_front(); await _frames(10)
	_check(main._front, "show_front returns to the first stage")
	print("TITLE_FRONT OK" if fails == 0 else "TITLE_FRONT FAIL %d" % fails)
	quit(fails)
