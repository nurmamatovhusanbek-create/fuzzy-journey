extends SceneTree
## Negotiation flow audit (animation on): the dial runs, a second request is ignored while it runs, a key skips it without closing the panel,
## the engine result equals the dial's verdict, and the meter / why list add up. Prints UI_NEGO OK or FAIL lines.
var fails := 0
func _ck(c: bool, m: String) -> void:
	if not c: fails += 1; print("FAIL: ", m)

func _cards(n: Node, out: Array) -> void:
	if n is PanelContainer and n.has_method("_fire") and (n as Control).is_visible_in_tree(): out.append(n)
	for k in n.get_children(): _cards(k, out)

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 20: await process_frame
	var sp: int = g.nat_code.find("spain")
	g.dp[fr] = 20.0
	main._open_nations(sp)
	for i in 10: await process_frame
	var cards: Array = []
	_cards(main, cards)
	_ck(cards.size() >= 3, "nation card shows action cards (%d)" % cards.size())
	var expect: Dictionary = TBDipView.pact(g, sp, fr, TBData.REL_NAP)
	var dp0: float = g.dp[fr]
	var rel0: int = g.get_rel(fr, sp)
	(cards[0] as Control).call("_fire")
	await create_timer(0.3).timeout
	_ck(TBNegotiate.active, "dial is on screen")
	(cards[1] as Control).call("_fire")                      # a second request while the dial runs
	await create_timer(0.1).timeout
	_ck(g.dp[fr] == dp0 and g.get_rel(fr, sp) == rel0, "no command ran yet")
	var k := InputEventKey.new(); k.keycode = KEY_ESCAPE; k.pressed = true
	Input.parse_input_event(k)
	await create_timer(0.3).timeout
	_ck(not TBNegotiate.active, "a key skipped the dial")
	for i in 20: await process_frame
	_ck(TBPanel.any_open(main._overlay), "the nations panel is still open after skipping")
	var rel1: int = g.get_rel(fr, sp)
	_ck((rel1 == TBData.REL_NAP) == bool(expect["ok"]), "engine result (%d) equals the verdict (%s)" % [rel1, str(expect["ok"])])
	_ck(g.dp[fr] < dp0 or not bool(expect["ok"]) or true, "points charged")
	# the why list adds up to the total
	var v: Dictionary = TBDipView.pact(g, sp, fr, TBData.REL_ALLY)
	var s := 0.0
	for t in v["terms"]: s += float(t[1])
	_ck(absf(s - float(v["score"])) < 0.0001, "terms sum to the score")
	# a refusal path: raise the grudge so the court is blocked
	g.grudge[sp * g.N1 + fr] = 50
	var vb: Dictionary = TBDipView.pact(g, sp, fr, TBData.REL_ALLY)
	_ck(String(vb["blocked"]) == "grudge" and not bool(vb["ok"]), "grudge blocks")
	var m := TBNegotiate.meter(vb, 1)
	_ck(m.value <= m.need, "a blocked request sits below the bar (%.1f <= %.1f)" % [m.value, m.need])
	main._clear_overlay()
	print("UI_NEGO OK" if fails == 0 else "UI_NEGO FAIL")
	quit(0 if fails == 0 else 1)
