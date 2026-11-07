## The Develop choice (rules 4, mock V2): a list of the projects a province can take and, for the chosen one, what it gives, what it costs, what it needs and a Start button.
## A project costs gold and a move, runs some turns and pays off at the end (TBInvest). Opens above the Develop verb; drag the title row, ✕ or Esc closes; 1-4 pick, Enter starts.
class_name TBDevelopModal
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

signal picked(cmd: Dictionary)
signal closed

const GLYPH := {1: "b_workshop", 2: "b_market", 3: "b_farm", 4: "b_armory"}

var _g: TBGame
var _p := -1
var _sel := 0
var _rows: Array = []                       # the list buttons
var _detail: VBoxContainer
var _env: Dictionary = {}
var _compact := false
var _narrow := false                        # a portrait screen: the list above the detail, the header on two rows
var _drag := false
var _drag_off := Vector2.ZERO
var _rule: Control
var _cans: Array = []

## one project in the list: emblem, name, one line (what it gives, or why it cannot), price and turns
class Row extends Button:
	var glyph := ""
	var name_t := ""
	var sub_t := ""
	var cost_t := ""
	var turns_t := ""
	var sel := false
	var ok_item := true
	var _hov := false
	func _init(h: float) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, h); size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_entered.connect(func(): _hov = true; queue_redraw())
		mouse_exited.connect(func(): _hov = false; queue_redraw())
	func _draw() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), TBTokens.BZ_BTN_FILL_HOT if (sel or _hov) else TBTokens.BZ_WELL)
		draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(w, h) - Vector2.ONE), TBTokens.BZ_WELL_LINE, false, 1.0)
		if sel: draw_rect(Rect2(0, 0, 3, h), TBTokens.BZ_HI)
		var d: float = h * 0.52
		var c := Vector2(20.0 + d * 0.5, h * 0.5)
		draw_circle(c, d * 0.5, TBTokens.BZ_FACE_B)
		draw_arc(c, d * 0.5 - 0.8, 0.0, TAU, 40, TBTokens.BZ_HI if (ok_item or sel) else TBTokens.BZ_LO, 1.6, true)
		TBBzIcons.draw(self, glyph, c, d * 0.5, TBTokens.BZ_HI if (ok_item or sel) else TBTokens.BZ_LO, 1.6)
		var x0: float = 20.0 + d + 16.0
		var rw: float = maxf(TBKit.body_b().get_string_size(cost_t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(TBKit.fsf(15.0))).x, TBKit.body().get_string_size(turns_t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(TBKit.fsf(12.0))).x)
		var dim: bool = not ok_item
		var up: String = name_t.to_upper() if (TBI18n.lang != "ru" and not TBKit.readable_fonts) else name_t
		var nm_c: Color = TBTokens.BZ_IVORY if not dim else TBTokens.BZ_DIM
		draw_string(TBKit.cinzel(700), Vector2(x0, h * 0.5 - 3.0), up, HORIZONTAL_ALIGNMENT_LEFT, w - x0 - rw - 40.0, int(TBKit.fsf(14.0)), nm_c)
		draw_string(TBKit.body(), Vector2(x0, h * 0.5 + 17.0), sub_t, HORIZONTAL_ALIGNMENT_LEFT, w - x0 - rw - 40.0, int(TBKit.fsf(13.5)), TBTokens.BZ_BAD_TXT if dim else TBTokens.BZ_DIM)
		draw_string(TBKit.body_b(), Vector2(w - 18.0 - rw, h * 0.5 - 3.0), cost_t, HORIZONTAL_ALIGNMENT_LEFT, rw + 2.0, int(TBKit.fsf(15.0)), TBTokens.BZ_IVORY if not dim else TBTokens.BZ_DIM)
		draw_string(TBKit.body(), Vector2(w - 18.0 - rw, h * 0.5 + 17.0), turns_t, HORIZONTAL_ALIGNMENT_LEFT, rw + 2.0, int(TBKit.fsf(12.0)), TBTokens.BZ_DIM)
		if has_focus() and TBFrame.kbd_nav: draw_rect(Rect2(Vector2(1.5, 1.5), Vector2(w, h) - Vector2(3, 3)), TBTokens.BZ_HI, false, 1.5)

func setup(g: TBGame, p: int, anchor: Rect2, vp: Vector2, env: Dictionary = {}) -> void:
	_g = g; _p = p; _env = env
	_compact = TBKit.is_phone(self) or vp.y < 820.0
	_narrow = vp.x < 700.0
	top_level = true; z_index = 60
	custom_minimum_size.x = minf(vp.x - 16.0, 600.0 if _compact else 790.0)
	add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true))
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 16 if _compact else 22)
	m.add_theme_constant_override("margin_top", 10 if _compact else 20); m.add_theme_constant_override("margin_bottom", 12 if _compact else 22)
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8 if _compact else 14)
	m.add_child(v)
	var hd := HBoxContainer.new()
	var cap := TBKit.caps(T.call("pj_title", {"p": TBI18n.place(g.pname(p))}), 14 if not _compact else 12); cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TBKit.wrappable(cap); hd.add_child(cap)
	var running: int = g.proj_kind[p]
	var st_txt: String = T.call("pj_none") if running == 0 else T.call("pj_running", {"k": T.call("pj_" + TBInvest.project_id(running)), "t": g.proj_left[p]})
	var st_l := TBKit.caps(st_txt, 12, TBTokens.BZ_HI if running != 0 else TBTokens.BZ_DIM)
	var gold_l := TBKit.caps(T.call("bp_gold_head", {"g": int(g.gold[g.human_id])}), 12, TBTokens.BZ_HI)
	var cb := TBBuildPicker.CloseBtn.new(30.0 if _compact else 34.0)
	TBKit.a11y(cb, String(T.call("close")), "button")
	cb.pressed.connect(func(): closed.emit(); queue_free())
	if _narrow:                                                           # title and cross on the first row, the project and the gold under them
		hd.add_child(cb); v.add_child(hd)
		var hd2 := HBoxContainer.new(); hd2.add_theme_constant_override("separation", 16)
		st_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; TBKit.wrappable(st_l)
		hd2.add_child(st_l); hd2.add_child(gold_l); v.add_child(hd2)
	else:
		hd.add_child(st_l)
		var sp := Control.new(); sp.custom_minimum_size = Vector2(14, 0); hd.add_child(sp)
		hd.add_child(gold_l)
		var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(16, 0); hd.add_child(sp2)
		hd.add_child(cb)
		v.add_child(hd)
	_rule = TBKit.header_rule(0)
	v.add_child(_rule)
	var stl: Label = K.label(T.call("pj_state", {"p": TBI18n.place(g.pname(p)), "pop": g.pop[p], "e": g.econ[p], "d": g.dev[p], "s": g.stab[p]}), 14 if _compact else 15, TBTokens.BZ_DIM)
	stl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stl.custom_minimum_size.x = 40; stl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(stl)
	var split := BoxContainer.new(); split.vertical = _narrow; split.add_theme_constant_override("separation", 14 if _narrow else (22 if _compact else 34))
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(split)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 7); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.size_flags_stretch_ratio = 1.0
	split.add_child(list)
	var n: int = g.human_id
	for k in range(1, TBInvest.PROJECTS.size() + 1):
		var cn: Dictionary = g.can({"cmd": "develop", "p": p, "k": k})
		_cans.append(cn)
		var r := Row.new(56.0 if (_compact or _narrow) else 80.0)
		r.glyph = GLYPH[k]; r.name_t = String(T.call("pj_" + TBInvest.project_id(k))); r.ok_item = bool(cn["ok"])
		r.sub_t = _effect(k, true) if bool(cn["ok"]) else _why(cn)
		r.cost_t = str(int(cn["gold"])); r.turns_t = CC.unit(int(cn.get("turns", TBInvest.project_turns(g, p, k))), "u_turn")
		var idx := k - 1
		r.pressed.connect(func(): _pick(idx))
		TBKit.a11y(r, r.name_t, "button")
		list.add_child(r); _rows.append(r)
	_detail = VBoxContainer.new(); _detail.add_theme_constant_override("separation", 10 if _compact else 14)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _detail.size_flags_stretch_ratio = 1.1
	split.add_child(_detail)
	var first := 0
	for i in _cans.size(): if bool(_cans[i]["ok"]): first = i; break
	_pick(first)
	_place(anchor)
	_place.bind(anchor).call_deferred()

func _why(cn: Dictionary) -> String:
	var key := "err_" + String(cn.get("reason", ""))
	return String(T.call(key)) if TBI18n.has_key(key) else String(cn.get("reason", ""))

## the line of what a project gives (first clause only for the list)
func _effect(k: int, short: bool) -> String:
	var gain: Dictionary = TBInvest.project_gain(_g, _p, k)
	var s := ""
	match k:
		1: s = T.call("pj_dev_fx", {"a": _g.dev[_p], "b": mini(5, _g.dev[_p] + 1)})
		2: s = T.call("pj_econ_fx", {"a": _g.econ[_p], "b": mini(5, _g.econ[_p] + 1)}) if int(gain.get("econ", 0)) > 0 else T.call("pj_econ_half")
		3: s = T.call("pj_settle_fx", {"n": int(gain.get("pop", 0))})
		4: s = T.call("pj_order_fx", {"n": int(gain.get("stab", 0))})
	return s.split(" · ")[0] if short else s

func _pick(i: int) -> void:
	_sel = clampi(i, 0, _cans.size() - 1)
	for j in _rows.size(): (_rows[j] as Row).sel = j == _sel; (_rows[j] as Row).queue_redraw()
	for c in _detail.get_children(): _detail.remove_child(c); c.queue_free()
	var k: int = _sel + 1
	var cn: Dictionary = _cans[_sel]
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 16)
	top.add_child(TBBuildPicker.Emblem.new(GLYPH[k], 56.0 if _compact else 76.0))
	var title: Label = TBKit.title(T.call("pj_" + TBInvest.project_id(k)), 18 if _compact else 22, TBTokens.c("ink_0"))
	TBKit.wrappable(title); title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	_detail.add_child(top)
	var fx := K.para_bz("[i]%s[/i]" % _effect(k, false), 15.0 if _compact else 16.0, 1.3)
	_detail.add_child(fx)
	var chips := HBoxContainer.new(); chips.add_theme_constant_override("separation", 10)
	var h: float = 50.0 if _compact else 62.0
	chips.add_child(TBBuildPicker.Chip.new(str(int(cn["gold"])), String(T.call("gold")), int(_g.gold[_g.human_id]) < int(cn["gold"]), h))
	chips.add_child(TBBuildPicker.Chip.new(str(int(cn.get("turns", 0))), String(T.call("bp_time")), false, h))
	chips.add_child(TBBuildPicker.Chip.new(str(int(cn["moves"])), String(T.call("bp_moves")), int(_g.mp[_g.human_id]) < int(cn["moves"]), h))
	_detail.add_child(chips)
	var cap := TBKit.caps(T.call("pj_needs"), 11, TBTokens.BZ_HI)
	_detail.add_child(cap)
	var needs: Array = cn.get("needs", [])
	for nd in needs:
		if _compact and bool(nd[0]): continue
		var crow := HBoxContainer.new(); crow.add_theme_constant_override("separation", 8)
		var ok: bool = bool(nd[0])
		var ic := Control.new(); ic.custom_minimum_size = Vector2(18, 20); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): TBBzIcons.draw(ic, "check" if ok else "close", Vector2(9, 10), 16.0, TBTokens.BZ_GOOD if ok else TBTokens.BZ_BAD_TXT, 2.0))
		crow.add_child(ic)
		var tl: Label = K.label(String(T.call(String(nd[1]), nd[2])), 14 if _compact else 15, TBTokens.BZ_DIM if ok else TBTokens.BZ_BAD_TXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.custom_minimum_size.x = 40
		crow.add_child(tl)
		_detail.add_child(crow)
	var go: Button = K.button(String(T.call("pj_start", {"g": int(cn["gold"])})) if bool(cn["ok"]) else String(T.call("pj_not")), func(): _do(), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not bool(cn["ok"]): K.disable(go, "")
	var gm := MarginContainer.new(); gm.add_theme_constant_override("margin_top", 6); gm.add_child(go)
	_detail.add_child(gm)
	_fit_later()

var _max_h := 0.0
func _fit_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree(): return
	_detail.custom_minimum_size.y = 0.0
	_max_h = maxf(_max_h, _detail.get_combined_minimum_size().y)
	_detail.custom_minimum_size.y = _max_h
	var top_y: float = position.y
	reset_size(); size = get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
	position.y = clampf(top_y, bounds.position.y + 8.0, maxf(bounds.position.y + 8.0, bounds.end.y - size.y - 8.0))
	position.x = clampf(position.x, bounds.position.x + 8.0, maxf(bounds.position.x + 8.0, bounds.end.x - size.x - 8.0))

func _place(anchor: Rect2) -> void:
	if not is_inside_tree(): return
	reset_size(); size = get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
	var keep: Array = _env.get("keep", [])
	var lo := bounds.position + Vector2(8.0, 8.0)
	var hi := bounds.end - size - Vector2(8.0, 8.0)
	var y: float = clampf(anchor.get_center().y - size.y * 0.5 if anchor.size.x > 0.0 else lo.y, lo.y, maxf(lo.y, hi.y))
	var chosen := Vector2.INF
	if anchor.size.x > 0.0:
		for sx in [anchor.end.x + 12.0, anchor.position.x - size.x - 12.0]:
			var r := Rect2(Vector2(sx, y), size)
			if r.position.x < lo.x or r.end.x > bounds.end.x - 8.0: continue
			var blocked := false
			for k in keep:
				if (k as Rect2).intersects(r):
					var up: float = (k as Rect2).position.y - size.y - 6.0
					if up >= lo.y and not (k as Rect2).intersects(Rect2(Vector2(r.position.x, up), size)): r.position.y = up
					else: blocked = true; break
			if not blocked: chosen = r.position; break
	if chosen == Vector2.INF: chosen = Vector2(clampf(anchor.end.x + 12.0 if anchor.size.x > 0.0 else lo.x, lo.x, maxf(lo.x, hi.x)), y)
	position = chosen.floor()

func _head_bottom() -> float:
	return (_rule.global_position.y + _rule.size.y - global_position.y) + 6.0 if _rule != null else 56.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and e.position.y <= _head_bottom(): _drag = true; _drag_off = e.global_position - position; accept_event()
		elif not e.pressed: _drag = false
	elif e is InputEventMouseMotion:
		if _drag:
			var vp: Vector2 = get_viewport_rect().size
			var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
			var np: Vector2 = e.global_position - _drag_off
			position = Vector2(clampf(np.x, bounds.position.x + 4.0, maxf(bounds.position.x + 4.0, bounds.end.x - size.x - 4.0)), clampf(np.y, bounds.position.y + 4.0, maxf(bounds.position.y + 4.0, bounds.end.y - size.y - 4.0)))
			accept_event()
		else: mouse_default_cursor_shape = Control.CURSOR_DRAG if e.position.y <= _head_bottom() else Control.CURSOR_ARROW

func _do() -> void:
	var cn: Dictionary = _cans[_sel]
	if not bool(cn["ok"]): return
	picked.emit({"cmd": "develop", "p": _p, "k": _sel + 1})
	closed.emit(); queue_free()

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventMouseButton and e.pressed:
		if not get_global_rect().has_point(e.position): closed.emit(); queue_free()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE: closed.emit(); queue_free(); get_viewport().set_input_as_handled()
		elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER: _do(); get_viewport().set_input_as_handled()
		elif e.keycode >= KEY_1 and e.keycode <= KEY_4: _pick(e.keycode - KEY_1); get_viewport().set_input_as_handled()
