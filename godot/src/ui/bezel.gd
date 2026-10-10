## Bezel drawing primitives (docs/ui_variants/src/bezel_kit.js): brass instrument rings with graduated ticks, arc gauges, notched plates.
## Round = instrument, notched rectangle = document. Everything is drawn from TBTokens colours; callers pass any CanvasItem.
class_name TBBezel
extends RefCounted

const BRASS_HI := TBTokens.BZ_HI
const BRASS := TBTokens.BZ_BRASS
const BRASS_LO := TBTokens.BZ_LO
const TRACK := TBTokens.BZ_TRACK

## Godot widens an antialiased stroke by about 0.8 *screen pixel* of feather; the demo (a browser) does not. aw() is the width, in layout units, to ask for to get
## the demo's: `ppu` = screen pixels per layout unit (the HUD sets it from the window's stretch whenever it lays out).
static var ppu: float = 1.0
static func aw(w: float) -> float: return maxf(0.5, w - 0.8 / maxf(0.2, ppu))
## a hairline thinner than the narrowest antialiased stroke (0.5 + feather) is drawn at that width and its alpha lowered by the extra coverage
static func ac(col: Color, w: float) -> Color:
	var cov: float = aw(w) + 0.8 / maxf(0.2, ppu)
	return Color(col.r, col.g, col.b, col.a * clampf(w / cov, 0.0, 1.0))

## 12 arc segments from light (top left) to dark (bottom right): the brass gradient of the ring
static func _brass_arc(ci: CanvasItem, c: Vector2, r: float, w: float, a0: float = 0.0, a1: float = TAU) -> void:
	var n: int = 14
	for i in n:
		var t0: float = a0 + (a1 - a0) * i / n
		var t1: float = a0 + (a1 - a0) * (i + 1) / n + 0.04
		var mid: float = (t0 + t1) * 0.5
		var k: float = 0.5 + 0.5 * cos(mid + PI * 0.75)            # 1 at top left, 0 at bottom right
		var col: Color = BRASS_LO.lerp(BRASS, clampf(k * 1.6, 0.0, 1.0)).lerp(BRASS_HI, clampf((k - 0.62) * 2.2, 0.0, 1.0))
		ci.draw_arc(c, r, t0, t1, 6, col, w, true)

## graduated marks on a circle: `n` marks, every `major`-th longer
static func ticks(ci: CanvasItem, c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float = 1.0, a0: float = 0.0, span: float = TAU, aa: bool = false) -> void:
	var cnt: int = n if span < TAU - 0.01 else n - 1
	var pts := PackedVector2Array()
	for i in cnt + 1:
		var a: float = a0 + span * i / n - PI * 0.5
		var l: float = len_px * (1.7 if (major > 0 and i % major == 0) else 1.0)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r); pts.append(c + d * (r - l))
	if pts.size() >= 2:
		if aa:
			var cc: Color = ac(col, w)
			for i in range(0, pts.size() - 1, 2): ci.draw_line(pts[i], pts[i + 1], cc, aw(w), true)
		else: ci.draw_multiline(pts, col, w)

## the instrument ring: a light brass hairline round a dark face with graduated ticks just inside it. Returns the face radius.
## `bold` is the heavy gradient band, kept only for the End Turn dial.
static func ring(ci: CanvasItem, c: Vector2, r: float, nt: int = 36, face: Color = Color.TRANSPARENT, shadow: bool = true, bold: bool = false, k: float = 1.0) -> float:
	if face.a <= 0.0: face = TBTokens.c("bar_0")
	if not bold:                                       # bezelSvg(light): soft shadow disc, face, brass hairline, graduated ticks (bezel_kit.js); k = the svg's scale
		if shadow: ci.draw_circle(c, r + 2.0 * k, TBTokens.with_a(TBTokens.BZ_SHADOW, 0.35))
		ci.draw_circle(c, r, face)
		ci.draw_arc(c, r - 0.7 * k, 0.0, TAU, maxi(48, int(r * 1.6)), ac(TBTokens.with_a(BRASS, 0.85), 1.3 * k), aw(1.3 * k), true)
		if nt > 0 and r >= 14.0 * k: ticks(ci, c, r - 3.0 * k, nt, 3.2 * k, 5, tick_col(), 0.7 * k, 0.0, TAU, true)
		return r - clampf(r * 0.12, 2.5, 6.0)          # content (glyphs, numbers, flags) is sized from the old band-width face, so a lighter ring does not make everything inside it bigger
	if shadow: ci.draw_circle(c + Vector2(0, 1.5), r + 1.5, TBTokens.DROP)
	var band: float = clampf(r * 0.12, 2.5, 6.0)
	_brass_arc(ci, c, r - band * 0.5, band)
	var fr: float = r - band
	ci.draw_circle(c, fr, face)
	ci.draw_arc(c, fr, 0.0, TAU, 48, Color(BRASS_HI, 0.55), 1.0, true)
	if nt > 0 and r >= 14.0: ticks(ci, c, fr - 1.0, nt, clampf(r * 0.07, 1.5, 3.0), 6, Color(BRASS, 0.75), 1.0)
	return fr

## 270 degree gauge: dark track and a fill arc, starting at the lower left (-135 degrees from the top) and running clockwise
static func gauge(ci: CanvasItem, c: Vector2, r: float, frac: float, col: Color, w: float = 3.0) -> void:
	var a0: float = -PI * 0.75 - PI * 0.5
	var a1: float = PI * 0.75 - PI * 0.5
	ci.draw_arc(c, r, a0, a1, 40, TRACK, w, true)
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.01: ci.draw_arc(c, r, a0, a0 + (a1 - a0) * f, maxi(6, int(40 * f)), col, w, true)

## ring ticks / graduated hairlines: the demo's #8f7637 (high contrast: the bar rule colour)
static func tick_col() -> Color: return TBTokens.c("rule_dark") if TBTokens.is_hc() else TBTokens.BZ_TICK

## an arc in the demo's convention: degrees, 0 at the top, clockwise (arcD in bezel_kit.js); `round_caps` = stroke-linecap round
static func arc_deg(ci: CanvasItem, c: Vector2, r: float, d0: float, d1: float, col: Color, w: float, round_caps: bool = false) -> void:
	if d1 - d0 <= 0.0 or r <= 0.0: return
	var n: int = maxi(6, int(absf(d1 - d0) / 4.0))
	ci.draw_arc(c, r, deg_to_rad(d0 - 90.0), deg_to_rad(d1 - 90.0), n, ac(col, w), aw(w), true)
	if round_caps:
		for d in [d0, d1]:
			ci.draw_circle(c + Vector2(sin(deg_to_rad(d)), -cos(deg_to_rad(d))) * r, w * 0.5, col)

## the 270 degree instrument gauge (gaugeSvg): dark track and a coloured arc from the lower left (-135 degrees) clockwise with round caps,
## 20 hairline ticks outside. `r` is the demo's gauge radius (30 on a desktop): the ring is r+8, the arc r-6, the ticks r+3.
static func gauge_demo(ci: CanvasItem, c: Vector2, r: float, frac: float, col: Color) -> void:
	ring(ci, c, r + 8.0, 0)
	arc_deg(ci, c, r - 6.0, -135.0, 135.0, TRACK, 3.2)
	arc_deg(ci, c, r - 6.0, -135.0, -135.0 + 270.0 * maxf(0.001, clampf(frac, 0.0, 1.0)), col, 3.2, true)
	ticks(ci, c, r + 3.0, 20, 3.0, 5, BRASS_LO, 0.8, deg_to_rad(-135.0), deg_to_rad(270.0), true)

## soft glow round a circle (CSS drop-shadow(0 0 blur colour)): stacked translucent discs fading outward
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, blur: float, steps: int = 8) -> void:
	for i in steps:
		var k: float = 1.0 - float(i) / steps
		ci.draw_circle(c, r + blur * k, Color(col.r, col.g, col.b, col.a * 0.5 / steps))

## a disc filled with the demo's diagonal brass gradient (linearGradient x1=0 y1=0 x2=1 y2=1 over the bounding box); stops: [[offset, Color], ...]
static func grad_disc(ci: CanvasItem, c: Vector2, r: float, stops: Array, n: int = 40) -> void:
	var col_at := func(p: Vector2) -> Color:
		var t: float = clampf(((p.x - (c.x - r)) + (p.y - (c.y - r))) / (4.0 * r), 0.0, 1.0)
		for i in stops.size() - 1:
			var a: Array = stops[i]; var b: Array = stops[i + 1]
			if t <= float(b[0]):
				return (a[1] as Color).lerp(b[1] as Color, (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
		return stops[stops.size() - 1][1]
	var cc: Color = col_at.call(c)
	for i in n:
		var a0: float = TAU * i / n; var a1: float = TAU * (i + 1) / n
		var p0: Vector2 = c + Vector2(cos(a0), sin(a0)) * r
		var p1: Vector2 = c + Vector2(cos(a1), sin(a1)) * r
		ci.draw_primitive(PackedVector2Array([c, p0, p1]), PackedColorArray([cc, col_at.call(p0), col_at.call(p1)]), PackedVector2Array())

## the notched polygon of the demo's plates: 45 degree corners of `cut`
static func notch(r: Rect2, cut: float) -> PackedVector2Array:
	var x0: float = r.position.x; var y0: float = r.position.y; var x1: float = r.end.x; var y1: float = r.end.y
	cut = clampf(cut, 0.0, minf(r.size.x, r.size.y) * 0.5)
	return PackedVector2Array([Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, y0 + cut), Vector2(x1, y1 - cut), Vector2(x1 - cut, y1), Vector2(x0 + cut, y1), Vector2(x0, y1 - cut), Vector2(x0, y0 + cut)])

## CSS drop-shadow of a notched plate (offset dy down, blur radius): translucent copies from shrunk to grown, so the shadow is half strength at the offset edge and gone `blur` beyond it
static func plate_shadow(ci: CanvasItem, r: Rect2, cut: float, dy: float, blur: float, col: Color) -> void:
	var n: int = 10
	for i in n:
		var g: float = blur * 0.9 * (2.0 * float(i) / (n - 1) - 1.0)
		ci.draw_colored_polygon(notch(Rect2(r.position + Vector2(0, dy), r.size).grow(g), maxf(0.0, cut + g * 0.4)), Color(col.r, col.g, col.b, col.a / n))

## a graduated ruler (minor mark every `step`, major every `major` marks) along a horizontal span
static func ruler_h(ci: CanvasItem, x0: float, x1: float, y: float, step: float, major: int, col: Color, len_px: float = 4.0, up: bool = false) -> void:
	var pts := PackedVector2Array()
	var i: int = 0
	var x: float = x0
	while x <= x1 + 0.1:
		var l: float = len_px * (1.8 if i % major == 0 else 1.0)
		pts.append(Vector2(x, y)); pts.append(Vector2(x, y + (-l if up else l)))
		x += step; i += 1
	if pts.size() >= 2: ci.draw_multiline(pts, col, 1.0)

static func ruler_v(ci: CanvasItem, y0: float, y1: float, x: float, step: float, major: int, col: Color, len_px: float = 4.0, left: bool = false) -> void:
	var pts := PackedVector2Array()
	var i: int = 0
	var y: float = y0
	while y <= y1 + 0.1:
		var l: float = len_px * (1.8 if i % major == 0 else 1.0)
		pts.append(Vector2(x, y)); pts.append(Vector2(x + (-l if left else l), y))
		y += step; i += 1
	if pts.size() >= 2: ci.draw_multiline(pts, col, 1.0)

## notched plate: 45 degree corners, brass hairline
static func plate(ci: CanvasItem, r: Rect2, fill: Color, edge: Color = Color.TRANSPARENT, cut: float = 6.0, edge_w: float = 1.0) -> void:
	TBHudParts.plate(ci, r, fill, edge if edge.a > 0.0 else TBTokens.c("rule"), cut, Color.TRANSPARENT, 0.0, edge_w)

## a diamond mark (status / bullet)
static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	TBHudParts.diamond(ci, c, s, col, true)

static func ink() -> Color: return TBTokens.c("ink_0")
static func dim() -> Color: return TBTokens.c("ink_1")
static func hi() -> Color: return TBTokens.c("brass_lt")
