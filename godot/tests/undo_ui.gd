extends SceneTree
## Undo through the real interface: an order, Ctrl+Z, the screen follows; the end of the turn closes the stack. Usage: -s tests/undo_ui.gd -- <w> <h>
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280; var h := int(a[1]) if a.size() > 1 else 720
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
	g.mp[me] = 20.0; g.gold[me] = 50000.0
	main._select(cap)
	for i in 10: await process_frame
	var army0: int = g.army[cap]; var mp0: float = g.mp[me]
	main._on_command({"cmd": "spread", "p": cap})
	for i in 10: await process_frame
	_check(main._undo.can(), "an order is on the undo stack")
	_check(g.mp[me] < mp0, "the order cost moves")
	var key := InputEventKey.new(); key.keycode = KEY_Z; key.ctrl_pressed = true; key.pressed = true
	main._unhandled_key_input(key)
	for i in 10: await process_frame
	_check(g.army[cap] == army0 and absf(g.mp[me] - mp0) < 0.01, "Ctrl+Z puts the army and the moves back (%d, %.1f)" % [g.army[cap], g.mp[me]])
	_check(main.g == g, "the game object is the same")
	_check(not main._undo.can(), "and the stack is empty again")
	main._on_command({"cmd": "muster", "pct": 25})
	for i in 5: await process_frame
	_check(main._undo.can(), "another order is recorded")
	main.end_turn()
	var guard := 0
	while main._busy and guard < 400: await create_timer(0.05).timeout; guard += 1
	for i in 10: await process_frame
	_check(not main._undo.can(), "the end of the turn closes the stack")
	main._open_game_menu()
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/pt5/n4_menu.png")
	print("UNDO_UI OK" if fails == 0 else "UNDO_UI FAIL %d" % fails)
	quit(fails)
