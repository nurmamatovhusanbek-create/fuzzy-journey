## Icon grammar (art bible 7.3): every glyph is drawn from primitives on a 24 x 24 grid (live area 20 x 20, origin at the centre),
## square caps, 45 / 90 degree angles, stroke by optical size (<= 17 px: 1.5, 18-27 px: 2, larger: 2.5), coordinates snapped to the pixel.
## Outline = available / default, filled = active (TBGlyph.draw_filled). Single colour per icon. The shapes are const data, so a draw allocates nothing.
## Ops: ["p", [x0,y0,x1,y1,...], closed]  straight strokes with square caps (closed: 1 = fillable, 2 = outline only)
##      ["P", [...], closed]               smooth polyline (curves)         ["c", x, y, r]  ring       ["d", x, y, r]  dot
##      ["a", x, y, r, deg0, deg1]         arc                              ["E", x, y, rx, ry]  ellipse ring
##      ["f", [...]]                       filled polygon (delta triangles, arrow head)
##      ["pk" / "dk" ...]                  marks that are knocked out of a filled glyph (the ! of warning, the i of info)
class_name TBGlyph
extends RefCounted

const G := {
	"coin": [["c", 0, 0, 9], ["pk", [0, -4, 0, 4]], ["pk", [-2.5, -4, 2.5, -4]], ["pk", [-2.5, 4, 2.5, 4]]],
	"men": [["c", 0, -4.5, 3.5], ["p", [-8, 9, -8, 5, -4, 2, 4, 2, 8, 5, 8, 9], 1]],
	"swords": [["p", [-8, -8, 8, 8]], ["p", [8, -8, -8, 8]], ["p", [1.5, 6.5, 6.5, 1.5]], ["p", [-6.5, 1.5, -1.5, 6.5]]],
	"scroll": [["p", [-8, -9, 4, -9, 8, -5, 8, 9, -8, 9], 1], ["p", [-4, -3, 4, -3]], ["p", [-4, 1, 4, 1]], ["p", [-4, 5, 1, 5]]],
	"book": [["p", [-10, -6, 0, -4, 10, -6, 10, 6, 0, 8, -10, 6], 1], ["p", [0, -4, 0, 8]]],
	"eye": [["P", [-10, 0, -7.5, -2.2, -5, -3.75, -2.5, -4.7, 0, -5, 2.5, -4.7, 5, -3.75, 7.5, -2.2, 10, 0, 7.5, 2.2, 5, 3.75, 2.5, 4.7, 0, 5, -2.5, 4.7, -5, 3.75, -7.5, 2.2], 1], ["c", 0, 0, 2.6], ["d", 0, 0, 1.0]],
	"flag": [["p", [-6, -10, -6, 10]], ["p", [-6, -9, 9, -4, -6, 1], 1]],
	"globe": [["co", 0, 0, 9], ["E", 0, 0, 4, 9], ["p", [-9, 0, 9, 0]]],
	"scales": [["p", [0, -9, 0, 8]], ["p", [-4, 9, 4, 9]], ["p", [-6.5, -6, 6.5, -6]], ["p", [-6.5, -6, -3, 1, -10, 1], 1], ["p", [6.5, -6, 10, 1, 3, 1], 1]],
	"coins": [["E", 0, -5, 8, 2.6], ["E", 0, 0, 8, 2.6], ["E", 0, 5, 8, 2.6], ["p", [-8, -5, -8, 5]], ["p", [8, -5, 8, 5]]],
	"trophy": [["p", [-6, -9, 6, -9, 5, -2, 2, 2, 2, 5, 5, 8, -5, 8, -2, 5, -2, 2, -5, -2], 1], ["a", -7, -4.5, 3.5, 90, 270], ["a", 7, -4.5, 3.5, -90, 90]],
	"lamp": [["a", 0, -1.5, 5.5, 144, 396], ["p", [-3, 5, 3, 5]], ["p", [-2, 8, 2, 8]], ["p", [0, -9.5, 0, -8]], ["p", [-6.6, -8.1, -5.5, -7]], ["p", [6.6, -8.1, 5.5, -7]]],
	"save": [["p", [-8, 2, -8, 8, 8, 8, 8, 2]], ["p", [0, -9, 0, 3]], ["p", [-4, -1, 0, 3, 4, -1]]],
	"crown": [["p", [-8, 6, -8, -5, -4, 0, 0, -8, 4, 0, 8, -5, 8, 6], 1]],
	"skull": [["a", 0, -1.5, 8.5, 180, 360], ["p", [-8.5, -1.5, -6, 5, -3, 5, -3, 9, 3, 9, 3, 5, 6, 5, 8.5, -1.5]], ["d", -3.5, 0, 2], ["d", 3.5, 0, 2]],
	"pin": [["a", 0, -2.5, 6.5, 140, 400], ["p", [-5, 1.7, 0, 10, 5, 1.7]], ["d", 0, -2.5, 2]],
	"flask": [["p", [-2.5, -9, -2.5, -2, -8, 8, 8, 8, 2.5, -2, 2.5, -9], 1], ["p", [-4.5, -9, 4.5, -9]]],
	"hourglass": [["p", [-6, -9, 6, -9, -6, 9, 6, 9], 2]],
	"chevrons": [["p", [-8, -7, -1, 0, -8, 7]], ["p", [0, -7, 7, 0, 0, 7]]],
	"back": [["p", [6, -8, -4, 0, 6, 8]]],
	"close": [["p", [-6, -6, 6, 6]], ["p", [6, -6, -6, 6]]],
	"shield": [["p", [-8, -9, 8, -9, 8, 0, 0, 10, -8, 0], 1], ["p", [0, -9, 0, 10]]],
	"dove": [["P", [-10, 3, -6, 0, -2, -1.5, 2, -1, 5, 0.5, 8, 0, 5, 3.5, 1, 5.5, -4, 5.5], 1], ["c", 6.5, -3.5, 2.2], ["p", [-2, -1, -6, -9, 2, -4]]],
	"warning": [["p", [0, -9, 10, 8, -10, 8], 1], ["pk", [0, -3, 0, 2]], ["dk", 0, 5, 1.1]],
	"info": [["c", 0, 0, 9], ["dk", 0, -4, 1.2], ["pk", [0, -1, 0, 5]]],
	"link": [["c", -4.5, 0, 5], ["c", 4.5, 0, 5]],
	"lock": [["p", [-6, -1, 6, -1, 6, 9, -6, 9], 1], ["a", 0, -4, 4, 180, 360], ["p", [-4, -4, -4, -1]], ["p", [4, -4, 4, -1]], ["dk", 0, 4, 1.4]],
	"check": [["p", [-8, 0, -3, 6, 8, -6]]],
	"filter": [["p", [-9, -8, 9, -8, 2, 0, 2, 8, -2, 6, -2, 0], 1]],
	"supply": [["p", [-9, -6, 6, -6, 4, 2, -7, 2], 1], ["p", [6, -6, 10, -6]], ["c", -4, 6, 2.6], ["c", 3, 6, 2.6]],
	"diamond": [["f", [0, -8, 8, 0, 0, 8, -8, 0]]],
	"tri_up": [["f", [0, -7, 8, 6, -8, 6]]],
	"tri_down": [["f", [0, 7, 8, -6, -8, -6]]],
	"arrowhead": [["f", [-6, -6.5, 8, 0, -6, 6.5]]],
}
## drawn only from 20 px up (16 px icons keep to the essentials)
const G_DETAIL := {
	"globe": [["p", [-7.5, -4.5, 7.5, -4.5]], ["p", [-7.5, 4.5, 7.5, 4.5]]],
	"shield": [["p", [-8, -3, 8, -3]]],
	"book": [["p", [-7, -1, -3, 0], 0], ["p", [3, 0, 7, -1], 0]],
}

static var _ci: CanvasItem
static var _c := Vector2.ZERO
static var _u := 1.0
static var _s := 2.0
static var _st := 1.0
static var _col := Color.WHITE
static var _knock := Color.BLACK
static var _fill := false
static var _scratch := PackedVector2Array()

## stroke width for an icon drawn at `size` px (art bible 7.3)
static func stroke_for(size: float) -> float:
	return 1.5 if size <= 17.0 else (2.0 if size <= 27.0 else 2.5)

static func _pt(x: float, y: float) -> Vector2:
	var v := _c + Vector2(x, y) * _u
	return Vector2(roundf(v.x / _st) * _st, roundf(v.y / _st) * _st)

static func _seg(a: Vector2, b: Vector2) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01: return
	var e := d / l * (_s * 0.5)              # square caps: extend both ends by half the stroke
	_ci.draw_line(a - e, b + e, _col, _s, not (is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y)))

static func _poly(f: Array, closed: int, knock: bool) -> void:
	var n: int = f.size() / 2
	var col := _col
	if knock: col = _knock
	if closed == 1 and _fill and not knock:
		_scratch.resize(n)
		for i in n: _scratch[i] = _pt(f[i * 2], f[i * 2 + 1])
		_ci.draw_colored_polygon(_scratch, _col)
		return
	var saved := _col
	_col = col
	for i in n - 1: _seg(_pt(f[i * 2], f[i * 2 + 1]), _pt(f[i * 2 + 2], f[i * 2 + 3]))
	if closed != 0: _seg(_pt(f[n * 2 - 2], f[n * 2 - 1]), _pt(f[0], f[1]))
	_col = saved

static func _smooth(f: Array, closed: int) -> void:
	var n: int = f.size() / 2
	_scratch.resize(n + (1 if closed != 0 else 0))
	for i in n: _scratch[i] = _c + Vector2(f[i * 2], f[i * 2 + 1]) * _u
	if closed != 0: _scratch[n] = _scratch[0]
	_ci.draw_polyline(_scratch, _col, _s, true)

static func _ellipse(x: float, y: float, rx: float, ry: float) -> void:
	_scratch.resize(25)
	for i in 25: _scratch[i] = _c + Vector2(x + cos(i * TAU / 24.0) * rx, y + sin(i * TAU / 24.0) * ry) * _u
	_ci.draw_polyline(_scratch, _col, _s, true)

static func _ops(ops: Array) -> void:
	for op in ops:
		match op[0]:
			"p": _poly(op[1], op[2] if op.size() > 2 else 0, false)
			"pk": _poly(op[1], 0, _fill)
			"P": _smooth(op[1], op[2] if op.size() > 2 else 0)
			"c":
				var cc := _c + Vector2(op[1], op[2]) * _u
				if _fill: _ci.draw_circle(cc, op[3] * _u + _s * 0.5, _col)
				else: _ci.draw_arc(cc, op[3] * _u, 0.0, TAU, 32, _col, _s, true)
			"co": _ci.draw_arc(_c + Vector2(op[1], op[2]) * _u, op[3] * _u, 0.0, TAU, 32, _col, _s, true)
			"d": _ci.draw_circle(_c + Vector2(op[1], op[2]) * _u, maxf(op[3] * _u, _s * 0.5), _col)
			"dk": _ci.draw_circle(_c + Vector2(op[1], op[2]) * _u, maxf(op[3] * _u, _s * 0.5), _knock if _fill else _col)
			"a": _ci.draw_arc(_c + Vector2(op[1], op[2]) * _u, op[3] * _u, deg_to_rad(op[4]), deg_to_rad(op[5]), 20, _col, _s, true)
			"E": _ellipse(op[1], op[2], op[3], op[4])
			"f":
				var f: Array = op[1]
				var n: int = f.size() / 2
				_scratch.resize(n)
				for i in n: _scratch[i] = _pt(f[i * 2], f[i * 2 + 1])
				_ci.draw_colored_polygon(_scratch, _col)

static func _star(r_out: float, r_in: float, filled: bool) -> void:
	_scratch.resize(11)
	for i in 11: _scratch[i] = _c + Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * (r_out if i % 2 == 0 else r_in) * _u
	if filled:
		_scratch.resize(10)
		_ci.draw_colored_polygon(_scratch, _col)
		_scratch.resize(11); _scratch[10] = _scratch[0]
	_ci.draw_polyline(_scratch, _knock if filled else _col, 1.0 if filled else _s, true)

static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, _w: float = 1.6) -> void:
	_run(ci, name, c, size, col, false, TBTokens.c("bar_0"))

## active / on state: closed shapes filled, marks knocked out in `knock` (default the bar colour; pass the plate colour on paper)
static func draw_filled(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, knock: Color = Color.TRANSPARENT) -> void:
	_run(ci, name, c, size, col, true, knock if knock.a > 0.0 else TBTokens.c("bar_0"))

static func _run(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, filled: bool, knock: Color) -> void:
	_ci = ci; _c = c; _u = size / 24.0; _s = stroke_for(size); _st = 1.0 if _s == 2.0 else 0.5; _col = col; _knock = knock; _fill = filled
	match name:
		"gear":
			_ci.draw_arc(c, 3.5 * _u, 0.0, TAU, 20, col, _s, true)
			_ci.draw_arc(c, 6.5 * _u, 0.0, TAU, 28, col, _s, true)
			for i in 8:
				var d := Vector2(cos(i * TAU / 8.0), sin(i * TAU / 8.0))
				_ci.draw_line(c + d * 7.0 * _u, c + d * 10.0 * _u, col, _s * 1.5, true)
		"star": _star(10.0, 4.2, filled)
		"general_star":
			_col = TBTokens.c("brass_lt"); _col.a = col.a; _knock = TBTokens.c("ink_0")
			_star(10.0, 4.2, true)
		"revolt":                                    # unrest: a jagged burst
			_scratch.resize(17)
			for i in 17: _scratch[i] = c + Vector2(sin(i * PI / 8.0), -cos(i * PI / 8.0)) * (10.0 if i % 2 == 0 else 4.5) * _u
			_scratch[16] = _scratch[0]
			if filled:
				_scratch.resize(16); _ci.draw_colored_polygon(_scratch, col); _scratch.resize(17); _scratch[16] = _scratch[0]
			_ci.draw_polyline(_scratch, col, _s, true)
		"capital":                                   # a 10 px ring around a filled 6 px square (a star always means "general")
			var rr := size * 0.5
			_ci.draw_arc(c, rr - _s * 0.5, 0.0, TAU, 28, col, _s, true)
			var q := roundf(size * 0.6 * 0.5) * 2.0
			_ci.draw_rect(Rect2(Vector2(roundf(c.x - q * 0.5), roundf(c.y - q * 0.5)), Vector2(q, q)), col)
		_:
			if G.has(name):
				_ops(G[name])
				if size >= 20.0 and G_DETAIL.has(name): _ops(G_DETAIL[name])
			else:
				_ci.draw_arc(c, 7.0 * _u, 0.0, TAU, 20, col, _s, true)

## ornamental divider: --- + --- for hero sheets and the title screen only (D3); whole-pixel lines and a 5 px diamond
static func rule(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var yy := floorf(y) + 0.5
	var mid := roundf((x0 + x1) * 0.5)
	ci.draw_line(Vector2(roundf(x0), yy), Vector2(mid - 9.0, yy), col, 1.0)
	ci.draw_line(Vector2(mid + 9.0, yy), Vector2(roundf(x1), yy), col, 1.0)
	_scratch.resize(4)
	_scratch[0] = Vector2(mid - 5.0, yy); _scratch[1] = Vector2(mid, yy - 5.0); _scratch[2] = Vector2(mid + 5.0, yy); _scratch[3] = Vector2(mid, yy + 5.0)
	ci.draw_colored_polygon(_scratch, col)
