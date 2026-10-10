## The corner minimap (Bezel demo renderMM): a round brass-ringed instrument showing the world as a small orthographic globe in the current lens colours.
## It turns with the main view (the flat map and the globe share lon0 / lat0), a frame on the globe shows what the main view covers once it is zoomed in,
## and a tap or drag on it turns the main view there. Built once from the province raster, re-coloured on refresh(). Always round, flat map or globe.
class_name TBMinimap
extends Control

signal looked(lon_deg: float, lat_deg: float)

var g: TBGame
var map: TBMapView
var round_r: float = 74.0               # the bezel's outer radius in layout units (the demo's mmR); the globe is 12 smaller
var _img: Image
var _tex: ImageTexture
var _src := PackedInt32Array()          # texel -> province (-1 sea)
var _w := 0
var _h := 0
var _dirty := true
var _gl: ColorRect                      # the mini-globe (shader)
var _mat: ShaderMaterial
var _fp: Control                        # the view frame, drawn above the globe
var globe := true

signal tip_requested
signal tip_hidden
var _hover_gen: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	_gl = ColorRect.new(); _gl.mouse_filter = Control.MOUSE_FILTER_IGNORE; _gl.color = Color.WHITE; _gl.visible = false
	_mat = ShaderMaterial.new(); _mat.shader = load("res://src/render/minimap_globe.gdshader"); _gl.material = _mat
	add_child(_gl)
	_fp = Control.new(); _fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fp.draw.connect(_draw_frame)
	add_child(_fp)

func setup(game: TBGame, view: TBMapView) -> void:
	g = game; map = view
	_w = 0
	_dirty = true
	queue_redraw()

func _build() -> void:
	var wd: TBWorld = g.world
	_w = 512; _h = 256
	_src.resize(_w * _h)
	for y in _h:
		var sy: int = clampi(int((y + 0.5) * wd.H / _h), 0, wd.H - 1)
		for x in _w:
			var sx: int = clampi(int((x + 0.5) * wd.W / _w), 0, wd.W - 1)
			var i: int = (sy * wd.W + sx) * 2
			_src[y * _w + x] = (wd.ids[i] | (wd.ids[i + 1] << 8)) - 1
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)

## kept for callers: the minimap is a round globe whatever the main map's view mode
func is_globe() -> bool: return true
func want_w(h: float) -> float: return h

## the globe's centre (control coordinates) and radius: the bezel has 10 units of room round it for the shadow, the caption sits beneath
func _globe_geom() -> Array:
	return [Vector2(size.x * 0.5, 10.0 + round_r), round_r - 12.0]

func _has_point(p: Vector2) -> bool:
	return p.distance_to(Vector2(size.x * 0.5, 10.0 + round_r)) <= round_r + 2.0

func refresh() -> void:
	_dirty = true
	if is_visible_in_tree(): queue_redraw()

func _recolor() -> void:
	if g == null or map == null or map.lenses == null: return
	if _w == 0: _build()
	var cols := PackedColorArray(); cols.resize(g.P)
	for q in g.P:
		var rgb: int = map.lenses.color(q)
		cols[q] = Color.hex((rgb << 8) | 0xff)
	var sea: Color = TBTokens.BZ_OCEAN
	var buf := PackedByteArray(); buf.resize(_src.size() * 4)
	var sea8 := [int(sea.r8), int(sea.g8), int(sea.b8)]
	for i in _src.size():
		var p: int = _src[i]
		var o: int = i * 4
		if p >= 0:
			var c: Color = sea.lerp(cols[p], 0.9)                                   # the demo draws land at 90 % over the ocean
			buf[o] = c.r8; buf[o + 1] = c.g8; buf[o + 2] = c.b8
		else:
			buf[o] = sea8[0]; buf[o + 1] = sea8[1]; buf[o + 2] = sea8[2]
		buf[o + 3] = 255
	_img.set_data(_w, _h, false, Image.FORMAT_RGBA8, buf)
	_tex.update(_img)
	_dirty = false

func _draw() -> void:
	var gm: Array = _globe_geom()
	var c: Vector2 = gm[0]; var R: float = gm[1]
	TBBezel.ring(self, c, round_r, 72, TBTokens.c("bar_0"))
	draw_circle(c, R, TBTokens.BZ_SEA)
	var cf: Font = TBHudParts.fcz(false)
	var cz: int = TBHudParts.fu(10.5)
	var cap: String = TBI18n.T("tk_minimap").to_upper() if TBI18n.lang != "ru" else TBI18n.T("tk_minimap")
	TBHudParts.txtl(self, cf, c.x, c.y + round_r + 19.0, cap, cz, TBTokens.c("smoke") if not TBTokens.is_hc() else TBTokens.c("cream"), 3.5, 1, 2.0, TBTokens.BZ_HALO)
	if g == null or map == null:
		_gl.visible = false; return
	if _dirty or _w == 0: _recolor()
	_gl.position = c - Vector2(R, R); _gl.size = Vector2(R, R) * 2.0
	_gl.visible = true
	_mat.set_shader_parameter("tex", _tex)
	_mat.set_shader_parameter("lon0", map.lon0)
	_mat.set_shader_parameter("lat0", map.lat0)
	_mat.set_shader_parameter("r_units", R)
	_fp.position = Vector2.ZERO; _fp.size = size
	_fp.queue_redraw()

# ---- orthographic projection of a lon/lat (radians) about the view centre: x right, y up, z toward the viewer
func _orth(lon: float, lat: float, l0: float, p0: float) -> Vector3:
	var dl: float = lon - l0
	var cp: float = cos(lat); var sp: float = sin(lat); var cl: float = cos(dl)
	var c0: float = cos(p0); var s0: float = sin(p0)
	return Vector3(cp * sin(dl), c0 * sp - s0 * cp * cl, s0 * sp + c0 * cp * cl)

func _horizon(a: Vector3, b: Vector3) -> Vector3:
	var t: float = a.z / (a.z - b.z)
	var x: float = a.x + t * (b.x - a.x); var y: float = a.y + t * (b.y - a.y)
	var h: float = maxf(sqrt(x * x + y * y), 1e-6)
	return Vector3(x / h, y / h, 0.0)

## the front-facing parts of a lon/lat polyline, as screen polylines (the demo's linePath: cut at the horizon)
func _lines(ll: Array, l0: float, p0: float, c: Vector2, R: float) -> Array:
	var out: Array = []
	var cur := PackedVector2Array()
	var prev: Variant = null
	for pt in ll:
		var q: Vector3 = _orth(float(pt.x), float(pt.y), l0, p0)
		if q.z >= 0.0:
			if cur.is_empty() and prev != null and (prev as Vector3).z < 0.0:
				var h: Vector3 = _horizon(prev, q)
				cur.append(c + Vector2(h.x, -h.y) * R)
			cur.append(c + Vector2(q.x, -q.y) * R)
		else:
			if not cur.is_empty():
				var h2: Vector3 = _horizon(prev, q)
				cur.append(c + Vector2(h2.x, -h2.y) * R)
				out.append(cur); cur = PackedVector2Array()
		prev = q
	if not cur.is_empty(): out.append(cur)
	return out

## the main view's footprint on the globe (lon/lat points, radians), or [] while the whole map is in view
func _footprint() -> Array:
	var pts: Array = []
	if map == null: return pts
	if map.mode == 1:
		var fit: float = maxf(1.0, (map.size.y / PI) / (map.size.x / TAU))
		if map.zoom <= fit * 1.12: return pts
		var fs: float = maxf(0.001, map.flat_scale())
		var hw: float = map.size.x * 0.5 / fs; var hh: float = map.size.y * 0.5 / fs
		var x0: float = map.lon0 - hw; var x1: float = map.lon0 + hw
		var y0: float = clampf(map.lat0 - hh, -1.48, 1.48); var y1: float = clampf(map.lat0 + hh, -1.48, 1.48)
		for i in 9: pts.append(Vector2(x0 + (x1 - x0) * i / 8.0, y1))
		for i in range(1, 9): pts.append(Vector2(x1, y1 + (y0 - y1) * i / 8.0))
		for i in range(1, 9): pts.append(Vector2(x1 - (x1 - x0) * i / 8.0, y0))
		for i in range(1, 8): pts.append(Vector2(x0, y0 + (y1 - y0) * i / 8.0))
		pts.append(pts[0])
	else:
		if map.zoom <= 1.12: return pts
		var ang: float = minf(PI * 0.5, 1.15 / maxf(0.4, map.zoom))
		var sl: float = sin(map.lat0); var cl: float = cos(map.lat0)
		for i in 49:
			var b: float = TAU * i / 48.0
			var lat: float = asin(clampf(sl * cos(ang) + cl * sin(ang) * cos(b), -1.0, 1.0))
			var lon: float = map.lon0 + atan2(sin(b) * sin(ang) * cl, cos(ang) - sl * sin(lat))
			pts.append(Vector2(lon, lat))
	return pts

func _draw_frame() -> void:
	if map == null or g == null: return
	var gm: Array = _globe_geom()
	var c: Vector2 = gm[0]; var R: float = gm[1]
	var fpp: Array = _footprint()
	if fpp.is_empty(): return
	var segs: Array = _lines(fpp, map.lon0, map.lat0, c, R)
	for s in segs:
		if (s as PackedVector2Array).size() < 2: continue
		_fp.draw_polyline(s, TBBezel.ac(TBTokens.with_a(TBTokens.BZ_HALO, 0.6), 3.2), TBBezel.aw(3.2), true)
		_fp.draw_polyline(s, TBBezel.ac(TBTokens.c("cream"), 1.3), TBBezel.aw(1.3), true)

## tap or drag: turn the main view to the spot under the pointer (the demo: pick(); a point on the rim snaps just inside it)
func _fly(pos: Vector2) -> void:
	if map == null: return
	var gm: Array = _globe_geom()
	var d: Vector2 = (pos - (gm[0] as Vector2)) / float(gm[1])
	d.y = -d.y
	if d.length_squared() >= 1.0: d = d.normalized() * 0.999
	var z: float = sqrt(1.0 - d.length_squared())
	var s0: float = sin(map.lat0); var c0: float = cos(map.lat0)
	var lat: float = asin(clampf(z * s0 + d.y * c0, -1.0, 1.0))
	var lon: float = map.lon0 + atan2(d.x, z * c0 - d.y * s0)
	looked.emit(rad_to_deg(lon), rad_to_deg(lat))
	map.fly_to(rad_to_deg(lon), rad_to_deg(lat))

var _drag := false
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (e as InputEventMouseButton).pressed
		if _drag: tip_hidden.emit(); _fly((e as InputEventMouseButton).position)
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_fly((e as InputEventMouseMotion).position)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover_gen += 1
		var gen: int = _hover_gen
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self) and gen == _hover_gen and not _drag and get_global_rect().has_point(get_global_mouse_position()): tip_requested.emit()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover_gen += 1; tip_hidden.emit()
