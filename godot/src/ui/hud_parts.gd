## HUD building blocks: top ribbon, dock buttons, resource readouts, the End-Turn seal.
class_name TBHudParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## ribbon behind the status line: lacquer fading slightly toward the map, closed by a brass hairline
class Ribbon extends StyleBox:
	func _init() -> void:
		set_content_margin(SIDE_LEFT, 12); set_content_margin(SIDE_RIGHT, 12); set_content_margin(SIDE_TOP, 6); set_content_margin(SIDE_BOTTOM, 8)
	func _draw(ci: RID, r: Rect2) -> void:
		var top := Color(0.02, 0.035, 0.07, 0.95); var bot := Color(0.03, 0.05, 0.1, 0.8)
		RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bot, bot]))
		var y := r.end.y - 0.5
		RenderingServer.canvas_item_add_line(ci, Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.83, 0.63, 0.09, 0.55), 1.0, true)
		RenderingServer.canvas_item_add_line(ci, Vector2(r.position.x, y + 3), Vector2(r.end.x, y + 3), Color(0.83, 0.63, 0.09, 0.18), 1.0, true)

## a figure with an engraved icon: [glyph] 4,585 / GOLD
class Readout extends HBoxContainer:
	var glyph := "coin"
	var col := Color(0.953, 0.773, 0.322)
	var _icon: Control
	var value: Label
	var caption: Label
	func setup(glyph_name: String, cap: String, icon_col: Color = Color(0.953, 0.773, 0.322)) -> Readout:
		glyph = glyph_name; col = icon_col
		add_theme_constant_override("separation", 6)
		_icon = Control.new(); _icon.custom_minimum_size = Vector2(22, 22); _icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER; _icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.draw.connect(func(): TBGlyph.draw(_icon, glyph, _icon.size * 0.5, 19.0, col, 1.5))
		add_child(_icon)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", -2); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value = K.num("", 16); v.add_child(value)
		caption = K.caps(cap, 9); v.add_child(caption)
		add_child(v)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self
	func _ready() -> void: set_process(false)        # only runs while a figure is rolling
	func set_value(text: String, color: Color = Color(0.91, 0.863, 0.8)) -> void:
		value.text = text
		value.add_theme_color_override("font_color", color)

	# ---- rolling numbers: the figure counts up/down to its new value and flashes green (gain) or red (loss)
	var _shown := NAN
	var _target := 0.0
	var _flash := 0.0
	var _flash_col := Color.WHITE
	var _base := Color(0.91, 0.863, 0.8)
	var _fmt := Callable()
	func set_num(v: float, fmt: Callable, color: Color = Color(0.91, 0.863, 0.8)) -> void:
		_fmt = fmt; _base = color
		if is_nan(_shown) or not TBMapView.animate:
			_shown = v; _target = v
			set_value(fmt.call(v), color); set_process(false); return
		if v != _target:
			_flash = 1.0
			_flash_col = Color(0.55, 0.95, 0.6) if v > _target else Color(1.0, 0.55, 0.5)
			_target = v
			set_process(true)
		else:
			value.add_theme_color_override("font_color", color if _flash <= 0.0 else value.get_theme_color("font_color"))
	func _process(delta: float) -> void:
		_shown += (_target - _shown) * (1.0 - exp(-9.0 * delta))
		if absf(_target - _shown) < 0.5: _shown = _target
		_flash = maxf(0.0, _flash - delta * 1.6)
		value.text = _fmt.call(_shown)
		value.add_theme_color_override("font_color", _base.lerp(_flash_col, _flash))
		if _shown == _target and _flash <= 0.0: set_process(false)

## square dock button with an engraved glyph and a tiny caption; optional count badge
class DockButton extends Button:
	var glyph := "gear"
	var cap := ""
	var badge := 0
	var badge_col := Color(0.953, 0.773, 0.322)
	func setup(g: String, caption: String, cb: Callable) -> DockButton:
		glyph = g; cap = caption
		custom_minimum_size = Vector2(54, 54); focus_mode = Control.FOCUS_NONE
		pressed.connect(cb)
		return self
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		var col := Color(0.953, 0.773, 0.322) if hot else Color(0.83, 0.68, 0.3)
		TBGlyph.draw(self, glyph, Vector2(size.x * 0.5, size.y * 0.4), 21.0, col, 1.6)
		var f := K.mono()
		var w := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(f, Vector2((size.x - w) * 0.5, size.y - 7.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.58, 0.5) if not hot else col)
		if badge > 0:
			var c := Vector2(size.x - 9, 9)
			draw_circle(c, 8.0, badge_col)
			var s := str(mini(badge, 99))
			var bw := K.mono_b().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(K.mono_b(), c + Vector2(-bw * 0.5, 3.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.04, 0.02))

## End Turn: a brass wax-seal medallion with a graduated bezel; the bezel sweeps while the turn resolves
class Seal extends Button:
	var busy := false
	var pulse := false              # gentle attention ring until the player has pressed it once
	var caption := "END TURN"
	var _t := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(92, 92); focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func set_busy(b: bool) -> void:
		busy = b; set_process(b or pulse); queue_redraw()
	func set_pulse(p: bool) -> void:
		pulse = p; set_process(busy or p); queue_redraw()
	func _process(d: float) -> void:
		_t += d; queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5 - 1.0
		var down := button_pressed and not disabled
		var hot := is_hovered() or down
		var gold := Color(0.953, 0.773, 0.322) if hot else Color(0.83, 0.63, 0.09)
		draw_circle(c + Vector2(0, 2), R, Color(0, 0, 0, 0.35))
		draw_circle(c, R, Color(0.03, 0.05, 0.1, 0.96))
		draw_arc(c, R - 1.0, 0, TAU, 56, gold, 2.0, true)
		draw_arc(c, R - 5.0, 0, TAU, 56, Color(gold.r, gold.g, gold.b, 0.35), 1.0, true)
		var spin := _t * 1.6 if busy else 0.0
		for i in 48:
			var a := i * TAU / 48.0 + spin
			var long := i % 4 == 0
			var d := Vector2(cos(a), sin(a))
			var lit := busy and fposmod(a - spin * 2.0, TAU) < 1.0
			draw_line(c + d * (R - 8.0), c + d * (R - (14.0 if long else 11.0)), Color(gold.r, gold.g, gold.b, 0.95 if lit or long else 0.5), 1.2, true)
		if pulse and not busy:
			var k := fposmod(_t * 0.9, 1.0)
			draw_arc(c, R + 2.0 + k * 9.0, 0, TAU, 48, Color(0.953, 0.773, 0.322, 0.55 * (1.0 - k)), 2.0, true)
		var inner := R - 19.0
		draw_circle(c, inner, Color(0.83, 0.63, 0.09, 0.32 if down else (0.16 if hot else 0.07)))
		draw_arc(c, inner, 0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.6), 1.0, true)
		var gcol := Color(0.45, 0.4, 0.3) if disabled else gold
		var u := R / 46.0
		TBGlyph.draw(self, "chevrons", c + Vector2(0, -6 * u), 22.0 * u, gcol, 2.0)
		var f := K.display()
		var fs := int(maxf(8.0, 9.0 * u))
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, 17.0 * u), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gcol)


## colour key for the active map lens: gradient bar for ramps, swatches for categories
class Legend extends Control:
	const D = preload("res://src/engine/data.gd")
	var items: Array = []          # [[rgb, label]]
	var ramp: Array = []           # rgb stops
	var lo := ""; var hi := ""
	var heading := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false
	func setup(lens: String) -> void:
		items = []; ramp = []; heading = ""
		var T: Callable = TBI18n.T
		var L = TBLenses
		match lens:
			"economic": ramp = L.ECON_RAMP
			"military": ramp = L.ARMY_RAMP
			"population": ramp = L.POP_RAMP
			"stability": ramp = L.STAB_RAMP
			"diplomatic":
				items = [[0x46c36b, T.call("leg_self")], [L.REL_COL[0], T.call("rel_peace")], [L.REL_COL[1], T.call("rel_war")], [L.REL_COL[2], T.call("rel_nap")], [L.REL_COL[3], T.call("rel_ally")], [L.REL_COL[4], T.call("rel_marriage")]]
			"governments":
				for i in 10: items.append([L.REGIME_COL[i], T.call("g_" + D.REGIME_ID[i])])
			"terrain":
				for i in L.TERRAIN_COL.size(): items.append([L.TERRAIN_COL[i], T.call("t_" + D.TERRAIN_ID[i])])
			"buildings":
				for i in range(1, L.BUILD_COL.size()): items.append([L.BUILD_COL[i], T.call("b_" + D.BUILDINGS[i - 1]["id"])])
		lo = T.call("leg_low"); hi = T.call("leg_high")
		heading = T.call("lens_" + lens)
		visible = not (ramp.is_empty() and items.is_empty())
		custom_minimum_size = Vector2(0, 0)
		var h := 40.0
		if not items.is_empty(): h = 24.0 + ceil(items.size() / 3.0) * 18.0
		custom_minimum_size = Vector2(340, h)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.1, 0.82), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.63, 0.09, 0.4), false, 1.0)
		var f := K.mono()
		draw_string(K.display(), Vector2(10, 15), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.953, 0.773, 0.322))
		if not ramp.is_empty():
			var x0 := 10.0; var x1 := size.x - 10.0; var y := 22.0
			var n := ramp.size() - 1
			for i in n:
				var a := Color.hex((ramp[i] << 8) | 0xFF); var b := Color.hex((ramp[i + 1] << 8) | 0xFF)
				var xa := x0 + (x1 - x0) * i / n; var xb := x0 + (x1 - x0) * (i + 1) / n
				draw_polygon(PackedVector2Array([Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + 8), Vector2(xa, y + 8)]), PackedColorArray([a, b, b, a]))
			draw_string(f, Vector2(x0, y + 22), lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.62, 0.58, 0.5))
			draw_string(f, Vector2(x1 - f.get_string_size(hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, y + 22), hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.62, 0.58, 0.5))
		else:
			var colw := (size.x - 20.0) / 3.0
			for i in items.size():
				var cx := 10.0 + (i % 3) * colw; var cy := 28.0 + (i / 3) * 18.0
				draw_rect(Rect2(cx, cy - 9, 12, 10), Color.hex((items[i][0] << 8) | 0xFF))
				draw_string(f, Vector2(cx + 17, cy), String(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, colw - 20, 10, Color(0.91, 0.863, 0.8))
