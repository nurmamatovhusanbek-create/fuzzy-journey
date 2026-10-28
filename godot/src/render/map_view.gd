## GPU map control: camera, input (mouse/touch/pinch), picking, palette upload.
class_name TBMapView
extends Control

signal province_picked(p: int, secondary: bool)
signal province_hovered(p: int)
signal province_peeked(p: int)       # touch long-press (450 ms): tooltip peek, no selection; -1 when released
signal view_changed
signal performance_low        # sustained slow frames while interacting -> UI may lower the quality tier

const SHADER := preload("res://src/render/globe.gdshader")
## One shader per quality tier: the tier is a `const` in each, so the code a tier never runs (the 3x3 B-spline id lookups of the high tier, for one) is not compiled in at all. The GPU
## then plans its registers for the code that does run, and the driver compiles less (ANGLE / D3D especially). The picture is the same code path as before, just without the
## branches that were never taken.
static var _tier_shaders := {}
static func tier_shader(q: int) -> Shader:
	if _tier_shaders.has(q): return _tier_shaders[q]
	var sh := Shader.new()
	var code: String = SHADER.code
	assert(code.contains("uniform int quality = 2;"))
	sh.code = code.replace("uniform int quality = 2;", "const int quality = %d;" % q)
	_tier_shaders[q] = sh
	return sh
var _shader_q := -1
const VIGNETTE := preload("res://src/render/vignette.gdshader")
const PAL_W := 2048
var _vig: ColorRect

var g: TBGame
var world: TBWorld
var lenses: TBLenses
var mode := 0                 # 0 globe, 1 flat
var lon0 := 0.26
var lat0 := 0.35
var zoom := 1.0
var grid_k := 1.0                       # graticule strength (0.35 on the title)
var selected := -1
var hover := -1
## camera / highlight animation (the GPU view is re-rendered only while something is moving)
static var animate := OS.get_environment("TB_NOANIM") == ""
var _sel_t := 1.0
var _sel_pulse := 0.0                # C6: 1 -> 0 over 0.55 s after a new selection (Light / Full): the province flashes cream once, then settles
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
var _outline_owner := -1        # nation whose border is outlined (the selected province's owner)
var _hi_owner := -1              # nation highlighted on the pick screen (others dim)
var render_scale := 1.0        # SubViewport resolution relative to the control's logical size
var _vp: SubViewport
var _view_tex: TextureRect
var labels: TBMapLabels
var routes: TBMapRoutes
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
		_mat.shader = tier_shader(quality); _shader_q = quality
		_rect.material = _mat
		_clip = Control.new()                                          # the scissor of a partial redraw (the whole viewport for a full one)
		_clip.clip_contents = true; _clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp.add_child(_clip)
		_clip.add_child(_rect)
		var bbraw := FileAccess.get_file_as_bytes("res://data/prov_bbox.bin.gz").decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		for bi in range(0, bbraw.size() - 1, 2): _pbb.append(bbraw.decode_s16(bi))
		RenderingServer.frame_post_draw.connect(_on_drawn)
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
		var cz := FileAccess.get_file_as_bytes("res://data/coast.bin.gz").decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)       # the coastal glow's distance field (tools/gen_coast.sh)
		_mat.set_shader_parameter("coast", ImageTexture.create_from_image(Image.create_from_data(world.W / 2, world.H / 2, false, Image.FORMAT_RH, cz)))
		_pal.resize(PAL_W * 4 * 4)
		_pal_img = Image.create_from_data(PAL_W, 4, false, Image.FORMAT_RGBA8, _pal)
		_pal_tex = ImageTexture.create_from_image(_pal_img)
		_mat.set_shader_parameter("pal", _pal_tex)
		resized.connect(_push_view)
		routes = TBMapRoutes.new(); add_child(routes); routes.attach(self)
		labels = TBMapLabels.new(); add_child(labels); labels.attach(self)
		labels.set_meta("bake_rect", func() -> Rect2: return Rect2(Vector2.ZERO, size))
		TBBake.attach(labels)
		TBBake.attach(routes)                                         # a still map: one picture of the route lines instead of a few dozen draw calls (src/ui/bake.gd). Not the labels: their text is rasterised at the screen's scale, a bitmap of it would be a touch softer
		_vig = ColorRect.new()                                        # the demo's vignette, over the map and its markers but under the interface
		_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
		var vm := ShaderMaterial.new(); vm.shader = VIGNETTE
		_vig.material = vm
		add_child(_vig)
	lenses = TBLenses.new(g)
	labels.set_game(g)
	routes.set_game(g)
	repaint_all()
	_push_view()

# ---------------------------------------------------------------- palette
func repaint_all() -> void:
	_fade.clear()
	TBVision.sync(g)
	_rel_changed()
	lenses.refresh_nations()
	lenses.prepare()
	for p in g.P:
		_write(p)
	_upload()

## repaint only changed provinces (engine dirty list); lenses that depend on global stats repaint everything
func repaint(dirty: PackedInt32Array, full: bool = false) -> void:
	TBVision.sync(g)
	if full or dirty.size() > g.P / 3 or _rel_changed() or (lenses.mode == "military" and g.rules >= 1 and not dirty.is_empty()):
		repaint_all(); return
	if lenses.cvd_active() and lenses.refresh_nations():     # an owner change re-solved the adjacency colouring
		repaint_all(); return
	var fade_ok: bool = quality >= 1 and TBFx.on(TBFx.FULL)                 # C2: a province that changes colour (a conquest) dissolves into its new one over 0.5 s
	var k := 0
	for p in dirty:
		var o: int = (p + 1) * 4
		var r0: int = _pal[o]; var g0: int = _pal[o + 1]; var b0: int = _pal[o + 2]
		var had: bool = _pal[o + 3] == 255
		_write(p)
		if fade_ok and had and (_pal[o] != r0 or _pal[o + 1] != g0 or _pal[o + 2] != b0):
			_fade[p] = [r0, g0, b0, int(_pal[o]), int(_pal[o + 1]), int(_pal[o + 2]), 0.0, minf(0.04 * float(k), 0.32)]
			k += 1
			_pal[o] = r0; _pal[o + 1] = g0; _pal[o + 2] = b0
	_upload()

var _fade := {}                              # province -> [from rgb, to rgb, elapsed, delay]
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
	if oc != 0 and ow != 0 and (lenses.mode == "political" or lenses.mode == "routes" or lenses.mode == "military" or lenses.mode == "wars"):
		var rc: int = lenses.nat_rgb[oc]
		_pal[r2] = (rc >> 16) & 255; _pal[r2 + 1] = (rc >> 8) & 255; _pal[r2 + 2] = rc & 255; _pal[r2 + 3] = 255
	else:
		_pal[r2 + 3] = 0

func _upload() -> void:
	_pal_gen += 1
	_request_render()
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
	_push_view()

## a route line was picked in the Routes lens: its kind's countries stay lit, the same line again (or the empty map) lets go
func set_route_kind(k: String) -> void:
	if lenses == null: return
	if lenses.route_kind == k: k = ""
	lenses.set_route_kind(k)
	repaint_all()
	if routes != null: routes.queue_redraw()
	_lk = []; _push_view()

func set_lens(name: String) -> void:
	if name != "routes" and lenses.route_kind != "": lenses.set_route_kind("")
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
## the flat map is a Mercator (as in the Bezel demo): x = lon, y = ln tan(pi/4 + lat/2), so shapes keep their proportions at every latitude
const MERC_LIM := 1.4844                                    # 85.05 deg, where the Mercator square ends
static func merc(lat: float) -> float: return log(tan(PI * 0.25 + clampf(lat, -MERC_LIM, MERC_LIM) * 0.5))
static func imerc(y: float) -> float: return 2.0 * atan(exp(y)) - PI * 0.5
## px per radian of the ground at the view centre (Mercator stretches by 1 / cos(lat)): sizes of things that live on the ground (nations, provinces)
func flat_local() -> float: return flat_scale() / maxf(0.2, cos(lat0))
## screen px per radian of longitude / of Mercator y at the view centre is flat_scale(); px per radian of latitude at lat is flat_scale() / cos(lat)

func _push_view() -> void:
	if _mat == null: return
	if _shader_q != quality and _shader_q >= 0:                       # the quality tier changed: its own shader
		_shader_q = quality; _mat.shader = tier_shader(quality)
	var rs: float = render_scale
	var vs := Vector2i(maxi(64, int(size.x * rs)), maxi(64, int(size.y * rs)))
	if _vp.size != vs:
		_vp.size = vs
		_rect.size = Vector2(vs)
		_clip.size = Vector2(vs)
	_mat.set_shader_parameter("rect_size", Vector2(vs))
	_mat.set_shader_parameter("lon0", lon0)
	_mat.set_shader_parameter("lat0", lat0)
	_mat.set_shader_parameter("grid_k", grid_k); _mat.set_shader_parameter("slat0", sin(lat0)); _mat.set_shader_parameter("clat0", cos(lat0))
	_mat.set_shader_parameter("merc0", log(tan(PI * 0.25 + clampf(lat0, -1.4844, 1.4844) * 0.5)))
	_mat.set_shader_parameter("radius", radius_px() * rs)
	_mat.set_shader_parameter("flat_scale", flat_scale() * rs)
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("sel_id", selected + 1 if selected >= 0 else -1)
	_mat.set_shader_parameter("hover_id", hover + 1 if hover >= 0 else -1)
	_mat.set_shader_parameter("sel_t", _sel_t)
	_mat.set_shader_parameter("sel_pulse", _sel_pulse)
	_mat.set_shader_parameter("hover_t", _hover_t)
	_mat.set_shader_parameter("hover_prev", _hover_prev + 1 if _hover_prev >= 0 else -1)
	_mat.set_shader_parameter("hover_prev_t", _hover_prev_t)
	_mat.set_shader_parameter("dim_others", 1.0 if dim_others else 0.0)
	_mat.set_shader_parameter("quality", quality)
	_mat.set_shader_parameter("theme", map_theme)
	_mat.set_shader_parameter("hc", 1 if TBTokens.is_hc() else 0)
	_mat.set_shader_parameter("strong", 1 if (TBTokens.is_hc() or TBLenses.cvd != "off") else 0)
	_mat.set_shader_parameter("px_scale", rs)
	_mat.set_shader_parameter("hi_owner", _hi_owner)
	_mat.set_shader_parameter("outline_owner", _outline_owner)
	_mat.set_shader_parameter("atlas", 1 if atlas_look() else 0)
	_mat.set_shader_parameter("signal_owner", g.human_id if (g != null and atlas_look()) else -1)
	_mat.set_shader_parameter("signal_col", Vector3(TBTokens.accent.r, TBTokens.accent.g, TBTokens.accent.b))
	_mat.set_shader_parameter("marching", 1 if TBKit.motion_ok() else 0)
	_mat.set_shader_parameter("tgt_any", 1 if not _targets.is_empty() else 0)
	if _vig != null: _vig.visible = atlas_look()
	_select_ids_texture()
	_request_render()
	if labels != null:
		labels.max_labels = [30, 70, 110][quality]
		labels.hidden_while_dragging = quality == 0 and _pressed and _drag_moved >= 6.0
		_labels_relayout()
	view_changed.emit()

## zoomed in far enough that other countries' districts are worth telling apart (their names, armies and terrain appear); further out, a country is one thing
func district_zoom() -> bool: return zoom >= (2.6 if mode == 0 else maxf(3.4, flat_fit() * 2.0))

# ---------------------------------------------------------------- redraws: all of the map, or only the part a hover / selection changed
## A hover brightens a nation, a selection washes a province: nothing else on the map changes, so the shader is run again only over their screen area (a scissor on the
## viewport, the rest of the picture kept). Anything else (the camera, the palette, a lens, targets, the quality) draws it all. The same shader and uniforms, so the pixels are
## the pixels a full redraw would give (tests/map_partial.gd draws random hovers both ways and compares).
var _clip: Control
var _pbb := PackedInt32Array()            # per province: x0 y0 x1 y1 in id texels (data/prov_bbox.bin.gz)
var _pal_gen := 0                         # counts palette uploads
var _rend_sig: Array = []                 # what the last redraw was made of (everything but the highlights)
var _rend_hl: Array = []                  # ... and the highlights it drew
var _pend_full := true                    # a full redraw is queued, not drawn yet
var _pend_part := Rect2()                 # highlight changes queued, not drawn yet (logical px)
var _pend_part_ok := false
var _rect_cache := {}                     # nation (n) / province (-1 - p) -> its screen rect in this view, or Rect2(0, 0, -1, -1) when it cannot be bounded
var partial_ok := true                    # false: every redraw is a full one (the tests compare the two)
var full_redraws := 0                     # counters for the tests and the diagnostics
var partial_redraws := 0

func _on_drawn() -> void:
	_pend_full = false; _pend_part_ok = false; _pend_part = Rect2()

func _request_render() -> void:
	if _vp == null or _mat == null: return
	var sig: Array = [_vp.size, lon0, lat0, radius_px(), flat_scale(), mode, quality, map_theme, TBTokens.is_hc(), TBLenses.cvd, atlas_look(), g.human_id if g != null else -1, TBTokens.accent,
		not _targets.is_empty(), dim_others, _hi_owner, _outline_owner, render_scale, _pal_gen, _ids_is_half]
	var hl: Array = [hover, _hover_t, _hover_prev, _hover_prev_t, selected, _sel_t, _sel_pulse]
	if _pend_full or _rend_hl.is_empty() or sig != _rend_sig or not partial_ok:
		_full_redraw(sig, hl); return
	if hl == _rend_hl: return                                          # nothing the picture shows has changed
	var r := _dirty_rect(_rend_hl, hl)
	_rend_hl = hl
	if r.size.x < 0.0:
		_full_redraw(sig, hl); return
	if r.size.x == 0.0 or r.size.y == 0.0: return                      # the changed places are off the screen
	_partial_redraw(r)

func _full_redraw(sig: Array, hl: Array) -> void:
	_rend_sig = sig; _rend_hl = hl; _pend_full = true; _pend_part_ok = false
	_rect_cache.clear()
	_clip.position = Vector2.ZERO; _clip.size = Vector2(_vp.size); _rect.position = Vector2.ZERO
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	full_redraws += 1

func _partial_redraw(r: Rect2) -> void:
	if _pend_full: return                                              # the queued full redraw will draw the newest state
	_pend_part = r if not _pend_part_ok else _pend_part.merge(r)
	_pend_part_ok = true
	var k: float = render_scale
	var x0: float = floorf(_pend_part.position.x * k); var y0: float = floorf(_pend_part.position.y * k)
	var x1: float = ceilf(_pend_part.end.x * k); var y1: float = ceilf(_pend_part.end.y * k)
	_clip.position = Vector2(x0, y0); _clip.size = Vector2(x1 - x0, y1 - y0); _rect.position = -_clip.position
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	partial_redraws += 1

## the screen area the change from highlights `a` to `b` touches; Rect2(0, 0, -1, -1) = cannot say (draw it all); a zero-size rect = off screen
func _dirty_rect(a: Array, b: Array) -> Rect2:
	var out := Rect2(); var have := false
	var parts: Array = []
	if a[0] != b[0] or a[1] != b[1]: parts.append([a[0], true]); parts.append([b[0], true])
	if a[2] != b[2] or a[3] != b[3]: parts.append([a[2], true]); parts.append([b[2], true])
	if a[4] != b[4] or a[5] != b[5] or a[6] != b[6]: parts.append([a[4], false]); parts.append([b[4], false])
	for pt in parts:
		var id: int = int(pt[0])
		if id < 0: continue
		var r: Rect2 = _hover_rect(id) if bool(pt[1]) else _prov_rect(id)
		if r.size.x < 0.0: return Rect2(0, 0, -1, -1)
		if r.size.x == 0.0: continue
		out = r if not have else out.merge(r); have = true
	if not have: return Rect2()
	if out.get_area() > size.x * size.y * 0.6: return Rect2(0, 0, -1, -1)      # most of the screen anyway
	return out

## what a hover on province h lights: its nation (your own land: the province alone, as the shader decides)
func _hover_rect(h: int) -> Rect2:
	var o: int = g.owner[h]
	var me: int = g.human_id if (g != null and atlas_look()) else -1
	if o == 0 or o == me: return _prov_rect(h)
	var key: int = o
	if _rect_cache.has(key): return _rect_cache[key]
	var out := Rect2(); var have := false
	for p in g.owned(o):
		var r := _prov_rect(p)
		if r.size.x < 0.0: out = r; break
		if r.size.x == 0.0: continue
		out = r if not have else out.merge(r); have = true
	_rect_cache[key] = out
	return out

func _prov_rect(p: int) -> Rect2:
	var key: int = -1 - p
	if _rect_cache.has(key): return _rect_cache[key]
	var bad := Rect2(0, 0, -1, -1)
	var r: Rect2 = bad
	var i: int = p * 4
	if i + 3 < _pbb.size() and _pbb[i + 2] >= 0:
		var x0: float = _pbb[i]; var y0: float = _pbb[i + 1]; var x1: float = _pbb[i + 2] + 1.0; var y1: float = _pbb[i + 3] + 1.0
		if x1 - x0 <= float(world.W) * 0.5:
			var mn := Vector2(1e9, 1e9); var mx := Vector2(-1e9, -1e9)
			var seen := 0; var total := 0
			for iy in 5:
				for ix in 5:
					var lon: float = ((x0 + (x1 - x0) * float(ix) / 4.0) / float(world.W) - 0.5) * 360.0
					var lat: float = (0.5 - (y0 + (y1 - y0) * float(iy) / 4.0) / float(world.H)) * 180.0
					var pr: Vector3 = project(lon, lat)
					total += 1
					if pr.z > 0.02:
						seen += 1
						mn = Vector2(minf(mn.x, pr.x), minf(mn.y, pr.y)); mx = Vector2(maxf(mx.x, pr.x), maxf(mx.y, pr.y))
			if seen == total:
				var m: float = 24.0 + 0.08 * maxf(mx.x - mn.x, mx.y - mn.y)
				r = Rect2(mn - Vector2(m, m), (mx - mn) + Vector2(m, m) * 2.0).intersection(Rect2(Vector2.ZERO, size))
				if r.size.x <= 0.0 or r.size.y <= 0.0: r = Rect2()
			elif seen == 0: r = Rect2()
	_rect_cache[key] = r
	return r

## the labels are laid out again only when something that moves them changed: the hover fade and the selection fade (every frame for 0.1 s after each mouse move)
## no longer redo the whole layout. While the camera moves, a relayout on a slow CPU waits for ~3x its own cost, so the frame rate holds (labels trail the map by a few frames).
var _lk := []
var _lbl_t := 0
var _lbl_pending := false
func _labels_relayout() -> void:
	var k := [lon0, lat0, zoom, size, mode, selected, quality, hover if labels.hover_matters() else -2, labels.hidden_while_dragging, render_scale, TBTokens.is_hc(), TBLenses.cvd, TBKit.text_scale, TBI18n.lang, map_theme, g.human_id if g != null else -1, (lenses.mode + lenses.route_kind) if lenses != null else ""]
	if k == _lk: return
	var cam: bool = _lk.size() > 4 and (k[0] != _lk[0] or k[1] != _lk[1] or k[2] != _lk[2] or k[3] != _lk[3])
	_lk = k
	var now := Time.get_ticks_msec()
	if cam and float(now - _lbl_t) < minf(140.0, labels.last_cost_ms * 3.0):
		_lbl_pending = true; return
	_lbl_t = now; _lbl_pending = false
	labels.queue_redraw()

## the Atlas Ledger map look (in game, standard theme, not high contrast)
func atlas_look() -> bool:
	return TBLenses.dark_land and map_theme == 0 and not TBTokens.is_hc()

var _anim_t := 0.0

func set_mode(m: int) -> void:
	mode = m
	zoom = 1.0 if m == 0 else flat_fit()
	lat0 = 0.35 if m == 0 else 0.0
	_push_view()

func select(p: int) -> void:
	if p != selected and TBKit.motion_ok(): _sel_t = 0.0
	if p != selected and p >= 0 and TBFx.on(TBFx.LIGHT): _sel_pulse = 1.0
	selected = p
	_push_view()

## the pointer left the map (onto a HUD control, a window, or out of the game): no district stays hovered, so its card goes away
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != -1:
		_set_hover(-1); province_hovered.emit(-1)

func _set_hover(h: int) -> void:
	if h == hover: return
	if TBKit.motion_ok():
		_hover_prev = hover; _hover_prev_t = _hover_t
		_hover_t = 0.0
	hover = h
	_push_view()

## put the camera on a place at once (the dive into a game uses it under its dissolve)
func jump_to(lon_deg: float, lat_deg: float, z: float) -> void:
	_fly = {}; _vel = Vector2.ZERO; _zoom_target = -1.0
	lon0 = deg_to_rad(lon_deg); lat0 = clampf(deg_to_rad(lat_deg), -1.45, 1.45); zoom = z
	_clamp_flat(); _push_view()

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

## zoom at which the whole Mercator world is as tall as the view (never less than 1: the world is as wide as the view)
func flat_fit() -> float: return maxf(1.0, (size.y / (2.0 * merc(MERC_LIM))) / (size.x / TAU))

func zoom_by(f: float, smooth: bool = false) -> void:
	var lo := 0.6 if mode == 0 else maxf(0.5, (size.y / (2.0 * merc(MERC_LIM))) / (size.x / TAU))
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
	var was := _hover_t + _hover_prev_t + _sel_t + _sel_pulse
	if motion:
		_hover_t = move_toward(_hover_t, 1.0 if hover >= 0 else 0.0, delta * 9.0)
		_hover_prev_t = move_toward(_hover_prev_t, 0.0, delta * 7.0)
		_sel_t = move_toward(_sel_t, 1.0, delta * 8.0)
		_sel_pulse = move_toward(_sel_pulse, 0.0, delta * 1.8) if TBFx.on(TBFx.LIGHT) else 0.0
	else:
		_hover_t = 1.0 if hover >= 0 else 0.0; _hover_prev_t = 0.0; _sel_t = 1.0; _sel_pulse = 0.0
	if absf(_hover_t + _hover_prev_t + _sel_t + _sel_pulse - was) > 0.0001: busy = true
	if not _fade.is_empty():
		var done: Array = []
		for p in _fade:
			var f: Array = _fade[p]
			f[6] += delta
			var kf: float = clampf((float(f[6]) - float(f[7])) / 0.5, 0.0, 1.0)
			var e: float = kf * kf * (3.0 - 2.0 * kf)
			var o: int = (int(p) + 1) * 4
			for c in 3: _pal[o + c] = int(roundf(lerpf(float(f[c]), float(f[3 + c]), e)))
			if kf >= 1.0: done.append(p)
		for p in done: _fade.erase(p)
		_pal_gen += 1
		_pal_img.set_data(PAL_W, 4, false, Image.FORMAT_RGBA8, _pal)
		_pal_tex.update(_pal_img)
		busy = true
	if _lbl_pending and float(Time.get_ticks_msec() - _lbl_t) >= minf(140.0, labels.last_cost_ms * 3.0):
		_lbl_pending = false; _lbl_t = Time.get_ticks_msec(); labels.queue_redraw()
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
		lat0 = imerc(merc(lat0) + d.y * k)
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
	var lim := maxf(0.0, merc(MERC_LIM) - (size.y / 2.0) / flat_scale())
	lat0 = imerc(clampf(merc(lat0), -lim, lim))

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
	var my := merc(lat0) - (pos.y - size.y * 0.5) / flat_scale()
	return Vector2.INF if absf(my) > merc(MERC_LIM) else Vector2(lon, imerc(my))

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
	return Vector3(size.x * 0.5 + dl2 * s, size.y * 0.5 - (merc(lat) - merc(lat0)) * s, 1.0)

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
						var rk: String = routes.pick_route(event.position) if (routes != null and lenses != null and lenses.mode == "routes") else ""
						if rk != "": set_route_kind(rk); _vel = Vector2.ZERO               # a route line: light its countries (no province is picked)
						else:
							if lenses != null and lenses.route_kind != "": set_route_kind(lenses.route_kind)           # the empty map: let the picked route go
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

## outline one nation's border in brass (the selected province's owner) without dimming the rest; -1 clears it
func outline_nation(n: int) -> void:
	if n == _outline_owner: return
	_outline_owner = n; _push_view()

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
