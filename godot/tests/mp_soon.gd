extends SceneTree
## The title's Multiplayer row says "Coming soon" and opens a note, not the lobby; with the switch on it opens the lobby. Usage: -s tests/mp_soon.gd -- 1280 720  (pictures to /tmp/mp_soon_*.png when a 3rd argument gives a folder)
var fails := 0
func check(c: bool, what: String) -> void:
	if c: print("  ok   ", what)
	else: fails += 1; print("  FAIL ", what)
func _find(n: Node, cls: String, acc: Array) -> void:
	if n is Button and n.get("tag") != null and n.get("title") != null: acc.append(n)       # the title's RowBtn (an inner class: no global name)
	for k in n.get_children(): _find(k, cls, acc)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true
	main.show_menu()
	for i in 40: await process_frame
	var rows: Array = []
	_find(main, "RowBtn", rows)
	var mp_row: Button = null
	for r in rows: if (r as Button).get("title") == TBI18n.T("multiplayer"): mp_row = r
	check(mp_row != null, "the title has a Multiplayer row")
	check(mp_row != null and String(mp_row.get("tag")) == TBI18n.T("coming_soon") and not mp_row.disabled, "it carries the COMING SOON tag and can be pressed")
	if a.size() > 2: root.get_viewport().get_texture().get_image().save_png("%s/mp_soon_title_%dx%d.png" % [a[2], w, h])
	var notes: Array = []; _notes(main._overlay, notes)
	for nt in notes:
		var nr: Rect2 = (nt as Control).get_global_rect()
		for r in rows: check(not nr.intersects((r as Control).get_global_rect()), "the Advisor's note does not cover the '%s' row" % String(r.get("title")))
	mp_row.pressed.emit()
	for i in 20: await process_frame
	check(main.mp.net == null, "pressing it starts no network")
	var found := false
	for l in _labels(main._overlay): if String(l.get("text")).to_upper() == TBI18n.T("mp_soon_title").to_upper(): found = true
	check(found, "a note 'Multiplayer is coming soon' opens")
	if a.size() > 2: root.get_viewport().get_texture().get_image().save_png("%s/mp_soon_note_%dx%d.png" % [a[2], w, h])
	main._clear_overlay()
	TBRelease.multiplayer = true
	main.show_menu()
	for i in 30: await process_frame
	rows.clear(); _find(main, "RowBtn", rows)
	for r in rows: if (r as Button).get("title") == TBI18n.T("multiplayer"): mp_row = r
	check(String(mp_row.get("tag")) == "", "with online play on the tag is gone")
	print("MP_SOON OK" if fails == 0 else "MP_SOON FAIL %d" % fails)
	quit(fails)

func _labels(n: Node) -> Array:
	var out: Array = []
	if n is Control and n.get("text") is String and String(n.get("text")) != "": out.append(n)
	for k in n.get_children(): out.append_array(_labels(k))
	return out
func _notes(n: Node, acc: Array) -> void:
	if n is TBAdvisorNote: acc.append(n)
	for k in n.get_children(): _notes(k, acc)
