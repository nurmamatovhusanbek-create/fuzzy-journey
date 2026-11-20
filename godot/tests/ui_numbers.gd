extends SceneTree
## Numbers a player reads are abbreviated: no visible text holds a plain run of five or more digits (5000000 reads 5.0M). Years and ids are four digits at most.
## The nation is rich, so every screen shows big amounts. Usage: -s tests/ui_numbers.gd (xvfb, TB_NOANIM=1)
var fails := 0
var bad := {}
func _scan(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree(): return
	var txt := ""
	if n is Label: txt = (n as Label).text
	elif n is Button: txt = (n as Button).text
	elif n is RichTextLabel: txt = (n as RichTextLabel).get_parsed_text()
	if txt != "":
		var re := RegEx.new(); re.compile("(?<![\\d.,])\\d{5,}(?![\\d])")
		var m := re.search(txt)
		if m != null: bad[txt.substr(0, 60)] = m.get_string()
	for c in n.get_children(): _scan(c)
const K = preload("res://src/ui/ui_kit.gd")
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _collect(n: Node, out: PackedStringArray) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree(): return
	if n is TBBz.TLabel: out.append((n as Label).text)
	elif n is Label: out.append((n as Label).text)
	for c in n.get_children(): _collect(c, out)
func _init() -> void:
	var sz := Vector2i(1920, 1080)
	DisplayServer.window_set_size(sz); root.size = sz
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"; main.cfg["fx"] = "off"; main.cfg["text_scale"] = 1.0
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	for i in 14: g.end_turn(); g.pending.clear()
	g.gold[g.human_id] = 5e6
	main._clear_overlay(); main._select(-1)
	for i in 30: await process_frame
	var cp: int = g.capital_of[g.human_id]
	var pages := {"map": func(): pass, "nations": func(): main._open_nations(-1), "budget": func(): main._open_budget(), "decrees": func(): main._open_decisions(), "council": func(): main._open_council(),
		"goals": func(): main._open_council("goals"), "annals": func(): main._open_annals(), "realm": func(): main._open_realm_page(), "dossier": func(): main._open_dossier(cp)}
	for k in pages:
		main._clear_overlay(); (pages[k] as Callable).call()
		for i in 25: await process_frame
		var before := bad.size()
		_scan(main)
		if bad.size() > before: print("  page ", k)
	# an event card says what will happen: the gold on it is the gold the engine takes from this nation, not the number in the data
	main._clear_overlay()
	g.pending.append({"uid": 9001, "n": g.human_id, "kind": "rand", "id": "noble_revolt", "icon": "swords", "cat": "CRISIS", "count": 2})
	main.show_events()
	for i in 30: await process_frame
	var texts := PackedStringArray()
	_collect(main._overlay, texts)
	var all := " ".join(texts)
	var want: String = K.signed(TBEvents.amount(g, g.human_id, "gold", -60.0)).replace("-", "−")
	_check(all.contains(want) and all.to_lower().contains("gold"), "the event card shows the gold really taken (%s) in: %s" % [want, all.substr(0, 200)])
	_check(not all.contains("−60 gold"), "and not the number of the data")
	for t in bad: print("  plain number ", bad[t], " in '", t, "'"); fails += 1
	print("UI_NUMBERS ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(fails)
