extends SceneTree
## The ruler line on a nation card follows the card's width when the window is made wider or narrower. Usage: -s tests/ruler_resize.gd -- <w> <h>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _paras(main: Node) -> Array:
	var out: Array = []; _walk(main, out, func(x): return x is TBBzParts.Para and (x as Control).is_visible_in_tree() and String(x.markup).begins_with("[i]") and x.size.x > 20.0)
	return out
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	await _frames(20)
	var other: int = 2 if me != 2 else 3
	var hd = TBModals.nations_screen(main._overlay, g, {"on_cmd": main._on_command, "on_goto": main._goto_nation, "on_fly": main._fly_to_nation, "select": other})
	await _frames(40)
	for size_i in [Vector2i(900, 640), Vector2i(1250, 700), Vector2i(760, 640), Vector2i(1100, 760)]:
		hd.user_size = Vector2(size_i); hd.user_pos = hd.card.position if hd.user_pos.x < -0.5 else hd.user_pos
		TBPanel._fit_bz(hd)
		await _frames(40)
		if OS.get_environment("TB_SHOT") != "": root.get_texture().get_image().save_png("%s_%d.png" % [OS.get_environment("TB_SHOT"), size_i.x])
		var ps: Array = _paras(main)
		var shown := 0
		for p in ps:
			var para: TBBzParts.Para = p
			if para.markup.find(TBRulers.display_name(g, other)) < 0: continue
			shown += 1
			# the lines must be those of a fresh layout at the width the paragraph has now, and it must be as tall as its lines
			var want_lines := 1
			var lay: Array = para._lines
			var fresh := TBBzParts.Para.new(para.markup, para.px, para.lh, para.col); root.add_child(fresh); fresh.size = Vector2(para.size.x, 10); fresh._layout(para.size.x)
			want_lines = fresh._lines.size(); fresh.queue_free()
			print("window ", size_i, " ruler width ", para.size.x, " lines ", lay.size(), " fresh ", want_lines, " height ", para.size.y, " min ", para.get_combined_minimum_size().y)
			_check(lay.size() == want_lines, "the ruler's lines follow the width (%d vs %d at %d)" % [lay.size(), want_lines, int(para.size.x)])
			_check(absf(para.size.y - para._lhu() * float(want_lines)) < 1.5, "the ruler's height follows its lines (%.1f vs %.1f)" % [para.size.y, para._lhu() * float(want_lines)])
		_check(shown >= 1, "the ruler is on the card (%d)" % shown)
	print("RULER_RESIZE OK" if fails == 0 else "RULER_RESIZE FAIL %d" % fails)
	quit(fails)
