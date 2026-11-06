extends SceneTree
## Looks for widows: a wrapped text that ends on a line of one or two words (and shorter than half the width). Opens the main screens and scans every visible
## wrapping Label, Para and chip. Usage: -s tests/widow_scan.gd -- <w> <h> [text scale]   (TB_LANG, TB_PHONE_UI)   Prints WIDOW lines and "WIDOW_SCAN OK|FAIL n".
var found := {}
var scanned := 0
func _frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: _run.call_deferred()
func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk(c, out)
func _scan(tag: String) -> void:
	var nodes: Array = []
	_walk(root, nodes)
	for n in nodes:
		if n is Label and (n as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and (n as Label).is_visible_in_tree():
			var l: Label = n
			var t: String = l.text
			if t.length() < 20 or l.size.x < 50.0: continue
			scanned += 1
			for p in t.split("\n"):
				if p.length() < 12 or p.replace("\u00A0", " ").split(" ", false).size() <= 3: continue            # nothing to repair in a name of two or three words
				var tp := TextParagraph.new(); tp.add_string(p, l.get_theme_font("font"), l.get_theme_font_size("font_size")); tp.width = l.size.x
				tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | (TextServer.BREAK_ADAPTIVE if l.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART else 0)
				var lc: int = tp.get_line_count()
				if lc < 2: continue
				var r: Vector2i = tp.get_line_range(lc - 1)
				var tail: String = p.substr(r.x, r.y - r.x).strip_edges()
				var wc: int = tail.replace(" ", " ").split(" ", false).size()
				if wc <= 2 and tp.get_line_width(lc - 1) < l.size.x * 0.5: found["%s | %s | …%s | w=%d lw=%.0f" % [tag, p.substr(0, 70), tail, int(l.size.x), tp.get_line_width(lc - 1)]] = 1
		elif n is TBBzParts.Para and (n as Control).is_visible_in_tree():
			var pa: TBBzParts.Para = n
			scanned += 1
			var ls: Array = pa._lines
			if ls.size() >= 2 and bool((ls[ls.size() - 2] as Dictionary).get("soft", false)):
				var lw: Array = (ls[ls.size() - 1] as Dictionary)["w"]
				var tot := 0
				for q in ls: tot += ((q as Dictionary)["w"] as Array).size()
				if tot > 3 and lw.size() <= 2 and float((ls[ls.size() - 1] as Dictionary)["x1"]) < pa.size.x * 0.5: found["%s | para | %s | lines=%s w=%d" % [tag, pa.markup.substr(0, 50), str(ls.map(func(q): return (q["w"] as Array).size())), int(pa.size.x)]] = 1
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); var sc := float(a[2]) if a.size() > 2 else 1.0
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lg: String = OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en"
	main.cfg["lang"] = lg; TBI18n.load_lang(lg); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"; main.cfg["text_scale"] = sc
	main._apply_quality(); main._update_ui_scale()
	if OS.get_environment("TB_PHONE_UI") != "": main.cfg["phone_ui"] = OS.get_environment("TB_PHONE_UI"); main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay()
	g.gold[me] = 3000.0; g.mp[me] = 6.0; g.tech_level[me] = 3.0
	await _frames(25)
	var p: int = g.capital_of[me]
	for q in g.owned(me): if g.capital[q] == 0 and g.army[q] <= 1: p = q; break
	main._select(p); await _frames(30); _scan("province")
	var vs: Array = main.panel._verbs
	for vi in vs.size():
		main._select(p); await _frames(10)
		main.panel._press(vi); await _frames(20); _scan("verb " + String(main.panel._verbs[vi]["id"]) if vi < main.panel._verbs.size() else "verb")
		main._clear_overlay(); main.panel._close_popover(); await _frames(4)
	main._select(-1); await _frames(5)
	var tabs := ["", "diplomacy", "relations", "wars"]
	for sc2 in ["nations", "budget", "decrees"]:
		main._open_screen(sc2); await _frames(30); _scan(sc2); main._clear_overlay(); await _frames(5)
	main._open_council(); await _frames(30); _scan("council"); main._clear_overlay(); await _frames(5)
	main._open_annals(); await _frames(30); _scan("annals"); main._clear_overlay(); await _frames(5)
	main._open_realm_page(); await _frames(30); _scan("realm"); main._clear_overlay(); await _frames(5)
	main._open_dossier(p); await _frames(30); _scan("dossier"); main._clear_overlay(); await _frames(5)
	for tb in ["saves", "settings", "howto", "honours"]:
		main._open_menu_hub(tb); await _frames(30); _scan("menu " + tb); main._clear_overlay(); await _frames(5)
	# every random event, every proposal
	var ids: Array = []
	for k in (TBI18n._dicts.get("en", {}) as Dictionary).keys():
		if String(k).begins_with("ev_") and String(k).ends_with("_t"): ids.append(String(k).substr(3, String(k).length() - 5))
	for id in ids:
		var cnt := 0
		while TBI18n.has_key("ev_%s_c%d" % [id, cnt]): cnt += 1
		if cnt == 0: continue
		TBModals.event_prompt(main._overlay, {"kind": "rand", "id": id, "count": cnt, "uid": 1, "cat": "culture"}, func(c): pass, g)
		await _frames(14); _scan("event " + id); main._clear_overlay(); await _frames(3)
	var other: int = 2 if me != 2 else 3
	for pid in ["nap", "ally", "peace", "marriage", "trade", "ultimatum"]:
		if not TBI18n.has_key("prop_" + pid): continue
		TBModals.event_prompt(main._overlay, {"kind": "prop", "id": pid, "from": other, "count": 2, "uid": 2, "p": g.capital_of[other]}, func(c): pass, g)
		await _frames(14); _scan("prop " + pid); main._clear_overlay(); await _frames(3)
	main._open_nation(other); await _frames(30); _scan("nation card"); main._clear_overlay(); await _frames(5)
	for k in found: print("WIDOW: ", lg, " ", k)
	print("scanned ", scanned, " wrapped texts; ", found.size(), " widows")
	print("WIDOW_SCAN OK" if found.is_empty() else "WIDOW_SCAN FAIL %d" % found.size())
	quit(0 if found.is_empty() else 1)
