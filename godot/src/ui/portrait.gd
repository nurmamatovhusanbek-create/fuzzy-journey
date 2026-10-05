## Ruler cameo: an engraved profile bust in a brass medallion. Headgear follows the regime, hair greys with age,
## the face (beard, hair, brow) is derived from the ruler's name so the same ruler always looks the same.
class_name TBPortrait
extends Control

const K = preload("res://src/ui/ui_kit.gd")
const INK := Color(0.06, 0.09, 0.17)
const SKIN := Color(0.36, 0.28, 0.14)
const SKIN_HI := Color(0.52, 0.41, 0.2)

var _regime := 2
var _age := 40
var _seed := 0
var _wash := Color(0.3, 0.4, 0.6)
var _trait := 0

func setup(g: TBGame, n: int, px: float = 64.0) -> TBPortrait:
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regime = g.regime[n]
	_age = TBRulers.age(g, n) if g.r_name[n] != "" else 40
	_seed = hash(String(g.r_name[n]) + str(g.r_num[n]) + str(n))
	var c: int = TBGame.gen_color(n)
	_wash = Color(((c >> 16) & 255) / 255.0, ((c >> 8) & 255) / 255.0, (c & 255) / 255.0)
	_trait = g.r_trait[n]
	queue_redraw()
	return self

func _pt(c: Vector2, r: float, x: float, y: float) -> Vector2: return c + Vector2(x, y) * r

func _fill(c: Vector2, r: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(_pt(c, r, v[0], v[1]))
	draw_colored_polygon(p, col)

## filled polygon clipped to the medallion disc
func _fill_clip(c: Vector2, r: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(_pt(c, r, v[0], v[1]))
	var disc := PackedVector2Array()
	for i in 48: disc.append(c + Vector2(cos(i * TAU / 48.0), sin(i * TAU / 48.0)) * (r - 1.0))
	for q in Geometry2D.intersect_polygons(p, disc): draw_colored_polygon(q, col)

func _line(c: Vector2, r: float, pts: Array, col: Color, w: float, closed: bool = false) -> void:
	var p := PackedVector2Array()
	for v in pts: p.append(_pt(c, r, v[0], v[1]))
	if closed: p.append(p[0])
	draw_polyline(p, col, w, true)

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 8.0: return
	var c := size * 0.5
	var r := s * 0.5 - 1.5
	var w := maxf(1.0, s / 44.0)
	# field: dark disc washed with the nation colour, hatching to read as an engraving
	draw_circle(c, r, INK)
	var halo := PackedVector2Array()
	for i in 40: halo.append(c + Vector2(cos(i * TAU / 40.0), sin(i * TAU / 40.0) * 0.9) * r * 0.78 + Vector2(0, r * 0.3))
	for q in Geometry2D.intersect_polygons(halo, PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)])):
		draw_colored_polygon(q, Color(_wash.r, _wash.g, _wash.b, 0.16))
	for i in range(-5, 6):
		var x := c.x + i * r * 0.17
		var hy := sqrt(maxf(0.0, r * r - (x - c.x) * (x - c.x)))
		draw_line(Vector2(x, c.y - hy * 0.92), Vector2(x, c.y + hy * 0.92), Color(K.GOLD.r, K.GOLD.g, K.GOLD.b, 0.07), 1.0)
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	var beard := rng.randi() % 3                     # 0 none, 1 short, 2 full
	var brow := rng.randf()
	var grey := clampf((_age - 42) / 28.0, 0.0, 1.0)
	var hair := Color(0.2, 0.15, 0.08).lerp(Color(0.82, 0.8, 0.74), grey)
	var line := K.GOLD2
	# shoulders + clothing
	_fill_clip(c, r, [[-1.0, 1.1], [-0.86, 0.62], [-0.7, 0.5], [-0.3, 0.34], [0.2, 0.32], [0.62, 0.5], [0.86, 0.62], [1.0, 1.1]], Color(_wash.r * 0.45 + 0.05, _wash.g * 0.45 + 0.05, _wash.b * 0.45 + 0.07))
	_line(c, r, [[-0.7, 0.5], [-0.3, 0.34], [0.2, 0.32], [0.62, 0.5]], line, w)
	# neck
	_fill(c, r, [[-0.12, 0.02], [0.17, 0.02], [0.2, 0.34], [-0.3, 0.34]], SKIN)
	_line(c, r, [[-0.12, 0.05], [-0.3, 0.34]], line, w * 0.8)
	_line(c, r, [[0.16, 0.12], [0.2, 0.32]], line, w * 0.8)
	# head: skull ellipse + profile (nose, lips, chin) facing right
	var skull := PackedVector2Array()
	for i in 28: skull.append(_pt(c, r, cos(i * TAU / 28.0) * 0.31 - 0.03, sin(i * TAU / 28.0) * 0.38 - 0.28))
	draw_colored_polygon(skull, SKIN)
	_fill(c, r, [[0.2, -0.46], [0.3, -0.34], [0.43, -0.2], [0.34, -0.15], [0.35, -0.1], [0.38, -0.06], [0.33, -0.01], [0.3, 0.07], [0.12, 0.13], [-0.1, 0.0], [0.0, -0.4]], SKIN)
	_fill(c, r, [[-0.02, -0.5], [0.2, -0.46], [0.0, -0.1], [-0.2, -0.05], [-0.3, -0.25]], SKIN_HI.darkened(0.1))
	_line(c, r, [[0.28, -0.46], [0.31, -0.34], [0.43, -0.2], [0.34, -0.15], [0.35, -0.1], [0.38, -0.06], [0.33, -0.01], [0.3, 0.07], [0.14, 0.14]], line, w)
	# eye + brow
	draw_circle(_pt(c, r, 0.2, -0.26), maxf(1.0, r * 0.028), line)
	_line(c, r, [[0.13, -0.32 - brow * 0.03], [0.28, -0.33 + brow * 0.04]], hair.lightened(0.15), w * 1.2)
	# ear
	_line(c, r, [[-0.05, -0.24], [-0.1, -0.18], [-0.04, -0.1]], line, w * 0.8)
	# hair at the back and temple
	_fill(c, r, [[-0.33, -0.2], [-0.33, -0.45], [-0.12, -0.62], [0.12, -0.6], [0.24, -0.5], [0.0, -0.46], [-0.12, -0.36], [-0.16, -0.12]], hair)
	# beard
	if beard >= 1:
		var low := 0.3 if beard == 2 else 0.17
		_fill(c, r, [[0.28, -0.04], [0.34, -0.0], [0.28, 0.1 + low * 0.4], [0.1, 0.12 + low], [-0.08, 0.04 + low * 0.5], [-0.14, -0.08], [0.0, 0.0], [0.2, -0.05]], hair)
	# age lines
	if _age > 50:
		_line(c, r, [[0.24, -0.2], [0.18, -0.17]], line, w * 0.6)
		_line(c, r, [[0.1, -0.36], [0.2, -0.38]], line, w * 0.6)
	_headgear(c, r, w, line, hair)
	_collar(c, r, w, line)
	# medallion rim: double brass rule with ticks
	draw_arc(c, r, 0, TAU, 48, K.GOLD, w * 1.4, true)
	draw_arc(c, r - w * 2.4, 0, TAU, 48, Color(K.GOLD.r, K.GOLD.g, K.GOLD.b, 0.5), w * 0.7, true)

func _headgear(c: Vector2, r: float, w: float, line: Color, hair: Color) -> void:
	match _regime:
		0:      # tribal: headband and two feathers
			_line(c, r, [[-0.32, -0.5], [0.0, -0.57], [0.26, -0.5]], line, w * 1.4)
			_line(c, r, [[-0.05, -0.56], [-0.12, -0.86]], line, w)
			_line(c, r, [[0.08, -0.55], [0.18, -0.84]], line, w)
			_fill(c, r, [[-0.05, -0.56], [-0.12, -0.86], [-0.02, -0.7]], K.CRIMSON)
		1:      # feudal: coronet
			_fill(c, r, [[-0.3, -0.5], [-0.3, -0.64], [-0.17, -0.56], [-0.02, -0.7], [0.13, -0.56], [0.26, -0.64], [0.26, -0.5]], K.GOLD)
			_line(c, r, [[-0.3, -0.5], [-0.3, -0.64], [-0.17, -0.56], [-0.02, -0.7], [0.13, -0.56], [0.26, -0.64], [0.26, -0.5]], line, w, true)
		2:      # monarchy: arched crown
			_fill(c, r, [[-0.32, -0.46], [-0.34, -0.7], [-0.18, -0.6], [-0.02, -0.8], [0.14, -0.6], [0.3, -0.7], [0.28, -0.46]], K.GOLD)
			_line(c, r, [[-0.32, -0.46], [-0.34, -0.7], [-0.18, -0.6], [-0.02, -0.8], [0.14, -0.6], [0.3, -0.7], [0.28, -0.46]], line, w, true)
			_line(c, r, [[-0.32, -0.55], [0.28, -0.55]], K.CRIMSON, w * 1.3)
			draw_circle(_pt(c, r, -0.02, -0.84), r * 0.04, line)
		3, 9:   # republic / city-state: laurel wreath
			_laurel(c, r, w, K.GREEN.lightened(0.15))
		4:      # empire: laurel with a jewel
			_laurel(c, r, w, K.GOLD2)
			draw_circle(_pt(c, r, 0.2, -0.5), r * 0.045, K.CRIMSON.lightened(0.25))
		5:      # democracy: bare head, suit and tie
			pass
		6:      # communism: peaked cap with a star
			_fill(c, r, [[-0.34, -0.42], [-0.3, -0.66], [0.1, -0.72], [0.3, -0.56], [0.44, -0.48], [0.42, -0.42]], Color(0.32, 0.2, 0.12))
			_line(c, r, [[-0.34, -0.42], [-0.3, -0.66], [0.1, -0.72], [0.3, -0.56], [0.44, -0.48], [0.42, -0.42], [-0.34, -0.42]], line, w)
			draw_circle(_pt(c, r, 0.04, -0.54), r * 0.05, K.CRIMSON.lightened(0.2))
		7:      # fascism: peaked cap with a band
			_fill(c, r, [[-0.34, -0.42], [-0.32, -0.7], [0.12, -0.74], [0.3, -0.6], [0.46, -0.5], [0.44, -0.42]], Color(0.16, 0.18, 0.2))
			_line(c, r, [[-0.34, -0.42], [-0.32, -0.7], [0.12, -0.74], [0.3, -0.6], [0.46, -0.5], [0.44, -0.42], [-0.34, -0.42]], line, w)
			_line(c, r, [[-0.34, -0.5], [0.4, -0.5]], K.CRIMSON, w * 1.4)
		8:      # horde: fur hat
			for i in 7:
				var x := -0.3 + i * 0.1
				draw_circle(_pt(c, r, x, -0.5), r * 0.075, Color(0.45, 0.34, 0.2))
			_fill(c, r, [[-0.3, -0.52], [-0.24, -0.78], [0.02, -0.86], [0.26, -0.76], [0.3, -0.52]], Color(0.4, 0.3, 0.17))
			_line(c, r, [[-0.3, -0.52], [-0.24, -0.78], [0.02, -0.86], [0.26, -0.76], [0.3, -0.52]], line, w)
			draw_circle(_pt(c, r, 0.02, -0.86), r * 0.04, K.CRIMSON.lightened(0.2))

func _laurel(c: Vector2, r: float, w: float, col: Color) -> void:
	for i in 9:
		var a: float = lerpf(PI * 1.05, PI * 1.98, i / 8.0)
		var p := _pt(c, r, cos(a) * 0.36 - 0.03, sin(a) * 0.4 - 0.3)
		var d := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5))
		draw_line(p - d * r * 0.07, p + d * r * 0.07, col, w * 1.7, true)
		draw_circle(p + Vector2(-d.y, d.x) * r * 0.04, r * 0.035, col)

func _collar(c: Vector2, r: float, w: float, line: Color) -> void:
	match _regime:
		5, 6, 7:   # lapels and a tie
			_line(c, r, [[-0.24, 0.34], [0.0, 0.58], [0.2, 0.32]], line, w)
			_fill(c, r, [[-0.03, 0.36], [0.05, 0.36], [0.07, 0.62], [0.0, 0.7], [-0.06, 0.62]], K.CRIMSON if _regime != 7 else Color(0.5, 0.1, 0.1))
		0, 8:      # fur mantle
			for i in 6: draw_circle(_pt(c, r, -0.5 + i * 0.2, 0.46 + (0.02 if i % 2 == 0 else 0.0)), r * 0.08, Color(0.5, 0.4, 0.26))
		_:         # robe edge with ermine tips
			_line(c, r, [[-0.4, 0.4], [-0.1, 0.56], [0.3, 0.4]], line, w)
			for i in 4: _line(c, r, [[-0.3 + i * 0.16, 0.5 + abs(i - 1.5) * 0.02], [-0.3 + i * 0.16, 0.58 + abs(i - 1.5) * 0.02]], line, w * 0.9)
