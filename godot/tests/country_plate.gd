extends SceneTree
## Country level (rules 4): a tap on a country's land opens its plate, the army stays hidden ("?") for a country nobody has looked at, the capital stars carry the standing, and closing in gives the district again.
## Usage: -s tests/country_plate.gd -- <w> <h> [shot prefix]
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
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lg: String = OS.get_environment("TB_LANG") if OS.get_environment("TB_LANG") != "" else "en"
	main.cfg["lang"] = lg; TBI18n.load_lang(lg); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main.cfg["phone_ui"] = "desktop"; main._update_ui_scale()
	main._begin_pick("timurid", "normal")
	var me: int = 1
	for n in range(1, main.g.N1): if main.g.nat_code[n] == "timurid" or main.g.dname(n).to_lower().contains("timurid"): me = n; break
	main._start_game(me)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	await _frames(25)
	var cp: int = g.capital_of[me]
	main.map.fly_to(g.world.lon[cp], g.world.lat[cp], 2.4, 0.0)
	await _frames(80)
	_check(main._country_grade(), "zoom 2.4 is country level")
	var other: int = g.nat_code.find("mamluke_sultanate")
	var oc: int = g.capital_of[other]
	main._on_pick(oc, false); await _frames(30)
	_check(main._country_plate != null and is_instance_valid(main._country_plate), "a tap on a country opens its plate")
	_check(main.selected < 0, "no district is selected at country level")
	var facts: Array = []; _walk(main._country_plate, facts, func(x): return x is TBCountryPlate.Fact)
	var texts: Array = facts.map(func(f): return f.txt)
	print("plate facts: ", texts)
	_check(texts.size() == 3, "three facts")
	_check(texts.has(TBI18n.T("cp_army_hidden")), "the army of a country nobody has looked at stays hidden")
	if OS.get_environment("TB_SHOT") != "": root.get_texture().get_image().save_png(OS.get_environment("TB_SHOT") + "_plate.png")
	var r: Rect2 = main._country_plate.get_global_rect()
	_check(root.get_visible_rect().grow(1.0).encloses(r), "the plate is inside the screen (%s)" % str(r))
	# standing under the stars
	_check(TBStanding.stars(g, me) >= 4, "the Timurids stand high (%d)" % TBStanding.stars(g, me))
	if h > w:                                                                # a portrait phone: the close-in check is done on the landscape sizes
		print("COUNTRY_PLATE OK" if fails == 0 else "COUNTRY_PLATE FAIL %d" % fails); quit(fails); return
	# closing in: the district
	main._close_country_plate()
	main.map.fly_to(g.world.lon[cp], g.world.lat[cp], 14.0, 0.0); await _frames(70)
	_check(not main._country_grade(), "close in is not country level")
	main._on_pick(cp, false); await _frames(20)
	_check(main.selected == cp, "close in, a tap selects the district")
	print("COUNTRY_PLATE OK" if fails == 0 else "COUNTRY_PLATE FAIL %d" % fails)
	quit(fails)
