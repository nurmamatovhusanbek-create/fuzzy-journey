## Pieces of the Nations screen that the demo draws with inline SVG: the relations bar, the stat cells and the big flag medal (docs/ui_variants/src/b_demo.html, nationBody).
class_name TBNationParts
extends RefCounted

## `#relsvg`: viewBox 440 x 52, a 9 unit track with graduated ticks below, the bar from the centre to the value, an ivory needle and the -100 / 0 / +100 labels.
class RelBar extends Control:
	var v := 0.0                         # -100..100
	var col := Color.WHITE
	func _init(value: float, c: Color) -> void:
		v = value; col = c
		custom_minimum_size = Vector2(0, 59); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE   # the inline svg is 52 tall and sits on its baseline: 7 more units of line box
	func _draw() -> void:
		# the scale is as wide as the card: only a card narrower than the demo's 440 units shrinks it (type, ticks and stroke); a wider card stretches the scale itself, ticks and all
		var s: float = minf(size.x / 440.0, 1.0)
		var m: float = 20.0 * s
		var L: float = maxf(size.x - 2.0 * m, 40.0)                       # the scale's length
		var oy: float = (52.0 - 52.0 * s) * 0.5
		var X := func(u: float) -> float: return m + u / 400.0 * L           # u: 0..400 along the scale
		var P := func(u: float, y: float) -> Vector2: return Vector2(X.call(u), oy + y * s)
		var ci := get_canvas_item()
		var track: Color = TBTokens.BZ_PANE_LINE
		draw_line(P.call(0.0, 22.0), P.call(400.0, 22.0), track, 9.0 * s)
		draw_circle(P.call(0.0, 22.0), 4.5 * s, track); draw_circle(P.call(400.0, 22.0), 4.5 * s, track)
		for i in 41:
			var u: float = float(i) * 10.0
			var ln: float = 9.0 if i % 10 == 0 else 4.0
			draw_line(P.call(u, 36.0), P.call(u, 36.0 + ln), TBTokens.c("rule"), maxf(1.0, s))
		var vu: float = 200.0 + v / 100.0 * 200.0
		if absf(v) > 0.01: draw_line(P.call(200.0, 22.0), P.call(vu, 22.0), col, 9.0 * s)
		var tri := PackedVector2Array([P.call(vu, 11.0), P.call(vu, 11.0) + Vector2(7.0 * s, -9.0 * s), P.call(vu, 11.0) + Vector2(-7.0 * s, -9.0 * s)])
		draw_colored_polygon(tri, TBTokens.BZ_IVORY)
		var f: Font = TBKit.cinzel(500)
		var sz: float = 9.0 * s
		var dim: Color = TBTokens.BZ_DIM
		TBBz.text(ci, f, P.call(0.0, 51.0), "−100", sz, dim)
		TBBz.text(ci, f, Vector2(X.call(200.0) - TBBz.tw(f, "0", sz) * 0.5, oy + 51.0 * s), "0", sz, dim)
		TBBz.text(ci, f, Vector2(X.call(400.0) - TBBz.tw(f, "+100", sz), oy + 51.0 * s), "+100", sz, dim)

## the bordered cell: a brass icon, the figure (Alegreya 700 16, line height 1) over a small caps caption
class StatCell extends Control:
	var icon := ""
	var value := ""
	var cap := ""
	func _init(ic: String, val: String, c: String) -> void:
		icon = ic; value = val; cap = c
		size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, _h())
	func _h() -> float: return 54.0                                # 1 + 7 padding, the 16 unit figure line, a caption line of the body's line height, 7 + 1
	func _draw() -> void:
		var ci := get_canvas_item()
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), TBTokens.BZ_WELL)
		draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), TBTokens.BZ_TRACK_LINE, false, 1.0)
		var cy: float = h * 0.5
		TBBzIcons.draw(self, icon, Vector2(1.0 + 9.0 + 9.5, cy), 19.0, TBTokens.c("brass"))
		var x: float = 1.0 + 9.0 + 19.0 + 8.0
		var fb: Font = TBKit.alegreya(700); var fc: Font = TBKit.cinzel(700)
		var top: float = cy - 27.0
		TBBz.text(ci, fb, Vector2(x, top + 20.0), value, 16.0, TBTokens.BZ_IVORY)
		TBBz.text(ci, fc, Vector2(x, top + 39.5), cap.to_upper() if TBI18n.lang != "ru" else cap, 8.5, TBTokens.BZ_DIM, 8.5 * 0.2)

## flagMedal(code, size) as a control
class FlagMedal extends Control:
	var tex: Texture2D
	var d := 80.0
	func _init(t: Texture2D, diameter: float) -> void:
		tex = t; d = diameter
		custom_minimum_size = Vector2(d, d); size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		TBFlags.draw_flag_medal(self, tex, size * 0.5, d)
