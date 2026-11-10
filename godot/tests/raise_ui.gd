extends SceneTree
## The ring offers ONE order for men (Raise troops) from rules 5; its card shows where the men come from; confirming sends the command. Usage: -s tests/raise_ui.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _init() -> void:
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["view"] = "flat"
	main._apply_a11y(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	var me: int = g.human_id
	g.gold[me] = 5e6; g.mp[me] = 10.0
	var p := -1
	for q in g.P: if g.owner[q] == me and (p < 0 or g.levy[q] > g.levy[p]): p = q
	main.map.jump_to(g.world.lon[p], g.world.lat[p], 4.0)
	for i in 10: await process_frame
	main._select(p)
	for i in 20: await process_frame
	var ids: Array = []
	for v in main.ring.verbs: ids.append(String(v["id"]))
	print("ring verbs: ", ids)
	_check(ids.has("raise"), "the ring has Raise troops")
	_check(not ids.has("recruit") and not ids.has("hire"), "Recruit and Hire are gone from the ring at rules 5")
	# the card
	main._open_amount("raise", p)
	for i in 8: await process_frame
	var card: TBRecruitCard = main._amount_card
	_check(card != null and card.visible and card.kind == "raise", "the card opens for raise")
	var pool: int = TBRaise.pool(g, p)
	card.picker.set_value(mini(pool + 150, TBRaise.max_amount(g, p)))
	card._on_amount(card.picker.value)
	for i in 4: await process_frame
	print("split text: ", card._split.text, " | price: ", card._price.text)
	_check(card._split.text.find("hired") >= 0, "past the pool the card says men are hired")
	card.picker.set_value(mini(200, pool)); card._on_amount(card.picker.value)
	for i in 4: await process_frame
	_check(card._split.text.find("levy pool") >= 0 or card._split.text.find("Levy") >= 0, "inside the pool the card says all from the levy pool")
	var army0: int = g.army[p]; var gold0: float = g.gold[me]
	card._confirm()
	for i in 6: await process_frame
	_check(g.army[p] == army0 + 200, "confirming raises the men (%d -> %d)" % [army0, g.army[p]])
	_check(g.gold[me] < gold0, "and charges gold")
	print("RAISE_UI ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
