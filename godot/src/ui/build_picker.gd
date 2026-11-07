## The Build picker ("Showcase"): a row of the buildings the district can take, each a disc with its state under it (level, building, or the price), and one page for the
## chosen one: its emblem, level pips, what it does, gold / time / moves chips, every level with its effect and price, what is still missing, and the Build / Demolish buttons.
## Opens above the Build verb like the other lists; 1-9 pick a building, Enter builds, Esc closes. The page never shrinks (the ladder always has room for five levels).
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
var _rail_btns: Array = []                   # the discs
var _detail: VBoxContainer
var _rule: Control                           # the rule under the title row: the window is dragged by everything above it
var _drag := false
var _drag_off := Vector2.ZERO
var _compact := false                        # a phone in landscape (short screen): smaller discs and rows
var _narrow := false                         # a portrait screen: two rows of discs, the page stacked

const MAX_LEVELS := 5

## text centred on a point (both ways), whatever the font
static func ctext(ci: CanvasItem, text: String, c: Vector2, font: Font, sz: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	ci.draw_string(font, Vector2(c.x - w * 0.5, c.y + (font.get_ascent(sz) - font.get_descent(sz)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

## one building in the row: a disc (brass ring; lit when chosen; a thick ring when built; a halo while it is being built), its name (two lines when it must) and its state
class DiscBtn extends Button:
	var glyph := ""
	var name_t := ""
	var state_t := ""
	var state_col := Color.WHITE
	var sel := false
	var ok_item := true
	var built := false
	var busy := false
	var dia := 56.0
	var _hov := false
	func _init(w: float, d: float, h: float) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dia = d; custom_minimum_size = Vector2(w, h); size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_entered.connect(func(): _hov = true; queue_redraw())
		mouse_exited.connect(func(): _hov = false; queue_redraw())
	func _draw() -> void:
		var w := size.x
		var c := Vector2(w * 0.5, 5.0 + dia * 0.5)
		var brass: Color = TBTokens.c("brass")
		draw_circle(c, dia * 0.5 + 1.0, TBTokens.BZ_SHADOW)
		draw_circle(c, dia * 0.5, TBTokens.BZ_FACE_B)
		var ring: Color = TBTokens.BZ_HI if (sel or built or busy) else (brass if (ok_item or _hov) else TBTokens.BZ_LO)
		draw_arc(c, dia * 0.5 - 0.8, 0.0, TAU, 64, ring, 2.5 if sel else (2.0 if built else 1.4), true)
		if sel or busy: draw_arc(c, dia * 0.5 + 3.5, 0.0, TAU, 64, TBTokens.with_a(brass, 0.34 if sel else 0.2), 2.0, true)
		if _hov and not sel: draw_circle(c, dia * 0.5 - 2.0, TBTokens.with_a(brass, 0.08))
		TBBzIcons.draw(self, glyph, c, dia * 0.46, TBTokens.BZ_HI if (ok_item or sel or built) else TBTokens.BZ_LO, 1.6)
		var f: Font = TBKit.cinzel(700)
		var sz: int = int(TBKit.fsf(9.5 if dia < 48.0 else 10.5))
		var up: String = name_t.to_upper() if (TBI18n.lang != "ru" and not TBKit.readable_fonts) else name_t
		var lines: Array = [up]
		if f.get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w - 2.0 and up.contains(" "):
			var cut: int = up.find(" ", up.length() / 2 - 2)
			if cut < 0: cut = up.rfind(" ")
			lines = [up.substr(0, cut), up.substr(cut + 1)]
		var widest: float = 0.0
		for ln in lines: widest = maxf(widest, f.get_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		while widest > w - 2.0 and sz > 7:                      # a long word (Uzbek, Russian) shrinks to its disc instead of running into the next one
			sz -= 1; widest = 0.0
			for ln in lines: widest = maxf(widest, f.get_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		var nom: float = float(int(TBKit.fsf(9.5 if dia < 48.0 else 10.5))) + 3.0
		var y0: float = 5.0 + dia + (6.0 if dia < 48.0 else 10.0) + nom * 0.5
		var tone: Color = TBTokens.BZ_IVORY if sel else TBTokens.BZ_DIM
		for i in lines.size(): TBBuildPicker.ctext(self, String(lines[i]), Vector2(w * 0.5, y0 + float(i) * nom), f, sz, tone)
		var ssz: int = int(TBKit.fsf(11.0 if dia < 48.0 else 11.5))
		TBBuildPicker.ctext(self, state_t, Vector2(w * 0.5, y0 + nom * 2.0 + 3.0), TBKit.body_b(), ssz, state_col)
		if has_focus() and TBFrame.kbd_nav: draw_arc(c, dia * 0.5 + 6.0, 0.0, TAU, 64, TBTokens.BZ_HI, 1.5, true)

## the window's close button: a ringed cross at the right of the title row
class CloseBtn extends Button:
	var _hov := false
	func _init(sz: float) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(sz, sz); size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_entered.connect(func(): _hov = true; queue_redraw())
		mouse_exited.connect(func(): _hov = false; queue_redraw())
	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 1.0
		if _hov: draw_circle(c, r, TBTokens.BZ_BTN_FILL_HOT)
		draw_arc(c, r, 0.0, TAU, 40, TBTokens.BZ_HI if _hov else TBTokens.BZ_LO, 1.4, true)
		TBBzIcons.draw(self, "close", c, r * 0.95, TBTokens.BZ_HI if _hov else TBTokens.BZ_DIM, 1.8)
		if has_focus() and TBFrame.kbd_nav: draw_arc(c, r + 3.0, 0.0, TAU, 40, TBTokens.BZ_HI, 1.5, true)

## the chosen building's emblem: a face, a brass ring, the glyph
class Emblem extends Control:
	var glyph := ""
	var d := 76.0
	func _init(gl: String, dia: float = 76.0) -> void:
		glyph = gl; d = dia; custom_minimum_size = Vector2(dia, dia); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		var r: float = d * 0.5
		draw_circle(c, r, TBTokens.BZ_SHADOW)
		draw_circle(c, r - 3.0, TBTokens.BZ_FACE_B)
		draw_arc(c, r - 3.0, 0.0, TAU, 56, TBTokens.with_a(TBTokens.c("brass"), 0.9), 1.4, true)
		draw_arc(c, r - 7.0, 0.0, TAU, 56, TBTokens.with_a(TBTokens.c("brass"), 0.25), 1.0, true)
		TBBzIcons.draw(self, glyph, c, d * 0.45, TBTokens.BZ_HI, 1.6)

## level pips under the name: filled up to the level now built
class Pips extends Control:
	var n := 1
	var lit := 0
	func _init(count: int, on: int) -> void:
		n = count; lit = on; custom_minimum_size = Vector2(float(count) * 27.0, 8.0); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	func _draw() -> void:
		for i in n:
			var x := float(i) * 27.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2.0, 1.0), Vector2(x + 22.0, 1.0), Vector2(x + 20.0, 7.0), Vector2(x, 7.0)]), TBTokens.BZ_HI if i < lit else TBTokens.BZ_TRACK_LINE)

## the round number of a level: filled when built, ringed bright when it is the next, dim otherwise
class NumDot extends Control:
	var num := 1
	var kind := 0                                   # 0 later, 1 built, 2 next
	func _init(n: int, k: int, d: float) -> void:
		num = n; kind = k; custom_minimum_size = Vector2(d, d); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		if kind == 1:
			draw_circle(c, r, TBTokens.BZ_HI)
			TBBzIcons.draw(self, "check", c, r * 1.25, TBTokens.BZ_FACE_B, 2.2)
			return
		draw_arc(c, r - 0.8, 0.0, TAU, 40, TBTokens.BZ_HI if kind == 2 else TBTokens.BZ_TRACK_LINE, 1.6, true)
		TBBuildPicker.ctext(self, str(num), c, TBKit.body_b(), int(TBKit.fsf(13.0)), TBTokens.BZ_HI if kind == 2 else TBTokens.BZ_DIM)

## gold / time / moves: a figure over its caption, centred
class Chip extends Control:
	var fig := ""
	var cap := ""
	var bad := false
	func _init(f: String, c: String, is_bad: bool, h: float) -> void:
		fig = f; cap = c; bad = is_bad; custom_minimum_size = Vector2(60, h); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TBTokens.BZ_WELL)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), TBTokens.BZ_WELL_LINE, false, 1.0)
		var cx: float = size.x * 0.5
		TBBuildPicker.ctext(self, fig, Vector2(cx, size.y * 0.38), TBKit.body_b(), int(TBKit.fsf(18.0)), TBTokens.BZ_BAD_TXT if bad else TBTokens.BZ_IVORY)
		var up: String = cap.to_upper() if (TBI18n.lang != "ru" and not TBKit.readable_fonts) else cap
		TBBuildPicker.ctext(self, up, Vector2(cx, size.y * 0.76), TBKit.cinzel(700), int(TBKit.fsf(9.5)), TBTokens.BZ_DIM)

static func glyph_of(id: String) -> String: return "b_" + id

## what one level of a building does, in figures: the per-level text (bl_<id>) with the level's amount
static func level_fx(id: String, lvl: int) -> String:
	var n: int = lvl
	match id:
		"farm", "workshop": n = 5 * lvl
		"fortress": n = 50 if lvl <= 1 else 80
	var k := "bl_" + id
	return String(T.call(k, {"n": n})) if TBI18n.has_key(k) else String(T.call("bd_" + id))

var _anchor := Rect2()
var _env: Dictionary = {}

func setup(g: TBGame, p: int, items: Array, anchor: Rect2, vp: Vector2, env: Dictionary = {}) -> void:
	_g = g; _p = p; _items = items; _anchor = anchor; _env = env
	_compact = TBKit.is_phone(self) or vp.y < 820.0          # a small stage (a phone, a small window): the picker must fit between the HUD parts
	_narrow = vp.x < 700.0
	top_level = true; z_index = 60
	custom_minimum_size.x = minf(vp.x - 16.0, 600.0 if _narrow else (640.0 if _compact else 790.0))
	add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true))
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 14 if _compact else 20)
	m.add_theme_constant_override("margin_top", 8 if _compact else 18); m.add_theme_constant_override("margin_bottom", 8 if _compact else 20)
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4 if _compact else 10)
	m.add_child(v)
	var hd := HBoxContainer.new()
	var cap := TBKit.caps(T.call("build"), 14 if not _compact else 12); cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hd.add_child(cap)
	if g.rules >= 2:
		var sl := TBKit.caps(T.call("bp_slots", {"u": g.b_used(p), "s": g.b_slots(p)}), 12, TBTokens.BZ_DIM); sl.size_flags_horizontal = Control.SIZE_SHRINK_END; hd.add_child(sl)
		var sp := Control.new(); sp.custom_minimum_size = Vector2(14, 0); hd.add_child(sp)
	var gl := TBKit.caps(T.call("bp_gold_head", {"g": int(g.gold[g.human_id])}), 12, TBTokens.BZ_HI); hd.add_child(gl)
	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(16, 0); hd.add_child(sp2)
	var cb := CloseBtn.new(30.0 if _compact else 34.0)
	TBKit.a11y(cb, String(T.call("close")), "button")
	cb.pressed.connect(func(): closed.emit(); queue_free())
	hd.add_child(cb)
	v.add_child(hd)
	_rule = TBKit.header_rule(0)
	v.add_child(_rule)
	var row := GridContainer.new(); row.columns = 5 if _narrow else maxi(1, items.size())
	row.add_theme_constant_override("h_separation", 2); row.add_theme_constant_override("v_separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var dia: float = 34.0 if _compact else 56.0
	var dh: float = 5.0 + dia + (6.0 if _compact else 10.0) + (float(int(TBKit.fsf(9.5 if _compact else 10.5))) + 3.0) * 2.0 + 3.0 + 12.0
	for i in items.size():
		var it: Dictionary = items[i]
		var bd: Dictionary = D.BUILDINGS[int(it["b"]) - 1]
		var id: String = String(bd["id"])
		var cur: int = g.bl(p, int(it["b"]))
		var db := DiscBtn.new(60.0 if _compact else 80.0, dia, dh)
		db.glyph = glyph_of(id); db.name_t = String(T.call("b_" + id)); db.ok_item = bool(it["can"]["ok"]) or cur > 0
		db.built = cur > 0; db.busy = int(g.b_building[p]) == int(it["b"])
		if db.busy:
			db.state_t = String(T.call("bp_busy")); db.state_col = TBTokens.BZ_HI
		elif cur > 0:
			db.state_t = String(T.call("bp_lvl_of", {"a": cur, "b": int(bd["maxLevel"])})) if int(bd["maxLevel"]) > 1 else String(T.call("bp_built_here")); db.state_col = TBTokens.BZ_GOOD
		else:
			db.state_t = "%d %s" % [int(it["can"]["gold"]), String(T.call("gold")).to_lower()]; db.state_col = TBTokens.BZ_DIM if db.ok_item else TBTokens.BZ_LO
		TBKit.a11y(db, String(it["label"]).strip_edges(), "button")
		var idx := i
		db.pressed.connect(func(): _pick(idx))
		row.add_child(db); _rail_btns.append(db)
	var sep := ColorRect.new(); sep.color = TBTokens.BZ_WELL_LINE; sep.custom_minimum_size = Vector2(0, 1); sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	_detail = VBoxContainer.new(); _detail.add_theme_constant_override("separation", 6 if _compact else 16)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_detail)
	var first := 0
	for i in items.size():
		if bool(items[i]["can"]["ok"]): first = i; break
	_pick(first)
	_place()
	_place.call_deferred()                                      # once the page has laid out (wrapped text changes the height)

func _ladder_row(id: String, k: int, kind: int, bd: Dictionary, row_h: float) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = TBTokens.BZ_BTN_FILL if kind == 2 else TBTokens.BZ_WELL
	sb.border_color = TBTokens.BZ_HI if kind == 2 else (TBTokens.BZ_LO if kind == 1 else TBTokens.BZ_WELL_LINE)
	sb.set_border_width_all(2 if kind == 2 else 1)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(0, row_h)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12); mc.add_theme_constant_override("margin_right", 14); mc.add_theme_constant_override("margin_top", 2 if _compact else 3); mc.add_theme_constant_override("margin_bottom", 2 if _compact else 3)
	pc.add_child(mc)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); h.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(h)
	h.add_child(NumDot.new(k, kind, 20.0 if _compact else 28.0))
	var tl: Label = K.label(level_fx(id, k), 13 if _compact else 15, TBTokens.BZ_IVORY if kind != 0 else TBTokens.BZ_DIM)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tl.custom_minimum_size.x = 40
	h.add_child(tl)
	var right := VBoxContainer.new(); right.add_theme_constant_override("separation", 1 if _compact else 3); right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind == 1:
		var bt: Label = K.label(String(T.call("bp_built_lv")), 14, TBTokens.BZ_GOOD); bt.add_theme_font_override("font", TBKit.body_b()); bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(bt)
	else:
		var gold_t: String = "%d %s" % [int(bd["cost"][k - 1]), String(T.call("gold")).to_lower()]
		var turn_t: String = CC.unit(int(bd["buildTime"][k - 1]), "u_turn")
		if _compact:                                            # one line: a short screen has no room for two
			var one: Label = K.label("%s · %s" % [gold_t, turn_t], 12, TBTokens.BZ_IVORY); one.add_theme_font_override("font", TBKit.body_b()); one.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right.add_child(one)
		else:
			var pr: Label = K.label(gold_t, 14, TBTokens.BZ_IVORY); pr.add_theme_font_override("font", TBKit.body_b()); pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right.add_child(pr)
			var tt: Label = K.label(turn_t, 12, TBTokens.BZ_DIM); tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right.add_child(tt)
	h.add_child(right)
	return pc

func _pick(i: int) -> void:
	_sel = clampi(i, 0, _items.size() - 1)
	for j in _rail_btns.size(): (_rail_btns[j] as DiscBtn).sel = j == _sel; (_rail_btns[j] as DiscBtn).queue_redraw()
	for c in _detail.get_children(): _detail.remove_child(c); c.queue_free()           # at once: the new page is measured without the old one
	var it: Dictionary = _items[_sel]
	var cn: Dictionary = it["can"]
	var bd: Dictionary = D.BUILDINGS[int(it["b"]) - 1]
	var id: String = String(bd["id"])
	var maxl: int = int(bd["maxLevel"])
	var cur_lv: int = _g.bl(_p, int(it["b"]))
	var lvl: int = int(cn.get("levels", cur_lv + 1))          # the level this build reaches
	var me: int = _g.human_id
	var maxed: bool = bool(it.get("maxed", false))
	var gold: int = int(cn["gold"]); var moves: int = int(cn["moves"]); var turns: int = int(it["turns"])
	var busy_here: bool = int(_g.b_building[_p]) == int(it["b"])
	# ---- the page: the building on the left, its levels on the right
	var page := BoxContainer.new(); page.vertical = _narrow; page.add_theme_constant_override("separation", 14 if _narrow else (20 if _compact else 28))
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(page)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 10 if _compact else 14)
	left.custom_minimum_size.x = 0.0 if _narrow else (230.0 if _compact else 290.0); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow else Control.SIZE_FILL
	page.add_child(left)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 14)
	top.add_child(Emblem.new(glyph_of(id), 48.0 if _compact else 80.0))
	var nm := VBoxContainer.new(); nm.add_theme_constant_override("separation", 8); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title: Label = TBKit.title(T.call("b_" + id), 16 if _compact else 22, TBTokens.c("ink_0"))
	K.wrappable(title)                                       # a long name (Uzbek, Russian) wraps inside its column instead of running over the next
	nm.add_child(title)
	var st := HBoxContainer.new(); st.add_theme_constant_override("separation", 10)
	st.add_child(Pips.new(maxl, cur_lv))
	if cur_lv > 0 or busy_here:
		var sl: Label = K.label(String(T.call("bp_busy")) if busy_here else (String(T.call("bp_lvl_of", {"a": cur_lv, "b": maxl})) if maxl > 1 else String(T.call("bp_built_here"))), 13, TBTokens.BZ_GOOD if not busy_here else TBTokens.BZ_HI)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		st.add_child(sl)
	nm.add_child(st)
	top.add_child(nm)
	left.add_child(top)
	var ek: String = "bd_" + id
	if TBI18n.has_key(ek): left.add_child(K.para_bz("[i]%s[/i]" % T.call(ek), 15.0 if _compact else 16.0, 1.3))
	var chips := HBoxContainer.new(); chips.add_theme_constant_override("separation", 8)
	var ch_h: float = 50.0 if _compact else 62.0
	chips.add_child(Chip.new(str(gold), String(T.call("gold")), int(_g.gold[me]) < gold, ch_h))
	chips.add_child(Chip.new(str(turns), String(T.call("bp_time")), false, ch_h))
	chips.add_child(Chip.new(str(moves), String(T.call("bp_moves")), int(_g.mp[me]) < moves, ch_h))
	if not _compact and not maxed: left.add_child(chips)                  # on a short screen the figures are in the checks, the disc and the button
	var rt := VBoxContainer.new(); rt.add_theme_constant_override("separation", 8); rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(rt)
	var lc := HBoxContainer.new(); lc.add_theme_constant_override("separation", 12)
	lc.add_child(TBKit.caps(T.call("bp_levels"), 11, TBTokens.BZ_HI))
	var lr := ColorRect.new(); lr.color = TBTokens.BZ_WELL_LINE; lr.custom_minimum_size = Vector2(0, 1); lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER; lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lc.add_child(lr)
	rt.add_child(lc)
	var row_h: float = 28.0 if _compact else 48.0
	var lsep: float = 3.0 if _compact else 6.0
	var lad := VBoxContainer.new(); lad.add_theme_constant_override("separation", int(lsep))
	lad.custom_minimum_size.y = float(MAX_LEVELS) * row_h + float(MAX_LEVELS - 1) * lsep
	for k in range(1, maxl + 1):
		lad.add_child(_ladder_row(id, k, 1 if k <= cur_lv else (2 if k == cur_lv + 1 else 0), bd, row_h))
	rt.add_child(lad)
	# ---- the footer: what is still missing, and the buttons
	var rule := ColorRect.new(); rule.color = TBTokens.BZ_WELL_LINE; rule.custom_minimum_size = Vector2(0, 1); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(rule)
	var need: float = float(bd["tech"][clampi(lvl - 1, 0, (bd["tech"] as Array).size() - 1)])
	var slot_row: Array = [true, T.call("bp_slot")]
	if _g.rules >= 2:
		if cur_lv > 0: slot_row = [true, T.call("bp_slot_up")]
		elif _g.b_used(_p) < _g.b_slots(_p): slot_row = [true, T.call("bp_slot_n", {"u": _g.b_used(_p), "s": _g.b_slots(_p)})]
		else: slot_row = [false, T.call("err_slots")]
	var why: String = String(cn.get("reason", ""))
	if why in ["coast", "arid", "polar", "busy", "max"] and TBI18n.has_key("err_" + why): slot_row = [false, T.call("err_" + why)]          # the reason a building cannot go here replaces the slot line
	var checks: Array = [slot_row,
		[_g.tech_level[me] >= need, T.call("bp_tech_y" if _g.tech_level[me] >= need else "bp_tech_n", {"t": "%.1f" % need})],
		[int(_g.gold[me]) >= gold, T.call("bp_gold_y" if int(_g.gold[me]) >= gold else "bp_gold_n", {"g": gold})],
		[int(_g.mp[me]) >= moves, T.call("bp_mp_y" if int(_g.mp[me]) >= moves else "bp_mp_n", {"m": moves})]]
	if maxed: checks = [[true, T.call("bp_built_here")]]                  # a finished building: nothing more to check, only Demolish is left
	var foot := BoxContainer.new(); foot.vertical = _narrow; foot.add_theme_constant_override("separation", 14 if _narrow else (16 if _compact else 26))
	_detail.add_child(foot)
	var grid := GridContainer.new(); grid.columns = 1 if _narrow else 2
	grid.add_theme_constant_override("h_separation", 16 if _compact else 22); grid.add_theme_constant_override("v_separation", 1 if _compact else 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c in checks:
		if _compact and bool(c[0]): continue                  # a short screen lists only what is still missing (the button says the rest)
		var crow := HBoxContainer.new(); crow.add_theme_constant_override("separation", 7); crow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ok: bool = bool(c[0])
		var ic := Control.new(); ic.custom_minimum_size = Vector2(18, 20); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): TBBzIcons.draw(ic, "check" if ok else "close", Vector2(9, 10), 16.0, TBTokens.BZ_GOOD if ok else TBTokens.BZ_BAD_TXT, 2.0))
		crow.add_child(ic)
		var tl: Label = K.label(String(c[1]), 13 if _compact else 15, TBTokens.BZ_DIM if ok else TBTokens.BZ_BAD_TXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.custom_minimum_size.x = 40
		crow.add_child(tl)
		grid.add_child(crow)
	foot.add_child(grid)
	var acts := HBoxContainer.new(); acts.add_theme_constant_override("separation", 12); acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.custom_minimum_size.x = 0.0 if _narrow else (240.0 if _compact else 340.0); acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow else Control.SIZE_SHRINK_END
	if _g.rules >= 2 and cur_lv > 0:
		var dm: Button = K.button(T.call("bp_demolish"), func(): _demolish(), false, true)
		dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dm.size_flags_stretch_ratio = 0.75
		acts.add_child(dm)
	var go: Button = K.button(String(T.call("err_max")) if maxed else T.call("bp_upgrade_for" if cur_lv > 0 else "bp_build_for", {"g": gold}), func(): _do(), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not bool(cn["ok"]): K.disable(go, "")
	acts.add_child(go)
	foot.add_child(acts)
	_fit_later()

var _max_h := 0.0
## choosing another building changes the page but not the panel: its top edge and its rail stay where they are (they used to move with every page, under the finger), and the page only ever grows
func _fit_later() -> void:
	await get_tree().process_frame                          # the page lays out first: a wrapping text is measured at its real width, not at its one-word minimum
	await get_tree().process_frame
	_fit()

func _fit() -> void:
	if not is_inside_tree(): return
	_detail.custom_minimum_size.y = 0.0
	_max_h = maxf(_max_h, _detail.get_combined_minimum_size().y)
	_detail.custom_minimum_size.y = _max_h
	var top_y: float = position.y
	reset_size(); size = get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
	var lo: float = bounds.position.y + 8.0
	var hi: float = maxf(lo, bounds.end.y - size.y - 8.0)
	position.y = clampf(top_y, lo, hi)
	var hx: float = maxf(bounds.position.x + 8.0, bounds.end.x - size.x - 8.0)
	position.x = clampf(position.x, bounds.position.x + 8.0, hx)

## beside the ring (right of it, then left), inside the safe screen, clear of the HUD's parts; otherwise the nearest spot inside the screen
func _place() -> void:
	if not is_inside_tree(): return
	reset_size(); size = get_combined_minimum_size()
	var sz: Vector2 = size
	var vp: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
	var keep: Array = _env.get("keep", [])
	var lo := bounds.position + Vector2(8.0, 8.0)
	var hi := bounds.end - sz - Vector2(8.0, 8.0)
	var cy: float = _anchor.get_center().y - sz.y * 0.5 if _anchor.size.x > 0.0 else lo.y
	var y: float = clampf(cy, lo.y, maxf(lo.y, hi.y))
	var spots: Array = []
	if _anchor.size.x > 0.0:
		spots.append(Vector2(_anchor.end.x + 12.0, y)); spots.append(Vector2(_anchor.position.x - sz.x - 12.0, y))
	var chosen := Vector2.INF
	for s in spots:
		var r := Rect2(s, sz)
		if r.position.x < lo.x or r.end.x > bounds.end.x - 8.0: continue
		var blocked := false
		for k in keep:
			if (k as Rect2).intersects(r):                                          # nudge it clear of a bar that is under it (the lens bar, the ticker) before giving up on this side
				var up: float = (k as Rect2).position.y - sz.y - 6.0
				if up >= lo.y and not (k as Rect2).intersects(Rect2(Vector2(r.position.x, up), sz)): r.position.y = up; s = Vector2(s.x, up)
				else: blocked = true; break
		if not blocked: chosen = s; break
	if chosen == Vector2.INF: chosen = Vector2(clampf(_anchor.end.x + 12.0 if _anchor.size.x > 0.0 else lo.x, lo.x, maxf(lo.x, hi.x)), y)
	position = chosen.floor()

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

## the window moves when its title row is dragged (the mouse or a finger)
func _head_bottom() -> float:
	return (_rule.global_position.y + _rule.size.y - global_position.y) + 6.0 if _rule != null else 56.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and e.position.y <= _head_bottom():
			_drag = true; _drag_off = e.global_position - position
			accept_event()
		elif not e.pressed: _drag = false
	elif e is InputEventMouseMotion:
		if _drag:
			var vp: Vector2 = get_viewport_rect().size
			var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
			var np: Vector2 = e.global_position - _drag_off
			position = Vector2(clampf(np.x, bounds.position.x + 4.0, maxf(bounds.position.x + 4.0, bounds.end.x - size.x - 4.0)), clampf(np.y, bounds.position.y + 4.0, maxf(bounds.position.y + 4.0, bounds.end.y - size.y - 4.0)))
			accept_event()
		else:
			mouse_default_cursor_shape = Control.CURSOR_DRAG if e.position.y <= _head_bottom() else Control.CURSOR_ARROW

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
