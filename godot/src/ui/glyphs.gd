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
	"smile": [["c", 0, 0, 9], ["d", -3.3, -2.6, 1.3], ["d", 3.3, -2.6, 1.3], ["a", 0, 0, 5.2, 25, 155]],
	"diamond": [["f", [0, -8, 8, 0, 0, 8, -8, 0]]],
	"tri_up": [["f", [0, -7, 8, 6, -8, 6]]],
	"tri_down": [["f", [0, 7, 8, -6, -8, -6]]],
	"arrowhead": [["f", [-6, -6.5, 8, 0, -6, 6.5]]],
	"plus": [["p", [-7, 0, 7, 0]], ["p", [0, -7, 0, 7]]],
	"minus": [["p", [-7, 0, 7, 0]]],
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

# =====================================================================================================================================
# Bezel icon set: the demo's 40 icons (docs/ui_variants/src/bezel_kit.js `IC`): 24 x 24 grid, 1.7 stroke, round caps and joins, SVG path data.
# TBGlyph.draw_ic(ci, "treasury", centre, 22.0, colour) draws one; the shapes are parsed once into polylines (curves and arcs flattened).
# =====================================================================================================================================
const IC := {
	"nations": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3v18M6.5 6q5.500 6 11 0M6.500 18q5.500-6 11 0"/>',
	"treasury": '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5q0 3 7 3t7-3V7M5 12v5q0 3 7 3t7-3v-5"/>',
	"decrees": '<path d="M12 3v18M6 21h12M4 7h16M4 7l-2.500 7h5zM20 7l-2.500 7h5z"/>',
	"council": '<path d="M3 9l9-5 9 5zM5 20h14M6 9v8M10 9v8M14 9v8M18 9v8"/>',
	"annals": '<path d="M3 5q4.500-1.500 9 1.500q4.500-3 9-1.500v13q-4.500-1.500-9 1.500q-4.500-3-9-1.500zM12 6.500v13"/>',
	"goals": '<path d="M7 4h10v6q0 5-5 5t-5-5zM7 6.500H4q0 4 3 4.500M17 6.500h3q0 4-3 4.500M12 15v4M8 20h8"/>',
	"army": '<path d="M5 19L18 6M18 6h-4M18 6v4M19 19L6 6M6 6h4M6 6v4M3.500 17.500l3 3M20.500 17.500l-3 3"/>',
	"people": '<circle cx="9" cy="8" r="3.200"/><path d="M3 20q0-6 6-6t6 6M16 5.500a3 3 0 010 5.500M18 14q3 1 3 6"/>',
	"envoys": '<rect x="3" y="6" width="18" height="13" rx="1.500"/><path d="M3.500 7l8.500 7 8.500-7"/>',
	"gold": '<circle cx="12" cy="12" r="9"/><path d="M12 7v10M9.500 9.500q0-2 2.500-2t2.500 1.800q0 1.700-2.500 2.200t-2.500 2.200q0 1.800 2.500 1.800t2.500-2"/>',
	"move": '<path d="M3 12h16M13 6l6 6-6 6"/>',
	"recruit": '<circle cx="12" cy="12" r="9"/><path d="M12 7.500v9M7.500 12h9"/>',
	"build": '<path d="M4 20V10l8-6 8 6v10zM10 20v-6h4v6"/>',
	"fortify": '<path d="M4 20V7h3v3h2.500V7h5v3H17V7h3v13zM10 20v-4h4v4"/>',
	"attack": '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
	"pact": '<circle cx="9" cy="12" r="5.500"/><circle cx="15" cy="12" r="5.500"/>',
	"trade": '<path d="M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4"/>',
	"spy": '<path d="M2 12q4.500-7 10-7t10 7q-4.500 7-10 7T2 12z"/><circle cx="12" cy="12" r="3"/>',
	"war": '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
	"settings": '<circle cx="12" cy="12" r="3.500"/><path d="M12 2.500v3M12 18.500v3M2.500 12h3M18.500 12h3M5.300 5.300l2.100 2.100M16.600 16.600l2.100 2.100M5.300 18.700l2.100-2.100M16.600 7.400l2.100-2.100"/>',
	"save": '<path d="M12 4v11M7 11l5 5 5-5M4 20h16"/>',
	"load": '<path d="M12 16V5M7 9l5-5 5 5M4 20h16"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"warn": '<path d="M12 3L22 20H2zM12 10v5M12 17.500v.5"/>',
	"info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.500v.5"/>',
	"check": '<path d="M4 12.500l5 5L20 6.500"/>',
	"star": '<path d="M12 3l2.600 5.600 6.100.7-4.500 4.200 1.200 6L12 16.500 6.600 19.500l1.200-6L3.300 9.300l6.100-.7z"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.500 2"/>',
	"research": '<path d="M12 3v4M12 7L6 21M12 7l6 14M8.500 16h7"/><circle cx="12" cy="4" r="1.200"/>',
	"invest": '<path d="M4 19l5-6 4 3 7-9M15 7h5v5"/>',
	"tax": '<circle cx="8" cy="8" r="2.500"/><circle cx="16" cy="16" r="2.500"/><path d="M18 5L6 19"/>',
	"happy": '<circle cx="12" cy="12" r="9"/><path d="M8 14q4 4 8 0M9 9.500v.5M15 9.500v.5"/>',
	"terrain": '<path d="M2 19l7-12 4 7 3-4 6 9z"/>',
	"menu": '<path d="M4 7h16M4 12h16M4 17h16"/>',
	"flag": '<path d="M5 21V4M5 5h13l-3 4 3 4H5"/>',
	"lock": '<rect x="5" y="11" width="14" height="9" rx="1.500"/><path d="M8 11V8a4 4 0 018 0v3"/>',
	"crown": '<path d="M3 18l1.500-10 5 4L12 5l2.500 7 5-4L21 18zM4 21h16"/>',
	"skull": '<path d="M12 3q8 0 8 8 0 3-2 4.500V20H6v-4.500Q4 14 4 11q0-8 8-8zM9 12v1M15 12v1M10 17v3M14 17v3"/>',
	"heart": '<path d="M12 20S3 14 3 8.500A4.500 4.500 0 0112 7a4.500 4.500 0 019 1.500C21 14 12 20 12 20z"/>',
	"ship": '<path d="M3 15h18l-2.500 5h-13zM12 3v12M12 4l6 8h-6M12 6L7 12h5"/>',
}

## old glyph names of the earlier icon grammar -> the demo's icons (so call sites keep working while the screens move to the demo names)
const IC_ALIAS := {
	"coin": "gold", "coins": "treasury", "men": "people", "swords": "attack", "scroll": "annals", "book": "annals", "eye": "spy", "globe": "nations",
	"scales": "decrees", "trophy": "goals", "lamp": "research", "flask": "research", "gear": "settings", "pin": "terrain", "hourglass": "clock",
	"chevrons": "move", "back": "move", "shield": "fortify", "dove": "pact", "link": "pact", "warning": "warn", "filter": "menu", "supply": "trade",
	"smile": "happy", "plus": "recruit", "minus": "recruit", "diamond": "star", "tri_up": "invest", "tri_down": "invest", "arrowhead": "move",
	"revolt": "warn", "capital": "flag", "general_star": "star", "scroll2": "annals", "quill": "annals", "sword": "attack", "swords2": "war",
	"envoy": "envoys", "gold_coin": "gold", "population": "people", "manpower": "army", "host": "army", "diplomacy": "envoys",
}

static var _ic_cache := {}
static var _ps := ""
static var _pi := 0

static func ic_name(name: String) -> String:
	if IC.has(name): return name
	return String(IC_ALIAS.get(name, ""))

static func _p_skip() -> void:
	while _pi < _ps.length() and (_ps[_pi] == " " or _ps[_pi] == "," or _ps[_pi] == "\n" or _ps[_pi] == "\t"): _pi += 1

static func _p_letter() -> bool:
	_p_skip()
	if _pi >= _ps.length(): return false
	var u: int = _ps.unicode_at(_pi)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122)

static func _p_num() -> float:
	_p_skip()
	var st := _pi
	if _pi < _ps.length() and (_ps[_pi] == "-" or _ps[_pi] == "+"): _pi += 1
	var dot := false
	while _pi < _ps.length():
		var ch: String = _ps[_pi]
		if ch >= "0" and ch <= "9": _pi += 1
		elif ch == "." and not dot: dot = true; _pi += 1
		else: break
	return _ps.substr(st, _pi - st).to_float()

static func _p_flag() -> bool:
	_p_skip()
	var f: bool = _ps[_pi] == "1"
	_pi += 1
	return f

static func _arc_pts(p0: Vector2, rx: float, ry: float, phi_deg: float, large: bool, sweep: bool, p1: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p0 == p1: return out
	rx = absf(rx); ry = absf(ry)
	if rx < 0.0001 or ry < 0.0001:
		out.append(p1); return out
	var phi: float = deg_to_rad(phi_deg)
	var cp: float = cos(phi); var sp: float = sin(phi)
	var dx: float = (p0.x - p1.x) * 0.5; var dy: float = (p0.y - p1.y) * 0.5
	var x1p: float = cp * dx + sp * dy; var y1p: float = -sp * dx + cp * dy
	var lam: float = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
	if lam > 1.0:
		var s: float = sqrt(lam); rx *= s; ry *= s
	var num: float = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
	var den: float = rx * rx * y1p * y1p + ry * ry * x1p * x1p
	var co: float = sqrt(maxf(0.0, num / den)) if den != 0.0 else 0.0
	if large == sweep: co = -co
	var cxp: float = co * rx * y1p / ry; var cyp: float = -co * ry * x1p / rx
	var cx: float = cp * cxp - sp * cyp + (p0.x + p1.x) * 0.5
	var cy: float = sp * cxp + cp * cyp + (p0.y + p1.y) * 0.5
	var th1: float = atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
	var th2: float = atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
	var dth: float = th2 - th1
	if sweep and dth < 0.0: dth += TAU
	elif not sweep and dth > 0.0: dth -= TAU
	var steps: int = maxi(4, ceili(absf(dth) / deg_to_rad(9.0)))
	for i in range(1, steps + 1):
		var t: float = th1 + dth * i / steps
		var ex: float = rx * cos(t); var ey: float = ry * sin(t)
		out.append(Vector2(cp * ex - sp * ey + cx, sp * ex + cp * ey + cy))
	out[out.size() - 1] = p1
	return out

static func _parse_d(d: String, subs: Array) -> void:
	_ps = d; _pi = 0
	var cur := Vector2.ZERO; var start := Vector2.ZERO; var c2 := Vector2.ZERO; var q1 := Vector2.ZERO
	var cmd := ""; var prev := ""
	var pts := PackedVector2Array(); var cor := PackedByteArray(); var closed := false
	var have := false
	while true:
		_p_skip()
		if _pi >= _ps.length(): break
		if _p_letter(): cmd = _ps[_pi]; _pi += 1
		var rel: bool = cmd == cmd.to_lower()
		var u: String = cmd.to_upper()
		if u != "S" and u != "C": pass
		match u:
			"M":
				if have: subs.append({"pts": pts, "corner": cor, "closed": closed})
				var x: float = _p_num(); var y: float = _p_num()
				cur = cur + Vector2(x, y) if rel else Vector2(x, y)
				start = cur; pts = PackedVector2Array([cur]); cor = PackedByteArray([1]); closed = false; have = true
				cmd = "l" if rel else "L"
			"L":
				var x: float = _p_num(); var y: float = _p_num()
				cur = cur + Vector2(x, y) if rel else Vector2(x, y)
				pts.append(cur); cor.append(1)
			"H":
				var x: float = _p_num()
				cur = Vector2(cur.x + x if rel else x, cur.y); pts.append(cur); cor.append(1)
			"V":
				var y: float = _p_num()
				cur = Vector2(cur.x, cur.y + y if rel else y); pts.append(cur); cor.append(1)
			"C", "S":
				var p1: Vector2
				if u == "C":
					var a: float = _p_num(); var b: float = _p_num()
					p1 = Vector2(a, b) + (cur if rel else Vector2.ZERO)
				else:
					p1 = cur + (cur - c2) if prev in ["C", "S"] else cur
				var a2: float = _p_num(); var b2: float = _p_num(); var a3: float = _p_num(); var b3: float = _p_num()
				var p2: Vector2 = Vector2(a2, b2) + (cur if rel else Vector2.ZERO)
				var p3: Vector2 = Vector2(a3, b3) + (cur if rel else Vector2.ZERO)
				for k in range(1, 13):
					var t: float = k / 12.0; var mt: float = 1.0 - t
					pts.append(mt * mt * mt * cur + 3.0 * mt * mt * t * p1 + 3.0 * mt * t * t * p2 + t * t * t * p3); cor.append(0)
				cor[cor.size() - 1] = 1
				c2 = p2; cur = p3
			"Q", "T":
				var p1: Vector2
				if u == "Q":
					var a: float = _p_num(); var b: float = _p_num()
					p1 = Vector2(a, b) + (cur if rel else Vector2.ZERO)
				else:
					p1 = cur + (cur - q1) if prev in ["Q", "T"] else cur
				var a3: float = _p_num(); var b3: float = _p_num()
				var p3: Vector2 = Vector2(a3, b3) + (cur if rel else Vector2.ZERO)
				for k in range(1, 11):
					var t: float = k / 10.0; var mt: float = 1.0 - t
					pts.append(mt * mt * cur + 2.0 * mt * t * p1 + t * t * p3); cor.append(0)
				cor[cor.size() - 1] = 1
				q1 = p1; cur = p3
			"A":
				var rx: float = _p_num(); var ry: float = _p_num(); var rot: float = _p_num()
				var large: bool = _p_flag(); var sweep: bool = _p_flag()
				var x: float = _p_num(); var y: float = _p_num()
				var p3: Vector2 = Vector2(x, y) + (cur if rel else Vector2.ZERO)
				var ap := _arc_pts(cur, rx, ry, rot, large, sweep, p3)
				for p in ap: pts.append(p); cor.append(0)
				if ap.size() > 0: cor[cor.size() - 1] = 1
				cur = p3
			"Z":
				closed = true; cur = start
				if pts.size() > 0 and pts[pts.size() - 1] != start: pts.append(start); cor.append(1)
				subs.append({"pts": pts, "corner": cor, "closed": true}); have = false
				pts = PackedVector2Array(); cor = PackedByteArray()
				# a path continuing after z starts a new subpath at the start point
				_p_skip()
				if _pi < _ps.length() and _p_letter() and _ps[_pi].to_upper() != "M":
					pts = PackedVector2Array([start]); cor = PackedByteArray([1]); have = true; closed = false
				continue
		prev = u
	if have and pts.size() > 0: subs.append({"pts": pts, "corner": cor, "closed": closed})

static func _ellipse_shape(cx: float, cy: float, rx: float, ry: float) -> Dictionary:
	var pts := PackedVector2Array(); var cor := PackedByteArray()
	for i in 41:
		var a: float = TAU * i / 40.0
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry)); cor.append(0)
	return {"pts": pts, "corner": cor, "closed": true}

static func ic_shapes(name: String) -> Array:
	var nm := ic_name(name)
	if nm == "": return []
	if _ic_cache.has(nm): return _ic_cache[nm]
	var subs: Array = []
	var re_el := RegEx.new(); re_el.compile("<(\\w+)([^>]*)/>")
	var re_at := RegEx.new(); re_at.compile("(\\w+)=\"([^\"]*)\"")
	for m in re_el.search_all(String(IC[nm])):
		var at := {}
		for a in re_at.search_all(m.get_string(2)): at[a.get_string(1)] = a.get_string(2)
		match m.get_string(1):
			"path": _parse_d(String(at.get("d", "")), subs)
			"circle": subs.append(_ellipse_shape(float(at["cx"]), float(at["cy"]), float(at["r"]), float(at["r"])))
			"ellipse": subs.append(_ellipse_shape(float(at["cx"]), float(at["cy"]), float(at["rx"]), float(at["ry"])))
			"rect":
				var x: float = float(at["x"]); var y: float = float(at["y"]); var w: float = float(at["width"]); var h: float = float(at["height"])
				var r: float = float(at.get("rx", "0"))
				var d := "M%f %fH%fa%f %f 0 01%f %fV%fa%f %f 0 01%f %fH%fa%f %f 0 01%f %fV%fa%f %f 0 01%f %fz" % [x + r, y, x + w - r, r, r, r, r, y + h - r, r, r, -r, r, x + r, r, r, -r, -r, y + r, r, r, r, -r]
				_parse_d(d, subs)
	_ic_cache[nm] = subs
	return subs

## one demo icon: centre c, `size` units square (the 24 grid scaled), stroke `w` on the 24 grid (1.7 by default), round caps and joins
static func draw_ic(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, w: float = 1.7) -> void:
	var shapes := ic_shapes(name)
	if shapes.is_empty():
		ci.draw_arc(c, size * 0.3, 0.0, TAU, 20, col, w * size / 24.0, true)
		return
	var k: float = size / 24.0
	var o: Vector2 = c - Vector2(size, size) * 0.5
	var sw: float = maxf(w * k - 0.85, 0.5)                    # Godot's antialiased lines add a ~1 px feather: take it off the stroke so the weight matches the SVG
	for sh in shapes:
		var src: PackedVector2Array = sh["pts"]
		var cor: PackedByteArray = sh["corner"]
		var n: int = src.size()
		if n < 2: continue
		var pts := PackedVector2Array()
		pts.resize(n)
		for i in n: pts[i] = o + src[i] * k
		ci.draw_polyline(pts, col, sw, true)
		if sw >= 1.2:                                           # round caps and joins
			var rr: float = sw * 0.5
			var closed: bool = sh["closed"]
			for i in n:
				if cor[i] == 1 and not (closed and i == n - 1): ci.draw_circle(pts[i], rr, col)
