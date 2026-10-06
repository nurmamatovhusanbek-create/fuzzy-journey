## GPU map control: camera, input (mouse/touch/pinch), picking, palette upload.
class_name TBMapView
extends Control

signal province_picked(p: int, secondary: bool)
signal province_hovered(p: int)
signal province_peeked(p: int)       # touch long-press (450 ms): tooltip peek, no selection; -1 when released
signal view_changed
signal performance_low        # sustained slow frames while interacting -> UI may lower the quality tier

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
## camera / highlight animation (the GPU view is re-rendered only while something is moving)
static var animate := OS.get_environment("TB_NOANIM") == ""
var _sel_t := 1.0
var _hover_t := 0.0
var _hover_prev := -1
var _hover_prev_t := 0.0
var _fly := {}
var _vel := Vector2.ZERO                  # drag velocity (px/s) for flick inertia
var _vel_us := 0
var _zoom_target := -1.0

## orders: valid targets are lit, everything else recedes to 60 % (art bible 5.3); the focus ring marks the Tab-selected province
var dim_others := false:
	set(v):
		if dim_others == v: return
		dim_others = v; _push_view()
var focus_province := -1
var _press_id := 0
var _peeked := false
## the last pick came from a finger (touch orders on a lit target; mouse selects and orders with the right button)
var last_pick_touch := DisplayServer.is_touchscreen_available()
var quality := 2
var map_theme := 0               # 0 standard, 1 parchment
var _hi_owner := -1              # nation highlighted on the pick screen (others dim)
var render_scale := 1.0        # SubViewport resolution relative to the control's logical size
var _vp: SubViewport
var _view_tex: TextureRect
var labels: TBMapLabels
## global rectangles the interface covers (dock, seal, ribbon, panel): labels keep out of them
var keepout_fn: Callable
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
	_rel_changed()
	lenses.refresh_nations()
	lenses.prepare()
	for p in g.P:
		_write(p)
	_upload()

## repaint only changed provinces (engine dirty list); lenses that depend on global stats repaint everything
func repaint(dirty: PackedInt32Array, full: bool = false) -> void:
	if full or dirty.size() > g.P / 3 or _rel_changed():
		repaint_all(); return
	if lenses.cvd_active() and lenses.refresh_nations():     # an owner change re-solved the adjacency colouring
		repaint_all(); return
	for p in dirty:
		_write(p)
	_upload()

var _rel_sig := -1
## true when the player's relations changed since the last full paint (a war or pact recolours every province of that nation)
func _rel_changed() -> bool:
	var me := g.human_id
	if me == 0: return false
	var sig := me
	for n in range(1, g.N1): sig = (sig * 31 + g.rel[me * g.N1 + n] + 1) & 0x3fffffff
	if sig == _rel_sig: return false
	_rel_sig = sig
	return true

func _write(p: int) -> void:
	var id := p + 1
	var c := lenses.color(p)
	var o := id * 4
	_pal[o] = (c >> 16) & 255; _pal[o + 1] = (c >> 8) & 255; _pal[o + 2] = c & 255; _pal[o + 3] = 255
	var ow := g.owner[p]
	var me := g.human_id
	var fl := 0                                  # relation class for the shader's border patterns: 1 own, 2 war, 3 ally, 4 truce / NAP, 5 rebel
	if ow != 0 and ow == g.rebel: fl = 5
	elif me != 0 and ow != 0:
		if ow == me: fl = 1
		else:
			var r := g.get_rel(me, ow)
			if r == 1: fl = 2
			elif r == 3 or r == 4: fl = 3
			elif r == 2: fl = 4
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

## highlight provinces (move/attack targets). Pass an empty array to clear.
var _targets := PackedInt32Array()
func set_targets(list: PackedInt32Array) -> void:
	for p in _targets: _pal[(3 * PAL_W + p + 1) * 4] = 0
	_targets = list
	for p in _targets: _pal[(3 * PAL_W + p + 1) * 4] = 255
	_upload()

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
	_mat.set_shader_parameter("sel_t", _sel_t)
	_mat.set_shader_parameter("hover_t", _hover_t)
	_mat.set_shader_parameter("hover_prev", _hover_prev + 1 if _hover_prev >= 0 else -1)
	_mat.set_shader_parameter("hover_prev_t", _hover_prev_t)
	_mat.set_shader_parameter("dim_others", 1.0 if dim_others else 0.0)
	_mat.set_shader_parameter("quality", quality)
	_mat.set_shader_parameter("theme", map_theme)
	_mat.set_shader_parameter("hc", 1 if TBTokens.is_hc() else 0)
	_mat.set_shader_parameter("strong", 1 if (TBTokens.is_hc() or TBLenses.cvd != "off") else 0)
	_mat.set_shader_parameter("px_scale", render_scale)
	_mat.set_shader_parameter("hi_owner", _hi_owner)
	_select_ids_texture()
	if labels != null:
		labels.max_labels = [30, 70, 110][quality]
		labels.hidden_while_dragging = quality == 0 and _pressed and _drag_moved >= 6.0
		labels.queue_redraw()
	view_changed.emit()

func set_mode(m: int) -> void:
	mode = m
	zoom = 1.0 if m == 0 else maxf(1.0, (size.y / PI) / (size.x / TAU))
	lat0 = 0.35 if m == 0 else 0.0
	_push_view()

func select(p: int) -> void:
	if p != selected and TBKit.motion_ok(): _sel_t = 0.0
	selected = p
	_push_view()

func _set_hover(h: int) -> void:
	if h == hover: return
	if TBKit.motion_ok():
		_hover_prev = hover; _hover_prev_t = _hover_t
		_hover_t = 0.0
	hover = h
	_push_view()

## glide the camera to a place (eased; instant when animations are off or the map is not laid out yet)
func fly_to(lon_deg: float, lat_deg: float, z: float = -1.0) -> void:
	var tl := deg_to_rad(lon_deg)
	var tla := clampf(deg_to_rad(lat_deg), -1.45, 1.45)
	var tz := z if z > 0.0 else zoom
	_vel = Vector2.ZERO; _zoom_target = -1.0
	if not TBKit.motion_ok() or size.x < 8.0 or _mat == null:
		lon0 = tl; lat0 = tla; zoom = tz
		_clamp_flat(); _push_view(); return
	var dl := wrapf(tl - lon0, -PI, PI)
	var span := absf(dl) + absf(tla - lat0) + absf(log(tz / zoom)) * 0.4
	_fly = {"t": 0.0, "dur": clampf(0.30 + span * 0.55, 0.30, 1.0), "l0": lon0, "dl": dl, "a0": lat0, "da": tla - lat0, "z0": zoom, "z1": tz}

func zoom_by(f: float, smooth: bool = false) -> void:
	var lo := 0.6 if mode == 0 else maxf(0.5, (size.y / PI) / (size.x / TAU))
	var hi := 14.0 if mode == 0 else 24.0
	_fly = {}
	if smooth and TBKit.motion_ok():
		var base := _zoom_target if _zoom_target > 0.0 else zoom
		_zoom_target = clampf(base * f, lo, hi)
		_push_view(); return
	_zoom_target = -1.0
	zoom = clampf(zoom * f, lo, hi)
	_clamp_flat(); _push_view()

func _process(delta: float) -> void:
	if _mat == null: return
	var busy := false
	var motion := TBKit.motion_ok()
	# flight
	if not _fly.is_empty():
		_fly["t"] += delta
		var k := clampf(_fly["t"] / _fly["dur"], 0.0, 1.0)
		var e := k * k * k * (k * (k * 6.0 - 15.0) + 10.0)          # smootherstep
		lon0 = wrapf(_fly["l0"] + _fly["dl"] * e, -PI, PI)
		lat0 = clampf(_fly["a0"] + _fly["da"] * e, -1.45, 1.45)
		zoom = _fly["z0"] * pow(_fly["z1"] / _fly["z0"], e)
		_clamp_flat()
		if k >= 1.0: _fly = {}
		busy = true
	# eased wheel zoom
	if _zoom_target > 0.0:
		var ratio := _zoom_target / zoom
		if absf(ratio - 1.0) < 0.002: zoom = _zoom_target; _zoom_target = -1.0
		else: zoom *= pow(ratio, 1.0 - exp(-14.0 * delta))
		_clamp_flat()
		busy = true
	# flick inertia
	if motion and not _pressed and _vel.length() > 12.0:
		drag_by(_vel * delta)
		_vel *= exp(-4.2 * delta)
		busy = true
	elif not _pressed:
		_vel = Vector2.ZERO
	# highlight fades and the breathing pulse
	var was := _hover_t + _hover_prev_t + _sel_t
	if motion:
		_hover_t = move_toward(_hover_t, 1.0 if hover >= 0 else 0.0, delta * 9.0)
		_hover_prev_t = move_toward(_hover_prev_t, 0.0, delta * 7.0)
		_sel_t = move_toward(_sel_t, 1.0, delta * 8.0)
	else:
		_hover_t = 1.0 if hover >= 0 else 0.0; _hover_prev_t = 0.0; _sel_t = 1.0
	if absf(_hover_t + _hover_prev_t + _sel_t - was) > 0.0001: busy = true
	if busy:
		_push_view()

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

var _last_drag_us := 0
var _slow_count := 0
var _sample_n := 0
## inter-event time while dragging ~ frame time on a vsync'd device; sustained > ~45 ms means the GPU can't keep up
func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_drag_us != 0:
		var dt := (now - _last_drag_us) / 1000.0
		if dt < 250.0:                       # ignore pauses
			_sample_n += 1
			if dt > 45.0: _slow_count += 1
			if _sample_n >= 30:
				if _slow_count >= 18: performance_low.emit()
				_sample_n = 0; _slow_count = 0
	_last_drag_us = now

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
## fingers wobble: on touch devices a tap may move a little before it stops being a tap
func _tap_slop() -> float: return 16.0 if DisplayServer.is_touchscreen_available() else 6.0

## touch long-press: after 450 ms of a still finger the tooltip peeks at the province without selecting it
func _arm_peek(id: int, pos: Vector2) -> void:
	if not is_inside_tree(): return
	get_tree().create_timer(0.45).timeout.connect(func():
		if id == _press_id and _pressed and _drag_moved < _tap_slop() and _touches.size() < 2:
			_peeked = true
			province_peeked.emit(pick_at(pos)))

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
			MOUSE_BUTTON_WHEEL_UP: if event.pressed: zoom_by(1.18, true)
			MOUSE_BUTTON_WHEEL_DOWN: if event.pressed: zoom_by(1.0 / 1.18, true)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press_id += 1; _peeked = false
					if event.device == InputEvent.DEVICE_ID_EMULATION: _arm_peek(_press_id, event.position)
					_pressed = true; _drag_moved = 0.0; _vel = Vector2.ZERO; _fly = {}; _zoom_target = -1.0; _vel_us = 0
				else:
					if _peeked: province_peeked.emit(-1); _peeked = false
					elif _pressed and _drag_moved < _tap_slop():
						last_pick_touch = event.device == InputEvent.DEVICE_ID_EMULATION
						province_picked.emit(_pick_tap(event.position), false); _vel = Vector2.ZERO
					elif Time.get_ticks_usec() - _vel_us > 90000 or not TBKit.motion_ok(): _vel = Vector2.ZERO      # finger rested before lifting: no flick
					_pressed = false
					_last_drag_us = 0
					_push_view()
			MOUSE_BUTTON_RIGHT:
				if event.pressed: last_pick_touch = false; province_picked.emit(pick_at(event.position), true)
	elif event is InputEventMouseMotion:
		if _pressed:
			_drag_moved += event.relative.length()
			if _drag_moved >= _tap_slop():
				_sample_frame()
				var now := Time.get_ticks_usec()
				if _vel_us != 0:
					var dt := maxf(0.004, (now - _vel_us) / 1e6)
					_vel = _vel.lerp(event.relative / dt, 0.4)
				_vel_us = now
				drag_by(event.relative)
		else:
			var h := pick_at(event.position)
			if h != hover:
				_set_hover(h); province_hovered.emit(h)

# ---------------------------------------------------------------- accessibility + nation pick helpers
## colour-vision mode and high contrast (called by main when the settings change); `cfg["cvd"]` in off / deuter / protan / tritan
func apply_a11y(cfg: Dictionary) -> void:
	var changed := TBLenses.set_cvd(String(cfg.get("cvd", "off")))
	if lenses != null and changed: repaint_all()
	_push_view()

## the pick screen lights the whole nation and dims the rest (pass the nation index); clear_highlight() restores the map
func highlight_nation(n: int) -> void:
	if n == _hi_owner: return
	_hi_owner = n; _push_view()

func clear_highlight() -> void:
	highlight_nation(-1)

## move the keyboard / list cursor to a province and bring it into view
func focus_on(p: int) -> void:
	if g == null or p < 0 or p >= g.P: return
	focus_province = p
	fly_to(world.lon[p], world.lat[p])
	if labels != null: labels.queue_redraw()

## tap magnet for the nation-pick screen: a tap within 20 dp of a much smaller nation (or of land when the tap hit the sea) snaps to it,
## so the tiniest nations stay selectable with a finger. Elsewhere it is plain picking.
func _pick_tap(pos: Vector2) -> int:
	var p := pick_at(pos)
	if g == null or g.human_id != 0: return p
	var counts := PackedInt32Array(); counts.resize(g.N1)
	for q in g.P: counts[g.owner[q]] += 1
	var best := p
	var best_n := counts[g.owner[p]] if (p >= 0 and g.owner[p] != 0) else 1000000
	var rad := float(TBKit.dp(20.0))
	for ring in [rad * 0.35, rad * 0.7, rad]:
		for k in 12:
			var q := pick_at(pos + Vector2.from_angle(k * TAU / 12.0) * ring)
			if q < 0 or g.owner[q] == 0: continue
			var c := counts[g.owner[q]]
			if c * 3 <= best_n: best = q; best_n = c
	return best
