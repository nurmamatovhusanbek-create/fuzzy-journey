## Surfaces of the interface (art bible 3 and 7.5). Everything is a StyleBox so any PanelContainer / Button / custom control can use it.
##   PLATE  flat chamfered rectangle: fill, 1 px border, cut 4 / 2 / 6, elevation 0 / 1 / 2 (one hard shadow). Panels, buttons, chips, cards.
##   SHEET  THE hero sheet (one per screen, ceremony only): paper grain, <= 1.5 px ragged edge, double rule, 6 px brass corner guards.
##   BAR    flat bar-0 strip with a 1 px rule-dark edge (top bar, dock rail). No leather, no studs.
##   SEAL   the End Turn wax disc with a single brass ring (the one wax object).
##   FOCUS  keyboard focus ring: 2 px ring + 2 px gap + 1 px contrast line, hue-independent (A11Y-KBD-003); drawn only while keyboard / pad navigating.
## Polygons are cached per size (no per-draw allocation); strokes are whole pixels. In high contrast: no texture, no ragged edge, no shadow, 2 px borders.
## Colours are resolved from TBTokens when a style is built: after switching TBTokens.mode rebuild the theme (TBKit.theme()).
class_name TBFrame
extends StyleBox

enum Kind { PLATE, SHEET, BAR, SEAL, FOCUS }
## corner bits for the chamfer mask
const TL := 1
const TR := 2
const BR := 4
const BL := 8
const ALL := 15

const _DIAG := 0.5857864             # 2 - sqrt(2): a 45 degree chamfer offset inwards by d shrinks by this fraction of d
const _CACHE_MAX := 600

## legacy colour names that older call sites still read (TBFrame.PAPER ...)
static var PAPER: Color = TBTokens.NORMAL["paper_0"]
static var INK: Color = TBTokens.NORMAL["ink_0"]
static var BRASS: Color = TBTokens.NORMAL["brass"]

## true once the player navigates by keyboard / pad, false again on a mouse or touch press (a focus ring is drawn only while true)
static var kbd_nav := false
static var _geo := {}
static var _pcs := {}
static var _inst := {}
static var _watch: Node = null

var kind: int = Kind.PLATE
var fill: Color = Color.TRANSPARENT
var border: Color = Color.TRANSPARENT
var cut: int = 4
var corners: int = ALL
var elevation: int = 0
var border_w: int = 1
var accent: Color = Color.TRANSPARENT      # PLATE: a bar along the left edge (selected row, armed / recommended card, toast meaning)
var accent_w: int = 0
var shift: int = 0                         # pressed: content moves 1 px down
var on_bar := false                        # FOCUS: cream ring on dark furniture / map instead of ink on paper
var inset: int = 0                         # FOCUS: draw the ring this many px inside the rect
var ring_tok := ""                         # FOCUS: token of the ring (default ink_0 / cream)
var line_tok := ""                         # FOCUS: token of the 1 px contrast line (default paper_0 / bar_0)
var rule_side: int = SIDE_BOTTOM           # BAR: which edge carries the 1 px rule (-1 = none)
var rule_col: Color = Color.TRANSPARENT
var hot := false                           # SEAL: hover
var pressed := false                       # SEAL: pressed (shadow removed)
var disabled := false                      # SEAL: 40 %

# ---- constructors --------------------------------------------------------------------------------------------------------
static func plate(fill_c: Color, border_c: Color, cut_px: int = 4, elev: int = 0, pad_x: float = 16.0, pad_y: float = 12.0, pressed_shift: bool = false, border_px: int = 1, mask: int = ALL) -> TBFrame:
	var f := TBFrame.new()
	f.kind = Kind.PLATE; f.fill = fill_c; f.border = border_c; f.cut = cut_px; f.elevation = elev
	f.border_w = border_px; f.corners = mask; f.shift = 1 if pressed_shift else 0
	f._margins(pad_x, pad_y)
	return f

## the one hero sheet; use for ceremony only (event, ultimatum, treaty, era, game over, chronicle)
static func hero(pad_x: float = 28.0, pad_y: float = 24.0, tint_c: Color = Color.TRANSPARENT) -> TBFrame:
	var f := TBFrame.new()
	f.kind = Kind.SHEET; f.fill = tint_c if tint_c.a > 0.0 else TBTokens.c("paper_0"); f.border = TBTokens.c("ink_0"); f.cut = TBTokens.CUT_PANEL; f.elevation = 2
	f._margins(pad_x, pad_y)
	return f

static func bar(pad_x: float = 12.0, pad_y: float = 6.0, alpha: float = 0.94, rule_edge: int = SIDE_BOTTOM) -> TBFrame:
	var f := TBFrame.new()
	f.kind = Kind.BAR; f.fill = TBTokens.ca("bar_0", alpha); f.rule_col = TBTokens.c("rule_dark"); f.rule_side = rule_edge
	f._margins(pad_x, pad_y)
	return f

## End Turn wax disc. Cached per state: do not mutate the returned style.
static func seal(is_pressed: bool = false, is_hot: bool = false, is_disabled: bool = false) -> TBFrame:
	var key := "seal%d%d%d%d" % [int(is_pressed), int(is_hot), int(is_disabled), TBTokens.mode]
	if _inst.has(key): return _inst[key]
	var f := TBFrame.new()
	f.kind = Kind.SEAL; f.pressed = is_pressed; f.hot = is_hot; f.disabled = is_disabled; f.elevation = 2
	f.fill = TBTokens.c("wax_press" if is_pressed else ("wax_hover" if is_hot else "wax")); f.border = TBTokens.c("wax_rim"); f.rule_col = TBTokens.c("brass")
	_inst[key] = f
	return f

## focus ring style, cached per variant: do not mutate
## ring_tok / line_tok name tokens for a ring that must sit on a special fill (the primary slab); empty = the ink-on-paper or cream-on-bar default
static func focus(bar_ground: bool = false, cut_px: int = 4, inset_px: int = 0, ring_tok: String = "", line_tok: String = "") -> TBFrame:
	var key := "focus%d%d%d%d%s%s" % [int(bar_ground), cut_px, inset_px, TBTokens.mode, ring_tok, line_tok]
	if _inst.has(key): return _inst[key]
	var f := TBFrame.new()
	f.kind = Kind.FOCUS; f.on_bar = bar_ground; f.cut = cut_px; f.inset = inset_px; f.ring_tok = ring_tok; f.line_tok = line_tok
	_inst[key] = f
	return f

# ---- shims for the previous kinds (SHEET / CHIT / WAX / LEATHER) --------------------------------------------------------
static func make(fill_c: Color, rule_c: Color, _notch: float = 10.0, double: bool = true, pad_x: float = 16.0, pad_y: float = 12.0) -> TBFrame:
	return plate(fill_c, rule_c, TBTokens.CUT_PANEL if double else TBTokens.CUT, 1 if double else 0, pad_x, pad_y)

## old "sheet" = a panel (flat plate); the real hero sheet is TBFrame.hero()
static func sheet(pad_x: float = 20.0, pad_y: float = 16.0, tint_c: Color = Color.TRANSPARENT) -> TBFrame:
	return plate(tint_c if tint_c.a > 0.0 else TBTokens.c("paper_0"), TBTokens.c("rule"), TBTokens.CUT_PANEL, 1, pad_x, pad_y)

## old "chit" = the secondary plate (paper-1, 1 px rule, cut 4)
static func chit(tint_c: Color = Color.TRANSPARENT, pad_x: float = 14.0, pad_y: float = 8.0, is_alert: bool = false) -> TBFrame:
	return plate(tint_c if tint_c.a > 0.0 else TBTokens.c("paper_1"), TBTokens.c("neg" if is_alert else "rule"), TBTokens.CUT, 0, pad_x, pad_y)

## old "wax" button = the flat danger plate
static func wax(pad_x: float = 16.0, pad_y: float = 10.0, is_pressed: bool = false) -> TBFrame:
	return plate(TBTokens.c("wax_press" if is_pressed else "wax"), TBTokens.c("wax_rim"), TBTokens.CUT, 0, pad_x, pad_y, is_pressed)

static func leather(pad_x: float = 12.0, pad_y: float = 6.0) -> TBFrame:
	return bar(pad_x, pad_y)

func _margins(px: float, py: float) -> void:
	set_content_margin(SIDE_LEFT, px); set_content_margin(SIDE_RIGHT, px)
	set_content_margin(SIDE_TOP, py + shift); set_content_margin(SIDE_BOTTOM, maxf(py - shift, 0.0))

# ---- input watcher: the focus ring follows the input device --------------------------------------------------------------
class FocusWatch extends Node:
	func _init() -> void:
		name = "TBFocusWatch"; process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(e: InputEvent) -> void:
		var was := TBFrame.kbd_nav
		if e is InputEventKey and e.pressed: TBFrame.kbd_nav = true
		elif e is InputEventJoypadButton and e.pressed: TBFrame.kbd_nav = true
		elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.5: TBFrame.kbd_nav = true
		elif e is InputEventMouseButton and e.pressed: TBFrame.kbd_nav = false
		elif e is InputEventScreenTouch and e.pressed: TBFrame.kbd_nav = false
		if was != TBFrame.kbd_nav:
			var f := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
			if f != null: f.queue_redraw()

static func ensure_watch() -> void:
	if _watch != null and is_instance_valid(_watch): return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return
	_watch = FocusWatch.new()
	tree.root.add_child.call_deferred(_watch)

# ---- cached colour arrays and polygons ------------------------------------------------------------------------------------
static func _pc(col: Color) -> PackedColorArray:
	if _pcs.has(col): return _pcs[col]
	if _pcs.size() > 400: _pcs.clear()
	var a := PackedColorArray([col])
	_pcs[col] = a
	return a

## chamfered rectangle outline inset by d px from a w x h box whose own chamfer is c px on the corners in `mask`
static func chamfer(w: float, h: float, c: float, mask: int, d: float = 0.0, ox: float = 0.0, oy: float = 0.0) -> PackedVector2Array:
	var k := maxf(c - _DIAG * d, 0.0)
	var x0 := d + ox; var y0 := d + oy; var x1 := w - d + ox; var y1 := h - d + oy
	var p := PackedVector2Array()
	if mask & TL and k > 0.0: p.append(Vector2(x0, y0 + k)); p.append(Vector2(x0 + k, y0))
	else: p.append(Vector2(x0, y0))
	if mask & TR and k > 0.0: p.append(Vector2(x1 - k, y0)); p.append(Vector2(x1, y0 + k))
	else: p.append(Vector2(x1, y0))
	if mask & BR and k > 0.0: p.append(Vector2(x1, y1 - k)); p.append(Vector2(x1 - k, y1))
	else: p.append(Vector2(x1, y1))
	if mask & BL and k > 0.0: p.append(Vector2(x0 + k, y1)); p.append(Vector2(x0, y1 - k))
	else: p.append(Vector2(x0, y1))
	return p

static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q

static func _circle(c: Vector2, r: float, n: int = 48) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n: p.append(c + Vector2(cos(i * TAU / n), sin(i * TAU / n)) * r)
	return p

static func _geo_get(key: Variant) -> Variant:
	return _geo.get(key)

static func _geo_put(key: Variant, v: Variant) -> void:
	if _geo.size() > _CACHE_MAX: _geo.clear()
	_geo[key] = v

# ---- drawing -----------------------------------------------------------------------------------------------------------------
func _draw(ci: RID, rect: Rect2) -> void:
	var w: int = roundi(rect.size.x); var h: int = roundi(rect.size.y)
	if w < 3 or h < 3: return
	var off := rect.position.round()
	var moved: bool = off != Vector2.ZERO
	if moved: RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, off))
	match kind:
		Kind.PLATE: _draw_plate(ci, w, h)
		Kind.SHEET: _draw_sheet(ci, w, h)
		Kind.BAR: _draw_bar(ci, w, h)
		Kind.SEAL: _draw_seal(ci, w, h)
		Kind.FOCUS: _draw_focus(ci, w, h)
	if moved: RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)

func _draw_plate(ci: RID, w: int, h: int) -> void:
	var hc := TBTokens.is_hc()
	var bw: int = border_w if (border_w == 0 or not hc) else maxi(border_w, 2)
	var el: int = 0 if (hc or shift > 0) else elevation
	var key := Vector4i(w, h, cut + corners * 64, bw + el * 8)
	var g: Variant = _geo_get(key)
	if g == null:
		var half := bw * 0.5
		g = [chamfer(w, h, cut, corners, half), _closed(chamfer(w, h, cut, corners, half)), chamfer(w, h, cut, corners, 0.0, 0.0, TBTokens.SHADOW_DY[el])]
		_geo_put(key, g)
	if el > 0: RenderingServer.canvas_item_add_polygon(ci, g[2], _pc(TBTokens.ca("table", TBTokens.SHADOW_A[el])))
	if fill.a > 0.0: RenderingServer.canvas_item_add_polygon(ci, g[0], _pc(fill))
	if bw > 0 and border.a > 0.0: RenderingServer.canvas_item_add_polyline(ci, g[1], _pc(border), float(bw), false)
	if accent_w > 0 and accent.a > 0.0:
		var inner_cut: int = cut if (corners & TL) else 0
		RenderingServer.canvas_item_add_rect(ci, Rect2(bw, maxi(bw, inner_cut), accent_w, h - 2 * maxi(bw, inner_cut)), accent)

func _draw_bar(ci: RID, w: int, h: int) -> void:
	RenderingServer.canvas_item_add_rect(ci, Rect2(0, 0, w, h), fill)
	var rw: int = 2 if TBTokens.is_hc() else 1
	match rule_side:
		SIDE_BOTTOM: RenderingServer.canvas_item_add_rect(ci, Rect2(0, h - rw, w, rw), rule_col)
		SIDE_TOP: RenderingServer.canvas_item_add_rect(ci, Rect2(0, 0, w, rw), rule_col)
		SIDE_LEFT: RenderingServer.canvas_item_add_rect(ci, Rect2(0, 0, rw, h), rule_col)
		SIDE_RIGHT: RenderingServer.canvas_item_add_rect(ci, Rect2(w - rw, 0, rw, h), rule_col)

func _draw_sheet(ci: RID, w: int, h: int) -> void:
	if TBTokens.is_hc():                        # high contrast: flat, no grain, no ragged edge, no guards, 2 px border
		var key := Vector4i(w, h, cut + ALL * 64, 2)
		var g: Variant = _geo_get(key)
		if g == null:
			g = [chamfer(w, h, cut, ALL, 1.0), _closed(chamfer(w, h, cut, ALL, 1.0)), chamfer(w, h, cut, ALL)]
			_geo_put(key, g)
		RenderingServer.canvas_item_add_polygon(ci, g[0], _pc(fill))
		RenderingServer.canvas_item_add_polyline(ci, g[1], _pc(border), 2.0, false)
		return
	var skey := Vector3i(w, h, 7)
	var s: Variant = _geo_get(skey)
	if s == null:
		var r := Rect2(0, 0, w, h)
		var seed_i: int = w * 31 + h + 7
		var edge := TBPaper.ragged(r, 1.5, 36.0, seed_i, float(cut))
		var uvs := PackedVector2Array()
		for p in edge: uvs.append(p / 256.0)                  # one texel per pixel: the grain never stretches
		var shadow := TBPaper.ragged(Rect2(0, TBTokens.SHADOW_DY[2], w, h), 1.5, 36.0, seed_i, float(cut))
		var rule1 := _closed(chamfer(w, h, 0.0, 0, 8.0))
		var rule2 := _closed(chamfer(w, h, 0.0, 0, 11.0))
		var gs := float(cut)
		var guards := []
		for c in 4:
			var cx: float = 0.0 if c % 2 == 0 else float(w)
			var cy: float = 0.0 if c < 2 else float(h)
			var sx: float = 1.0 if c % 2 == 0 else -1.0
			var sy: float = 1.0 if c < 2 else -1.0
			guards.append(PackedVector2Array([Vector2(cx + sx * gs, cy), Vector2(cx, cy + sy * gs), Vector2(cx + sx * gs, cy + sy * gs)]))
		s = [edge, uvs, shadow, _closed(edge), rule1, rule2, guards]
		_geo_put(skey, s)
	RenderingServer.canvas_item_add_polygon(ci, s[2], _pc(TBTokens.ca("table", TBTokens.SHADOW_A[2])))
	RenderingServer.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	RenderingServer.canvas_item_add_polygon(ci, s[0], _pc(fill), s[1], TBPaper.texture(TBPaper.SHEET).get_rid())
	RenderingServer.canvas_item_add_polyline(ci, s[3], _pc(TBTokens.with_a(border, 0.30)), 1.0, false)
	RenderingServer.canvas_item_add_polyline(ci, s[4], _pc(TBTokens.with_a(border, 0.45)), 1.0, false)
	RenderingServer.canvas_item_add_polyline(ci, s[5], _pc(TBTokens.with_a(border, 0.22)), 1.0, false)
	var brass := TBTokens.c("brass")
	for tri in s[6]: RenderingServer.canvas_item_add_polygon(ci, tri, _pc(brass))

func _draw_seal(ci: RID, w: int, h: int) -> void:
	var hc := TBTokens.is_hc()
	var r: float = minf(w, h) * 0.5
	var c := Vector2(w * 0.5, h * 0.5)
	var key := Vector3i(w, h, 11)
	var g: Variant = _geo_get(key)
	if g == null:
		var body := _circle(c, r - 1.0)
		var uvs := PackedVector2Array()
		for p in body: uvs.append(p / 256.0)
		g = [body, uvs, _circle(c + Vector2(0, TBTokens.SHADOW_DY[2]), r - 1.0), _closed(_circle(c, r - 1.5)), _closed(_circle(c, r - 4.0))]
		_geo_put(key, g)
	var a: float = 0.4 if disabled else 1.0
	if not (pressed or disabled or hc): RenderingServer.canvas_item_add_polygon(ci, g[2], _pc(TBTokens.ca("table", TBTokens.SHADOW_A[2])))
	var body_c := TBTokens.with_a(fill, a)
	if hc:
		RenderingServer.canvas_item_add_polygon(ci, g[0], _pc(body_c))
	else:
		RenderingServer.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		RenderingServer.canvas_item_add_polygon(ci, g[0], _pc(body_c), g[1], TBPaper.texture(TBPaper.WAX).get_rid())
	RenderingServer.canvas_item_add_polyline(ci, g[3], _pc(TBTokens.with_a(border, a)), 1.0, true)
	RenderingServer.canvas_item_add_polyline(ci, g[4], _pc(TBTokens.with_a(rule_col, a)), 2.0, true)       # the single brass ring

func _draw_focus(ci: RID, w: int, h: int) -> void:
	if not kbd_nav: return
	var hc := TBTokens.is_hc()
	var key := Vector4i(w, h, cut + inset * 64, 6 if hc else 5)
	var g: Variant = _geo_get(key)
	if g == null:
		var i := float(inset)
		g = [_closed(chamfer(w, h, cut, ALL, i + 0.5)), _closed(chamfer(w, h, cut, ALL, i + (2.5 if hc else 2.0)))]    # 1 px contrast line, then the 2 px ring (3 px in high contrast)
		_geo_put(key, g)
	var ring: Color = TBTokens.c(ring_tok if ring_tok != "" else ("cream" if on_bar else "ink_0"))
	var outer: Color = TBTokens.c(line_tok if line_tok != "" else ("bar_0" if on_bar else "paper_0"))
	RenderingServer.canvas_item_add_polyline(ci, g[0], _pc(outer), 1.0, false)
	RenderingServer.canvas_item_add_polyline(ci, g[1], _pc(ring), 3.0 if hc else 2.0, false)

## ring for custom-drawn controls: `ctl.draw_style_box(TBFrame.focus(), Rect2(Vector2.ZERO, ctl.size))` when ctl.has_focus()
