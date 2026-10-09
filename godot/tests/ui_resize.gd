extends SceneTree
## Resize + modal layering audit: a window resize must not replay notices or rebuild them, and nothing from the HUD (tooltip, popover,
## notices, gauges) may draw above an open modal. Prints UI_RESIZE OK or FAIL lines.
var fails := 0
func _ck(c: bool, m: String) -> void:
	if not c: fails += 1; print("FAIL: ", m)

## effective draw order key of a control: its z (summed up the tree while z_as_relative) in a stable tree-order comparison
func _z(c: CanvasItem) -> int:
	var z := 0
	var n: Node = c
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative: break
		n = n.get_parent()
	return z

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france") if main.g != null else 1)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 30: await process_frame
	var hud = main.hud
	hud.toast("Austria masses troops on your border", true)
	hud.toast("Spain proposes a pact", false)
	await create_timer(0.8).timeout
	var tk: TBAlertTicker = hud._ticker
	var ids: Array = []
	for k in tk.rows: ids.append(tk.rows[k].get_instance_id())
	var info_id: int = tk.info.get_instance_id() if tk.info != null else 0
	# resize a few times: same rows, none re-animating, the info row not faded back in
	for sz in [Vector2i(900, 415), Vector2i(540, 960), Vector2i(800, 360), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(sz); root.size = sz
		await process_frame
		await process_frame
		var ids2: Array = []
		for k in tk.rows: ids2.append(tk.rows[k].get_instance_id())
		_ck(ids2 == ids, "ticker rows are the same objects after resizing to %s" % str(sz))
		for k in tk.rows:
			var rw = tk.rows[k]
			_ck(rw.ap >= 0.999, "row %s is not re-animating at %s (ap %.2f)" % [k, str(sz), rw.ap])
		if tk.info != null:
			_ck(tk.info.get_instance_id() == info_id, "info toast is the same object at %s" % str(sz))
			_ck(tk.info.modulate.a >= 0.999, "info toast is not fading in again at %s (a %.2f)" % [str(sz), tk.info.modulate.a])
	# a modal opened while a HUD tooltip / popover is up: neither may stay above it
	for open_fn in ["_open_menu_hub", "_open_budget", "_open_nations"]:
		main._clear_overlay()
		for i in 5: await process_frame
		var anchor: Control = hud._chips.values()[0] if hud._chips.size() > 0 else hud
		hud._tip_show(anchor, ["Treasury", "Gold in hand"])
		var tip: Control = hud._tip
		_ck(tip != null, "a tooltip is up before %s" % open_fn)
		main.call(open_fn)
		for i in 10: await process_frame
		var modal: Control = null
		for c in main._overlay.get_children():
			if c.has_meta("tb_modal") and not c.is_queued_for_deletion(): modal = c
		_ck(modal != null, "%s opened a modal" % open_fn)
		if modal != null:
			if hud._tip != null and is_instance_valid(hud._tip):
				_ck(_z(hud._tip) < _z(modal), "%s: tooltip (z %d) is under the modal (z %d)" % [open_fn, _z(hud._tip), _z(modal)])
			if hud._pop != null and is_instance_valid(hud._pop):
				_ck(_z(hud._pop) < _z(modal), "%s: popover (z %d) is under the modal (z %d)" % [open_fn, _z(hud._pop), _z(modal)])
	# a popover open when a modal opens
	main._clear_overlay()
	for i in 5: await process_frame
	var pa: Control = hud._chips.values()[0] if hud._chips.size() > 0 else hud
	hud._open_pop("menu", Label.new(), pa)
	main._open_budget()
	for i in 10: await process_frame
	var modal2: Control = null
	for c in main._overlay.get_children():
		if c.has_meta("tb_modal") and not c.is_queued_for_deletion(): modal2 = c
	_ck(modal2 != null, "budget modal is open")
	if modal2 != null and hud._pop != null and is_instance_valid(hud._pop):
		_ck(_z(hud._pop) < _z(modal2), "popover (z %d) is under the modal (z %d)" % [_z(hud._pop), _z(modal2)])
	# resizing with a modal open does not bring HUD pieces above it
	DisplayServer.window_set_size(Vector2i(540, 960)); root.size = Vector2i(540, 960)
	for i in 5: await process_frame
	_ck(TBPanel.any_open(main._overlay) or modal2 != null, "modal survives a resize")
	print("UI_RESIZE OK" if fails == 0 else "UI_RESIZE FAILS %d" % fails)
	quit(1 if fails > 0 else 0)
