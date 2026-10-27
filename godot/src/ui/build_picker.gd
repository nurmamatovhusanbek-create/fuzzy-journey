## The Build picker ("Blueprint"): a narrow rail of the buildings the district can take, and one page for the chosen one: its emblem, what it does, its level, the
## figures, what is still missing, and one Build button. Opens above the Build verb like the other lists; 1-9 pick a building, Enter builds, Esc closes.
class_name TBBuildPicker
extends PanelContainer

const D = preload("res://src/engine/data.gd")
const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

signal picked(cmd: Dictionary)
signal closed

var _g: TBGame
var _p := -1
var _items: Array = []                       # {b (1-based building index), can, label, turns, gold}
var _sel := 0
var _rail_btns: Array = []
var _detail: VBoxContainer

## one building on the rail: a notched plate with its emblem and a pip per level (the level this build would reach is lit)
class RailBtn extends Button:
	var glyph := ""
	var sel := false
	var ok_item := true
	var levels := 1
	var lit := 1
	var _hov := false
	func _init() -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(62, 52)
		mouse_entered.connect(func(): _hov = true; queue_redraw())
		mouse_exited.connect(func(): _hov = false; queue_redraw())
	func _draw() -> void:
		var ci := get_canvas_item()
		var w := size.x; var h := size.y
		TBBz.poly(ci, TBBz.notch(0, 0, w, h, 5.0), TBTokens.BZ_BTN_FILL_HOT if (sel or _hov) else TBTokens.BZ_WELL)
		var edge: Color = TBTokens.BZ_HI if sel else (TBTokens.c("brass") if _hov else TBTokens.BZ_WELL_LINE)
		var o := TBBz.notch(0.5, 0.5, w - 0.5, h - 0.5, 5.0); o.append(o[0])
		draw_polyline(o, edge, 1.5 if sel else 1.0, true)
		var ink: Color = TBTokens.BZ_HI if (ok_item or sel) else TBTokens.c("ink_off")
		TBBzIcons.draw(self, glyph, Vector2(w * 0.5, h * 0.5 - 4.0), 22.0, ink)
		var pw := 6.0; var gap := 2.0
		var x0: float = w * 0.5 - (float(levels) * pw + float(levels - 1) * gap) * 0.5
		for i in levels:
			draw_rect(Rect2(x0 + float(i) * (pw + gap), h - 7.0, pw, 2.0), TBTokens.BZ_HI if i < lit else TBTokens.BZ_TRACK_LINE)
		if has_focus() and TBFrame.kbd_nav: TBBz.draw_notch_focus_at(ci, Rect2(0, 0, w, h), 5.0)

## the chosen building's emblem: a face, a brass ring, the glyph
class Emblem extends Control:
	var glyph := ""
	func _init(gl: String) -> void:
		glyph = gl; custom_minimum_size = Vector2(76, 76); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 38.0, TBTokens.BZ_SHADOW)
		draw_circle(c, 35.0, TBTokens.BZ_FACE_B)
		draw_arc(c, 35.0, 0.0, TAU, 56, TBTokens.with_a(TBTokens.c("brass"), 0.9), 1.4, true)
		draw_arc(c, 31.0, 0.0, TAU, 56, TBTokens.with_a(TBTokens.c("brass"), 0.25), 1.0, true)
		TBBzIcons.draw(self, glyph, c, 34.0, TBTokens.BZ_HI, 1.6)

## level pips under the name: lit up to the level this build reaches
class Pips extends Control:
	var n := 1
	var lit := 1
	func _init(count: int, on: int) -> void:
		n = count; lit = on; custom_minimum_size = Vector2(float(count) * 27.0, 8.0); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	func _draw() -> void:
		for i in n:
			var x := float(i) * 27.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2.0, 1.0), Vector2(x + 22.0, 1.0), Vector2(x + 20.0, 7.0), Vector2(x, 7.0)]), TBTokens.BZ_HI if i < lit else TBTokens.BZ_TRACK_LINE)

static func glyph_of(id: String) -> String: return "b_" + id

func setup(g: TBGame, p: int, items: Array, anchor: Rect2, vp: Vector2) -> void:
	_g = g; _p = p; _items = items
	top_level = true; z_index = 60
	custom_minimum_size.x = 410.0                                 # the rail (62) + the page (300) + the margins: the figures below must not wrap
	add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true))
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 16); m.add_theme_constant_override("margin_bottom", 18)
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var hd := HBoxContainer.new()
	var cap := TBKit.caps(T.call("build")); cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hd.add_child(cap)
	if g.rules >= 2:
		var sl := TBKit.caps(T.call("bp_slots", {"u": g.b_used(p), "s": g.b_slots(p)}), 12, TBTokens.BZ_DIM); sl.size_flags_horizontal = Control.SIZE_SHRINK_END; hd.add_child(sl)
		var sp := Control.new(); sp.custom_minimum_size = Vector2(14, 0); hd.add_child(sp)
	var gl := TBKit.caps(T.call("bp_gold_head", {"g": int(g.gold[g.human_id])}), 12, TBTokens.BZ_HI); hd.add_child(gl)
	v.add_child(hd)
	v.add_child(TBKit.header_rule(0))
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 12)
	v.add_child(split)
	var rail := VBoxContainer.new(); rail.add_theme_constant_override("separation", 7); split.add_child(rail)
	for i in items.size():
		var it: Dictionary = items[i]
		var bd: Dictionary = D.BUILDINGS[int(it["b"]) - 1]
		var rb := RailBtn.new()
		rb.glyph = glyph_of(String(bd["id"])); rb.ok_item = bool(it["can"]["ok"]); rb.levels = int(bd["maxLevel"]); rb.lit = int(it["can"].get("levels", 1))
		TBKit.a11y(rb, String(it["label"]).strip_edges(), "button")
		var idx := i
		rb.pressed.connect(func(): _pick(idx))
		rail.add_child(rb); _rail_btns.append(rb)
	_detail = VBoxContainer.new(); _detail.add_theme_constant_override("separation", 10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _detail.custom_minimum_size = Vector2(300, 0)
	split.add_child(_detail)
	var first := 0
	for i in items.size():
		if bool(items[i]["can"]["ok"]): first = i; break
	_pick(first)
	reset_size()
	var sz := get_combined_minimum_size()
	size = sz
	position = Vector2(clampf(anchor.position.x + anchor.size.x * 0.5 - sz.x * 0.5, 6.0, maxf(6.0, vp.x - sz.x - 6.0)), clampf(anchor.position.y - sz.y - 6.0, 6.0, maxf(6.0, vp.y - sz.y - 6.0)))

func _pick(i: int) -> void:
	_sel = clampi(i, 0, _items.size() - 1)
	for j in _rail_btns.size(): (_rail_btns[j] as RailBtn).sel = j == _sel; (_rail_btns[j] as RailBtn).queue_redraw()
	for c in _detail.get_children(): c.queue_free()
	var it: Dictionary = _items[_sel]
	var cn: Dictionary = it["can"]
	var bd: Dictionary = D.BUILDINGS[int(it["b"]) - 1]
	var id: String = String(bd["id"])
	var lvl: int = int(cn.get("levels", 1))
	var me: int = _g.human_id
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12)
	top.add_child(Emblem.new(glyph_of(id)))
	var nm := VBoxContainer.new(); nm.add_theme_constant_override("separation", 7); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title: Label = TBKit.title(T.call("b_" + id), 16, TBTokens.c("ink_0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.custom_minimum_size.x = 40
	nm.add_child(title)
	nm.add_child(Pips.new(int(bd["maxLevel"]), lvl))
	top.add_child(nm)
	_detail.add_child(top)
	var ek: String = "bd_" + id
	if TBI18n.has_key(ek): _detail.add_child(K.para_bz("[i]%s[/i]" % T.call(ek), 16.0, 1.3))
	var gold: int = int(cn["gold"]); var moves: int = int(cn["moves"]); var turns: int = int(it["turns"])
	var after: int = int(_g.gold[me]) - gold
	var rows: Array = [[T.call("bp_cost"), "%d %s" % [gold, T.call("gold").to_lower()], 0], [T.call("bp_time"), CC.unit(turns, "u_turn"), 0], [T.call("bp_moves"), str(moves), 0],
		[T.call("bp_after"), "%d %s" % [after, T.call("gold").to_lower()], -1 if after < 0 else 0]]
	_detail.add_child(K.fxl(rows, 0))
	var need: float = float(bd["tech"][clampi(lvl - 1, 0, (bd["tech"] as Array).size() - 1)])
	var cur_lv: int = _g.bl(_p, int(it["b"]))
	var slot_row: Array = [true, T.call("bp_slot")]
	if _g.rules >= 2:
		if cur_lv > 0: slot_row = [true, T.call("bp_slot_up")]
		elif _g.b_used(_p) < _g.b_slots(_p): slot_row = [true, T.call("bp_slot_n", {"u": _g.b_used(_p), "s": _g.b_slots(_p)})]
		else: slot_row = [false, T.call("err_slots")]
	var checks: Array = [slot_row,
		[_g.tech_level[me] >= need, T.call("bp_tech_y" if _g.tech_level[me] >= need else "bp_tech_n", {"t": "%.1f" % need})],
		[int(_g.gold[me]) >= gold, T.call("bp_gold_y" if int(_g.gold[me]) >= gold else "bp_gold_n", {"g": gold})],
		[int(_g.mp[me]) >= moves, T.call("bp_mp_y" if int(_g.mp[me]) >= moves else "bp_mp_n", {"m": moves})]]
	for c in checks:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 7)
		var ok: bool = bool(c[0])
		var ic := Control.new(); ic.custom_minimum_size = Vector2(18, 20); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): TBBzIcons.draw(ic, "check" if ok else "close", Vector2(9, 10), 16.0, TBTokens.BZ_GOOD if ok else TBTokens.BZ_BAD_TXT, 2.0))
		row.add_child(ic)
		var tl: Label = K.label(String(c[1]), 15, TBTokens.BZ_DIM if ok else TBTokens.BZ_BAD_TXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.custom_minimum_size.x = 40
		row.add_child(tl)
		_detail.add_child(row)
	var can_ok: bool = bool(cn["ok"])
	var go: Button = K.button(T.call("bp_build_for", {"g": gold}), func(): _do(), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not can_ok: K.disable(go, "")
	_detail.add_child(go)
	if _g.rules >= 2 and cur_lv > 0:
		var dm: Button = K.button(T.call("bp_demolish"), func(): _demolish(), false, true)
		dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.add_child(dm)
	reset_size(); size = get_combined_minimum_size()

func _do() -> void:
	var it: Dictionary = _items[_sel]
	if not bool(it["can"]["ok"]): return
	picked.emit({"cmd": "build", "p": _p, "b": it["b"]})
	closed.emit(); queue_free()

func _demolish() -> void:
	var it: Dictionary = _items[_sel]
	if _g.bl(_p, int(it["b"])) == 0: return
	picked.emit({"cmd": "demolish", "p": _p, "b": it["b"]})
	closed.emit(); queue_free()

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventMouseButton and e.pressed:
		if not get_global_rect().has_point(e.position):
			closed.emit(); queue_free()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			closed.emit(); queue_free(); get_viewport().set_input_as_handled()
		elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			_do(); get_viewport().set_input_as_handled()
		elif e.keycode >= KEY_1 and e.keycode <= KEY_9 and e.keycode - KEY_1 < _items.size():
			_pick(e.keycode - KEY_1); get_viewport().set_input_as_handled()
