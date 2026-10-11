extends SceneTree
## Movable, resizable, non-modal windows: the Nations window leaves the map and the End Turn dial usable, is dragged by its header, resized from its
## edge and corner, remembered per screen, and a country clicked on the map shows its card.
var fails := 0
func _ck(c: bool, m: String) -> void:
	if not c: fails += 1; print("FAIL: ", m)

func _mouse(ctl: Control, pressed: bool, at: Vector2) -> void:
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at; e.global_position = ctl.global_position + at
	ctl.gui_input.emit(e)

func _move(ctl: Control, at: Vector2) -> void:
	var e := InputEventMouseMotion.new(); e.position = at; e.global_position = ctl.global_position + at
	ctl.gui_input.emit(e)

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	TBPanel.win_mem = {}
	main._open_nations()
	for i in 12: await process_frame
	var h: TBPanel.Handle = main._nations_window()
	_ck(h != null and h.movable and not h.modal, "the Nations window is a non-modal movable window")
	_ck(h.backdrop == null, "no scrim over the map")
	_ck(not main._modal_open(), "no modal is open")
	_ck(main.hud._seal.z_index > h.root.z_index, "the End Turn dial is drawn above the window")
	# drag by the header
	var p0: Vector2 = h.card.position
	var hd: Control = h.head
	_mouse(hd, true, Vector2(200, 20)); _move(hd, Vector2(260, 60)); _mouse(hd, false, Vector2(260, 60))
	for i in 4: await process_frame
	_ck(h.card.position.distance_to(p0 + Vector2(60, 40)) < 2.0, "the header drags the window (%s -> %s)" % [str(p0), str(h.card.position)])
	_ck(TBPanel.win_mem.has("nations") and float(TBPanel.win_mem["nations"]["x"]) == h.card.position.x, "its place is remembered")
	# resize by the corner
	var s0: Vector2 = h.card.size
	var br: Control = h.resizers[2]
	_mouse(br, true, Vector2(5, 5)); _move(br, Vector2(-45, -35)); _mouse(br, false, Vector2(-45, -35))
	for i in 4: await process_frame
	_ck(h.card.size.x < s0.x - 30.0 and h.card.size.y < s0.y - 20.0, "the corner resizes the window (%s -> %s)" % [str(s0), str(h.card.size)])
	# reopen: same place and size
	var pos1: Vector2 = h.card.position; var size1: Vector2 = h.card.size
	main._clear_overlay()
	for i in 4: await process_frame
	main._open_nations()
	for i in 12: await process_frame
	var h2: TBPanel.Handle = main._nations_window()
	_ck(h2.card.position.distance_to(pos1) < 2.0 and h2.card.size.distance_to(size1) < 2.0, "the window reopens where it was left")
	# a country on the map shows its card
	var other := 0
	for p in g.P:
		if g.owner[p] > 0 and g.owner[p] != fr: other = p; break
	main._on_pick(other, false)
	for i in 8: await process_frame
	var h3: TBPanel.Handle = main._nations_window()
	_ck(h3 != null, "the Nations window stays open after a click on the map")
	# double click on the header: docked again
	_mouse(h3.head, true, Vector2(100, 20))
	var dc := InputEventMouseButton.new(); dc.button_index = MOUSE_BUTTON_LEFT; dc.pressed = true; dc.double_click = true
	h3.head.gui_input.emit(dc)
	for i in 4: await process_frame
	_ck(h3.user_pos.x < 0.0 and not TBPanel.win_mem.has("nations"), "a double click on the header docks it again")
	main._clear_overlay()
	print("UI_WINDOWS OK" if fails == 0 else "UI_WINDOWS FAIL")
	quit(0 if fails == 0 else 1)
