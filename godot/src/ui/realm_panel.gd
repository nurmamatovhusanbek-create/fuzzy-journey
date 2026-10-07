## The realm panel (Age of Civilizations "civilization menu"): flag, name and figures of the player's nation, who it is allied / at war with,
## and the list of decisions (screens). Opens from the flag block, stays open while the map is used, covers the minimap.
class_name TBRealmPanel
extends PanelContainer

signal action(id: String)
signal nation_pressed(n: int)
signal closed

const P = preload("res://src/ui/hud_parts.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

var g: TBGame
var _sc: ScrollContainer
var _col: VBoxContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", P.sbox(P.al(P.tk("bar_0"), 0.95), P.tk("rule"), 0.0, 1))
	_sc = ScrollContainer.new(); _sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_sc)
	_col = VBoxContainer.new(); _col.add_theme_constant_override("separation", 0); _col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sc.add_child(_col)

# ---------------------------------------------------------------- pieces
class Head extends Control:
	var g: TBGame
	var n := 0
	signal pressed_nation
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_STOP; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed_nation.emit(); accept_event()
	func _draw() -> void:
		var fb: Font = P.body_b()
		var fl := Rect2(P.R(8.0), P.R(8.0), P.R(120.0), P.R(80.0))
		draw_texture_rect(TBFlags.texture(g.nat_code[n], g.color[n]), fl, false)
		draw_rect(fl, P.al(Color.BLACK, 0.6), false, 1.0)
		var tx: float = fl.end.x + P.R(10.0)
		var nz: int = P.fr(26.0)
		var nm: String = g.dname(n)
		draw_string(fb, Vector2(tx, P.base(fb, nz, P.R(26.0))), P.fit(fb, nm, nz, size.x - tx - P.R(8.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, nz, P.tk("cream"))
		var l2: String = "%s: " % TBI18n.T.call("aoc_provinces")
		var fm: Font = P.body()
		var z2: int = P.fr(21.0)
		draw_string(fm, Vector2(tx, P.base(fm, z2, P.R(58.0))), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, P.tk("smoke"))
		draw_string(fb, Vector2(tx + P.tw(fm, l2, z2), P.base(fb, z2, P.R(58.0))), str(g.owned(n).size()), HORIZONTAL_ALIGNMENT_LEFT, -1, z2, P.tk("brass_lt"))
		var era: String = TBI18n.T.call("era_name_%d" % g.era[n])
		draw_string(fm, Vector2(tx, P.base(fm, P.fr(19.0), P.R(84.0))), P.fit(fm, "%.1f · %s" % [g.tech_level[n], era], P.fr(19.0), size.x - tx - P.R(6.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, P.fr(19.0), P.tk("smoke"))

class Facts extends Control:
	var g: TBGame
	var n := 0
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_style_box(P.sbox(P.al(Color.BLACK, 0.2), P.al(P.tk("rule"), 0.4), P.R(3.0), 1), Rect2(P.R(6.0), 0, size.x - P.R(12.0), size.y))
		var fb: Font = P.body_b(); var fm: Font = P.body()
		var z: int = P.fr(19.0)
		var rows: Array = []
		var cap: int = g.capital_of[n]
		rows.append([TBI18n.T.call("capital"), TBI18n.place(g.world.name[cap]) if cap >= 0 else "—"])
		rows.append([TBI18n.T.call("govt"), TBI18n.T.call("g_" + D.REGIME_ID[g.regime[n]])])
		if g.rules >= 1 and g.r_name[n] != "":
			rows.append([TBI18n.T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)])
		var inc: Dictionary = g.income(n)
		rows.append([TBI18n.T.call("pop"), TBKit.fmt(int(inc.get("pop", 0)))])
		var y: float = P.R(10.0)
		var lh: float = P.R(30.0)
		for r in rows:
			draw_string(fm, Vector2(P.R(16.0), P.base(fm, z, y + lh * 0.5)), P.fit(fm, String(r[0]), z, size.x * 0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.tk("smoke"))
			var v: String = P.fit(fb, String(r[1]), z, size.x * 0.52)
			draw_string(fb, Vector2(size.x - P.R(16.0) - P.tw(fb, v, z), P.base(fb, z, y + lh * 0.5)), v, HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.tk("cream"))
			y += lh
		custom_minimum_size = Vector2(0, y + P.R(8.0))

class Sect extends Control:
	var text := ""
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), P.al(P.tk("bar_2"), 0.9))
		draw_rect(Rect2(0, 0, size.x, 1), P.al(P.tk("rule"), 0.7)); draw_rect(Rect2(0, size.y - 1, size.x, 1), P.al(P.tk("rule"), 0.7))
		var fb: Font = P.body_b(); var z: int = P.fr(20.0)
		draw_string(fb, Vector2((size.x - P.tw(fb, text, z)) * 0.5, P.base(fb, z, size.y * 0.5)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.tk("cream"))

## a row of flags behind a small relation glyph; tapping a flag opens that nation
class FlagRow extends Control:
	signal picked(n: int)
	var glyph := "link"
	var gcol := Color.WHITE
	var g: TBGame
	var list: Array = []
	var _rects: Array = []
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_STOP; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _layout(w: float) -> float:
		_rects.clear()
		var x0: float = P.R(54.0); var fw: float = P.R(38.0); var fh: float = P.R(26.0); var gp: float = P.R(6.0)
		var x: float = x0; var y: float = P.R(8.0)
		for n in list:
			if x + fw > w - P.R(6.0): x = x0; y += fh + gp
			_rects.append([Rect2(x, y, fw, fh), n])
			x += fw + gp
		return y + fh + P.R(8.0)
	func _get_minimum_size() -> Vector2: return Vector2(0, maxf(P.R(44.0), _layout(maxf(size.x, P.R(300.0)))))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for r in _rects:
				if (r[0] as Rect2).grow(2.0).has_point((e as InputEventMouseButton).position): picked.emit(int(r[1])); accept_event(); return
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: update_minimum_size()
	func _draw() -> void:
		_layout(size.x)
		TBGlyph.draw(self, glyph, Vector2(P.R(28.0), P.R(21.0)), P.R(28.0), gcol, 1.8)
		for r in _rects:
			var rc: Rect2 = r[0]
			draw_texture_rect(TBFlags.texture(g.nat_code[int(r[1])], g.color[int(r[1])]), rc, false)
			draw_rect(rc, P.al(Color.BLACK, 0.7), false, 1.0)
		if list.is_empty(): draw_string(P.body(), Vector2(P.R(54.0), P.base(P.body(), P.fr(19.0), P.R(22.0))), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, P.fr(19.0), P.tk("ink_off"))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), P.al(P.tk("rule"), 0.25))

class Row extends P.Hit:
	var glyph := "gear"
	var label := ""
	var value := ""
	var vcol := Color.TRANSPARENT
	var badge := 0
	var gcol := Color.TRANSPARENT
	func _get_minimum_size() -> Vector2: return Vector2(0, P.R(47.0))
	func _has_point(p: Vector2) -> bool: return Rect2(Vector2.ZERO, size).has_point(p)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if hover or down: draw_rect(r, P.al(P.tk("bar_2"), 0.85))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), P.al(P.tk("rule"), 0.25))
		var cy: float = size.y * 0.5 + (1.0 if down else 0.0)
		TBGlyph.draw(self, glyph, Vector2(P.R(32.0), cy), P.R(28.0), gcol if gcol.a > 0.0 else P.tk("brass_lt"), 1.8)
		var fb: Font = P.body_b(); var z: int = P.fr(20.0)
		var rw: float = P.tw(fb, value, z) + P.R(14.0) if value != "" else 0.0
		draw_string(fb, Vector2(P.R(62.0), P.base(fb, z, cy)), P.fit(fb, label, z, size.x - P.R(70.0) - rw - (P.R(30.0) if badge > 0 else 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.tk("cream"))
		var x: float = size.x - P.R(14.0)
		if badge > 0:
			var bc := Vector2(x - P.R(10.0), cy)
			draw_circle(bc, P.R(12.0), P.tk("neg_bar") if value == "!" else P.tk("brass_lt"))
			var bz: int = P.fr(16.0)
			var bs: String = str(mini(badge, 99))
			draw_string(fb, Vector2(bc.x - P.tw(fb, bs, bz) * 0.5, P.base(fb, bz, cy)), bs, HORIZONTAL_ALIGNMENT_LEFT, -1, bz, P.tk("bar_0"))
			x -= P.R(30.0)
		if value != "" and value != "!":
			draw_string(fb, Vector2(x - P.tw(fb, value, z), P.base(fb, z, cy)), value, HORIZONTAL_ALIGNMENT_LEFT, -1, z, vcol if vcol.a > 0.0 else P.tk("brass_lt"))
		if has_focus(): P.focus_ring(self, r)

# ---------------------------------------------------------------- build
func rebuild() -> void:
	if g == null: return
	for c in _col.get_children(): _col.remove_child(c); c.queue_free()
	var n: int = g.human_id
	var head := Head.new(); head.g = g; head.n = n; head.custom_minimum_size = Vector2(0, P.R(98.0))
	head.pressed_nation.connect(func(): action.emit("nation"))
	_col.add_child(head)
	var facts := Facts.new(); facts.g = g; facts.n = n
	_col.add_child(facts); facts.queue_redraw()
	_sect(TBI18n.T.call("aoc_diplomacy"))
	var allies: Array = []; var wars: Array = []; var pacts: Array = []; var vassals: Array = []
	for o in range(1, g.N1):
		if o == n or g.alive[o] == 0: continue
		match g.get_rel(n, o):
			D.REL_ALLY: allies.append(o)
			D.REL_WAR: wars.append(o)
			D.REL_NAP, D.REL_MARRIAGE: pacts.append(o)
		if g.overlord[o] == n: vassals.append(o)
	_flags("link", P.tk("info"), allies)
	_flags("swords", P.tk("neg_bar"), wars)
	_flags("dove", P.tk("cream"), pacts)
	if not vassals.is_empty(): _flags("crown", P.tk("brass_lt"), vassals)
	_sect(TBI18n.T.call("aoc_decisions"))
	var inc: Dictionary = g.income(n)
	var bd: Dictionary = TBAdvisor.breakdown(g, n, inc)
	var net: int = int(bd["net"])
	_row("budget", "coins", TBI18n.T.call("dk_budget"), ("+%s" % TBKit.fmt(net)) if net >= 0 else ("−%s" % TBKit.fmt(-net)), P.tk("pos_bar") if net >= 0 else P.tk("neg_bar"))
	var act: int = 0
	for i in TBDecisions.LIST.size():
		if g.dec_until[n * TBDecisions.LIST.size() + i] > g.turn: act += 1
	_row("decisions", "scales", TBI18n.T.call("dk_decisions"), str(act) if act > 0 else "")
	var al: Array = TBAdvisor.alerts(g, n)
	var crit: int = 0
	for a in al: if int(a["sev"]) == 2: crit += 1
	var rw := _row("advisor", "lamp", TBI18n.T.call("dk_advisor"), "!" if crit > 0 else "")
	rw.badge = al.size()
	_row("nations", "globe", TBI18n.T.call("dk_nations"), "")
	_row("goals", "trophy", TBI18n.T.call("dk_goals"), "")
	_row("chronicle", "book", TBI18n.T.call("dk_chronicle"), "")
	_row("save", "save", TBI18n.T.call("dk_save"), "")
	_row("settings", "gear", TBI18n.T.call("dk_settings"), "")

func _sect(t: String) -> void:
	var s := Sect.new(); s.text = t; s.custom_minimum_size = Vector2(0, P.R(40.0)); _col.add_child(s)

func _flags(glyph: String, col: Color, list: Array) -> void:
	var fr := FlagRow.new(); fr.g = g; fr.glyph = glyph; fr.gcol = col; fr.list = list
	fr.picked.connect(func(o: int): nation_pressed.emit(o))
	_col.add_child(fr)

func _row(id: String, glyph: String, label: String, value: String, vcol: Color = Color.TRANSPARENT) -> Row:
	var r := Row.new(); r.glyph = glyph; r.label = label; r.value = value; r.vcol = vcol; r.set_a11y(label)
	r.pressed.connect(func(): action.emit(id))
	_col.add_child(r)
	return r
