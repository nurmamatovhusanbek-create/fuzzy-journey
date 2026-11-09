extends SceneTree
## The Outliner lists what is under way and the pinned provinces; each row names a province to fly to; pins are bounded and survive in settings. Usage: -s tests/outliner.gd -- <w> <h> <outprefix>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 720; var pre: String = a[2] if a.size() > 2 else "/tmp/pt5/outl"
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	TBI18n.load_lang("en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["comfort_seen"] = true
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	var g: TBGame = main.g
	var me := g.human_id
	var cap: int = g.capital_of[me]
	g.gold[me] = 90000.0; g.mp[me] = 30.0
	main._on_command({"cmd": "spread", "p": cap})
	var q := -1
	for p in g.owned(me): if p != cap and g.dev[p] < 4: q = p; break
	main._on_command({"cmd": "develop", "p": q, "k": 1})
	main._on_command({"cmd": "build", "p": cap, "b": 1})
	for i in 10: await process_frame
	var cfg: Dictionary = main.cfg
	TBOutliner.toggle_pin(cfg, q); TBOutliner.toggle_pin(cfg, cap)
	var data := TBOutliner.rows(g, me, cfg)
	print("projects ", data["projects"].size(), " armies ", data["armies"].size(), " wars ", data["wars"].size(), " pins ", data["pins"].size())
	_check(data["projects"].size() >= 1, "a running project or building is listed")
	_check(data["armies"].size() >= 2, "armies and marches are listed")
	_check(data["pins"].size() == 2, "two pins")
	for r in data["projects"] + data["armies"] + data["pins"]: _check(int(r[1]) >= 0 and int(r[1]) < g.P and String(r[0]) != "", "every row names a province and a text")
	TBOutliner.toggle_pin(cfg, q)
	_check(TBOutliner.pins(cfg) == [cap], "unpinning removes it")
	for i in 40: TBOutliner.toggle_pin(cfg, i)
	_check(TBOutliner.pins(cfg).size() <= TBOutliner.MAX_PINS, "pins are bounded")
	_check(TBCfgGuard.accept("pins", cfg["pins"], []) == cfg["pins"], "the settings file accepts them")
	main._select(cap)
	main.hud._screen("outliner")
	for i in 20: await process_frame
	_check(TBPanel.any_open(main._overlay), "F7 opens the window")
	root.get_viewport().get_texture().get_image().save_png(pre + "_1.png")
	print("OUTLINER OK" if fails == 0 else "OUTLINER FAIL %d" % fails)
	quit(fails)
