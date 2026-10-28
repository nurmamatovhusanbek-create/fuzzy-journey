extends SceneTree
## F2: the Advisor's note. Title: one true line under the menu, rotates, never twice in a bag, hidden by the era ring, switchable off; every language has every line; the plate stays clear of the menu.
## Game: shown only when a turn takes over a second, gone when it ends, above the lens bar, off with the setting. Effects Off: no fades.
## Usage: -s tests/advisor_note.gd -- <w> <h>     (TB_DPR / TB_DPI emulate a phone's density; the window size then decides the stage)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1

func _buttons(n: Node, acc: Array) -> void:
	for c in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree(): acc.append(c)
		_buttons(c, acc)

func _note(main: Control) -> Node:
	return main._overlay.get_node_or_null("AdvisorNote")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main._apply_quality(); main._update_ui_scale(); main._apply_a11y()
	# every line in every language
	for lang in ["en", "ru", "uz"]:
		TBI18n.load_lang(lang)
		for k in TBAdvisorNote.KEYS:
			var tx: String = TBI18n.T(k)
			_check(tx != "" and tx != k, "%s has %s" % [lang, k])
		_check(TBI18n.T("advisor_note") != "advisor_note" and TBI18n.T("tips_title") != "tips_title", "%s has the plate label and the setting" % lang)
	TBI18n.load_lang("en")
	# ---- the title
	main._spin = false; main.show_menu(); main._spin = false
	for i in 12: await process_frame
	var n = _note(main)
	if main._title_wide:
		_check(n != null, "the title has the note")
		if n != null:
			var vs: Vector2 = main.size
			_check(n.shown and n.modulate.a > 0.99, "it is shown (Effects Off: at once)")
			_check(TBAdvisorNote.KEYS.has(n.key()) and n.line() != "", "a real line: %s" % n.line())
			var r := Rect2(n.position, n.size)
			_check(Rect2(Vector2.ZERO, vs).encloses(r), "on screen: %s in %s" % [str(r), str(vs)])
			var bs: Array = []; _buttons(main._overlay, bs)
			for b in bs:
				var br := Rect2((b as Control).get_global_rect().position - main.global_position, (b as Control).size)
				if br.size.x > 20.0: _check(not r.intersects(br), "clear of the button '%s' (%s vs %s)" % [(b as Button).text, str(r), str(br)])
			# a bag: twelve takes, twelve different lines; the next bag does not start with the line just shown
			var seen := {}
			var last: String = n.key()
			for i in TBAdvisorNote.KEYS.size():
				n.next_tip(); seen[n.key()] = true
			_check(seen.size() >= TBAdvisorNote.KEYS.size() - 1, "a bag shows each line once (%d different)" % seen.size())
			var before: String = n.key(); n.next_tip()
			_check(n.key() != before, "a new line each time")
			# every language: the plate fits above the footer and clear of the menu
			for lang in ["ru", "uz", "en"]:
				main.cfg["lang"] = lang; TBI18n.load_lang(lang)
				main._spin = false; main.show_menu(); main._spin = false
				for i in 6: await process_frame
				var n2 = _note(main)
				for k in TBAdvisorNote.KEYS:
					n2._key = k; n2._relayout()
					_check(n2.size.y <= 80.0 * n2.u * 2.0 and n2.position.y >= 0.0 and n2.position.y + n2.size.y <= vs.y, "%s %s fits (%.0f tall)" % [lang, k, n2.size.y])
					var bs2: Array = []; _buttons(main._overlay, bs2)
					for b in bs2:
						var br2 := Rect2((b as Control).get_global_rect().position - main.global_position, (b as Control).size)
						if br2.size.x > 20.0 and Rect2(n2.position, n2.size).intersects(br2): _check(false, "%s %s overlaps '%s'" % [lang, k, (b as Button).text])
			# the era ring takes the column (and the note) away
			main._open_era_picker()
			for i in 30: await process_frame
			var n3 = _note(main)
			_check(n3 != null and not n3.visible, "the era ring hides the note")
	else:
		_check(n == null, "no note on a narrow title")
	# the switch
	main.cfg["tips"] = false; main.show_menu(); main._spin = false
	for i in 6: await process_frame
	_check(_note(main) == null, "off: no note on the title")
	main.cfg["tips"] = true
	# ---- the game
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 20: await process_frame
	var hud = main.hud
	_check(hud._advice != null and not hud._advice.shown, "idle: no note")
	hud.set_busy(true)
	for i in 10: await process_frame
	_check(not hud._advice.shown, "a turn under a second: no note")
	hud.set_busy(false)
	for i in 40: await process_frame
	_check(not hud._advice.shown, "...and none after it")
	hud.set_busy(true)
	for i in 45: await process_frame
	var vs2: Vector2 = hud._vp
	if hud._prof != 3:
		_check(hud._advice.shown and hud._advice.visible and hud._advice.modulate.a > 0.99, "a long turn: the note shows")
		var ar := Rect2(hud._advice.position, hud._advice.size)
		_check(Rect2(Vector2.ZERO, vs2).encloses(ar) and ar.end.y <= hud._mode.position.y, "above the lens bar and on screen: %s, lens bar at %s" % [str(ar), str(hud._mode.position)])
		_check(absf((ar.position.x + ar.size.x * 0.5) - vs2.x * 0.5) < 2.0, "centred")
	hud.set_busy(false)
	for i in 4: await process_frame
	_check(not hud._advice.shown and not hud._advice.visible, "gone when the turn ends")
	hud.tips_on = false
	hud.set_busy(true)
	for i in 45: await process_frame
	_check(not hud._advice.shown, "tips off: no note in the game")
	hud.set_busy(false)
	# Effects Light: it fades (not at once)
	main.cfg["fx"] = "light"; TBFx.apply(main.cfg); hud.tips_on = true
	hud.set_busy(true)
	for i in 31: await process_frame
	_check(hud._advice.shown and hud._advice.modulate.a < 0.99, "Light: fading in (%.2f)" % hud._advice.modulate.a)
	for i in 30: await process_frame
	_check(hud._advice.modulate.a > 0.99, "Light: faded in")
	hud.set_busy(false)
	print("ADVISOR_NOTE OK" if fails == 0 else "ADVISOR_NOTE FAIL %d" % fails)
	quit(fails)
