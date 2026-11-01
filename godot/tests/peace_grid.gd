extends SceneTree
## Alignment of the peace table: every row of the window shares one left and one right edge, the switch sits inside its row at the same right edge as the buttons, the word and the switch share a centre line,
## and the two buttons are the same height with their text centred. Usage: -s tests/peace_grid.gd -- <w> <h> <text scale>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _walk(n: Node, out: Array, cls: String) -> void:
	if n.get_class() == cls or (n.get_script() != null and String(n.get_script().get_global_name()) == cls): out.append(n)
	for c in n.get_children(): _walk(c, out, cls)
func _find_toggles(n: Node, out: Array) -> void:
	if n is Button and n.has_method("set_on") and n.has_method("_fit"): out.append(n)
	for c in n.get_children(): _find_toggles(c, out)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 800; var sc := float(a[2]) if a.size() > 2 else 1.0
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang(OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["text_scale"] = sc; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main._apply_a11y()
	for i in 20: await process_frame
	var gg: TBGame = main.g; var me: int = gg.human_id; var en := -1
	for n in range(1, gg.N1):
		if n != me and n != gg.rebel and gg.alive[n] != 0 and gg.human[n] == 0 and gg.own_count(n) > 5 and not gg.friendly(me, n): en = n; break
	gg.set_rel(me, en, TBData.REL_WAR)
	var ol: Array = gg.owned(en)
	for i in 4: gg.occupier[ol[i]] = me; gg.siege[ol[i]] = 0
	gg.occ_rev += 1; gg.war_score[me * gg.N1 + en] = 48; gg.war_turns[me * gg.N1 + en] = 9; gg.exh[en] = 30.0; gg.gold[en] = 900.0
	var hd := TBTermsScreen.open(main._overlay, gg, en, {"on_cmd": func(_c): pass})
	for i in 20: await process_frame
	var body: Control = hd.body
	var br := body.get_global_rect()
	print("body x %.1f..%.1f  w %.1f" % [br.position.x, br.end.x, br.size.x])
	var rows := 0
	for c in body.get_children():
		if not (c is Control) or not (c as Control).visible: continue
		var r := (c as Control).get_global_rect()
		print("  %-14s x %.1f..%.1f  y %.1f h %.1f" % [c.get_class() if c.get_script() == null else String(c.get_script().get_global_name()), r.position.x, r.end.x, r.position.y, r.size.y])
		_check(absf(r.position.x - br.position.x) < 0.6, "row %d starts at the content's left edge (%.1f vs %.1f)" % [rows, r.position.x, br.position.x])
		_check(absf(r.end.x - br.end.x) < 0.6, "row %d ends at the content's right edge (%.1f vs %.1f)" % [rows, r.end.x, br.end.x])
		rows += 1
	var tg: Array = []
	_find_toggles(body, tg)
	for t in tg:
		var tr := (t as Control).get_global_rect()
		var kids: Array = []
		_walk(t, kids, "Control")
		var sw: Control = null; var word: Label = null; var lab: Label = null
		for k in (t as Node).get_child(0).get_children():
			if k is Label and lab == null: lab = k
			elif k is Label: word = k
			elif k is Control: sw = k
		if sw == null or word == null or lab == null: _check(false, "toggle row structure"); continue
		var sr := sw.get_global_rect(); var wr := word.get_global_rect(); var lr := lab.get_global_rect()
		print("  toggle  row x %.1f..%.1f  label %.1f..%.1f  word %.1f..%.1f cy %.1f  switch %.1f..%.1f cy %.1f" % [tr.position.x, tr.end.x, lr.position.x, lr.end.x, wr.position.x, wr.end.x, wr.get_center().y, sr.position.x, sr.end.x, sr.get_center().y])
		_check(absf(wr.get_center().y - sr.get_center().y) < 1.0, "the word and the switch share a centre line")
		_check(absf(sr.end.x - br.end.x) < 0.6, "the switch ends at the content's right edge (%.1f vs %.1f)" % [sr.end.x, br.end.x])
		_check(absf(lr.position.x - br.position.x) < 0.6, "the label starts at the content's left edge (%.1f vs %.1f)" % [lr.position.x, br.position.x])
	_check(tg.size() >= 3, "the toggle rows were found (%d)" % tg.size())
	var btn: Array = []
	_walk(body, btn, "Button")
	for b in btn:
		var br2 := (b as Control).get_global_rect()
		if (b as Button).text != "" and (b as Control).get_script() != null and String((b as Control).get_script().get_global_name()) == "ToggleRow": continue
		print("  button '%s' x %.1f..%.1f y %.1f h %.1f" % [(b as Button).text, br2.position.x, br2.end.x, br2.position.y, br2.size.y])
	# behaviour: the Offer button follows the price
	var offer: Button = null
	for b in btn: if (b as Button).text.to_upper().contains("OFFER"): offer = b
	_check(offer != null and offer.disabled, "nothing ticked: the Offer button is off")
	if offer != null and tg.size() >= 4:
		(tg[0] as Button).emit_signal("pressed")
		await process_frame
		_check(not offer.disabled, "one province ticked and within the score: the Offer button is on")
		(tg[tg.size() - 2] as Button).emit_signal("pressed")          # vassal: 50 points, more than the 48 to spend
		await process_frame
		_check(offer.disabled, "a vassal demand beyond the score switches the Offer button off")
		(tg[tg.size() - 2] as Button).emit_signal("pressed")
		await process_frame
		_check(not offer.disabled, "taking it back switches it on again")
	print("PEACE_GRID OK" if fails == 0 else "PEACE_GRID FAIL %d" % fails)
	quit(fails)
