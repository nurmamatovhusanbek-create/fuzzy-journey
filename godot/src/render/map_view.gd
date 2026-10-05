## GPU map control: camera, input (mouse/touch/pinch), picking, palette upload.
class_name TBMapView
extends Control

signal province_picked(p: int, secondary: bool)
signal province_hovered(p: int)
signal view_changed

const SHADER := preload("res://src/render/globe.gdshader")
const PAL_W := 2048

var g: TBGame
var world: TBWorld
var lenses: TBLenses
var mode := 0                 # 0 globe, 1 flat
var lon0 := 0.26
var lat0 := 0.35
var zoom := 1.0
var selected := -1
var hover := -1

var quality := 2
var render_scale := 1.0        # SubViewport resolution relative to the control's logical size
var _vp: SubViewport
var _view_tex: TextureRect
var labels: TBMapLabels
var _mat: ShaderMaterial
var _rect: ColorRect
var _ids_tex: ImageTexture
var _ids_tex_half: ImageTexture      # 2048x1024 copy for the low tier (4 MB instead of 16 MB of VRAM)
var _ids_is_half := false
var _pal_img: Image
var _pal_tex: ImageTexture
var _pal := PackedByteArray()
var _touches := {}
var _pinch_dist := 0.0
var _dragging := false
var _drag_moved := 0.0
var _pressed := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func setup(game: TBGame) -> void:
	g = game
	world = game.world
	if _rect == null:
		# the shader draws into a SubViewport so low-end devices can render below native resolution
		_vp = SubViewport.new()
		_vp.disable_3d = true
		_vp.transparent_bg = false
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE     # re-rendered only when the view or palette changes (battery!)
		_vp.size = Vector2i(maxi(64, int(size.x)), maxi(64, int(size.y)))
		add_child(_vp)
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.size = Vector2(_vp.size)
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_rect.material = _mat
		_vp.add_child(_rect)
		_view_tex = TextureRect.new()
		_view_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		_view_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view_tex.stretch_mode = TextureRect.STRETCH_SCALE
		_view_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_view_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_view_tex.texture = _vp.get_texture()
		add_child(_view_tex)
		var img := Image.create_from_data(world.W, world.H, false, Image.FORMAT_RG8, world.ids)
		_ids_tex = ImageTexture.create_from_image(img)
		_mat.set_shader_parameter("ids", _ids_tex)
		_mat.set_shader_parameter("id_size", Vector2(world.W, world.H))
		_pal.resize(PAL_W * 4 * 4)
		_pal_img = Image.create_from_data(PAL_W, 4, false, Image.FORMAT_RGBA8, _pal)
		_pal_tex = ImageTexture.create_from_image(_pal_img)
		_mat.set_shader_parameter("pal", _pal_tex)
		resized.connect(_push_view)
		labels = TBMapLabels.new(); add_child(labels); labels.attach(self)
	lenses = TBLenses.new(g)
	labels.set_game(g)
	repaint_all()
	_push_view()

# ---------------------------------------------------------------- palette
func repaint_all() -> void:
	lenses.refresh_nations()
	lenses.prepare()
	for p in g.P:
		_write(p)
	_upload()

## repaint only changed provinces (engine dirty list); lenses that depend on global stats repaint everything
func repaint(dirty: PackedInt32Array, full: bool = false) -> void:
	if full or dirty.size() > g.P / 3:
		repaint_all(); return
	for p in dirty:
		_write(p)
	_upload()

func _write(p: int) -> void:
	var id := p + 1
	var c := lenses.color(p)
	var o := id * 4
	_pal[o] = (c >> 16) & 255; _pal[o + 1] = (c >> 8) & 255; _pal[o + 2] = c & 255; _pal[o + 3] = 255
	var ow := g.owner[p]
	var me := g.human_id
	var fl := 0
	if me != 0 and ow != 0:
		if ow == me: fl = 1
		elif g.get_rel(me, ow) == 1: fl = 2
	var r1 := (PAL_W + id) * 4
	_pal[r1] = ow & 255; _pal[r1 + 1] = (ow >> 8) & 255; _pal[r1 + 2] = fl; _pal[r1 + 3] = 255
	var r2 := (2 * PAL_W + id) * 4
	var oc := g.occupier[p]
	if oc != 0 and ow != 0 and (lenses.mode == "political" or lenses.mode == "military" or lenses.mode == "wars"):
		var rc: int = lenses.nat_rgb[oc]
		_pal[r2] = (rc >> 16) & 255; _pal[r2 + 1] = (rc >> 8) & 255; _pal[r2 + 2] = rc & 255; _pal[r2 + 3] = 255
	else:
		_pal[r2 + 3] = 0

func _upload() -> void:
	if _vp != null: _vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if labels != null: labels.queue_redraw()
	_pal_img.set_data(PAL_W, 4, false, Image.FORMAT_RGBA8, _pal)
	_pal_tex.update(_pal_img)

func set_lens(name: String) -> void:
	lenses.mode = name
	repaint_all()

## low tier samples a half-resolution ID texture (built once, nearest) to save VRAM and fill-rate
func _select_ids_texture() -> void:
	var want_half := quality == 0
	if want_half == _ids_is_half: return
	_ids_is_half = want_half
	if want_half:
		if _ids_tex_half == null:
			var img := Image.create_from_data(world.W, world.H, false, Image.FORMAT_RG8, world.ids)
			img.resize(world.W / 2, world.H / 2, Image.INTERPOLATE_NEAREST)
			_ids_tex_half = ImageTexture.create_from_image(img)
		_mat.set_shader_parameter("ids", _ids_tex_half)
		_mat.set_shader_parameter("id_size", Vector2(world.W / 2, world.H / 2))
	else:
		_mat.set_shader_parameter("ids", _ids_tex)
		_mat.set_shader_parameter("id_size", Vector2(world.W, world.H))

# ---------------------------------------------------------------- camera
func radius_px() -> float: return minf(size.x, size.y) * 0.44 * zoom
func flat_scale() -> float: return size.x / TAU * zoom

func _push_view() -> void:
	if _mat == null: return
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var vs := Vector2i(maxi(64, int(size.x * render_scale)), maxi(64, int(size.y * render_scale)))
	if _vp.size != vs:
		_vp.size = vs
		_rect.size = Vector2(vs)
	_mat.set_shader_parameter("rect_size", Vector2(vs))
	_mat.set_shader_parameter("lon0", lon0)
	_mat.set_shader_parameter("lat0", lat0)
	_mat.set_shader_parameter("radius", radius_px() * render_scale)
	_mat.set_shader_parameter("flat_scale", flat_scale() * render_scale)
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("sel_id", selected + 1 if selected >= 0 else -1)
	_mat.set_shader_parameter("hover_id", hover + 1 if hover >= 0 else -1)
	_mat.set_shader_parameter("quality", quality)
	_select_ids_texture()
	if labels != null:
		labels.max_labels = [40, 90, 160][quality]
		labels.hidden_while_dragging = _pressed and _drag_moved >= 6.0
		labels.queue_redraw()
	view_changed.emit()

func set_mode(m: int) -> void:
	mode = m
	zoom = 1.0 if m == 0 else maxf(1.0, (size.y / PI) / (size.x / TAU))
	lat0 = 0.35 if m == 0 else 0.0
	_push_view()

func select(p: int) -> void:
	selected = p
	_push_view()

func fly_to(lon_deg: float, lat_deg: float, z: float = -1.0) -> void:
	lon0 = deg_to_rad(lon_deg); lat0 = clampf(deg_to_rad(lat_deg), -1.45, 1.45)
	if z > 0.0: zoom = z
	_clamp_flat(); _push_view()

func zoom_by(f: float) -> void:
	var lo := 0.6 if mode == 0 else maxf(0.5, (size.y / PI) / (size.x / TAU))
	var hi := 14.0 if mode == 0 else 24.0
	zoom = clampf(zoom * f, lo, hi)
	_clamp_flat(); _push_view()

func drag_by(d: Vector2) -> void:
	if mode == 0:
		var k := 1.0 / radius_px()
		lon0 = wrapf(lon0 - d.x * k, -PI, PI)
		lat0 = clampf(lat0 + d.y * k, -1.45, 1.45)
	else:
		var k := 1.0 / flat_scale()
		lon0 = wrapf(lon0 - d.x * k, -PI, PI)
		lat0 += d.y * k
		_clamp_flat()
	_push_view()

func _clamp_flat() -> void:
	if mode != 1: return
	var lim := maxf(0.0, PI / 2 - (size.y / 2.0) / flat_scale())
	lat0 = clampf(lat0, -lim, lim)

# ---------------------------------------------------------------- picking
## screen position (control-local px) -> province index or -1
func pick_at(pos: Vector2) -> int:
	var ll := unproject(pos)
	if ll == Vector2.INF: return -1
	var u := fposmod(ll.x / TAU + 0.5, 1.0)
	var x := mini(world.W - 1, int(u * world.W))
	var y := clampi(int((0.5 - ll.y / PI) * world.H), 0, world.H - 1)
	var i := (y * world.W + x) * 2
	return (world.ids[i] | (world.ids[i + 1] << 8)) - 1

## returns Vector2(lon, lat) radians or Vector2.INF
func unproject(pos: Vector2) -> Vector2:
	if mode == 0:
		var d := (pos - size * 0.5) / radius_px()
		d.y = -d.y
		var r2 := d.length_squared()
		if r2 >= 1.0: return Vector2.INF
		var z := sqrt(1.0 - r2)
		var s0 := sin(lat0); var c0 := cos(lat0)
		return Vector2(lon0 + atan2(d.x, z * c0 - d.y * s0), asin(clampf(z * s0 + d.y * c0, -1.0, 1.0)))
	var lon := lon0 + (pos.x - size.x * 0.5) / flat_scale()
	var lat := lat0 - (pos.y - size.y * 0.5) / flat_scale()
	return Vector2.INF if absf(lat) > PI / 2 else Vector2(lon, lat)

## forward projection of lon/lat (degrees) -> screen px; z>0 means visible. Used by overlays.
func project(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg); var lat := deg_to_rad(lat_deg)
	if mode == 0:
		var dl := lon - lon0
		var cl := cos(lat); var sl := sin(lat); var s0 := sin(lat0); var c0 := cos(lat0)
		var x := cl * sin(dl); var y := c0 * sl - s0 * cl * cos(dl); var z := s0 * sl + c0 * cl * cos(dl)
		var R := radius_px()
		return Vector3(size.x * 0.5 + R * x, size.y * 0.5 - R * y, z)
	var dl2 := wrapf(lon - lon0, -PI, PI)
	var s := flat_scale()
	return Vector3(size.x * 0.5 + dl2 * s, size.y * 0.5 - (lat - lat0) * s, 1.0)

# ---------------------------------------------------------------- input
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: _touches[event.index] = event.position
		else: _touches.erase(event.index)
		_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var ks := _touches.keys()
			var d: float = (_touches[ks[0]] - _touches[ks[1]]).length()
			if _pinch_dist > 0.0 and d > 0.0: zoom_by(d / _pinch_dist)
			_pinch_dist = d
		return
	if _touches.size() >= 2: return          # ignore emulated mouse while pinching
	if event is InputEventMagnifyGesture:
		zoom_by(event.factor); return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: if event.pressed: zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN: if event.pressed: zoom_by(0.9)
			MOUSE_BUTTON_LEFT:
				if event.pressed: _pressed = true; _drag_moved = 0.0
				else:
					if _pressed and _drag_moved < 6.0: province_picked.emit(pick_at(event.position), false)
					_pressed = false
					_push_view()
			MOUSE_BUTTON_RIGHT:
				if event.pressed: province_picked.emit(pick_at(event.position), true)
	elif event is InputEventMouseMotion:
		if _pressed:
			_drag_moved += event.relative.length()
			if _drag_moved >= 6.0: drag_by(event.relative)
		else:
			var h := pick_at(event.position)
			if h != hover:
				hover = h; _push_view(); province_hovered.emit(h)
