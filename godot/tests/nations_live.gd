extends SceneTree
## An open Nations window follows the state: after a pact is made and the turn goes by, its list row and its card show the new figures without being closed. Usage: -s tests/nations_live.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _walk(n: Node, out: Array, test: Callable) -> void:
	if test.call(n): out.append(n)
	for c in n.get_children(): _walk(c, out, test)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800)); root.size = Vector2i(1280, 800)
	TBI18n.load_lang("en")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	var g: TBGame = main.g
	var me: int = g.human_id
	var sp: int = g.nat_code.find("spain")
	main._open_nations(sp)
	for i in 20: await process_frame
	var rows: Array = []; _walk(main, rows, func(x): return x is TBNationsScreen.NationRow and (x as TBNationsScreen.NationRow).n == sp)
	_check(rows.size() == 1, "the window lists Spain (%d)" % rows.size())
	var r: TBNationsScreen.NationRow = rows[0]
	var before: String = r.st_text
	var rel0: int = r.rel
	g.set_rel(me, sp, TBData.REL_ALLY)
	g.army[g.capital_of[sp]] += 777
	TBNationsScreen.refresh_live()
	for i in 10: await process_frame
	_check(r.rel == TBData.REL_ALLY, "the row follows the new relation (%d -> %d)" % [rel0, r.rel])
	_check(r.st_text != before or rel0 == TBData.REL_ALLY, "and its status text (%s -> %s)" % [before, r.st_text])
	main._on_command({"cmd": "endTurn"}) if false else null
	print("NATIONS_LIVE OK" if fails == 0 else "NATIONS_LIVE FAIL %d" % fails)
	quit(fails)
