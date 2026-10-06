## Ruler cameo: a flat paper tile with an ink bust (art bible 5.4, review A-9). No medallion, no rim ticks, no wash, no saturated colour: only
## TBTokens (paper-1 tile, 1 px rule, ink silhouette, detail in paper negative space). Headgear follows the regime, the beard and hair are derived from
## the ruler's name so the same ruler always looks the same, and the hair lightens with age. Chip sizes: 32 (silhouette + headgear), 48 (+ beard, ear),
## 72 and above (+ brow, age lines, collar detail).
class_name TBPortrait
extends Control

const SIZES := [32, 48, 72]
const _FACE := [[0.2, -0.46], [0.3, -0.34], [0.43, -0.2], [0.34, -0.15], [0.35, -0.1], [0.38, -0.06], [0.33, -0.01], [0.3, 0.07], [0.12, 0.13], [-0.1, 0.0], [0.0, -0.4]]

var _regime := 2
var _age := 40
var _seed := 0
var _trait := 0
var _plate: TBFrame
var _plate_mode := -1
var _beard := 0
var _brow := 0.0

## px is snapped to the chip variants 32 / 48 / 72 (larger values keep the 72 detail, scaled)
func setup(g: TBGame, n: int, px: float = 48.0) -> TBPortrait:
	var snapped_px: float = px
	if px < 40.0: snapped_px = 32.0
	elif px < 60.0: snapped_px = 48.0
	elif px < 80.0: snapped_px = 72.0
	custom_minimum_size = Vector2(snapped_px, snapped_px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regime = g.regime[n]
	_age = TBRulers.age(g, n) if g.r_name[n] != "" else 40
	_seed = hash(String(g.r_name[n]) + str(g.r_num[n]) + str(n))
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	_beard = rng.randi() % 3
	_brow = rng.randf()
	_trait = g.r_trait[n]
	queue_redraw()
	return self

func _pt(c: Vector2, r: float, x: float, y: float) -> Vector2: return c + Vector2(x, y) * r

func _fill(c: Vector2, r: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(_pt(c, r, v[0], v[1]))
	draw_colored_polygon(p, col)

func _line(c: Vector2, r: float, pts: Array, col: Color, w: float, closed: bool = false) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(_pt(c, r, v[0], v[1]))
	if closed: p.append(p[0])
	draw_polyline(p, col, w, true)

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s < 8.0: return
	if _plate == null or _plate_mode != TBTokens.mode:
		_plate = TBFrame.plate(TBTokens.c("paper_1"), TBTokens.c("rule"), 2, 0, 0, 0)
		_plate_mode = TBTokens.mode
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))
	var ink: Color = TBTokens.c("ink_0")
	var ink2: Color = TBTokens.c("ink_1")
	var tile: Color = TBTokens.c("paper_1")
	var c := size * 0.5 + Vector2(0, s * 0.04)
	var r: float = s * 0.46
	var detail: int = 0 if s < 40.0 else (1 if s < 60.0 else 2)
	var w: float = maxf(1.0, s / 40.0)
	var grey: float = clampf((_age - 42) / 28.0, 0.0, 1.0)
	var hair: Color = ink.lerp(ink2, grey)
	# shoulders and neck, clipped to the tile by staying inside [-1, 1]
	_fill(c, r, [[-0.92, 1.0], [-0.84, 0.62], [-0.62, 0.46], [-0.26, 0.34], [0.22, 0.32], [0.6, 0.46], [0.84, 0.62], [0.92, 1.0]], ink)
	_fill(c, r, [[-0.12, 0.02], [0.17, 0.02], [0.2, 0.34], [-0.3, 0.34]], ink)
	# head: skull ellipse + profile (nose, lips, chin) facing right
	var skull := PackedVector2Array()
	for i in 24: skull.append(_pt(c, r, cos(i * TAU / 24.0) * 0.31 - 0.03, sin(i * TAU / 24.0) * 0.38 - 0.28))
	draw_colored_polygon(skull, ink)
	_fill(c, r, _FACE, ink)
	# hair at the back and temple (lighter ink with age)
	_fill(c, r, [[-0.33, -0.2], [-0.33, -0.45], [-0.12, -0.62], [0.12, -0.6], [0.24, -0.5], [0.0, -0.46], [-0.12, -0.36], [-0.16, -0.12]], hair)
	if detail >= 1:
		if _beard >= 1:
			var low: float = 0.3 if _beard == 2 else 0.17
			_fill(c, r, [[0.28, -0.04], [0.34, -0.0], [0.28, 0.1 + low * 0.4], [0.1, 0.12 + low], [-0.08, 0.04 + low * 0.5], [-0.14, -0.08], [0.0, 0.0], [0.2, -0.05]], hair)
		draw_circle(_pt(c, r, 0.2, -0.26), maxf(1.0, r * 0.03), tile)                       # eye in negative space
		_line(c, r, [[-0.05, -0.24], [-0.1, -0.18], [-0.04, -0.1]], tile, w * 0.8)          # ear
	if detail >= 2:
		_line(c, r, [[0.13, -0.32 - _brow * 0.03], [0.28, -0.33 + _brow * 0.04]], tile, w * 1.1)
		if _age > 50:
			_line(c, r, [[0.24, -0.2], [0.18, -0.17]], tile, w * 0.6)
			_line(c, r, [[0.1, -0.36], [0.2, -0.38]], tile, w * 0.6)
	_headgear(c, r, w, ink, tile, detail)
	if detail >= 1: _collar(c, r, w, tile, detail)

func _headgear(c: Vector2, r: float, w: float, ink: Color, tile: Color, detail: int) -> void:
	match _regime:
		0:      # tribal: headband and two feathers
			_line(c, r, [[-0.32, -0.5], [0.0, -0.57], [0.26, -0.5]], ink, w * 1.6)
			_line(c, r, [[-0.05, -0.56], [-0.12, -0.86]], ink, w * 1.3)
			_line(c, r, [[0.08, -0.55], [0.18, -0.84]], ink, w * 1.3)
		1:      # feudal: coronet
			var pts: Array = [[-0.3, -0.5], [-0.3, -0.64], [-0.17, -0.56], [-0.02, -0.7], [0.13, -0.56], [0.26, -0.64], [0.26, -0.5]]
			_fill(c, r, pts, ink)
			if detail >= 1: _line(c, r, [[-0.3, -0.54], [0.26, -0.54]], tile, w * 0.9)
		2:      # monarchy: arched crown
			var pts2: Array = [[-0.32, -0.46], [-0.34, -0.7], [-0.18, -0.6], [-0.02, -0.8], [0.14, -0.6], [0.3, -0.7], [0.28, -0.46]]
			_fill(c, r, pts2, ink)
			draw_circle(_pt(c, r, -0.02, -0.84), r * 0.05, ink)
			if detail >= 1: _line(c, r, [[-0.32, -0.55], [0.28, -0.55]], tile, w)
		3, 9:   # republic / city-state: laurel wreath
			_laurel(c, r, w, ink)
		4:      # empire: laurel with a jewel
			_laurel(c, r, w, ink)
			if detail >= 1: draw_circle(_pt(c, r, 0.2, -0.5), r * 0.05, tile)
		5:      # democracy: bare head
			pass
		6:      # communism: peaked cap with a star
			_fill(c, r, [[-0.34, -0.42], [-0.3, -0.66], [0.1, -0.72], [0.3, -0.56], [0.44, -0.48], [0.42, -0.42]], ink)
			if detail >= 1: draw_circle(_pt(c, r, 0.04, -0.54), r * 0.055, tile)
		7:      # fascism: peaked cap with a band
			_fill(c, r, [[-0.34, -0.42], [-0.32, -0.7], [0.12, -0.74], [0.3, -0.6], [0.46, -0.5], [0.44, -0.42]], ink)
			if detail >= 1: _line(c, r, [[-0.34, -0.5], [0.4, -0.5]], tile, w * 1.2)
		8:      # horde: fur hat
			_fill(c, r, [[-0.3, -0.52], [-0.24, -0.78], [0.02, -0.86], [0.26, -0.76], [0.3, -0.52]], ink)
			if detail >= 1:
				for i in 4: draw_circle(_pt(c, r, -0.18 + i * 0.12, -0.52), r * 0.04, tile)

func _laurel(c: Vector2, r: float, w: float, col: Color) -> void:
	for i in 9:
		var a: float = lerpf(PI * 1.05, PI * 1.98, i / 8.0)
		var p := _pt(c, r, cos(a) * 0.36 - 0.03, sin(a) * 0.4 - 0.3)
		var d := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5))
		draw_line(p - d * r * 0.08, p + d * r * 0.08, col, w * 1.8, true)

func _collar(c: Vector2, r: float, w: float, tile: Color, detail: int) -> void:
	match _regime:
		5, 6, 7:   # lapels and a tie, in negative space
			_line(c, r, [[-0.24, 0.34], [0.0, 0.58], [0.2, 0.32]], tile, w)
			if detail >= 2: _line(c, r, [[0.0, 0.36], [0.0, 0.62]], tile, w * 1.3)
		0, 8:      # fur mantle
			if detail >= 2:
				for i in 5: draw_circle(_pt(c, r, -0.5 + i * 0.25, 0.64), r * 0.05, tile)
		_:         # robe edge
			_line(c, r, [[-0.4, 0.5], [-0.1, 0.62], [0.3, 0.5]], tile, w)
