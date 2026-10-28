extends SceneTree
## A4: on the nation-pick screen the nation under the pointer is outlined and a small card (ruler, rank, army, technology, start rating) appears; it goes when the pointer leaves
## or when that nation is selected (the confirm card takes over). Usage: -s tests/pick_hover.gd -- <out dir>  (fixed fps 30, TB_NOANIM empty)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["text_scale"] = 1.0; main.cfg["fx"] = "full"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	for i in 25: await process_frame
	var g: TBGame = main.g; var m: TBMapView = main.map
	var pf: TBPickFlow = main._pick_flow
	var fr: int = g.nat_code.find("france"); var au: int = g.nat_code.find("austrian_empire")
	var pa: int = g.owned(fr)[0]; var pb: int = g.owned(au)[0]
	main._on_hover(pa)
	_check(pf._hov.visible and pf._hov_n == fr, "hovering a province of France shows its card")
	_check(m._outline_owner == fr, "and outlines France on the map")
	for i in 6: await process_frame
	_check(pf._hov.modulate.a > 0.99, "the card has faded in")
	main._on_hover(pb)
	_check(pf._hov_n == au and m._outline_owner == au, "moving to Austria swaps the card and the outline")
	var has_name := false
	for c in pf._hov_v.get_children():
		for d in c.get_children(): if d is VBoxContainer: for e in d.get_children(): if e is Label and (e as Label).text.to_lower().contains("austria"): has_name = true
	_check(has_name, "the card names the nation")
	main._on_hover(-1)
	_check(not pf._hov.visible and m._outline_owner == -1, "the pointer leaving the map clears both")
	pf.select_nation(fr, false)
	main._on_hover(pa)
	_check(not pf._hov.visible, "the selected nation shows the confirm card, not the hover card")
	main._on_hover(pb)
	for i in 4: await process_frame
	_check(pf._hov.visible and pf._card.visible, "another nation still gets a hover card beside the confirm card")
	root.get_viewport().get_texture().get_image().save_png("%s/pick_hover.png" % out)
	var r1 := Rect2(pf._hov.position, pf._hov.size); var r2 := Rect2(pf._card.position, pf._card.size)
	_check(not r1.intersects(r2), "the two cards do not overlap")
	var vs: Vector2 = pf._vp()
	_check(r1.position.x >= 0 and r1.position.y >= 0 and r1.end.x <= vs.x and r1.end.y <= vs.y, "the hover card stays on screen (%s in %s)" % [str(r1), str(vs)])
	main._start_game(fr)
	_check(m._outline_owner != au, "starting the game leaves no stale hover outline")
	print("PICK_HOVER ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
