extends SceneTree
## Type floor: every visible text on the main screens must render at least FLOOR physical pixels tall at the given window size (the type roles of ui_tokens.gd:
## caption 12, detail 13, body 14 at the standard density). Usage: -s tests/ui_type_floor.gd -- <w> <h> <floor px> [report only: 1]   Prints the smallest texts and fails when any is below the floor.
var fails := 0
var seen := {}
var small := {}
var floor_px := 11.0
func _walk(n: Node, ppu: float) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree(): return
	var u := -1.0
	var txt := ""
	if n is TBBz.TLabel:
		u = (n as TBBz.TLabel).fsz(); txt = (n as Label).text
	elif n is Label and (n as Label).text.strip_edges() != "":
		u = float((n as Label).get_theme_font_size("font_size")); txt = (n as Label).text
		if u <= 1.0: u = -1.0
	elif n is Button and (n as Button).text.strip_edges() != "":
		u = float((n as Button).get_theme_font_size("font_size")); txt = (n as Button).text
		if u <= 1.0: u = -1.0
	if u > 0.0 and txt.strip_edges() != "":
		var p := snappedf(u * ppu, 0.5)
		seen[p] = int(seen.get(p, 0)) + 1
		if p < floor_px: small[txt.substr(0, 28)] = p
	for c in n.get_children(): _walk(c, ppu)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1]); floor_px = float(a[2]); var report_only: bool = a.size() > 3
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "globe"; main.cfg["fx"] = "off"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	for i in 12: g.end_turn(); g.pending.clear()
	main._clear_overlay(); main._select(-1)
	for i in 30: await process_frame
	var ppu: float = float(root.size.x) / float(root.content_scale_size.x)
	print("window ", root.size, " logical ", root.content_scale_size, " px per unit ", snappedf(ppu, 0.001))
	var pages := {"map": func(): pass, "nations": func(): main._open_nations(-1), "budget": func(): main._open_budget(), "decrees": func(): main._open_decisions(), "council": func(): main._open_council(), "goals": func(): main._open_council("goals"), "annals": func(): main._open_annals(), "realm": func(): main._open_realm_page(), "menu": func(): main._open_menu_hub("settings")}
	for k in pages:
		main._clear_overlay(); (pages[k] as Callable).call()
		for i in 25: await process_frame
		_walk(main, ppu)
	var keys: Array = seen.keys(); keys.sort()
	var line := ""
	for k in keys: line += "%s px x%d  " % [str(k), int(seen[k])]
	print("text sizes (physical px): ", line)
	for t in small: print("  below ", floor_px, ": ", small[t], " px  '", t, "'")
	if not small.is_empty() and not report_only: fails += 1
	print("UI_TYPE_FLOOR ", "OK" if fails == 0 else "FAIL (%d texts under the floor)" % small.size())
	quit(fails)
