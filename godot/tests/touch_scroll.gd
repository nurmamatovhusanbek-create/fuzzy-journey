extends SceneTree
## A finger drags a list: it scrolls with the finger, and the row under the finger is not pressed. Also: the corner grip of a window is big enough for a finger and resizes it.
## Usage: -s tests/touch_scroll.gd -- <w> <h>   (TB_DPR / TB_DPI emulate a phone)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1
	else: print("  ok   ", what)
func _frames(n: int) -> void:
	for i in n: await process_frame

func _scrollers(n: Node, acc: Array) -> void:
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree(): acc.append(n)
	for k in n.get_children(): _scrollers(k, acc)

func _texts(n: Node, skip: Node, acc: Array) -> void:
	if n == skip: return
	if n is Control and (n as Control).is_visible_in_tree() and n.get("text") is String and String(n.get("text")) != "": acc.append(String(n.get("text")))
	for k in n.get_children(): _texts(k, skip, acc)

func _px(main: Control, logical: Vector2) -> Vector2: return main.get_viewport().get_final_transform() * logical

func _touch(main: Control, idx: int, pos_px: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.position = pos_px; e.pressed = pressed
	Input.parse_input_event(e)
func _drag(idx: int, pos_px: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx; e.position = pos_px; e.relative = rel
	Input.parse_input_event(e)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(20)
	main._open_nations(fr)
	await _frames(16)
	var hd: TBPanel.Handle = main._nations_window()
	var card: Control = hd.card
	var list: ScrollContainer = null
	var all: Array = []; _scrollers(card, all)
	for sc in all:
		var s: ScrollContainer = sc
		var r := s.get_global_rect()
		if r.position.x < card.get_global_rect().position.x + card.size.x * 0.45 and s.get_v_scroll_bar().max_value > s.size.y + 60.0 and (list == null or r.size.y > list.size.y): list = s
	_check(list != null, "the Nations list is a scroll container with more rows than room")
	if list == null: quit(1); return
	print("  list ", list.get_path(), " rect ", list.get_global_rect(), " mode ", list.vertical_scroll_mode, " vis ", list.is_visible_in_tree(), " max ", list.get_v_scroll_bar().max_value, " page ", list.get_v_scroll_bar().page, " card ", card.get_global_rect())
	var before_texts: Array = []; _texts(card, list, before_texts)
	var start_l: Vector2 = list.get_global_rect().get_center()
	var p0: Vector2 = _px(main, start_l)
	_touch(main, 0, p0, true); await _frames(2)
	var pos := p0
	for i in 14:
		var rel := Vector2(0, -34.0)
		pos += rel
		_drag(0, pos, rel); await _frames(1)
	_touch(main, 0, pos, false); await _frames(6)
	var moved: float = list.scroll_vertical
	print("  list scrolled to ", moved, " of ", list.get_v_scroll_bar().max_value - list.size.y)
	_check(moved > 150.0, "a finger drag up scrolls the list (%.0f)" % moved)
	var after_texts: Array = []; _texts(card, list, after_texts)
	_check(before_texts == after_texts, "the row under the finger was not pressed (the detail card is unchanged)")
	# and back down
	p0 = _px(main, start_l); pos = p0
	_touch(main, 0, p0, true); await _frames(2)
	for i in 14:
		var rel2 := Vector2(0, 34.0)
		pos += rel2
		_drag(0, pos, rel2); await _frames(1)
	_touch(main, 0, pos, false); await _frames(6)
	_check(list.scroll_vertical < moved - 100.0, "a finger drag down scrolls back (%.0f)" % list.scroll_vertical)
	# a tap still presses a row
	var tap_l: Vector2 = list.get_global_rect().position + Vector2(list.size.x * 0.5, 120.0)
	var t_px := _px(main, tap_l)
	_touch(main, 0, t_px, true); await _frames(2); _touch(main, 0, t_px, false); await _frames(8)
	var tap_texts: Array = []; _texts(card, list, tap_texts)
	_check(tap_texts != after_texts, "a tap on a row still selects it")
	# the corner grip
	var grip: Control = null
	for rz in hd.resizers: if String((rz as Control).get_meta("side")) == "br": grip = rz
	_check(grip != null and grip.size.x >= 40.0, "the corner grip is big enough for a finger (%s units)" % str(grip.size if grip != null else Vector2.ZERO))
	if grip != null:
		var size0: Vector2 = card.size
		var gp: Vector2 = grip.get_global_rect().get_center()
		var g_px := _px(main, gp); var gpos := g_px
		_touch(main, 0, g_px, true); await _frames(2)
		for i in 8:
			var rel3 := Vector2(-22.0, -16.0)
			gpos += rel3; _drag(0, gpos, rel3); await _frames(1)
		_touch(main, 0, gpos, false); await _frames(8)
		_check(card.size.x < size0.x - 40.0 and card.size.y < size0.y - 30.0, "dragging the corner grip with a finger makes the window smaller (%s -> %s)" % [str(size0), str(card.size)])
	print("TOUCH_SCROLL OK" if fails == 0 else "TOUCH_SCROLL FAIL %d" % fails)
	quit(fails)
