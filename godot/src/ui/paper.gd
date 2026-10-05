## Procedural materials for the "cartographer's table" look: laid paper, aged vellum, wax, umber leather.
## Everything is generated once from native noise (a fraction of a second) and cached; no image assets.
class_name TBPaper
extends RefCounted

enum { SHEET, VELLUM, WAX, LEATHER }
const SIZE := 256

static var _tex := {}

## grey noise -> tinted RGBA between two colours (contrast shaped so the texture only gently modulates the vertex colour)
static func _make(kind: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 1 + kind * 7
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.frequency = 0.018 if kind != LEATHER else 0.05
	var cloud := n.get_image(SIZE, SIZE, false, true)           # seamless
	var g := FastNoiseLite.new()
	g.noise_type = FastNoiseLite.TYPE_SIMPLEX
	g.seed = 99 + kind
	g.frequency = 0.55 if kind != LEATHER else 0.9              # grain
	var grain := g.get_image(SIZE, SIZE, false, true)
	var cd := cloud.get_data(); var gd := grain.get_data()
	var out := PackedByteArray(); out.resize(SIZE * SIZE * 4)
	var base := Color(1, 1, 1); var low := 0.86; var gw := 0.07; var cw := 0.14
	match kind:
		VELLUM: low = 0.80; cw = 0.2
		WAX: low = 0.78; gw = 0.05; cw = 0.26
		LEATHER: low = 0.62; gw = 0.2; cw = 0.2
	for i in SIZE * SIZE:
		var c := float(cd[i]) / 255.0
		var gr := float(gd[i]) / 255.0
		var v := clampf(1.0 - cw * (1.0 - c) - gw * (1.0 - gr), low, 1.0)
		var b := int(v * 255.0)
		out[i * 4] = b; out[i * 4 + 1] = b; out[i * 4 + 2] = b; out[i * 4 + 3] = 255
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, out)
	return ImageTexture.create_from_image(img)

static func texture(kind: int) -> ImageTexture:
	if not _tex.has(kind): _tex[kind] = _make(kind)
	return _tex[kind]

## deterministic 0..1 value from an integer pair (edge jitter must not flicker between redraws)
static func h2(a: int, b: int) -> float:
	var x: int = (a * 374761393 + b * 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0

## a rectangle outline with slightly uneven edges (hand-cut paper); `amp` in px, `step` px between samples
static func ragged(r: Rect2, amp: float, step: float, seed_v: int, cut: float = 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x; var y0 := r.position.y; var x1 := r.end.x; var y1 := r.end.y
	var nx := maxi(2, int(r.size.x / step)); var ny := maxi(2, int(r.size.y / step))
	pts.append(Vector2(x0 + cut, y0 + (h2(seed_v, 1) - 0.5) * amp))
	for i in range(1, nx): pts.append(Vector2(x0 + r.size.x * i / nx, y0 + (h2(seed_v + i, 2) - 0.5) * amp))
	pts.append(Vector2(x1 - cut, y0 + (h2(seed_v, 3) - 0.5) * amp))
	pts.append(Vector2(x1 + (h2(seed_v, 4) - 0.5) * amp, y0 + cut))
	for j in range(1, ny): pts.append(Vector2(x1 + (h2(seed_v + j, 5) - 0.5) * amp, y0 + r.size.y * j / ny))
	pts.append(Vector2(x1 + (h2(seed_v, 6) - 0.5) * amp, y1 - cut))
	pts.append(Vector2(x1 - cut, y1 + (h2(seed_v, 7) - 0.5) * amp))
	for i in range(nx - 1, 0, -1): pts.append(Vector2(x0 + r.size.x * i / nx, y1 + (h2(seed_v + i, 8) - 0.5) * amp))
	pts.append(Vector2(x0 + cut, y1 + (h2(seed_v, 9) - 0.5) * amp))
	pts.append(Vector2(x0 + (h2(seed_v, 10) - 0.5) * amp, y1 - cut))
	for j in range(ny - 1, 0, -1): pts.append(Vector2(x0 + (h2(seed_v + j, 11) - 0.5) * amp, y0 + r.size.y * j / ny))
	pts.append(Vector2(x0 + (h2(seed_v, 12) - 0.5) * amp, y0 + cut))
	return pts

## a roundish blob (wax): radius wobbles with a few harmonics
static func blob(c: Vector2, rx: float, ry: float, seed_v: int, wobble: float = 0.06, n: int = 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p1 := h2(seed_v, 21) * TAU; var p2 := h2(seed_v, 22) * TAU; var p3 := h2(seed_v, 23) * TAU
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + wobble * (sin(a * 3.0 + p1) * 0.6 + sin(a * 5.0 + p2) * 0.3 + sin(a * 9.0 + p3) * 0.2)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts

## a rounded-rectangle outline with a soft, hand-pressed wobble (wax stamp): corners of radius `rad`, edge jitter `amp` px
static func stamp(r: Rect2, rad: float, amp: float, seed_v: int, step: float = 7.0) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var base := PackedVector2Array()
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var arc := maxi(4, int(rad / 2.5))
	for c in 4:
		for k in arc + 1:
			var a := -PI * 0.5 + (c + float(k) / arc) * PI * 0.5
			base.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	# subdivide long straight runs so the wobble is visible along the edges
	var pts := PackedVector2Array()
	var cen := r.get_center()
	var n := base.size()
	for i in n:
		var a2 := base[i]; var b2 := base[(i + 1) % n]
		var segs := maxi(1, int(a2.distance_to(b2) / step))
		for j in segs:
			var q := a2.lerp(b2, float(j) / segs)
			var d := (q - cen).normalized()
			pts.append(q + d * (h2(seed_v, pts.size() + 31) - 0.5) * 2.0 * amp)
	return pts
