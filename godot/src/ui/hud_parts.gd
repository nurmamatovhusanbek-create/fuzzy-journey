## HUD building blocks (design/ux/hud.md, art bible 3 / 7.5): flat chamfered plates, resource chips, dock buttons, the End Turn
## plate, the lens legend, tooltips. Everything is drawn with primitives from TBTokens colours; no textures, no ornament.
class_name TBHudParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## player text scale (100 / 125 / 150 / 175 %): every HUD font size goes through fs()
static var text_scale: float = 1.0
## Age-of-Civilizations HUD scale: every AoC part is designed in 1080p pixels ("R" units) and multiplied by u (set by the HUD layout, text scale included)
static var u: float = 0.667
static func R(px: float) -> float: return px * u
## a font size for an AoC part: R units through u, never below the 12 px caption floor
static func fr(px: float) -> int: return maxi(12, int(round(px * u)))
## panel opacity floor (88 - 100 %), the alpha of bar / rail / chip grounds
static var opacity: float = 0.86
static var _f_nat: Font

## a font size through the text scale; never below the 12 px caption floor (A11Y-TXT-002)
static func fs(px: float) -> int: return maxi(12, int(round(px * text_scale)))
static func tk(token: String) -> Color: return TBTokens.c(token)
## a kit setting read defensively (the kit may not define it yet): TBKit.get-style access on the script
static func kit(setting: String, fallback: Variant) -> Variant:
	var sc: Script = K
	var v: Variant = sc.get(setting)
	return fallback if v == null else v
## pull the player's settings from the kit: text scale (100 / 125 / 150 / 200 %), called before every build / layout
static func sync_settings() -> void:
	text_scale = clampf(float(kit("text_scale", 1.0)), 1.0, 2.0)
## minimum hit area in logical px: 48 always, 56 with "large targets" (A11Y-TCH-001; never gated on the platform)
static func touch() -> float:
	return 56.0 if (bool(kit("large_targets", false)) or bool(kit("touch_large", false))) else 48.0
## colour with another alpha
static func al(c: Color, alpha: float) -> Color:
	c.a = alpha
	return c
## true when the player asked for reduced motion (A11Y-MOT-001) or TB_NOANIM is set (tests): every HUD tween, roll and pulse checks this
static func reduced_motion() -> bool: return bool(kit("reduce_motion", false)) or not TBMapView.animate

static var _f_body: Font
static var _f_body_b: Font
static var _f_for: int = -1
## Alegreya's word space is ~3 px at 12-14 px, which reads as no space on a dark ground: widen it by 2 (the sans needs none)
static func _fonts() -> void:
	var k: int = 1 if K.serif else 0
	if _f_for == k and _f_body != null: return
	_f_for = k
	var v := FontVariation.new(); v.base_font = K.body(); v.spacing_space = 2 if K.serif else 0; v.opentype_features = {"tnum": 1}; _f_body = v
	var vb := FontVariation.new(); vb.base_font = K.body_b(); vb.spacing_space = 2 if K.serif else 0; vb.opentype_features = {"tnum": 1}; _f_body_b = vb
static func body() -> Font:
	_fonts()
	return _f_body
static func body_b() -> Font:
	_fonts()
	return _f_body_b

static func f_nat() -> Font:
	if _f_nat == null: _f_nat = K.tracked(K.display_hi(), 1)
	return _f_nat

# ---------------------------------------------------------------- drawing helpers
## rectangle with every corner cut by `cut` px (the interface's one shape)
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var x0: float = r.position.x; var y0: float = r.position.y; var x1: float = r.end.x; var y1: float = r.end.y
	cut = clampf(cut, 0.0, maxf(0.0, minf(r.size.x, r.size.y) * 0.5 - 0.01))
	if cut < 0.5: return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	return PackedVector2Array([Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, y0 + cut), Vector2(x1, y1 - cut), Vector2(x1 - cut, y1), Vector2(x0 + cut, y1), Vector2(x0, y1 - cut), Vector2(x0, y0 + cut)])

## flat plate: fill, optional 1-px border, optional bar on the left edge
static func plate(ci: CanvasItem, r: Rect2, fill: Color, border: Color = Color.TRANSPARENT, cut: float = 2.0, bar: Color = Color.TRANSPARENT, bar_w: float = 0.0, border_w: float = 1.0) -> void:
	if r.size.x < 1.0 or r.size.y < 1.0: return
	ci.draw_colored_polygon(chamfer(r, cut), fill)
	if border.a > 0.0:
		var line: PackedVector2Array = chamfer(r.grow(-border_w * 0.5), maxf(0.0, cut - border_w * 0.3))
		line.append(line[0])
		ci.draw_polyline(line, border, border_w, true)
	if bar_w > 0.0 and bar.a > 0.0:
		ci.draw_rect(Rect2(r.position.x, r.position.y + cut, bar_w, r.size.y - cut * 2.0), bar)

static func base(font: Font, size: int, cy: float) -> float:
	return cy + (font.get_ascent(size) - font.get_descent(size)) * 0.5

static func tw(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## draw text at a baseline position, return its width
static func txt(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, max_w: float = -1.0) -> float:
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, col)
	return tw(font, s, size) if max_w < 0.0 else minf(tw(font, s, size), max_w)

## one line that fits max_w: trailing "…" when it does not
static func fit(font: Font, s: String, size: int, max_w: float) -> String:
	if tw(font, s, size) <= max_w: return s
	var t := s
	while t.length() > 1 and tw(font, t + "…", size) > max_w: t = t.left(t.length() - 1)
	return t.strip_edges() + "…"

static func tri(ci: CanvasItem, c: Vector2, s: float, col: Color, up: bool = true, filled: bool = true, w: float = 1.5) -> void:
	var h: float = s * 0.5
	var d: float = -1.0 if up else 1.0
	var pts := PackedVector2Array([c + Vector2(0, d * h), c + Vector2(h * 0.95, -d * h * 0.8), c + Vector2(-h * 0.95, -d * h * 0.8)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, w, true)

static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color, filled: bool = true, w: float = 1.5) -> void:
	var h: float = s * 0.5
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, w, true)

static func tick(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float = 2.0) -> void:
	var h: float = s * 0.5
	ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.8, 0.0), c + Vector2(-h * 0.2, h * 0.6), c + Vector2(h * 0.85, -h * 0.6)]), col, w, true)

## "!" inside a warning triangle
static func warn_mark(ci: CanvasItem, c: Vector2, s: float, col: Color, filled: bool = false) -> void:
	tri(ci, c, s, col, true, filled, 1.5)
	var ink: Color = tk("bar_0") if filled else col
	ci.draw_line(c + Vector2(0, -s * 0.14), c + Vector2(0, s * 0.1), ink, 1.5)
	ci.draw_rect(Rect2(c.x - 0.75, c.y + s * 0.2, 1.5, 1.5), ink)

static func chev(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float = 2.0) -> void:
	var h: float = s * 0.5
	ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.5, -h), c + Vector2(h * 0.5, 0.0), c + Vector2(-h * 0.5, h)]), col, w, true)

## hot-seat seat shapes: P1 square, P2 triangle, P3 circle, P4 diamond (never colour alone)
static func seat_shape(ci: CanvasItem, c: Vector2, s: float, idx: int, col: Color, filled: bool = true) -> void:
	match idx % 4:
		0:
			if filled: ci.draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), col)
			else: ci.draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), col, false, 1.5)
		1: tri(ci, c, s + 2.0, col, true, filled)
		2:
			if filled: ci.draw_circle(c, s * 0.5, col)
			else: ci.draw_arc(c, s * 0.5, 0.0, TAU, 20, col, 1.5, true)
		_: diamond(ci, c, s + 2.0, col, filled)

## TBGlyph plus the two bar-only icons ("menu" three lines, "dots" three dots)
static func icon(ci: CanvasItem, glyph: String, c: Vector2, px: float, col: Color, w: float) -> void:
	match glyph:
		"menu":
			for i in 3: ci.draw_line(c + Vector2(-px * 0.38, (i - 1) * px * 0.28), c + Vector2(px * 0.38, (i - 1) * px * 0.28), col, w)
		"dots":
			for i in 3: ci.draw_circle(c + Vector2((i - 1) * px * 0.32, 0), px * 0.09 + (0.6 if w > 2.0 else 0.0), col)
		_: TBGlyph.draw(ci, glyph, c, px, col, w)

static func focus_ring(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r.grow(1.0), tk("bar_0"), false, 1.0)
	ci.draw_rect(r.grow(-1.0), tk("cream"), false, 2.0)

## lens id -> icon (TBGlyph is the only icon source)
static func lens_glyph(lens: String) -> String:
	match lens:
		"political": return "flag"
		"diplomatic": return "dove"
		"economic": return "coins"
		"military": return "swords"
		"wars": return "skull"
		"stability": return "scales"
		"population": return "men"
		"buildings": return "gear"
		"governments": return "crown"
		"terrain": return "globe"
	return "globe"

static func seat_index(g: TBGame, n: int) -> int:
	return g.humans().find(n)

# ---------------------------------------------------------------- styleboxes and small widgets
## a StyleBox drawing the flat plate (popovers, tooltips, toast rows, buttons)
class PlateBox extends StyleBox:
	var fill: Color = Color.TRANSPARENT
	var border: Color = Color.TRANSPARENT
	var cut: float = 4.0
	var bar: Color = Color.TRANSPARENT
	var bar_w: float = 0.0
	var elevation: int = 0               # 0 none, 1 one hard shadow 3 px down
	func setup(f: Color, b: Color, c: float, pad_x: float, pad_y: float) -> PlateBox:
		fill = f; border = b; cut = c
		set_content_margin(SIDE_LEFT, pad_x); set_content_margin(SIDE_RIGHT, pad_x)
		set_content_margin(SIDE_TOP, pad_y); set_content_margin(SIDE_BOTTOM, pad_y)
		return self
	func _draw(ci: RID, r: Rect2) -> void:
		var body: Rect2 = Rect2(r.position, r.size - Vector2(0, 3.0 if elevation > 0 else 0.0))
		if body.size.x < 1.0 or body.size.y < 1.0: return
		if elevation > 0:
			RenderingServer.canvas_item_add_polygon(ci, TBHudParts.chamfer(Rect2(body.position + Vector2(0, 3.0), body.size), cut), PackedColorArray([TBHudParts.al(TBHudParts.tk("bar_0"), 0.26)]))
		RenderingServer.canvas_item_add_polygon(ci, TBHudParts.chamfer(body, cut), PackedColorArray([fill]))
		if border.a > 0.0:
			var line: PackedVector2Array = TBHudParts.chamfer(body.grow(-0.5), maxf(0.0, cut - 0.3))
			line.append(line[0])
			RenderingServer.canvas_item_add_polyline(ci, line, PackedColorArray([border]), 1.0, true)
		if bar_w > 0.0 and bar.a > 0.0:
			RenderingServer.canvas_item_add_rect(ci, Rect2(body.position.x, body.position.y + cut, bar_w, body.size.y - cut * 2.0), bar)

## dark furniture plate (tooltips, toasts, popovers on the map)
static func bar_box(pad_x: float = 12.0, pad_y: float = 8.0, cut: float = 4.0, elevated: bool = false) -> PlateBox:
	var b: PlateBox = PlateBox.new().setup(al(tk("bar_0"), 0.96), tk("rule_dark"), cut, pad_x, pad_y)
	b.elevation = 1 if elevated else 0
	return b

## pale document plate (realm sheet)
static func paper_box(pad_x: float = 16.0, pad_y: float = 14.0) -> PlateBox:
	var b: PlateBox = PlateBox.new().setup(tk("paper_0"), tk("rule"), 6.0, pad_x, pad_y)
	b.elevation = 1
	return b

## flat button: kind "primary" (brass), "secondary" (outlined); dark = on bar ground
static func btn(text: String, kind: String, cb: Callable, dark: bool = true, px: int = 14) -> Button:
	var b := Button.new()
	b.text = text; b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 40)
	var fill: Color; var fill_h: Color; var fill_p: Color; var edge: Color; var ink: Color
	if kind == "primary":
		fill = tk("brass"); fill_h = tk("brass_hover"); fill_p = tk("brass_press"); edge = tk("brass_ink"); ink = tk("ink_0")
	elif kind == "danger":
		fill = tk("wax"); fill_h = tk("wax_hover"); fill_p = tk("wax_press"); edge = tk("wax_rim"); ink = tk("on_wax")
	elif dark:
		fill = tk("bar_1"); fill_h = tk("bar_2"); fill_p = tk("bar_2"); edge = tk("rule_dark"); ink = tk("cream")
	else:
		fill = tk("paper_1"); fill_h = tk("paper_hover"); fill_p = tk("paper_2"); edge = tk("rule"); ink = tk("ink_0")
	b.add_theme_stylebox_override("normal", PlateBox.new().setup(fill, edge, 4.0, 12, 6))
	b.add_theme_stylebox_override("hover", PlateBox.new().setup(fill_h, edge, 4.0, 12, 6))
	b.add_theme_stylebox_override("pressed", PlateBox.new().setup(fill_p, edge, 4.0, 12, 6))
	b.add_theme_stylebox_override("disabled", PlateBox.new().setup(al(fill, 0.5), edge, 4.0, 12, 6))
	b.add_theme_stylebox_override("focus", PlateBox.new().setup(Color.TRANSPARENT, tk("cream") if dark else tk("ink_0"), 4.0, 12, 6))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, ink)
	b.add_theme_font_override("font", TBHudParts.body_b())
	b.add_theme_font_size_override("font_size", fs(px))
	if cb.is_valid(): b.pressed.connect(cb)
	return b

## dark tooltip / pinned popover content: title (brass) over body lines (cream), max 280 wide
static func tip_box(title: String, body: String, max_w: float = 320.0) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = tk("bar_1"); sb.border_color = tk("rule"); sb.set_border_width_all(1); sb.set_corner_radius_all(10)
	sb.shadow_color = al(Color.BLACK, 0.55); sb.shadow_size = 14; sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	if title != "":
		var t := Label.new(); t.text = title; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_theme_font_override("font", TBHudParts.body_b()); t.add_theme_font_size_override("font_size", fs(13)); t.add_theme_color_override("font_color", tk("cream"))
		v.add_child(t)
	if body != "":
		var b := Label.new(); b.text = body; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_font_override("font", TBHudParts.body()); b.add_theme_font_size_override("font_size", fs(13)); b.add_theme_color_override("font_color", tk("smoke"))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(minf(max_w, 280.0), 0)
		v.add_child(b)
	return pc

# ---------------------------------------------------------------- interactive base
## a drawn control with hover / press / long-press / keyboard activation and tooltip hooks
class Hit extends Control:
	signal pressed
	signal tip_on
	signal tip_off
	var hover: bool = false
	var down: bool = false
	var a11y: String = ""
	var _long: bool = false
	var _gen: int = 0
	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func set_a11y(name: String) -> void:
		a11y = name; set_meta("a11y", name)
	## the hit area is at least 48 x 48 (56 with large targets) around the visual, on both axes (A11Y-TCH-001)
	func hit_rect() -> Rect2:
		var t: float = TBHudParts.touch()
		var ex := Vector2(maxf(2.0, (t - size.x) * 0.5), maxf(2.0, (t - size.y) * 0.5))
		return Rect2(-ex, size + ex * 2.0)
	func _has_point(p: Vector2) -> bool:
		return hit_rect().has_point(p)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (e as InputEventMouseButton).pressed:
				down = true; _long = false; queue_redraw(); accept_event()
				_gen += 1; _arm(_gen)
			else:
				var was: bool = down
				down = false; queue_redraw()
				if was and not _long and hit_rect().has_point((e as InputEventMouseButton).position):
					tip_off.emit(); pressed.emit()
				accept_event()
		elif e.is_action_pressed("ui_accept"):
			pressed.emit(); accept_event()
	func _arm(g: int) -> void:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(self) and down and g == _gen:
			_long = true; tip_on.emit()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			hover = true; queue_redraw(); _gen += 1; _hover_tip(_gen)
		elif what == NOTIFICATION_MOUSE_EXIT:
			hover = false; down = false; queue_redraw(); _gen += 1; tip_off.emit()
		elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()
	func _hover_tip(g: int) -> void:
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self) and hover and g == _gen and not down: tip_on.emit()

# ---------------------------------------------------------------- AoC drawing helpers
static var _sb: Dictionary = {}
## cached StyleBoxFlat: fill, 1-px edge, corner radius
static func sbox(fill: Color, edge: Color, radius: float, bw: int = 1) -> StyleBoxFlat:
	fill.a = snappedf(fill.a, 0.05); edge.a = snappedf(edge.a, 0.05)               # fading callers do not mint a new box every frame
	var key := "%s%s%d%d%d" % [fill.to_html(true), edge.to_html(true), int(radius), bw, TBTokens.sig()]
	if _sb.has(key): return _sb[key]
	if _sb.size() > 400: _sb.clear()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill; sb.border_color = edge
	sb.set_border_width_all(bw if edge.a > 0.0 else 0)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true; sb.anti_aliasing_size = 0.8
	_sb[key] = sb
	return sb

# ---------------------------------------------------------------- Atlas Ledger primitives
static func sel_fill() -> Color: return TBTokens.INK_500 if not TBTokens.is_hc() else tk("bar_2")
static func accent_soft() -> Color: return al(tk("brass_lt"), 0.18)
## a thin card: ink-800, hairline, radius 16 (panels) / 10 (small cards) / pill
static func card_box(radius: float = 16.0, fill_a: float = 0.97) -> StyleBoxFlat:
	return sbox(al(tk("bar_0"), fill_a), tk("rule"), radius, 1)

# ---------------------------------------------------------------- resource chip
## Atlas chip: 32 px pill, [icon 16] value (14/600) suffix delta (12, signed, coloured). Warning state: warn border + a pulsing dot.
class Chip extends Hit:
	var glyph: String = "coin"
	var value: String = ""
	var final_text: String = ""
	var suffix: String = ""
	var delta: int = 0
	var has_delta: bool = false
	var delta_on: bool = true
	var sub_text: String = ""           # replaces the delta (manpower: "43 %")
	var state: int = 0                  # 0 normal, 1 caution, 2 critical
	var compact: bool = false
	var tight: bool = false
	var glyph_col: Color = Color.TRANSPARENT
	var val_col: Color = Color.TRANSPARENT
	var spark: Array = []               # treasury history (floats): a 48 x 16 line next to the value
	var _shown: float = NAN
	var _target: float = 0.0
	var _fmt: Callable = Callable()
	var _t: float = 0.0
	func _ready() -> void: set_process(false)
	func fv() -> int: return TBHudParts.fs(14.0)
	func fd() -> int: return TBHudParts.fs(12.0)
	func ico() -> float: return 16.0
	func pad() -> float: return 12.0
	func dtext() -> String:
		if sub_text != "": return sub_text
		return ("+%s" % K.fmt(float(delta))) if delta >= 0 else ("−%s" % K.fmt(float(-delta)))
	func has_sub() -> bool: return (sub_text != "" or (delta_on and has_delta)) and not tight
	func desired_w() -> float:
		var shown: String = final_text if final_text != "" else value
		var w: float = pad() + ico() + 6.0 + TBHudParts.tw(K.mono_b(), shown, fv()) + pad()
		if suffix != "": w += TBHudParts.tw(K.mono(), suffix, fd())
		if has_sub(): w += 8.0 + TBHudParts.tw(K.mono(), dtext(), fd())
		if spark.size() >= 3: w += 8.0 + 48.0
		if state >= 1: w += 14.0
		return ceilf(w)
	func set_num(v: float, fmt: Callable) -> void:
		_fmt = fmt; final_text = fmt.call(v)
		if is_nan(_shown) or TBHudParts.reduced_motion():
			_shown = v; _target = v; value = final_text; set_process(state >= 1 and not TBHudParts.reduced_motion()); queue_redraw(); return
		if v != _target:
			_target = v; set_process(true)
		elif not is_processing():
			value = final_text
		queue_redraw()
	func _process(d: float) -> void:
		_t += d
		if not is_nan(_shown) and _shown != _target:
			_shown += (_target - _shown) * (1.0 - exp(-9.0 * d))
			if absf(_target - _shown) < 0.5: _shown = _target
			value = _fmt.call(_shown)
		queue_redraw()
		if _shown == _target and state < 1: set_process(false)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge: Color = TBHudParts.tk("rule")
		if state == 2: edge = TBHudParts.tk("neg_bar")
		elif state == 1: edge = TBHudParts.tk("warn_bar")
		var bg: Color = TBHudParts.tk("bar_1") if (hover or down) else TBHudParts.al(TBHudParts.tk("bar_0"), 0.96)
		draw_style_box(TBHudParts.sbox(bg, edge, size.y * 0.5, 1), r)
		var oy: float = 1.0 if down else 0.0
		var cy: float = size.y * 0.5 + oy
		var x: float = pad()
		var gc: Color = glyph_col if glyph_col.a > 0.0 else TBHudParts.tk("brass_lt")
		TBGlyph.draw(self, glyph, Vector2(x + ico() * 0.5, cy), ico(), gc, 1.5)
		x += ico() + 6.0
		var fb: Font = K.mono_b()
		var vc: Color = val_col if val_col.a > 0.0 else TBHudParts.tk("cream")
		x += TBHudParts.txt(self, fb, Vector2(x, TBHudParts.base(fb, fv(), cy)), value, fv(), vc)
		var fm: Font = K.mono()
		if suffix != "": x += TBHudParts.txt(self, fm, Vector2(x, TBHudParts.base(fm, fd(), cy)), suffix, fd(), TBHudParts.tk("smoke"))
		if has_sub():
			x += 8.0
			var col: Color = TBHudParts.tk("smoke")
			if sub_text == "": col = TBHudParts.tk("pos_bar") if delta > 0 else (TBHudParts.tk("neg_bar") if delta < 0 else TBHudParts.tk("smoke"))
			x += TBHudParts.txt(self, fm, Vector2(x, TBHudParts.base(fm, fd(), cy)), dtext(), fd(), col)
		if spark.size() >= 3:
			x += 8.0
			var sr := Rect2(x, cy - 8.0, 48.0, 16.0)
			var lo: float = minf(0.0, float(spark.min())); var hi: float = maxf(float(spark.max()), lo + 1.0)
			var pts := PackedVector2Array()
			for i in spark.size():
				pts.append(Vector2(sr.position.x + sr.size.x * i / float(spark.size() - 1), sr.end.y - sr.size.y * (float(spark[i]) - lo) / (hi - lo)))
			draw_polyline(pts, TBHudParts.al(TBHudParts.tk("smoke"), 0.9), 1.3, true)
		if state >= 1:
			var pulse: float = 0.65 + 0.35 * sin(_t * 3.14) if not TBHudParts.reduced_motion() else 1.0
			draw_circle(Vector2(size.x - pad() + 2.0, cy), 3.0, TBHudParts.al(edge, pulse))
		if has_focus(): TBHudParts.focus_ring(self, r)

# ---------------------------------------------------------------- crest
## 40 x 28 flag, nation name 16/600 and a 12 px subtitle (ruler); the whole block opens the nation card
class NationChip extends Hit:
	var flag: Texture2D
	var nation: String = ""
	var subtitle: String = ""
	var show_name: bool = true
	var seat: int = -1
	var seat_text: String = ""
	var badge: int = 0
	var rank_text: String = ""
	var compact: bool = false
	func desired_w() -> float:
		var w: float = 10.0 + 40.0 + 10.0
		var tn: float = TBHudParts.tw(K.body_b(), nation, TBHudParts.fs(16.0))
		var ts: float = TBHudParts.tw(K.body(), subtitle, TBHudParts.fs(12.0)) if subtitle != "" else 0.0
		w += maxf(tn, ts) + 12.0
		if seat >= 0: w += 34.0
		return ceilf(w)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge: Color = TBHudParts.tk("brass_lt") if (hover or has_focus()) else TBHudParts.tk("rule")
		draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_1") if down else TBHudParts.al(TBHudParts.tk("bar_0"), 0.96), edge, 10.0, 1), r)
		var oy: float = 1.0 if down else 0.0
		var fr_ := Rect2(10.0, (size.y - 28.0) * 0.5 + oy, 40.0, 28.0)
		if flag != null: draw_texture_rect(flag, fr_, false)
		draw_rect(fr_, TBHudParts.al(Color.WHITE, 0.14), false, 1.0)
		var x: float = fr_.end.x + 10.0
		var fb: Font = K.body_b()
		var fn: int = TBHudParts.fs(16.0)
		var has_sub: bool = subtitle != ""
		var ny: float = size.y * (0.38 if has_sub else 0.5) + oy
		if show_name: x += TBHudParts.txt(self, fb, Vector2(x, TBHudParts.base(fb, fn, ny)), nation, fn, TBHudParts.tk("cream"))
		if has_sub and show_name:
			var f2: Font = K.body()
			TBHudParts.txt(self, f2, Vector2(fr_.end.x + 10.0, TBHudParts.base(f2, TBHudParts.fs(12.0), size.y * 0.7 + oy)), subtitle, TBHudParts.fs(12.0), TBHudParts.tk("smoke"))
		if seat >= 0:
			var sx: float = size.x - 22.0
			TBHudParts.seat_shape(self, Vector2(sx, size.y * 0.5 - 6.0), 10.0, seat, TBHudParts.tk("brass_lt"))
			var fs_: Font = K.body_b()
			var zs: int = TBHudParts.fs(12.0)
			draw_string(fs_, Vector2(sx - TBHudParts.tw(fs_, seat_text, zs) * 0.5, size.y * 0.5 + 14.0), seat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, zs, TBHudParts.tk("brass_lt"))
		if badge > 0: draw_circle(Vector2(size.x - 8.0, 8.0), 4.0, TBHudParts.tk("warn_bar"))
		if has_focus(): TBHudParts.focus_ring(self, r)

# ---------------------------------------------------------------- date pill
## "1804 AD · Turn 7": a chip, tabular figures
class DateText extends Control:
	var year: String = ""
	var turn_cap: String = ""
	var compact: bool = false
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func fv() -> int: return TBHudParts.fs(14.0)
	func _txt() -> String: return "%s · %s" % [year, turn_cap]
	func desired_w() -> float: return ceilf(TBHudParts.tw(K.mono_b(), _txt(), fv()) + 28.0)
	func _draw() -> void:
		draw_style_box(TBHudParts.sbox(TBHudParts.al(TBHudParts.tk("bar_0"), 0.96), TBHudParts.tk("rule"), size.y * 0.5, 1), Rect2(Vector2.ZERO, size))
		var fb: Font = K.mono_b()
		var t: String = _txt()
		draw_string(fb, Vector2((size.x - TBHudParts.tw(fb, t, fv())) * 0.5, TBHudParts.base(fb, fv(), size.y * 0.5)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fv(), TBHudParts.tk("cream"))

# ---------------------------------------------------------------- segmented mode switch
## 32 px segmented control (ink-700 track, selected segment ink-500): the map lenses next to the minimap
class ModeSwitch extends Hit:
	signal picked(id: String)
	var items: Array = []               # [[id, label]]
	var current: String = ""
	var _rects: Array = []
	func fz() -> int: return TBHudParts.fs(13.0)
	func _seg_w(i: int) -> float: return ceilf(TBHudParts.tw(K.body_m(), String(items[i][1]), fz()) + 24.0)
	func desired_w() -> float:
		var w: float = 4.0
		for i in items.size(): w += _seg_w(i)
		return w + 4.0
	func _has_point(p: Vector2) -> bool: return Rect2(Vector2.ZERO, size).grow(2.0).has_point(p)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				if (_rects[i] as Rect2).has_point((e as InputEventMouseButton).position):
					picked.emit(String(items[i][0])); accept_event(); return
	func _draw() -> void:
		draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_1"), TBHudParts.tk("rule"), 10.0, 1), Rect2(Vector2.ZERO, size))
		_rects.clear()
		var x: float = 4.0
		for i in items.size():
			var w: float = _seg_w(i)
			var rc := Rect2(x, 3.0, w, size.y - 6.0)
			_rects.append(rc)
			var on: bool = String(items[i][0]) == current
			if on: draw_style_box(TBHudParts.sbox(TBHudParts.sel_fill(), Color.TRANSPARENT, 7.0, 0), rc)
			var f: Font = K.body_m()
			var t: String = String(items[i][1])
			draw_string(f, Vector2(rc.position.x + (rc.size.x - TBHudParts.tw(f, t, fz())) * 0.5, TBHudParts.base(f, fz(), rc.get_center().y)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fz(), TBHudParts.tk("cream") if on else TBHudParts.tk("smoke"))
			x += w
		if has_focus(): TBHudParts.focus_ring(self, Rect2(Vector2.ZERO, size))

# ---------------------------------------------------------------- dock / lens / menu icon button
## flat icon button: 40 px visual square on a 56 px rail, label beneath, 3 px brass bar + filled icon when active
class IconBtn extends Hit:
	var glyph: String = "gear"
	var label: String = ""
	var active: bool = false
	var badge: int = 0
	var badge_crit: bool = false
	var edge: int = 0                   # active bar edge: 0 left, 1 bottom, 2 top
	var sq: float = 40.0
	var icon_px: float = 24.0
	var show_label: bool = true
	var hint: String = ""               # hotkey text (menus)
	var framed: bool = false            # stands alone on the map: a bordered card
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var oy: float = 1.0 if down else 0.0
		if framed: draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_1") if (hover or down or active) else TBHudParts.al(TBHudParts.tk("bar_0"), 0.96), TBHudParts.tk("brass_lt") if active else TBHudParts.tk("rule"), 10.0, 1), r)
		var inner := Rect2(r.position + Vector2(3.0, 2.0), r.size - Vector2(6.0, 4.0))
		if framed: pass
		elif active: draw_style_box(TBHudParts.sbox(TBHudParts.accent_soft(), Color.TRANSPARENT, 10.0, 0), inner)
		elif hover or down: draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_1"), Color.TRANSPARENT, 10.0, 0), inner)
		if active and not framed:
			match edge:
				0: draw_rect(Rect2(0, 10.0, 3.0, size.y - 20.0), TBHudParts.tk("brass_lt"))
				1: draw_rect(Rect2(10.0, size.y - 3.0, size.x - 20.0, 3.0), TBHudParts.tk("brass_lt"))
				_: draw_rect(Rect2(10.0, 0, size.x - 20.0, 3.0), TBHudParts.tk("brass_lt"))
		var col: Color = TBHudParts.tk("brass_lt") if active else TBHudParts.tk("cream")
		var labelled: bool = show_label and label != ""
		var c: Vector2 = Vector2(size.x * 0.5, (size.y * 0.38) if labelled else size.y * 0.5) + Vector2(0, oy)
		TBHudParts.icon(self, glyph, c, icon_px, col, 1.5)
		if labelled:
			var f: Font = K.body_m()
			var z: int = TBHudParts.fs(12.0)
			var s: String = TBHudParts.fit(f, label, z, size.x - 4.0)
			var w: float = TBHudParts.tw(f, s, z)
			draw_string(f, Vector2((size.x - w) * 0.5, size.y - 8.0 + oy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, z, TBHudParts.tk("cream") if active else TBHudParts.tk("smoke"))
		if badge > 0:
			var bc: Vector2 = Vector2(size.x * 0.5 + icon_px * 0.55, size.y * 0.38 - icon_px * 0.45) if labelled else Vector2(size.x - 8.0, 8.0)
			draw_circle(bc, 8.0, TBHudParts.tk("neg_bar") if badge_crit else TBHudParts.tk("brass_lt"))
			var fb: Font = K.mono_b()
			var s2: String = str(mini(badge, 99))
			var sw: float = TBHudParts.tw(fb, s2, 12)
			draw_string(fb, Vector2(bc.x - sw * 0.5, TBHudParts.base(fb, 12, bc.y)), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TBHudParts.tk("table"))
		if has_focus(): TBHudParts.focus_ring(self, r)

# ---------------------------------------------------------------- surfaces
## the ground behind the top bar / rail / bottom bar
class Surface extends Control:
	var kind: String = "card"           # card (rail, drawers) | bottom (phone tab bar)
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"bottom":
				draw_rect(r, TBHudParts.al(TBHudParts.tk("bar_0"), 0.98))
				draw_rect(Rect2(0, 0, size.x, 1.0), TBHudParts.tk("rule"))
			_:
				draw_style_box(TBHudParts.card_box(16.0), r)

# ---------------------------------------------------------------- End Turn seal
## the one wax object (art bible 7.5): an 80 px circle (72 compact / portrait) drawn by TBFrame.seal (wax grain + one brass ring), the
## chevrons glyph and, when it fits, the caption inside. States: idle / hint (ring runs down) / busy (sweeping arc, static ring with
## reduced motion) / waiting (multiplayer) / seat (hot-seat, "Pass to P2") / over (wax at 40 %). A long caption moves to the SealNote chip.
class Seal extends Hit:
	enum S { IDLE, HINT, BUSY, WAIT, SEAT, OVER }
	var state: int = S.IDLE
	var caption: String = ""
	var sub: String = ""
	var caption_inside: bool = true         # false: the caption is too long for the label under the button; the SealNote chip shows it
	var sub_inside: bool = false
	var attention: int = 0                  # unresolved crisis alerts: count badge + a gentle glow
	var pulse: bool = false                 # first-run attention pulse
	var hint_left: float = 0.0              # 0..1 remaining of the 3 s confirm window
	var compact: bool = false
	var narrow: bool = false
	var turn_no: int = 0                    # the number inside the circle
	var seat_text: String = ""              # hot-seat: "P2" replaces the number
	var _t: float = 0.0
	var _pulses: int = 0
	func _ready() -> void: set_process(false)
	## 72 px circle (64 on phones); the label sits under it
	func diameter() -> float: return 64.0 if (compact or narrow) else 72.0
	func width_px() -> float: return diameter()
	func height_px() -> float: return diameter() + 22.0
	func caption_text() -> String: return caption
	func _animated() -> bool: return not TBHudParts.reduced_motion()
	func fits_inside(text: String) -> bool: return TBHudParts.tw(K.body_b(), text, TBHudParts.fs(12.0)) <= 104.0
	func sub_fits(_text: String) -> bool: return false
	func _one_line() -> bool: return true
	func _sync() -> void:
		set_process(_animated() and (state == S.BUSY or state == S.HINT or attention > 0 or (pulse and _pulses < 3)))
		queue_redraw()
	func set_state(s: int) -> void: state = s; _sync()
	func set_pulse(p: bool) -> void: pulse = p; _pulses = 0; _sync()
	func _centre() -> Vector2: return Vector2(size.x * 0.5, diameter() * 0.5)
	func _has_point(p: Vector2) -> bool:
		var c: Vector2 = _centre()
		var rr: float = maxf(diameter() * 0.5 + 4.0, TBHudParts.touch() * 0.5)
		return (p - c).length() <= rr or Rect2(Vector2(c.x - width_px() * 0.5, diameter()), Vector2(width_px(), 22.0)).has_point(p)
	func _process(d: float) -> void:
		_t += d
		if state == S.HINT: hint_left = maxf(0.0, hint_left - d / 3.0)
		queue_redraw()
		if state != S.BUSY and state != S.HINT and attention <= 0 and not (pulse and _pulses < 3): set_process(false)
	func _draw() -> void:
		var c: Vector2 = _centre()
		var rad: float = diameter() * 0.5
		var dead: bool = state == S.BUSY or state == S.WAIT or state == S.OVER
		var oy: float = 1.0 if (down and not dead) else 0.0
		var acc: Color = TBHudParts.tk("act")
		var fill: Color = TBHudParts.tk("act_press") if (down and not dead) else (TBHudParts.tk("act_hover") if (hover and not dead) else acc)
		var on: Color = TBHudParts.tk("on_act")
		if state == S.OVER: fill = TBHudParts.al(TBHudParts.tk("bar_2"), 1.0); on = TBHudParts.tk("ink_off")
		if state == S.BUSY or state == S.WAIT: fill = TBHudParts.al(acc, 0.35)
		# attention: a slow 2 s glow ring
		if attention > 0 and state == S.IDLE:
			var k: float = 0.5 + 0.5 * sin(_t * TAU / 2.0) if _animated() else 0.6
			draw_arc(c, rad + 4.0 + 4.0 * k, 0.0, TAU, 48, TBHudParts.al(acc, 0.25 + 0.25 * k), 3.0, true)
		draw_circle(c + Vector2(0, 2.0), rad, TBHudParts.al(Color.BLACK, 0.35))                 # shadow-2
		draw_circle(c + Vector2(0, oy), rad, fill)
		# content: the turn number (20/600), chevrons while seats pass, a spinner while it resolves
		var fb: Font = K.mono_b()
		var z: int = TBHudParts.fs(20.0)
		if state == S.BUSY or state == S.WAIT:
			var a0: float = _t * TAU / 1.1 if _animated() else 0.0
			draw_arc(c, rad - 7.0, 0.0, TAU, 40, TBHudParts.al(on, 0.0), 3.0, true)
			draw_arc(c, rad - 7.0, a0, a0 + deg_to_rad(250.0 if not _animated() else 110.0), 28, acc, 3.0, true)
		elif state == S.HINT:
			var left: float = hint_left if _animated() else 1.0
			draw_arc(c, rad - 6.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, on, 3.0, true)
			TBHudParts.chev(self, Vector2(c.x - 3.0, c.y), 18.0, on, 2.2); TBHudParts.chev(self, Vector2(c.x + 6.0, c.y), 18.0, on, 2.2)
		elif state == S.SEAT:
			var tt: String = seat_text if seat_text != "" else "›"
			draw_string(fb, Vector2(c.x - TBHudParts.tw(fb, tt, z) * 0.5, TBHudParts.base(fb, z, c.y + oy)), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, z, on)
		else:
			var tt2: String = str(turn_no) if turn_no > 0 else ""
			if tt2 != "": draw_string(fb, Vector2(c.x - TBHudParts.tw(fb, tt2, z) * 0.5, TBHudParts.base(fb, z, c.y + oy)), tt2, HORIZONTAL_ALIGNMENT_LEFT, -1, z, on)
			else:
				TBHudParts.chev(self, Vector2(c.x - 3.0, c.y + oy), 20.0, on, 2.4); TBHudParts.chev(self, Vector2(c.x + 7.0, c.y + oy), 20.0, on, 2.4)
		# label under the circle
		var f: Font = K.body_b()
		var fz: int = TBHudParts.fs(12.0)
		var cap: String = caption if caption_inside else ""
		if cap != "":
			draw_string(f, Vector2((size.x - TBHudParts.tw(f, cap, fz)) * 0.5, diameter() + 16.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fz, TBHudParts.tk("cream") if state != S.OVER else TBHudParts.tk("ink_off"))
		if attention > 0 and state == S.IDLE:
			var bc := Vector2(c.x + rad * 0.72, c.y - rad * 0.72)
			draw_circle(bc, 10.0, TBHudParts.tk("neg_bar"))
			var fm: Font = K.mono_b()
			var s: String = str(mini(attention, 9))
			draw_string(fm, Vector2(bc.x - TBHudParts.tw(fm, s, 12) * 0.5, TBHudParts.base(fm, 12, bc.y)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TBHudParts.tk("table"))
		if has_focus():
			draw_arc(c, rad + 4.0, 0.0, TAU, 48, TBHudParts.tk("cream"), 2.0, true)

## the label chip that belongs to the seal: the moves / turn / pending summary (and the caption when it does not fit the disc).
## It never truncates: it wraps. Sits above the seal, right-aligned.
class SealNote extends Control:
	var head: String = ""
	var body: String = ""
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func is_empty() -> bool: return head == "" and body == ""
	func _fh() -> int: return TBHudParts.fs(14.0)
	func _fb() -> int: return TBHudParts.fs(13.0)
	## chip size for a maximum width
	func measure(max_w: float) -> Vector2:
		var fh: Font = TBHudParts.body_b()
		var fb: Font = TBHudParts.body()
		var inner: float = max_w - 20.0
		var w: float = 0.0
		var h: float = 12.0
		if head != "":
			var hs: Vector2 = fh.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, inner, _fh(), -1, TextServer.BREAK_WORD_BOUND)
			w = maxf(w, hs.x); h += hs.y
		if body != "":
			var bs: Vector2 = fb.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, inner, _fb(), -1, TextServer.BREAK_WORD_BOUND)
			w = maxf(w, bs.x); h += bs.y
		return Vector2(ceilf(minf(max_w, w + 20.0)), ceilf(h))
	func _draw() -> void:
		draw_style_box(TBHudParts.sbox(TBHudParts.al(TBHudParts.tk("bar_0"), 0.96), TBHudParts.tk("rule"), 10.0, 1), Rect2(Vector2.ZERO, size))
		var fh: Font = TBHudParts.body_b()
		var fb: Font = TBHudParts.body()
		var inner: float = size.x - 20.0
		var y: float = 6.0
		if head != "":
			draw_multiline_string(fh, Vector2(10.0, y + fh.get_ascent(_fh())), head, HORIZONTAL_ALIGNMENT_LEFT, inner, _fh(), -1, TBHudParts.tk("cream"), TextServer.BREAK_WORD_BOUND)
			y += fh.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, inner, _fh(), -1, TextServer.BREAK_WORD_BOUND).y
		if body != "":
			draw_multiline_string(fb, Vector2(10.0, y + fb.get_ascent(_fb())), body, HORIZONTAL_ALIGNMENT_LEFT, inner, _fb(), -1, TBHudParts.tk("smoke"), TextServer.BREAK_WORD_BOUND)

# ---------------------------------------------------------------- legend
## colour key for the active map lens: gradient bar for ramps, swatches + words for categories
class Legend extends Control:
	const D = preload("res://src/engine/data.gd")
	var items: Array = []          # [[rgb, label]]
	var ramp: Array = []           # rgb stops
	var lo: String = ""
	var hi: String = ""
	var heading: String = ""
	var framed: bool = true        # false when embedded in a popover
	var width: float = 210.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false
	func has_key() -> bool: return not (ramp.is_empty() and items.is_empty())
	func setup(lens: String) -> void:
		items = []; ramp = []; heading = ""
		var T: Callable = TBI18n.T
		var L = TBLenses
		match lens:
			"economic": ramp = L.ECON_RAMP
			"military": ramp = L.ARMY_RAMP
			"population": ramp = L.POP_RAMP
			"stability": ramp = L.STAB_RAMP
			"diplomatic":
				items = [[0x46c36b, T.call("leg_self")], [L.REL_COL[0], T.call("rel_peace")], [L.REL_COL[1], T.call("rel_war")], [L.REL_COL[2], T.call("rel_nap")], [L.REL_COL[3], T.call("rel_ally")], [L.REL_COL[4], T.call("rel_marriage")]]
			"governments":
				for i in 10: items.append([L.REGIME_COL[i], T.call("g_" + D.REGIME_ID[i])])
			"terrain":
				for i in L.TERRAIN_COL.size(): items.append([L.TERRAIN_COL[i], T.call("t_" + D.TERRAIN_ID[i])])
			"buildings":
				for i in range(1, L.BUILD_COL.size()): items.append([L.BUILD_COL[i], T.call("b_" + D.BUILDINGS[i - 1]["id"])])
		lo = T.call("leg_low"); hi = T.call("leg_high")
		heading = T.call("lens_" + lens)
		visible = has_key()
		custom_minimum_size = Vector2(width, height_needed())
		queue_redraw()
	func height_needed() -> float:
		var hd: float = TBHudParts.fs(12.0) + 10.0
		if not ramp.is_empty(): return hd + 12.0 + 6.0 + TBHudParts.fs(12.0) + 8.0
		return hd + ceilf(items.size() / 2.0) * (TBHudParts.fs(12.0) + 7.0) + 6.0
	func _draw() -> void:
		var pad: float = 10.0 if framed else 0.0
		if framed: TBHudParts.plate(self, Rect2(Vector2.ZERO, size), TBHudParts.al(TBHudParts.tk("bar_0"), TBHudParts.opacity), TBHudParts.tk("rule_dark"), 4.0)
		var f12: int = TBHudParts.fs(12.0)
		var fh: Font = TBHudParts.body_b()
		var y: float = pad + 2.0
		TBHudParts.txt(self, fh, Vector2(pad, y + fh.get_ascent(f12)), TBHudParts.fit(fh, heading, f12, size.x - pad * 2.0), f12, TBHudParts.tk("brass_lt"))
		y += f12 + 8.0
		var fm: Font = TBHudParts.body()
		if not ramp.is_empty():
			var x0: float = pad; var x1: float = size.x - pad
			var n: int = ramp.size() - 1
			for i in n:
				var a: Color = Color.hex((int(ramp[i]) << 8) | 0xFF); var b: Color = Color.hex((int(ramp[i + 1]) << 8) | 0xFF)
				var xa: float = x0 + (x1 - x0) * i / n; var xb: float = x0 + (x1 - x0) * (i + 1) / n
				draw_polygon(PackedVector2Array([Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + 12), Vector2(xa, y + 12)]), PackedColorArray([a, b, b, a]))
			for t in 3: draw_rect(Rect2(x0 + (x1 - x0) * (t + 1) * 0.25 - 0.5, y + 12.0, 1.0, 3.0), TBHudParts.tk("smoke"))
			draw_rect(Rect2(x0, y, x1 - x0, 12.0), TBHudParts.tk("rule_dark"), false, 1.0)
			var yb: float = y + 12.0 + 4.0 + fm.get_ascent(f12)
			draw_string(fm, Vector2(x0, yb), lo, HORIZONTAL_ALIGNMENT_LEFT, -1, f12, TBHudParts.tk("smoke"))
			draw_string(fm, Vector2(x1 - TBHudParts.tw(fm, hi, f12), yb), hi, HORIZONTAL_ALIGNMENT_LEFT, -1, f12, TBHudParts.tk("smoke"))
		else:
			var colw: float = (size.x - pad * 2.0) * 0.5
			var rh: float = f12 + 7.0
			for i in items.size():
				var cx: float = pad + (i % 2) * colw; var cy: float = y + (i / 2) * rh
				draw_rect(Rect2(cx, cy + 1.0, 12, 12), Color.hex((int(items[i][0]) << 8) | 0xFF))
				draw_rect(Rect2(cx, cy + 1.0, 12, 12), TBHudParts.tk("rule_dark"), false, 1.0)
				var s: String = TBHudParts.fit(fm, String(items[i][1]), f12, colw - 20.0)
				draw_string(fm, Vector2(cx + 17.0, cy + 1.0 + fm.get_ascent(f12) - 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, f12, TBHudParts.tk("cream"))

# ---------------------------------------------------------------- hot-seat round strip (zone G)
## Round 4:  [] P1 ended   /\ P2 playing   () P3 waiting   <> P4 waiting
class SeatStrip extends Control:
	var round_text: String = ""
	var seats: Array = []                # [{"i": seat index, "tag": "P1", "state": 0 ended / 1 playing / 2 waiting, "word": "..."}]
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func desired_w() -> float:
		var f: Font = TBHudParts.body_b()
		var f12: int = TBHudParts.fs(12.0)
		var w: float = 12.0 + TBHudParts.tw(f, round_text, f12) + 12.0
		for s in seats: w += 10.0 + 4.0 + TBHudParts.tw(f, "%s %s" % [s["tag"], s["word"]], f12) + 14.0
		return ceilf(w)
	func _draw() -> void:
		TBHudParts.plate(self, Rect2(Vector2.ZERO, size), TBHudParts.al(TBHudParts.tk("bar_1"), TBHudParts.opacity), Color.TRANSPARENT, 2.0)
		var f: Font = TBHudParts.body_b()
		var f12: int = TBHudParts.fs(12.0)
		var cy: float = size.y * 0.5
		var x: float = 12.0
		x += TBHudParts.txt(self, f, Vector2(x, TBHudParts.base(f, f12, cy)), round_text, f12, TBHudParts.tk("smoke")) + 12.0
		for s in seats:
			var st: int = int(s["state"])
			var col: Color = TBHudParts.tk("brass_lt") if st == 1 else (TBHudParts.tk("cream") if st == 0 else TBHudParts.tk("smoke"))
			TBHudParts.seat_shape(self, Vector2(x + 5.0, cy), 10.0, int(s["i"]), col, st != 2)
			x += 14.0
			x += TBHudParts.txt(self, f, Vector2(x, TBHudParts.base(f, f12, cy)), "%s %s" % [s["tag"], s["word"]], f12, col) + 14.0
