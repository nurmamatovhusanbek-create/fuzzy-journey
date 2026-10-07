## Corner minimap (Age of Civilizations style): the whole world in the current lens colours with a rectangle for what the main view
## shows; tap or drag to fly there. Built once from the province raster, re-coloured on refresh().
class_name TBMinimap
extends Control

signal looked(lon_deg: float, lat_deg: float)

var g: TBGame
var map: TBMapView
var _img: Image
var _tex: ImageTexture
var _src := PackedInt32Array()          # texel -> province (-1 sea)
var _w := 0
var _h := 0
var _dirty := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

func setup(game: TBGame, view: TBMapView) -> void:
	g = game; map = view
	_w = 0
	_dirty = true
	queue_redraw()

func _build() -> void:
	var wd: TBWorld = g.world
	_w = 296; _h = 148
	_src.resize(_w * _h)
	for y in _h:
		var sy: int = clampi(int((y + 0.5) * wd.H / _h), 0, wd.H - 1)
		for x in _w:
			var sx: int = clampi(int((x + 0.5) * wd.W / _w), 0, wd.W - 1)
			var i: int = (sy * wd.W + sx) * 2
			_src[y * _w + x] = (wd.ids[i] | (wd.ids[i + 1] << 8)) - 1
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)

func refresh() -> void:
	_dirty = true
	if is_visible_in_tree(): queue_redraw()

func _recolor() -> void:
	if g == null or map == null or map.lenses == null: return
	if _w == 0: _build()
	var cache: Dictionary = {}
	for i in _src.size():
		var p: int = _src[i]
		var c: Color = TBTokens.c("table")
		if p >= 0:
			if not cache.has(p):
				var rgb: int = map.lenses.color(p)
				cache[p] = Color.hex((rgb << 8) | 0xff)
			c = cache[p]
		_img.set_pixel(i % _w, i / _w, c)
	_tex.update(_img)
	_dirty = false

func _view_rect() -> Rect2:
	if map == null: return Rect2()
	var dw: float = size.x
	var dh: float = size.y
	var cx: float = (map.lon0 / TAU + 0.5) * dw
	var cy: float = (0.5 - map.lat0 / PI) * dh
	var half_lon: float
	var half_lat: float
	if map.mode == 1:
		half_lon = (map.size.x * 0.5 / map.flat_scale()) / TAU * dw
		half_lat = (map.size.y * 0.5 / map.flat_scale()) / PI * dh
	else:
		var ang: float = minf(PI * 0.5, 1.15 / maxf(0.4, map.zoom))
		half_lon = ang / TAU * dw / maxf(0.25, cos(map.lat0))
		half_lat = ang / PI * dh
	return Rect2(cx - half_lon, cy - half_lat, half_lon * 2.0, half_lat * 2.0)

func _draw() -> void:
	if g == null: return
	if _dirty or _w == 0: _recolor()
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	var vr: Rect2 = _view_rect()
	var col: Color = TBTokens.c("cream")
	# the view rectangle wraps around the date line
	for off in [-size.x, 0.0, size.x]:
		var r: Rect2 = Rect2(vr.position + Vector2(off, 0), vr.size)
		if r.end.x < 0.0 or r.position.x > size.x: continue
		draw_rect(r, TBTokens.ca("bar_0", 0.6), false, 3.0)
		draw_rect(r, col, false, 1.5)

func _fly(pos: Vector2) -> void:
	if map == null: return
	var lon: float = (pos.x / maxf(1.0, size.x) - 0.5) * 360.0
	var lat: float = (0.5 - pos.y / maxf(1.0, size.y)) * 180.0
	looked.emit(lon, lat)
	map.fly_to(lon, lat)

var _drag := false
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (e as InputEventMouseButton).pressed
		if _drag: _fly((e as InputEventMouseButton).position)
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_fly((e as InputEventMouseMotion).position)
		accept_event()
