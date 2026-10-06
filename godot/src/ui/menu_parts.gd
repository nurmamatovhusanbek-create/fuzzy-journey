## Title-screen parts: the bezel ring around the globe, typographic menu entries, a soft scrim behind the text.
class_name TBMenuParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## graduated bezel (like an armillary / compass ring) that turns with the globe
class Bezel extends Control:
	var map: TBMapView
	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if map == null: return
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.44 * map.zoom
		var spin := -map.lon0
		var gold := Color(0.83, 0.63, 0.09)
		draw_circle(c, R * 1.0, Color(0.015, 0.025, 0.06, 0.5))      # dims the globe so the title reads over any continent
		draw_arc(c, R * 1.06, 0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.55), 1.0, true)
		draw_arc(c, R * 1.075, 0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.2), 1.0, true)
		for i in 120:
			var a := i * TAU / 120.0 + spin
			var d := Vector2(cos(a), sin(a))
			var big := i % 10 == 0
			var mid := i % 5 == 0
			draw_line(c + d * R * 1.06, c + d * R * (1.103 if big else (1.088 if mid else 1.075)), Color(gold.r, gold.g, gold.b, 0.8 if big else 0.4), 1.0, true)
		# four fixed lubber marks (N/E/S/W) so the turning bezel reads as an instrument
		for q in 4:
			var a := q * PI * 0.5 - PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var p := c + d * R * 1.06
			draw_colored_polygon(PackedVector2Array([p, p + d.rotated(0.09) * R * 0.045, p + d.rotated(-0.09) * R * 0.045]), Color(0.953, 0.773, 0.322, 0.9))

## soft dark pool behind the title so it stays readable over any part of the globe
class Scrim extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var rx := size.x * 0.5; var ry := size.y * 0.5
		for i in 14:
			var k := 1.0 - i / 14.0
			draw_set_transform(c, 0, Vector2(rx * k / maxf(ry * k, 1.0), 1.0))
			draw_circle(Vector2.ZERO, ry * k, Color(0.02, 0.03, 0.07, 0.065))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## one stop on the era timeline: rail, diamond node, year, name
class EraRow extends Button:
	var year_text := ""
	var selected := false
	var first := false
	var last := false
	func _init(y: String, name_text: String) -> void:
		year_text = y; text = ""; tooltip_text = ""; focus_mode = Control.FOCUS_NONE; flat = true
		custom_minimum_size = Vector2(0, 34); name = "Era"
		set_meta("label", name_text)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var ox := Color(0.52, 0.11, 0.09)           # oxblood
		var ink := Color(0.165, 0.125, 0.082)
		var rule := Color(0.45, 0.32, 0.12)
		var hot := is_hovered() or selected
		if selected:
			draw_rect(Rect2(28, 2, size.x - 28, size.y - 4), Color(0.55, 0.14, 0.1, 0.12))
			draw_line(Vector2(28, 2), Vector2(28, size.y - 2), ox, 2.0)
		var cx := 12.0; var cy := size.y * 0.5
		if not first: draw_line(Vector2(cx, 0), Vector2(cx, cy - 7), Color(rule.r, rule.g, rule.b, 0.55), 1.0)
		if not last: draw_line(Vector2(cx, cy + 7), Vector2(cx, size.y), Color(rule.r, rule.g, rule.b, 0.55), 1.0)
		var pts := PackedVector2Array([Vector2(cx, cy - 6), Vector2(cx + 6, cy), Vector2(cx, cy + 6), Vector2(cx - 6, cy)])
		if selected: draw_colored_polygon(pts, ox)
		else:
			pts.append(pts[0]); draw_polyline(pts, Color(rule.r, rule.g, rule.b, 0.95 if hot else 0.7), 1.3, true)
		var col := ox if hot else ink
		draw_string(K.mono(), Vector2(40, cy + 5), year_text, HORIZONTAL_ALIGNMENT_LEFT, 84, 13, ox if selected else rule)
		draw_string(K.display(), Vector2(128, cy + 5), String(get_meta("label")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 132, 15, col)

## text-only menu entry: engraved capitals, flanked by diamonds when hot
class Entry extends Button:
	var big := false
	func _init(text_value: String, is_big: bool, cb: Callable) -> void:
		text = text_value; big = is_big; flat = true; focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 58 if is_big else 46)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		add_theme_font_override("font", K.display_hi() if is_big else K.display())
		add_theme_font_size_override("font_size", 28 if is_big else 19)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]: add_theme_color_override(k, K.GOLD2 if is_big else K.TEXT)
		add_theme_color_override("font_hover_color", Color(0.72, 0.13, 0.1))
		if cb.is_valid(): pressed.connect(cb)
	func _draw() -> void:
		var hot := is_hovered() or button_pressed or big
		if not hot: return
		var f := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cy := size.y * 0.5
		var gap := 16.0
		var col := Color(0.62, 0.14, 0.1, 0.95 if (is_hovered() or button_pressed) else 0.7)
		for s in [-1.0, 1.0]:
			var x: float = size.x * 0.5 + s * (w * 0.5 + gap)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, cy), Vector2(x, cy - 5), Vector2(x + 5, cy), Vector2(x, cy + 5)]), col)
			draw_line(Vector2(x + s * 10, cy), Vector2(x + s * (26 if is_hovered() else 16), cy), col, 1.0, true)
