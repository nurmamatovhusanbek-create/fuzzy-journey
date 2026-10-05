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
		value = K.num("", 16, K.CREAM); v.add_child(value)
		caption = K.caps(cap, 9, K.SMOKE); v.add_child(caption)
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

## dock button: a brass-ringed umber medallion with an engraved glyph and a tiny caption beneath
class DockButton extends Button:
	var glyph := "gear"
	var cap := ""
	var badge := 0
	var badge_col := Color(0.953, 0.773, 0.322)
	func setup(g: String, caption: String, cb: Callable) -> DockButton:
		glyph = g; cap = caption
		custom_minimum_size = Vector2(54, 58); focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pressed.connect(cb)
		return self
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		var down := button_pressed
		var R := minf(size.x * 0.5 - 4.0, 21.0)
		var c := Vector2(size.x * 0.5, R + 3.0 + (1.0 if down else 0.0))
		draw_circle(c + Vector2(0, 2.0), R, Color(0, 0, 0, 0.4))
		draw_circle(c, R, Color(0.17, 0.12, 0.075, 0.97) if not hot else Color(0.26, 0.18, 0.1, 0.98))
		draw_arc(c, R - 0.5, 0, TAU, 40, K.BRASS_LT if hot else K.BRASS, 2.0, true)
		draw_arc(c, R - 4.0, 0, TAU, 40, Color(K.BRASS.r, K.BRASS.g, K.BRASS.b, 0.3), 1.0, true)
		draw_arc(c, R - 0.5, PI * 1.1, PI * 1.55, 12, Color(1, 0.95, 0.75, 0.55), 1.4, true)       # rim highlight
		TBGlyph.draw(self, glyph, c, 19.0, K.BRASS_LT if hot else K.BRASS, 1.6)
		var f := K.mono()
		var w := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string_outline(f, Vector2((size.x - w) * 0.5, size.y - 3.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.02, 0.015, 0.01, 0.8))
		draw_string(f, Vector2((size.x - w) * 0.5, size.y - 3.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, K.CREAM if hot else K.SMOKE)
		if badge > 0:
			var bc := Vector2(size.x - 8, 8)
			draw_circle(bc, 8.0, badge_col)
			draw_arc(bc, 8.0, 0, TAU, 20, Color(0.1, 0.06, 0.02, 0.8), 1.0, true)
			var s := str(mini(badge, 99))
			var bw := K.mono_b().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(K.mono_b(), bc + Vector2(-bw * 0.5, 3.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.04, 0.02))

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
		var gold := K.BRASS_LT if hot else K.BRASS
		draw_circle(c + Vector2(0, 2), R, Color(0, 0, 0, 0.4))
		draw_circle(c, R, Color(0.14, 0.10, 0.06, 0.97))
		draw_arc(c, R - 1.0, 0, TAU, 56, gold, 2.0, true)
		draw_arc(c, R - 5.0, 0, TAU, 56, Color(gold.r, gold.g, gold.b, 0.35), 1.0, true)
		var spin := _t * 1.6 if busy else 0.0
		for i in 48:
			var a := i * TAU / 48.0 + spin
			var long := i % 4 == 0
			var d := Vector2(cos(a), sin(a))
			var lit := busy and fposmod(a - spin * 2.0, TAU) < 1.0
			draw_line(c + d * (R - 7.0), c + d * (R - (13.0 if long else 10.0)), Color(gold.r, gold.g, gold.b, 0.95 if lit or long else 0.45), 1.2, true)
		if pulse and not busy:
			var k := fposmod(_t * 0.9, 1.0)
			draw_arc(c, R + 2.0 + k * 9.0, 0, TAU, 48, Color(0.953, 0.773, 0.322, 0.55 * (1.0 - k)), 2.0, true)
		# the wax: an uneven disc pressed by a die, with an embossed rim, glyph and caption
		var inner := R - 17.0
		var seed_v := 41
		var blob := TBPaper.blob(c, inner, inner, seed_v, 0.05, 40)
		var wax_c := Color(0.66, 0.16, 0.13) if not down else Color(0.5, 0.1, 0.08)
		if disabled: wax_c = Color(0.4, 0.28, 0.25)
		var uvs := PackedVector2Array()
		for p in blob: uvs.append((p - (c - Vector2(inner, inner))) / (inner * 2.0))
		draw_polygon(blob, PackedColorArray([wax_c]), uvs, TBPaper.texture(TBPaper.WAX))
		var ring := blob.duplicate(); ring.append(blob[0])
		draw_polyline(ring, Color(0.28, 0.04, 0.03, 0.95), 1.4, true)
		draw_arc(c, inner - 4.0, 0, TAU, 40, Color(0.32, 0.05, 0.04, 0.6), 1.2, true)
		draw_arc(c, inner - 4.0, PI * 1.1, PI * 1.6, 12, Color(1, 0.7, 0.6, 0.35), 1.4, true)
		var u := R / 46.0
		var emb := Color(0.99, 0.9, 0.78, 0.95) if not disabled else Color(0.8, 0.7, 0.6, 0.6)
		var shade := Color(0.25, 0.03, 0.02, 0.8)
		TBGlyph.draw(self, "chevrons", c + Vector2(0.8, -5.2 * u), 20.0 * u, shade, 2.2)
		TBGlyph.draw(self, "chevrons", c + Vector2(0, -6 * u), 20.0 * u, emb, 2.0)
		var f := K.display()
		var fs := int(maxf(8.0, 8.5 * u))
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5 + 0.7, 15.0 * u + 0.7), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shade)
		draw_string(f, c + Vector2(-w * 0.5, 15.0 * u), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, emb)


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
