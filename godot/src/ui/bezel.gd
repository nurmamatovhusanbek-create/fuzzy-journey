## Bezel drawing primitives (docs/ui_variants/src/bezel_kit.js): brass instrument rings with graduated ticks, arc gauges, notched plates.
## Round = instrument, notched rectangle = document. Everything is drawn from TBTokens colours; callers pass any CanvasItem.
class_name TBBezel
extends RefCounted

const BRASS_HI := TBTokens.BZ_HI
const BRASS := TBTokens.BZ_BRASS
const BRASS_LO := TBTokens.BZ_LO
const TRACK := TBTokens.BZ_TRACK

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
static func ticks(ci: CanvasItem, c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float = 1.0, a0: float = 0.0, span: float = TAU) -> void:
	var cnt: int = n if span < TAU - 0.01 else n - 1
	var pts := PackedVector2Array()
	for i in cnt + 1:
		var a: float = a0 + span * i / n - PI * 0.5
		var l: float = len_px * (1.7 if (major > 0 and i % major == 0) else 1.0)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r); pts.append(c + d * (r - l))
	if pts.size() >= 2: ci.draw_multiline(pts, col, w)

## the instrument ring: soft shadow, brass gradient band, dark face, hairline and graduated ticks. Returns the face radius.
static func ring(ci: CanvasItem, c: Vector2, r: float, nt: int = 36, face: Color = Color.TRANSPARENT, shadow: bool = true) -> float:
	var band: float = clampf(r * 0.12, 2.5, 6.0)
	if face.a <= 0.0: face = TBTokens.c("bar_0")
	if shadow: ci.draw_circle(c + Vector2(0, 1.5), r + 1.5, TBTokens.DROP)
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
