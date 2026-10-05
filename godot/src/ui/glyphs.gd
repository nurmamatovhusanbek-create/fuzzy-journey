## Engraved line icons drawn with primitives (no emoji / icon fonts: those are missing or inconsistent on phones).
class_name TBGlyph
extends RefCounted

static func _poly(ci: CanvasItem, pts: Array, c: Vector2, r: float, col: Color, w: float, closed: bool = false) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(c + (v as Vector2) * r)
	if closed: p.append(p[0])
	ci.draw_polyline(p, col, w, true)

static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var p := PackedVector2Array()
	for i in 25: p.append(c + Vector2(cos(i * TAU / 24.0) * rx, sin(i * TAU / 24.0) * ry))
	ci.draw_polyline(p, col, w, true)

static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, w: float = 1.6) -> void:
	var r := size * 0.5
	match name:
		"coin":
			ci.draw_arc(c, r * 0.9, 0, TAU, 28, col, w, true)
			ci.draw_arc(c, r * 0.58, 0, TAU, 20, col, w * 0.7, true)
			ci.draw_line(c + Vector2(0, -r * 0.28), c + Vector2(0, r * 0.28), col, w, true)
		"men":
			ci.draw_arc(c + Vector2(0, r * 0.1), r * 0.78, PI, TAU, 16, col, w, true)
			ci.draw_line(c + Vector2(-r * 0.78, r * 0.1), c + Vector2(-r * 0.78, r * 0.75), col, w, true)
			ci.draw_line(c + Vector2(r * 0.78, r * 0.1), c + Vector2(r * 0.78, r * 0.75), col, w, true)
			ci.draw_line(c + Vector2(0, -r * 0.65), c + Vector2(0, r * 0.75), col, w * 0.8, true)
			ci.draw_line(c + Vector2(-r * 0.78, r * 0.75), c + Vector2(-r * 0.25, r * 0.75), col, w, true)
			ci.draw_line(c + Vector2(r * 0.78, r * 0.75), c + Vector2(r * 0.25, r * 0.75), col, w, true)
		"swords":
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(-0.8 * s, -0.8) * r, c + Vector2(0.8 * s, 0.8) * r, col, w, true)
				var g := c + Vector2(0.35 * s, 0.35) * r
				ci.draw_line(g + Vector2(0.28 * s, -0.28) * r, g + Vector2(-0.28 * s, 0.28) * r, col, w, true)
		"scroll":
			ci.draw_rect(Rect2(c + Vector2(-0.62, -0.62) * r, Vector2(1.24, 1.24) * r), col, false, w)
			for i in 3: ci.draw_line(c + Vector2(-0.35, -0.3 + i * 0.3) * r, c + Vector2(0.35, -0.3 + i * 0.3) * r, col, w * 0.8, true)
			ci.draw_arc(c + Vector2(-0.62, -0.62) * r, r * 0.16, 0, TAU, 8, col, w * 0.8, true)
			ci.draw_arc(c + Vector2(0.62, 0.62) * r, r * 0.16, 0, TAU, 8, col, w * 0.8, true)
		"book":
			_poly(ci, [Vector2(-0.8, -0.6), Vector2(0, -0.45), Vector2(0.8, -0.6), Vector2(0.8, 0.6), Vector2(0, 0.75), Vector2(-0.8, 0.6)], c, r, col, w, true)
			ci.draw_line(c + Vector2(0, -0.45) * r, c + Vector2(0, 0.75) * r, col, w, true)
		"eye":
			var up := PackedVector2Array(); var dn := PackedVector2Array()
			for i in 13:
				var t := -1.0 + i / 6.0
				up.append(c + Vector2(t * 0.95, -0.5 * (1.0 - t * t)) * r); dn.append(c + Vector2(t * 0.95, 0.5 * (1.0 - t * t)) * r)
			ci.draw_polyline(up, col, w, true); ci.draw_polyline(dn, col, w, true)
			ci.draw_arc(c, r * 0.26, 0, TAU, 12, col, w, true)
			ci.draw_circle(c, r * 0.1, col)
		"flag":
			ci.draw_line(c + Vector2(-0.55, -0.85) * r, c + Vector2(-0.55, 0.85) * r, col, w, true)
			_poly(ci, [Vector2(-0.55, -0.8), Vector2(0.85, -0.42), Vector2(-0.55, -0.02)], c, r, col, w, true)
		"globe":
			ci.draw_arc(c, r * 0.88, 0, TAU, 28, col, w, true)
			_ell(ci, c, r * 0.38, r * 0.88, col, w * 0.8)
			ci.draw_line(c + Vector2(-0.88, 0) * r, c + Vector2(0.88, 0) * r, col, w * 0.8, true)
			ci.draw_line(c + Vector2(-0.75, -0.45) * r, c + Vector2(0.75, -0.45) * r, col, w * 0.6, true)
			ci.draw_line(c + Vector2(-0.75, 0.45) * r, c + Vector2(0.75, 0.45) * r, col, w * 0.6, true)
		"scales":
			ci.draw_line(c + Vector2(0, -0.8) * r, c + Vector2(0, 0.7) * r, col, w, true)
			ci.draw_line(c + Vector2(-0.4, 0.8) * r, c + Vector2(0.4, 0.8) * r, col, w, true)
			ci.draw_line(c + Vector2(-0.8, -0.5) * r, c + Vector2(0.8, -0.5) * r, col, w, true)
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(0.8 * s, -0.5) * r, c + Vector2(0.55 * s, 0.05) * r, col, w * 0.7, true)
				ci.draw_line(c + Vector2(0.8 * s, -0.5) * r, c + Vector2(1.05 * s, 0.05) * r, col, w * 0.7, true)
				ci.draw_arc(c + Vector2(0.8 * s, 0.05) * r, r * 0.26, 0, PI, 10, col, w, true)
		"coins":
			for i in 3: _ell(ci, c + Vector2(0, (0.45 - i * 0.42)) * r, r * 0.72, r * 0.26, col, w * 0.9)
			ci.draw_line(c + Vector2(-0.72, 0.45) * r, c + Vector2(-0.72, -0.4) * r, col, w * 0.8, true)
			ci.draw_line(c + Vector2(0.72, 0.45) * r, c + Vector2(0.72, -0.4) * r, col, w * 0.8, true)
		"trophy":
			_poly(ci, [Vector2(-0.55, -0.75), Vector2(0.55, -0.75), Vector2(0.45, -0.05), Vector2(0.14, 0.3), Vector2(0.14, 0.58), Vector2(0.45, 0.82), Vector2(-0.45, 0.82), Vector2(-0.14, 0.58), Vector2(-0.14, 0.3), Vector2(-0.45, -0.05)], c, r, col, w, true)
			ci.draw_arc(c + Vector2(-0.58, -0.38) * r, r * 0.26, PI * 0.5, PI * 1.5, 8, col, w * 0.8, true)
			ci.draw_arc(c + Vector2(0.58, -0.38) * r, r * 0.26, -PI * 0.5, PI * 0.5, 8, col, w * 0.8, true)
		"lamp":
			ci.draw_arc(c + Vector2(0, -0.25) * r, r * 0.5, PI * 0.8, PI * 2.2, 18, col, w, true)
			ci.draw_line(c + Vector2(-0.28, 0.45) * r, c + Vector2(0.28, 0.45) * r, col, w, true)
			ci.draw_line(c + Vector2(-0.2, 0.7) * r, c + Vector2(0.2, 0.7) * r, col, w, true)
			for a in [-1.0, 0.0, 1.0]:
				var d := Vector2(sin(a * 0.9), -cos(a * 0.9))
				ci.draw_line(c + Vector2(0, -0.25) * r + d * r * 0.72, c + Vector2(0, -0.25) * r + d * r * 0.95, col, w * 0.8, true)
		"save":
			_poly(ci, [Vector2(-0.7, 0.15), Vector2(-0.7, 0.7), Vector2(0.7, 0.7), Vector2(0.7, 0.15)], c, r, col, w)
			ci.draw_line(c + Vector2(0, -0.8) * r, c + Vector2(0, 0.35) * r, col, w, true)
			_poly(ci, [Vector2(-0.35, 0.0), Vector2(0, 0.38), Vector2(0.35, 0.0)], c, r, col, w)
		"gear":
			ci.draw_arc(c, r * 0.36, 0, TAU, 16, col, w, true)
			for i in 8:
				var d := Vector2(cos(i * TAU / 8.0), sin(i * TAU / 8.0))
				ci.draw_line(c + d * r * 0.58, c + d * r * 0.9, col, w * 1.6, true)
			ci.draw_arc(c, r * 0.62, 0, TAU, 24, col, w * 0.8, true)
		"crown":
			_poly(ci, [Vector2(-0.8, 0.6), Vector2(-0.8, -0.5), Vector2(-0.4, 0.0), Vector2(0, -0.7), Vector2(0.4, 0.0), Vector2(0.8, -0.5), Vector2(0.8, 0.6)], c, r, col, w, true)
		"skull":
			ci.draw_arc(c + Vector2(0, -0.1) * r, r * 0.75, PI * 0.95, PI * 2.05, 18, col, w, true)
			_poly(ci, [Vector2(-0.7, 0.05), Vector2(-0.5, 0.55), Vector2(-0.25, 0.55), Vector2(-0.25, 0.8), Vector2(0.25, 0.8), Vector2(0.25, 0.55), Vector2(0.5, 0.55), Vector2(0.7, 0.05)], c, r, col, w)
			ci.draw_circle(c + Vector2(-0.3, 0.0) * r, r * 0.17, col); ci.draw_circle(c + Vector2(0.3, 0.0) * r, r * 0.17, col)
		"pin":
			ci.draw_arc(c + Vector2(0, -0.2) * r, r * 0.55, PI * 0.78, PI * 2.22, 16, col, w, true)
			_poly(ci, [Vector2(-0.38, 0.2), Vector2(0, 0.85), Vector2(0.38, 0.2)], c, r, col, w)
			ci.draw_circle(c + Vector2(0, -0.2) * r, r * 0.16, col)
		"flask":
			_poly(ci, [Vector2(-0.22, -0.8), Vector2(-0.22, -0.15), Vector2(-0.8, 0.7), Vector2(0.8, 0.7), Vector2(0.22, -0.15), Vector2(0.22, -0.8)], c, r, col, w)
			ci.draw_line(c + Vector2(-0.34, -0.8) * r, c + Vector2(0.34, -0.8) * r, col, w, true)
		"hourglass":
			_poly(ci, [Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(-0.6, 0.8), Vector2(0.6, 0.8)], c, r, col, w, true)
		"chevrons":
			_poly(ci, [Vector2(-0.7, -0.6), Vector2(-0.05, 0.0), Vector2(-0.7, 0.6)], c, r, col, w * 1.3)
			_poly(ci, [Vector2(0.0, -0.6), Vector2(0.65, 0.0), Vector2(0.0, 0.6)], c, r, col, w * 1.3)
		"back":
			_poly(ci, [Vector2(0.6, -0.7), Vector2(-0.5, 0.0), Vector2(0.6, 0.7)], c, r, col, w * 1.3)
		"close":
			ci.draw_line(c + Vector2(-0.6, -0.6) * r, c + Vector2(0.6, 0.6) * r, col, w * 1.3, true)
			ci.draw_line(c + Vector2(0.6, -0.6) * r, c + Vector2(-0.6, 0.6) * r, col, w * 1.3, true)
		"shield":
			_poly(ci, [Vector2(-0.7, -0.75), Vector2(0.7, -0.75), Vector2(0.7, 0.05), Vector2(0, 0.9), Vector2(-0.7, 0.05)], c, r, col, w, true)
			ci.draw_line(c + Vector2(0, -0.75) * r, c + Vector2(0, 0.9) * r, col, w * 0.7, true)
			ci.draw_line(c + Vector2(-0.7, -0.2) * r, c + Vector2(0.7, -0.2) * r, col, w * 0.7, true)
		"dove":
			_ell(ci, c + Vector2(-0.05, 0.15) * r, r * 0.55, r * 0.28, col, w)
			ci.draw_arc(c + Vector2(0.5, -0.2) * r, r * 0.2, 0, TAU, 10, col, w, true)
			_poly(ci, [Vector2(-0.55, 0.1), Vector2(-0.95, -0.1), Vector2(-0.8, 0.35)], c, r, col, w)
			ci.draw_arc(c + Vector2(-0.1, -0.1) * r, r * 0.55, PI * 1.1, PI * 1.7, 10, col, w, true)
		"star":
			var p := PackedVector2Array()
			for i in 11: p.append(c + Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * r * (0.9 if i % 2 == 0 else 0.4))
			ci.draw_polyline(p, col, w, true)
		_:
			ci.draw_arc(c, r * 0.7, 0, TAU, 16, col, w, true)

## ornamental divider: ——— ◆ ———
static func rule(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var mid := (x0 + x1) * 0.5
	ci.draw_line(Vector2(x0, y), Vector2(mid - 9, y), col, 1.0, true)
	ci.draw_line(Vector2(mid + 9, y), Vector2(x1, y), col, 1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(mid - 5, y), Vector2(mid, y - 4), Vector2(mid + 5, y), Vector2(mid, y + 4)]), col)
	ci.draw_line(Vector2(x0, y + 3), Vector2(mid - 22, y + 3), Color(col.r, col.g, col.b, col.a * 0.45), 1.0, true)
	ci.draw_line(Vector2(mid + 22, y + 3), Vector2(x1, y + 3), Color(col.r, col.g, col.b, col.a * 0.45), 1.0, true)
