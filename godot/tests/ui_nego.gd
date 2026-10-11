extends SceneTree
## Court requests audit: the nation card's request buttons show the likelihood, one press sends the request (points spent, nothing decided), the
## button reads Proposed / next turn, the answer arrives with the next turn as a flag notice; the meter / why list add up. Prints UI_NEGO OK or FAIL lines.
var fails := 0
func _ck(c: bool, m: String) -> void:
	if not c: fails += 1; print("FAIL: ", m)

func _cards(n: Node, out: Array) -> void:
	if n is TBBz.Btn and (n as TBBz.Btn).sub != "" and not (n as Button).disabled and (n as Control).is_visible_in_tree(): out.append(n)       # the diplomacy plates carry their envoy cost as a sub line
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
	var dp0: float = g.dp[fr]
	var rel0: int = g.get_rel(fr, sp)
	# one press sends the request: the points go now, nothing is decided, the button reads Proposed / next turn, the others wait
	var pct: int = TBAsks.chance(g, fr, "nap", sp)
	_ck(String((cards[0] as TBBz.Btn).sub) == "%d%%" % pct, "the button shows the likelihood (%s vs %d%%)" % [(cards[0] as TBBz.Btn).sub, pct])
	(cards[0] as Button).pressed.emit()
	await create_timer(0.3).timeout
	_ck(g.asks.size() == 1 and g.dp[fr] < dp0 and g.get_rel(fr, sp) == rel0, "the request is on its way, points spent, relation unchanged")
	_ck(not TBNegotiate.active, "no dial")
	var after: Array = []
	_cards(main, after)
	var wait := 0
	for c in after: if (c as TBBz.Btn).sub == TBI18n.T("ask_next"): wait += 1
	_ck(wait == 1, "exactly one button reads next turn (%d)" % wait)
	_ck(TBPanel.any_open(main._overlay), "the nations panel stays open")
	g.end_turn()
	var ans := 0
	for e in g.log: if String(e["kind"]) == "ans" and int(e["a"]) == fr and int(e["b"]) == sp: ans += 1
	_ck(ans == 1 and g.asks.is_empty(), "the answer arrives with the next turn")
	for e in TBAdvisor.ticker(g, fr): if String(e["cls"]) == "answer" and int(e["n"]) == sp: ans += 10
	_ck(ans == 11, "and shows as a flag notice")
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
