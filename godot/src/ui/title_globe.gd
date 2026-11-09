## The first title stage's globe: a smooth pre-made map of the world on a shader sphere that turns slowly, with the golden era ring around it (only the part that is on the screen shows when the globe
## stands in the corner). `set_pose(centre, radius)` places it; the morph to the second stage tweens the pose and the ring.
class_name TBTitleGlobe
extends Control

const SHADER := preload("res://src/render/title_globe.gdshader")
const DISC := 0.7692                              # the disc's share of the square (the rest is glow)
const TEX_PATH := "res://assets/title/globe_flat.png"
static var _tex: ImageTexture
var _mat: ShaderMaterial
var centre := Vector2.ZERO
var radius := 400.0
var ring_k := 1.2                                 # the golden ring's radius in globe radii
var ring_a := 1.0
var turn := 0.6                                   # radians
var spin := true
var fade := 1.0

## the map as a texture with mipmaps (made once per run, kept while the title is up: about 50 MB)
static func texture() -> ImageTexture:
	if _tex != null: return _tex
	var ct: Texture2D = load(TEX_PATH)
	if ct == null: return null
	var img: Image = ct.get_image()
	if img == null: return null
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex

static func release() -> void: _tex = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new(); _mat.shader = SHADER
	material = _mat

var _ring: Ring

func _ready() -> void:
	_ring = Ring.new(self); add_child(_ring)
	var t := texture()
	if t != null: _mat.set_shader_parameter("tex", t)
	_apply()

func set_pose(c: Vector2, r: float) -> void:
	centre = c; radius = r; _apply()

func _apply() -> void:
	var side: float = radius * 2.0 / DISC
	position = centre - Vector2(side, side) * 0.5
	size = Vector2(side, side)
	if _mat != null:
		_mat.set_shader_parameter("lon0", turn); _mat.set_shader_parameter("alpha", fade)
	queue_redraw()
	if _ring != null: _ring.queue_redraw()

var boost := 0.0                                   # extra turn (radians a second) while the globe settles in at the start
func _process(delta: float) -> void:
	if spin and visible and is_visible_in_tree() and TBKit.motion_ok():
		turn = fposmod(turn + delta * (deg_to_rad(2.0) + boost), TAU)
		_mat.set_shader_parameter("lon0", turn)
		queue_redraw()                                  # something on screen changed: draw it (the project redraws only on request)

## the way in: the globe fades up and spins fast, then slows to its quiet turn
func intro() -> void:
	if not TBFx.on(TBFx.LIGHT) or not is_inside_tree(): return
	modulate.a = 0.0; boost = 1.1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "boost", 0.0, 2.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## the shader draws on a plain rectangle (a control with no draw call has nothing to put the shader on)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

## the golden ring is its own layer, without the shader
class Ring extends Control:
	var g: TBTitleGlobe
	func _init(globe: TBTitleGlobe) -> void:
		g = globe; mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_preset(Control.PRESET_FULL_RECT)
	## a heavy gold circle, a thin one beside it and the tick marks (long ones every 30 degrees); around the globe's centre
	func _draw() -> void:
		if g.ring_a <= 0.01: return
		var c: Vector2 = size * 0.5
		var radius: float = g.radius
		var R: float = radius * g.ring_k
		var gold: Color = TBTokens.with_a(TBTokens.BZ_HI, 0.95 * g.ring_a)
		draw_arc(c, R, 0.0, TAU, 256, gold, maxf(2.0, radius * 0.0035), true)
		draw_arc(c, R + radius * 0.022, 0.0, TAU, 256, TBTokens.with_a(TBTokens.BZ_LO, 0.9 * g.ring_a), 1.2, true)
		for i in 120:
			var a: float = float(i) * TAU / 120.0
			var long: bool = i % 10 == 0
			var l: float = radius * (0.016 if long else 0.008)
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (R - 3.0), c + d * (R - 3.0 - l), gold if long else TBTokens.with_a(TBTokens.BZ_TICK, g.ring_a), 1.8 if long else 1.1, true)
