## HUD building blocks (design/ux/hud.md, art bible 3 / 7.5): flat chamfered plates, resource chips, dock buttons, the End Turn
## plate, the lens legend, tooltips. Everything is drawn with primitives from TBTokens colours; no textures, no ornament.
class_name TBHudParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const BZ = preload("res://src/ui/bezel.gd")

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

# ---- Bezel demo type. Sizes are the demo's design units (a unit is not a screen pixel, so no 12 px floor), CSS-style letter spacing, Cinzel / Alegreya / JetBrains Mono.
static var _fv: Dictionary = {}
## light text on a dark ground looks heavier in a browser (gamma / stem darkening) than FreeType draws it: a touch of embolden closes the gap
const EMBOLDEN := 0.12
## a demo font size through the player's text scale
static func fu(px: float) -> int: return maxi(6, int(px * text_scale + 0.4999))        # 10.5 -> 10: a half unit rounds down (a browser sets 10.5 px type a little narrower than 11)
## Cinzel 700 (heavy) or 500; Cyrillic falls back to Alegreya SC
static func fcz(heavy: bool = true) -> Font:
	var k: String = "cz%d" % int(heavy)
	if not _fv.has(k):
		var v := FontVariation.new()
		v.base_font = K._font("cinzel-latin-700-normal" if heavy else "cinzel-latin-500-normal", ["alegreya-sc-cyrillic-700-normal" if heavy else "alegreya-sc-cyrillic-500-normal"])
		v.variation_embolden = EMBOLDEN
		_fv[k] = v
	return _fv[k]
## Alegreya 400 / 500 / 700 (or 400 italic) with lining figures (the demo: font-feature-settings 'lnum')
static func fal(w: int = 700, italic: bool = false) -> Font:
	var k: String = "al%d%d" % [w, int(italic)]
	if not _fv.has(k):
		var f: String = "alegreya-latin-400-italic" if italic else ("alegreya-latin-%d-normal" % w)
		var fb: String = "alegreya-cyrillic-400-italic" if italic else ("alegreya-cyrillic-%d-normal" % w)
		var v := FontVariation.new(); v.base_font = K._font(f, [fb]); v.opentype_features = {"lnum": 1}; v.variation_embolden = EMBOLDEN
		_fv[k] = v
	return _fv[k]
static func fmono() -> Font:
	if not _fv.has("mono"): _fv["mono"] = K._font("jetbrains-mono-latin-400-normal", ["jetbrains-mono-cyrillic-400-normal"])
	return _fv["mono"]
## width of `s` with CSS letter-spacing `ls` px (it trails the last glyph too, as CSS does)
static func twl(font: Font, s: String, size: int, ls: float = 0.0) -> float:
	if ls == 0.0: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w: float = 0.0
	for i in s.length(): w += font.get_char_size(s.unicode_at(i), size).x + ls
	return w
## text on a baseline; align 0 left / 1 centre / 2 right of x. `halo` > 0 draws a dark outline of that radius under it (paint-order: stroke). Returns the width.
static func txtl(ci: CanvasItem, font: Font, x: float, base: float, s: String, size: int, col: Color, ls: float = 0.0, align: int = 0, halo: float = 0.0, halo_col: Color = Color.TRANSPARENT) -> float:
	var w: float = twl(font, s, size, ls)
	var x0: float = x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	if halo > 0.0:
		var hc: Color = halo_col if halo_col.a > 0.0 else TBTokens.HALO
		if ls == 0.0: ci.draw_string_outline(font, Vector2(x0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(ceil(halo * 2.0)), hc)
		else:
			var hx: float = x0
			for i in s.length():
				ci.draw_char_outline(font, Vector2(hx, base), s[i], size, int(ceil(halo * 2.0)), hc)
				hx += font.get_char_size(s.unicode_at(i), size).x + ls
	if ls == 0.0:
		ci.draw_string(font, Vector2(x0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	else:
		var cx: float = x0
		for i in s.length():
			ci.draw_char(font, Vector2(cx, base), s[i], size, col)
			cx += font.get_char_size(s.unicode_at(i), size).x + ls
	return w
## the rail labels' text-shadow: 0 0 3px / 7px / 12px of the ground colour, as three growing dark outlines under the text
static func glow_text(ci: CanvasItem, font: Font, x: float, base: float, s: String, size: int, col: Color, ls: float = 0.0) -> void:
	var gc: Color = TBTokens.BZ_HALO
	for pass_ in [[6, 0.16], [3, 0.30], [1, 0.55]]:
		var hx: float = x
		for i in s.length():
			ci.draw_char_outline(font, Vector2(hx, base), s[i], size, int(pass_[0]), Color(gc.r, gc.g, gc.b, float(pass_[1])))
			hx += font.get_char_size(s.unicode_at(i), size).x + ls
	txtl(ci, font, x, base, s, size, col, ls)
## keyboard focus on a rectangular demo control: `outline: 2px solid var(--hi)` (the caller grows the rect by the 3 unit offset)
static func focus_box(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, tk("brass_lt"), false, 2.0)
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
static func body_i() -> Font: return K.body_i()
static func body_b() -> Font:
	_fonts()
	return _f_body_b

static func f_nat() -> Font:
	if _f_nat == null: _f_nat = K.tracked(K.display_hi(), 1)
	return _f_nat

# ---------------------------------------------------------------- drawing helpers
## rectangle with every corner cut by `cut` px (the interface's one shape)
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	if TBFrame.bezel and cut > 0.0: cut = 5.0 if cut <= 3.0 else (6.0 if cut <= 6.0 else cut)
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

## text with a dark halo so it reads on the map
static func txt_o(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, max_w: float = -1.0) -> float:
	ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, 4, TBTokens.HALO)
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
	var border_w: float = 1.0
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
			RenderingServer.canvas_item_add_polyline(ci, line, PackedColorArray([border]), border_w, true)
		if bar_w > 0.0 and bar.a > 0.0:
			RenderingServer.canvas_item_add_rect(ci, Rect2(body.position.x, body.position.y + cut, bar_w, body.size.y - cut * 2.0), bar)

## the demo's `plate()` (bezel_kit.js + bezel.css .pw/.plate/.pin): a drop shadow (0 14 22 black 60 %), a notched #7F6A33 hairline plate, a #1d1812 -> #13100c face with a
## 3 unit darker frame and a faint brass line 1 unit inside it. Tooltips, popovers and the gear menu.
class DemoBox extends StyleBox:
	var cut: float = 6.0
	var shadow: bool = true
	func setup(c: float, pad_x: float, pad_y_top: float, pad_y_bottom: float) -> DemoBox:
		cut = c
		set_content_margin(SIDE_LEFT, pad_x); set_content_margin(SIDE_RIGHT, pad_x)
		set_content_margin(SIDE_TOP, pad_y_top); set_content_margin(SIDE_BOTTOM, pad_y_bottom)
		return self
	func _draw(ci: RID, r: Rect2) -> void:
		if r.size.x < 4.0 or r.size.y < 4.0: return
		if shadow:
			var n: int = 10
			for i in n:
				var g: float = 22.0 * 0.9 * (2.0 * float(i) / (n - 1) - 1.0) * 0.5
				RenderingServer.canvas_item_add_polygon(ci, TBBezel.notch(Rect2(r.position + Vector2(0, 14.0), r.size).grow(g), maxf(0.0, cut + g * 0.4)), PackedColorArray([TBTokens.with_a(Color.BLACK, 0.6 / n)]))
		var lo: Color = TBBezel.BRASS_LO if not TBTokens.is_hc() else TBTokens.c("rule_dark")
		RenderingServer.canvas_item_add_polygon(ci, TBBezel.notch(r, cut), PackedColorArray([lo]))
		var inner: Rect2 = r.grow(-1.0)
		var pts: PackedVector2Array = TBBezel.notch(inner, cut - 1.0)
		var cols := PackedColorArray()
		var ca: Color = TBTokens.BZ_PL_A if not TBTokens.is_hc() else TBTokens.c("bar_1")
		var cb: Color = TBTokens.BZ_PL_B if not TBTokens.is_hc() else TBTokens.c("bar_0")
		for q in pts: cols.append(ca.lerp(cb, clampf((q.y - inner.position.y) / maxf(1.0, inner.size.y), 0.0, 1.0)))
		RenderingServer.canvas_item_add_polygon(ci, pts, cols)
		var frame: PackedVector2Array = TBBezel.notch(inner.grow(-1.5), maxf(0.0, cut - 1.0 - 0.9))
		frame.append(frame[0])
		RenderingServer.canvas_item_add_polyline(ci, frame, PackedColorArray([cb]), 3.0, true)
		var hair: PackedVector2Array = TBBezel.notch(inner.grow(-3.5), maxf(0.0, cut - 1.0 - 2.1))
		hair.append(hair[0])
		RenderingServer.canvas_item_add_polyline(ci, hair, PackedColorArray([TBTokens.with_a(TBBezel.BRASS, 0.22)]), 1.0, true)

## the demo's plate as a popover / tooltip box
static func bar_box(pad_x: float = 12.0, pad_y: float = 8.0, cut: float = 6.0, elevated: bool = false) -> DemoBox:
	var b: DemoBox = DemoBox.new().setup(maxf(cut, 6.0), pad_x, pad_y, pad_y)
	b.shadow = elevated
	return b

## pale document plate (realm sheet)
static func paper_box(pad_x: float = 16.0, pad_y: float = 14.0) -> PlateBox:
	var b: PlateBox = PlateBox.new().setup(tk("paper_0"), tk("rule"), 6.0, pad_x, pad_y)
	b.elevation = 1
	return b

## the demo's `.bt` button: a notched plate, Cinzel caps 11.5 letter-spaced .16em, 32 high. kind "primary" (brass face), "danger" (rust), anything else the dark plate with brass text
static func btn(text: String, kind: String, cb: Callable, dark: bool = true, px: int = 14) -> Button:
	var b := Button.new()
	b.text = text.to_upper() if TBI18n.lang != "ru" else text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 32)
	var fill: Color; var fill_h: Color; var edge: Color; var edge_h: Color; var ink: Color; var ink_h: Color
	if kind == "primary":
		fill = Color(TBTokens.BZ_G_A.lerp(TBTokens.BZ_G_B, 0.5)); fill_h = fill.lightened(0.08); edge = TBTokens.BZ_G_B; edge_h = TBTokens.BZ_HI; ink = tk("on_act"); ink_h = ink
	elif kind == "danger":
		fill = tk("wax_hover"); fill_h = tk("wax_hover").lightened(0.08); edge = tk("wax"); edge_h = tk("wax_rim"); ink = tk("on_wax"); ink_h = Color.WHITE
	else:
		fill = tk("bar_1"); fill_h = tk("bar_2"); edge = TBBezel.BRASS_LO; edge_h = TBBezel.BRASS; ink = tk("brass_lt"); ink_h = Color.WHITE
	if TBTokens.is_hc():
		edge = tk("rule_dark"); edge_h = tk("brass_lt"); ink = tk("cream") if kind != "primary" else tk("on_act"); ink_h = ink
	b.add_theme_stylebox_override("normal", PlateBox.new().setup(fill, edge, 6.0, 14, 6))
	b.add_theme_stylebox_override("hover", PlateBox.new().setup(fill_h, edge_h, 6.0, 14, 6))
	b.add_theme_stylebox_override("pressed", PlateBox.new().setup(fill.darkened(0.15), edge_h, 6.0, 14, 6))
	b.add_theme_stylebox_override("disabled", PlateBox.new().setup(al(fill, 0.5), edge, 6.0, 14, 6))
	b.add_theme_stylebox_override("focus", PlateBox.new().setup(Color.TRANSPARENT, tk("brass_lt"), 6.0, 14, 6))
	for k in ["font_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, ink)
	b.add_theme_color_override("font_hover_color", ink_h)
	var f := FontVariation.new(); f.base_font = fcz(true); f.spacing_glyph = 2; f.variation_embolden = EMBOLDEN
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", fu(11.5))
	if cb.is_valid(): b.pressed.connect(cb)
	return b

## tooltip / pinned popover content (the demo's #tip): the plate, a title (Cinzel 700 12.5, caps, --hi), a headline (Alegreya 15.5, --dim), figure rows (label ..... value, 14.5)
## and a key hint in JetBrains Mono 10.5. rows: [[label, value, tone]]; tone: "" | "pos" | "neg" | "sum" (a total: a rule above it)
static func tip_box(title: String, body: String, max_w: float = 320.0, rows: Array = [], hint: String = "") -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", DemoBox.new().setup(6.0, 15.0, 12.0, 11.0))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var width: float = clampf(max_w, 190.0, 330.0 - 30.0)
	var dim: Color = TBTokens.BZ_DIM if not TBTokens.is_hc() else tk("smoke")
	if title != "":
		var t := Label.new(); t.text = (title.to_upper() if TBI18n.lang != "ru" else title); t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tf := FontVariation.new(); tf.base_font = fcz(true); tf.spacing_glyph = 2; tf.variation_embolden = EMBOLDEN
		t.add_theme_font_override("font", tf); t.add_theme_font_size_override("font_size", fu(12.5)); t.add_theme_color_override("font_color", tk("brass_lt"))
		v.add_child(t)
	if body != "":
		var b := Label.new(); b.text = body; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_font_override("font", fal(400)); b.add_theme_font_size_override("font_size", fu(15.5)); b.add_theme_color_override("font_color", dim)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(width, 0)
		var bm := MarginContainer.new(); bm.add_theme_constant_override("margin_top", 5); bm.mouse_filter = Control.MOUSE_FILTER_IGNORE; bm.add_child(b)
		v.add_child(bm)
	if not rows.is_empty():
		var g := VBoxContainer.new(); g.add_theme_constant_override("separation", 0); g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.custom_minimum_size = Vector2(width, 0)
		for r in rows:
			var tone: String = String(r[2]) if r.size() > 2 else ""
			var line := HBoxContainer.new(); line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := Label.new(); l.text = String(r[0]); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_override("font", fal(400)); l.add_theme_font_size_override("font_size", fu(14.5)); l.add_theme_color_override("font_color", tk("cream") if tone == "sum" else dim)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var vl := Label.new(); vl.text = String(r[1]); vl.mouse_filter = Control.MOUSE_FILTER_IGNORE; vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			vl.add_theme_font_override("font", fal(700)); vl.add_theme_font_size_override("font_size", fu(14.5))
			vl.add_theme_color_override("font_color", TBTokens.BZ_GOOD if tone == "pos" else (TBTokens.BZ_BAD_TXT if tone == "neg" else tk("cream")))
			if tone == "sum":
				var rule := ColorRect.new(); rule.color = TBTokens.BZ_RULER; rule.custom_minimum_size = Vector2(0, 1); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
				g.add_child(rule)
			var lm := MarginContainer.new(); lm.add_theme_constant_override("margin_top", 2); lm.add_theme_constant_override("margin_bottom", 2); lm.add_theme_constant_override("margin_right", 0); lm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(l); line.add_child(vl)
			lm.add_child(line); g.add_child(lm)
		var gm := MarginContainer.new(); gm.add_theme_constant_override("margin_top", 6); gm.mouse_filter = Control.MOUSE_FILTER_IGNORE; gm.add_child(g)
		v.add_child(gm)
	if hint != "":
		var h := Label.new(); h.text = hint; h.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_font_override("font", fmono()); h.add_theme_font_size_override("font_size", fu(10.5)); h.add_theme_color_override("font_color", TBTokens.BZ_DIM2 if not TBTokens.is_hc() else tk("smoke"))
		h.custom_minimum_size = Vector2(width, 0)
		var hm := MarginContainer.new(); hm.add_theme_constant_override("margin_top", 7); hm.mouse_filter = Control.MOUSE_FILTER_IGNORE; hm.add_child(h)
		v.add_child(hm)
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
static var _nb: Dictionary = {}
## Bezel mode: every rounded box becomes a notched plate (radius -> notch size)
static func _nbox(fill: Color, edge: Color, radius: float, bw: int) -> PlateBox:
	fill.a = snappedf(fill.a, 0.05); edge.a = snappedf(edge.a, 0.05)
	var key := "%s%s%d%d%d" % [fill.to_html(true), edge.to_html(true), int(radius), bw, TBTokens.sig()]
	if _nb.has(key): return _nb[key]
	if _nb.size() > 400: _nb.clear()
	var cut: float = 0.0 if radius <= 4.0 else (3.0 if radius <= 7.0 else (6.0 if radius <= 12.0 else (9.0 if radius < 16.0 else 12.0)))
	var b: PlateBox = PlateBox.new().setup(fill, edge, cut, 0, 0)
	b.border_w = float(maxi(bw, 1))
	_nb[key] = b
	return b
## cached StyleBoxFlat: fill, 1-px edge, corner radius
static func sbox(fill: Color, edge: Color, radius: float, bw: int = 1) -> StyleBox:
	if TBFrame.bezel: return _nbox(fill, edge, radius, bw)
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
static func card_box(radius: float = 16.0, fill_a: float = 0.97) -> StyleBox:
	return sbox(al(tk("bar_0"), fill_a), tk("rule"), radius, 1)

# ---------------------------------------------------------------- resource gauge
## Bezel gauge (gaugeSvg + the `.g` cell of renderTop): a brass instrument ring with the value in its face and a 270 degree arc, the caption (Cinzel caps) and
## a signed delta beneath. Sizes are the demo's: gauge radius 30, cell 84 wide (phone 15 / 56, no delta line).
class Chip extends Hit:
	var glyph: String = "coin"          # kept for callers; the demo's gauge shows its value, not an icon
	var value: String = ""
	var final_text: String = ""
	var suffix: String = ""
	var delta: int = 0
	var has_delta: bool = false
	var delta_on: bool = true
	var sub_text: String = ""           # replaces the delta (manpower: "43 %")
	var state: int = 0                  # 0 normal, 1 caution, 2 critical
	var compact: bool = false           # phone landscape: gauge radius 15, caption 8.5, no delta line
	var tight: bool = false
	var glyph_col: Color = Color.TRANSPARENT
	var val_col: Color = Color.TRANSPARENT
	var spark: Array = []               # kept for the tooltip
	var caption: String = ""
	var frac: float = -1.0              # 0..1 arc fill
	var delta_tone: int = 0             # 0 dim, 1 signed colour (the Treasury figure)
	var _shown: float = NAN
	var _target: float = 0.0
	var _fmt: Callable = Callable()
	var _t: float = 0.0
	var _floats: Array = []              # [{t, txt, pos}]: the change that just happened, rising over the gauge
	var _pulse: float = 1.0
	func _ready() -> void: set_process(false)
	## drop the remembered value and any rising figures: the next number shown is a fresh start (seat change, new game)
	func forget() -> void:
		_shown = NAN; _floats.clear()
	func gr() -> float: return 15.0 if (compact or tight) else 30.0
	func gsz() -> float: return 56.0 if (compact or tight) else 84.0
	func gbox() -> float: return 2.0 * (gr() + 12.0)
	func medal() -> float: return gbox() - 6.0
	func fcap() -> int: return TBHudParts.fu(8.5 if (compact or tight) else 10.5)
	func cap_font() -> Font: return TBHudParts.fcz(true)
	func cap_ls() -> float: return (8.5 if (compact or tight) else 10.5) * 0.16
	func cap_text() -> String: return caption.to_upper() if TBI18n.lang != "ru" else caption
	func cap_h() -> float: return roundf(cap_font().get_height(fcap()))
	func has_sub() -> bool: return (sub_text != "" or (delta_on and has_delta)) and not (compact or tight)
	func dtext() -> String:
		if sub_text != "": return sub_text
		return ("+%s" % K.fmt(float(delta))) if delta >= 0 else ("−%s" % K.fmt(float(-delta)))
	func desired_w() -> float:
		var w: float = gsz()                                                      # the demo's cell is a fixed 84 (56): a caption a little wider than it just overhangs
		if caption != "":
			var cw: float = TBHudParts.twl(cap_font(), cap_text(), fcap(), cap_ls())
			if cw > w + 12.0: w = cw + 4.0
		return ceilf(w)
	func desired_h() -> float:
		var h: float = gbox()
		if caption != "": h += cap_h()
		if has_sub(): h += 1.0 + 16.0
		return ceilf(h)
	func set_num(v: float, fmt: Callable) -> void:
		_fmt = fmt; final_text = fmt.call(v)
		if not is_nan(_shown) and not TBHudParts.reduced_motion() and absf(v - _target) >= 1.0 and v != _target:
			_floats.append({"t": 0.0, "txt": ("+" if v > _target else "−") + K.fmt(absf(v - _target)), "pos": v > _target})
			if _floats.size() > 3: _floats.pop_front()
			_pulse = 0.0
			set_process(true)
		if is_nan(_shown) or TBHudParts.reduced_motion():
			_shown = v; _target = v; value = final_text; set_process(state >= 1 and not TBHudParts.reduced_motion()); queue_redraw(); return
		if v != _target:
			_target = v; set_process(true)
		elif not is_processing():
			value = final_text
		queue_redraw()
	func _process(d: float) -> void:
		_t += d; _pulse += d
		for fl in _floats: fl["t"] = float(fl["t"]) + d
		_floats = _floats.filter(func(e): return float(e["t"]) < 1.3)
		if not is_nan(_shown) and _shown != _target:
			_shown += (_target - _shown) * (1.0 - exp(-9.0 * d))
			if absf(_target - _shown) < 0.5: _shown = _target
			value = _fmt.call(_shown)
		queue_redraw()
		if _shown == _target and state < 1 and _floats.is_empty() and _pulse > 0.5: set_process(false)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var gs: float = gbox()
		var c := Vector2(size.x * 0.5, gs * 0.5)
		var tone: Color = glyph_col if glyph_col.a > 0.0 else TBBezel.BRASS
		var edge: Color = tone
		if state == 2: edge = TBTokens.BZ_BAD
		elif state == 1: edge = TBHudParts.tk("warn_bar")
		var k: float = 1.0
		if _pulse < 0.5 and not TBHudParts.reduced_motion(): k = 1.0 + 0.13 * sin(PI * clampf(_pulse / 0.5, 0.0, 1.0)) * (1.0 if _pulse < 0.5 else 0.0)   # .g.pulse: scale 1.13 at 40 %
		if hover: TBBezel.glow(self, c, (gr() + 8.0 + 2.0) * k, TBTokens.with_a(TBTokens.c("brass_lt"), 0.45), 8.0)
		if k != 1.0: draw_set_transform(c, 0.0, Vector2(k, k)); c = Vector2.ZERO
		var f: float = frac if frac >= 0.0 else 0.0
		TBBezel.gauge_demo(self, c, gr(), f, edge)
		if state >= 1:
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.14) if not TBHudParts.reduced_motion() else 1.0
			draw_arc(c, gr() + 8.0 + 3.0, 0.0, TAU, 48, TBHudParts.al(edge, 0.35 + 0.4 * pulse), 1.6, true)
		var fb: Font = TBHudParts.fal(700)
		var base_z: float = maxf(11.0, gr() * 0.6) * (0.78 if value.length() > 3 else 1.0)
		var z: int = TBHudParts.fu(base_z)
		var vc: Color = val_col if val_col.a > 0.0 else TBHudParts.tk("cream")
		var maxw: float = (gr() + 8.0) * 1.7
		while z > 6 and TBHudParts.tw(fb, value, z) > maxw: z -= 1
		draw_string(fb, c + Vector2(-TBHudParts.tw(fb, value, z) * 0.5, gr() * 0.12), value, HORIZONTAL_ALIGNMENT_LEFT, -1, z, vc)
		if k != 1.0: draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var y: float = gs
		if caption != "":
			var cf: Font = cap_font()
			var cc: Color = TBTokens.BZ_DIM if not TBTokens.is_hc() else TBHudParts.tk("smoke")
			if state >= 1: cc = edge
			TBHudParts.txtl(self, cf, size.x * 0.5, y + cf.get_ascent(fcap()), cap_text(), fcap(), cc, cap_ls(), 1)
			y += cap_h()
		if has_sub():
			var fm: Font = TBHudParts.fal(700)
			var col: Color = TBTokens.BZ_DIM if not TBTokens.is_hc() else TBHudParts.tk("smoke")
			if delta_tone == 1 and sub_text == "": col = TBTokens.BZ_GOOD if delta >= 0 else TBTokens.BZ_NOTICE_BAD
			var dz: int = TBHudParts.fu(13.0)
			y += 1.0
			TBHudParts.txtl(self, fm, size.x * 0.5, y + (16.0 - fm.get_height(dz)) * 0.5 + fm.get_ascent(dz), dtext(), dz, col, 0.0, 1)
		for fl in _floats:                                                       # floatTop: the change rises over the gauge and fades
			var kk: float = float(fl["t"]) / 1.3
			var fa: float = clampf(kk / 0.15, 0.0, 1.0) * (1.0 - clampf((kk - 0.15) / 0.85, 0.0, 1.0))
			var fb2: Font = TBHudParts.fal(700)
			var fz: int = TBHudParts.fu(22.0)
			var fy: float = gs * 0.35 + 22.0 + lerpf(6.0, -26.0, kk)
			var fcol: Color = TBTokens.BZ_GOOD if bool(fl["pos"]) else TBTokens.BZ_BAD_TXT
			TBHudParts.txtl(self, fb2, size.x * 0.5, fy, String(fl["txt"]), fz, TBHudParts.al(fcol, fa), 0.0, 1, 2.0, TBTokens.with_a(TBTokens.HALO, fa))
		if has_focus(): TBHudParts.focus_box(self, Rect2(c.x - (gr() + 10.0), 0, (gr() + 10.0) * 2.0, size.y).grow(2.0))

# ---------------------------------------------------------------- crest
## the nation medallion (renderTop): the flag in a brass instrument ring (radius med-2, flag circle med-14), the name in Cinzel caps and the ruler in italic beside it
class NationChip extends Hit:
	var flag: Texture2D
	var nation: String = ""
	var subtitle: String = ""
	var show_name: bool = true
	var seat: int = -1
	var seat_text: String = ""
	var badge: int = 0
	var rank_text: String = ""
	var compact: bool = false           # phone landscape: medallion 25, no name
	func med() -> float: return 25.0 if compact else 46.0
	func medal() -> float: return 2.0 * med()
	func name_font() -> Font: return TBHudParts.fcz(true)
	func fname() -> int: return TBHudParts.fu(19.0)
	func fsub() -> int: return TBHudParts.fu(15.0)
	func desired_w() -> float:
		var w: float = 2.0 * med() + 8.0
		if not show_name: return ceilf(w)
		var tn: float = TBHudParts.twl(name_font(), nation.to_upper() if TBI18n.lang != "ru" else nation, fname(), 19.0 * 0.2)
		var ts: float = TBHudParts.tw(TBHudParts.fal(400, true), subtitle, fsub()) if subtitle != "" else 0.0
		w = 2.0 * med() + 22.0 + maxf(tn, ts) + 6.0
		if seat >= 0: w += 34.0
		return ceilf(w)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var m: float = med()
		var c := Vector2(m + 4.0, m + 4.0)
		TBBezel.ring(self, c, m - 2.0, 48, TBTokens.c("bar_0"))
		var pr: float = m - 14.0
		if flag != null:                                                    # the flag fills its circle (an era flag is pre-cropped on its main element: tools/flags/focus.json)
			var pts := PackedVector2Array(); var uvs := PackedVector2Array()
			var fs_: Vector2 = flag.get_size()
			var side: float = minf(fs_.x, fs_.y)
			var uo := Vector2((fs_.x - side) * 0.5, (fs_.y - side) * 0.5)
			for i in 64:
				var a: float = TAU * i / 64.0
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * pr)
				uvs.append((uo + Vector2(side, side) * 0.5 + d * side * 0.5) / fs_)
			draw_colored_polygon(pts, Color.WHITE, uvs, flag)
		if show_name:
			var x: float = 2.0 * m + 22.0
			var fb: Font = name_font()
			var fn: int = fname()
			var top: float = m - 21.0 + 4.0                                  # the demo's text block top (renderTop: top = M + med - 21)
			var nm: String = nation.to_upper() if TBI18n.lang != "ru" else nation
			TBHudParts.txtl(self, fb, x, top + fb.get_ascent(fn), nm, fn, TBTokens.c("cream"), 19.0 * 0.2)
			if subtitle != "":
				var f2: Font = TBHudParts.fal(400, true)
				var z2: int = fsub()
				TBHudParts.txtl(self, f2, x, top + roundf(fb.get_height(fn)) + 3.0 + f2.get_ascent(z2), subtitle, z2, TBTokens.c("smoke"))
		if seat >= 0:
			var sx: float = size.x - 22.0
			TBHudParts.seat_shape(self, Vector2(sx, c.y - 6.0), 10.0, seat, TBHudParts.tk("brass_lt"))
			var fs2: Font = TBHudParts.fal(700)
			var zs: int = TBHudParts.fu(12.0)
			draw_string(fs2, Vector2(sx - TBHudParts.tw(fs2, seat_text, zs) * 0.5, c.y + 14.0), seat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, zs, TBHudParts.tk("brass_lt"))
		if badge > 0: draw_circle(Vector2(c.x + m * 0.7, c.y - m * 0.7), 4.0, TBHudParts.tk("warn_bar"))
		if has_focus(): TBHudParts.focus_box(self, Rect2(2.0, 2.0, 2.0 * m, 2.0 * m + 4.0))

# ---------------------------------------------------------------- date medallion
## the calendar (renderTop, 84 box scaled): the year over the turn caption in a graduated brass ring with the year's progress as a brass arc
class DateText extends Control:
	var year: String = ""
	var turn_cap: String = ""
	var turn_no: int = 0
	var phase: float = 0.5               # share of the year gone (the demo: 30 degrees per month)
	var compact: bool = false            # phone landscape: 46 box, the turn number only
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func medal() -> float: return 46.0 if compact else 84.0
	func desired_w() -> float: return medal()
	func _draw() -> void:
		var s: float = medal() / 84.0
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		TBBezel.ring(self, c, 40.0 * s, 48, TBTokens.c("bar_0"), true, false, s)
		TBBezel.arc_deg(self, c, 30.0 * s, 0.0, minf(359.9, 360.0 * clampf(phase, 0.0, 1.0)), TBBezel.BRASS, 3.0 * s)
		var o: Vector2 = c - Vector2(42.0, 42.0) * s
		if compact:
			var fb: Font = TBHudParts.fcz(false)
			var z: int = TBHudParts.fu(19.0 * s)
			TBHudParts.txtl(self, fb, o.x + 42.0 * s, o.y + 52.0 * s, str(turn_no) if turn_no > 0 else "", z, TBBezel.BRASS, 1.5 * s, 1)
		else:
			var fb2: Font = TBHudParts.fcz(true)
			var z2: int = TBHudParts.fu(16.0 * s)
			var ys: String = year.replace(" AD", "")
			TBHudParts.txtl(self, fb2, o.x + 42.0 * s, o.y + 43.0 * s, ys, z2, TBTokens.c("cream"), 0.0, 1)
			var cf: Font = TBHudParts.fcz(false)
			var tz: int = TBHudParts.fu(10.0 * s)
			TBHudParts.txtl(self, cf, o.x + 42.0 * s, o.y + 57.0 * s, turn_cap.to_upper() if TBI18n.lang != "ru" else turn_cap, tz, TBBezel.BRASS, 1.5 * s, 1)

# ---------------------------------------------------------------- lens tuner
## renderTuner: a notched-less plate (hairline rect) with a graduated scale, the lens names over it and a red pointer under the active one
class ModeSwitch extends Hit:
	signal picked(id: String)
	var items: Array = []               # [[id, label]]
	var current: String = ""
	var compact: bool = false           # phone landscape: 380 x 38
	var _rects: Array = []
	var _px: float = -1.0                # the pointer's x offset, eased toward the active lens (the demo: .4 s cubic-bezier(.3,1.4,.5,1))
	var _from: float = 0.0
	var _to: float = 0.0
	var _t: float = 1.0
	func plate_w() -> float: return 380.0 if compact else 560.0
	func plate_h() -> float: return 38.0 if compact else 60.0
	func fz() -> int: return TBHudParts.fu(9.5 if compact else 12.5)
	func ls() -> float: return 0.8 if compact else 2.4
	func _font(on: bool) -> Font: return TBHudParts.fcz(on)
	func _lab(i: int) -> String: return String(items[i][1]).to_upper() if TBI18n.lang != "ru" else String(items[i][1])
	func desired_w() -> float: return plate_w()
	func set_current(id: String) -> void:
		var idx: int = -1
		for i in items.size():
			if String(items[i][0]) == id: idx = i
		current = id
		var w: float = plate_w()
		var tgt: float = (w - 28.0) * idx / maxf(1.0, float(items.size())) if idx >= 0 else _to
		if _px < 0.0 or TBHudParts.reduced_motion(): _px = tgt; _to = tgt; _from = tgt; _t = 1.0
		elif tgt != _to:
			_from = _px; _to = tgt; _t = 0.0; set_process(true)
		queue_redraw()
	func _process(d: float) -> void:
		_t = minf(1.0, _t + d / 0.4)
		var u: float = _t
		var e: float = _bez(u)
		_px = lerpf(_from, _to, e)
		queue_redraw()
		if _t >= 1.0: set_process(false)
	## cubic-bezier(.3, 1.4, .5, 1) solved for t by bisection
	static func _bez(x: float) -> float:
		var lo: float = 0.0; var hi: float = 1.0
		for _i in 18:
			var m: float = (lo + hi) * 0.5
			var bx: float = 3.0 * (1.0 - m) * (1.0 - m) * m * 0.3 + 3.0 * (1.0 - m) * m * m * 0.5 + m * m * m
			if bx < x: lo = m
			else: hi = m
		var t: float = (lo + hi) * 0.5
		return 3.0 * (1.0 - t) * (1.0 - t) * t * 1.4 + 3.0 * (1.0 - t) * t * t * 1.0 + t * t * t
	func _has_point(p: Vector2) -> bool: return Rect2(Vector2.ZERO, size).grow(2.0).has_point(p)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				if (_rects[i] as Rect2).has_point((e as InputEventMouseButton).position):
					picked.emit(String(items[i][0])); accept_event(); return
	func _draw() -> void:
		var w: float = plate_w(); var h: float = plate_h()
		draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), TBTokens.with_a(TBTokens.BZ_TUNER, 0.93))
		draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), TBBezel.BRASS_LO if not TBTokens.is_hc() else TBTokens.c("rule_dark"), false, 1.0)
		var pts := PackedVector2Array()
		for i in 61:
			var x: float = 14.0 + (w - 28.0) * i / 60.0
			pts.append(Vector2(x, h - 12.0)); pts.append(Vector2(x, h - 12.0 + (10.0 if i % 15 == 0 else (7.0 if i % 5 == 0 else 4.0))))
		var tcol: Color = TBTokens.with_a(TBBezel.BRASS, 0.7 if compact else 1.0)
		var tcol2: Color = TBBezel.ac(tcol, 0.8)
		for i4 in range(0, pts.size() - 1, 2): draw_line(pts[i4], pts[i4 + 1], tcol2, TBBezel.aw(0.8), true)
		_rects.clear()
		var n: int = items.size()
		for i in n:
			var cx: float = 14.0 + (w - 28.0) * (i + 0.5) / maxf(1.0, float(n))
			var on: bool = String(items[i][0]) == current
			var f: Font = _font(on)
			var cw: float = (w - 28.0) / maxf(1.0, float(n))
			_rects.append(Rect2(cx - cw * 0.5, 0.0, cw, h))
			TBHudParts.txtl(self, f, cx, (15.0 if compact else 24.0), _lab(i), fz(), TBTokens.c("cream") if on else (TBTokens.BZ_DIM2 if not TBTokens.is_hc() else TBHudParts.tk("smoke")), ls(), 1)
		if current != "" and _px >= 0.0:
			var px: float = 14.0 + (w - 28.0) * 0.5 / maxf(1.0, float(n)) + _px
			draw_colored_polygon(PackedVector2Array([Vector2(px, h - 13.0), Vector2(px - 5.0, h - 22.0), Vector2(px + 5.0, h - 22.0)]), TBTokens.BZ_BAD)
		if has_focus(): TBHudParts.focus_box(self, Rect2(Vector2.ZERO, size).grow(3.0))

# ---------------------------------------------------------------- dock / lens / menu icon button
## round medallion with the demo's icon inside. A rail item (edge 0, `row`): the Cinzel label sits to its right on a pill that lights on hover.
## `framed`: a bare medallion standing on the map (gear, zoom, more lenses). edge 1 / 2: the portrait tab bar (label beneath).
class IconBtn extends Hit:
	var glyph: String = "gear"
	var label: String = ""
	var active: bool = false
	var badge: int = 0
	var badge_crit: bool = false
	var edge: int = 0                   # 0 rail (vertical list), 1 / 2 tab bar
	var sq: float = 40.0
	var icon_px: float = 24.0
	var show_label: bool = true
	var hint: String = ""               # hotkey text (menus)
	var framed: bool = false            # stands alone on the map: a bare medallion
	var ticks_n: int = 24               # ring ticks of a framed medallion (the zoom buttons have none)
	var compact: bool = false           # phone landscape: rail icon 20, no label
	var dia: float = 52.0               # the medallion's diameter in a rail row (railD)
	## the game's glyph names -> the demo's icon names
	static func demo_icon(g: String) -> String:
		match g:
			"globe": return "nations"
			"coins": return "treasury"
			"scales": return "decrees"
			"lamp": return "council"
			"book": return "annals"
			"trophy": return "goals"
			"gear", "menu": return "settings"
		return g
	func _lab() -> String: return label.to_upper() if TBI18n.lang != "ru" else label
	## width of a rail row: the medallion, 14 gap, the label, 16 padding
	func row_w() -> float:
		var lw: float = TBHudParts.twl(TBHudParts.fcz(active), _lab(), TBHudParts.fu(13.0), 2.6) if (show_label and label != "") else 0.0
		return dia + ((14.0 + lw + 16.0) if lw > 0.0 else 0.0)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var ic: String = demo_icon(glyph)
		if edge > 0:
			_draw_tab(r, ic)
			return
		if framed:
			var d: float = minf(size.x, size.y)
			var c := Vector2(size.x * 0.5, size.y * 0.5)
			var k: float = d / 54.0
			TBBezel.ring(self, c, 25.0 * k, ticks_n, TBTokens.c("bar_0"), true, false, k)
			if active: draw_arc(c, 25.0 * k + 3.0, 0.0, TAU, 48, TBHudParts.tk("brass_lt"), 1.6, true)
			var col: Color = TBHudParts.tk("brass_lt")
			if ic == "plus" or ic == "minus":                                              # the zoom buttons: a 12-box + / -
				var s: float = d * 0.46; var u: float = s / 12.0
				var o: Vector2 = c - Vector2(s, s) * 0.5
				draw_line(o + Vector2(1, 6) * u, o + Vector2(11, 6) * u, col, 1.8 * u)
				draw_circle(o + Vector2(1, 6) * u, 0.9 * u, col); draw_circle(o + Vector2(11, 6) * u, 0.9 * u, col)
				if ic == "plus":
					draw_line(o + Vector2(6, 1) * u, o + Vector2(6, 11) * u, col, 1.8 * u)
					draw_circle(o + Vector2(6, 1) * u, 0.9 * u, col); draw_circle(o + Vector2(6, 11) * u, 0.9 * u, col)
			else:
				TBBzIcons.draw(self, ic, c, icon_px, col)
			if has_focus(): TBHudParts.focus_box(self, r.grow(3.0))
			return
		# rail row
		var D: float = dia
		var row: bool = show_label and label != ""
		var c2 := Vector2(D * 0.5, size.y * 0.5)
		if hover or has_focus():                                                          # .rail-b:hover: a pill lit from the left (border-radius 30, gradient to rgba(201,162,75,.12))
			var rad: float = minf(30.0, size.y * 0.5)
			var poly := PackedVector2Array(); var cols := PackedColorArray()
			var arc_n: int = 10
			for i in arc_n + 1:                                                           # right cap, top to bottom
				var an: float = -PI * 0.5 + PI * i / arc_n
				poly.append(Vector2(size.x - rad + cos(an) * rad, rad + sin(an) * rad + (size.y * 0.5 - rad)))
			for i in arc_n + 1:                                                           # left cap, bottom to top
				var an2: float = PI * 0.5 + PI * i / arc_n
				poly.append(Vector2(rad + cos(an2) * rad, rad + sin(an2) * rad + (size.y * 0.5 - rad)))
			for q in poly:
				cols.append(Color(TBBezel.BRASS.r, TBBezel.BRASS.g, TBBezel.BRASS.b, 0.12 * clampf(q.x / maxf(1.0, size.x), 0.0, 1.0)))
			draw_polygon(poly, cols)
		var k2: float = D / 66.0
		if hover or has_focus(): TBBezel.glow(self, c2, 33.0 * k2, TBTokens.with_a(TBTokens.c("brass_lt"), 0.5), 7.0)
		TBBezel.ring(self, c2, 31.0 * k2, 24, TBTokens.c("bar_0"), true, false, k2)
		if active: draw_circle(c2, 25.0 * k2, TBTokens.with_a(TBBezel.BRASS, 0.22))
		var col2: Color = TBTokens.c("cream")
		if not TBTokens.is_hc(): col2 = Color.WHITE if active else TBTokens.BZ_RAIL_ICON
		TBBzIcons.draw(self, ic, c2, icon_px, col2)
		if row:
			var f: Font = TBHudParts.fcz(active)
			var z: int = TBHudParts.fu(13.0)
			var lc: Color = (TBTokens.c("cream") if active else TBTokens.BZ_DIM) if not hover else Color.WHITE
			if TBTokens.is_hc(): lc = TBTokens.c("cream")
			TBHudParts.glow_text(self, f, D + 14.0, size.y * 0.5 + (f.get_ascent(z) - f.get_height(z) * 0.5), _lab(), z, lc, 2.6)
		if badge > 0:
			var bc: Vector2 = c2 + Vector2(D * 0.39, -D * 0.39)
			draw_circle(bc, 8.0, TBTokens.BZ_BAD if badge_crit else TBHudParts.tk("brass_lt"))
			var fbm: Font = K.mono_b()
			var s4: String = str(mini(badge, 99))
			draw_string(fbm, Vector2(bc.x - TBHudParts.tw(fbm, s4, 12) * 0.5, TBHudParts.base(fbm, 12, bc.y)), s4, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TBHudParts.tk("table"))
		if has_focus(): TBHudParts.focus_box(self, r.grow(3.0))
	## the portrait tab bar item: medallion with the label beneath (the layout the phone had before the demo's landscape one)
	func _draw_tab(r: Rect2, ic: String) -> void:
		var oy: float = 1.0 if down else 0.0
		var col: Color = TBHudParts.tk("brass_lt") if active else TBHudParts.tk("cream")
		var labelled: bool = show_label and label != ""
		var d: float = (minf(size.x, size.y) - 2.0) if not labelled else minf(size.x - 6.0, size.y * 0.62)
		d = maxf(d, 24.0)
		var R: float = d * 0.5
		var c: Vector2 = Vector2(size.x * 0.5, R + 2.0 + oy) if labelled else Vector2(size.x * 0.5, size.y * 0.5 + oy)
		var fr: float = TBBezel.ring(self, c, R, 0 if R < 17.0 else 24, TBTokens.c("bar_2") if (hover or down or active) else TBTokens.c("bar_0"))
		if active: draw_arc(c, R + 2.5, 0.0, TAU, 40, TBHudParts.tk("brass_lt"), 1.6, true)
		TBBzIcons.draw(self, ic, c, minf(icon_px, fr * 1.15), col)
		if labelled:
			var f2: Font = TBHudParts.fcz(false)
			var z2: int = TBHudParts.fs(12.0)
			var s3: String = TBHudParts.fit(f2, _lab(), z2, size.x - 2.0)
			draw_string(f2, Vector2((size.x - TBHudParts.tw(f2, s3, z2)) * 0.5, size.y - 4.0 + oy), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, TBHudParts.tk("cream") if active else TBHudParts.tk("smoke"))
		if badge > 0:
			var bc: Vector2 = c + Vector2(R * 0.78, -R * 0.78)
			draw_circle(bc, 8.0, TBHudParts.tk("neg_bar") if badge_crit else TBHudParts.tk("brass_lt"))
			var fb: Font = K.mono_b()
			var s4: String = str(mini(badge, 99))
			draw_string(fb, Vector2(bc.x - TBHudParts.tw(fb, s4, 12) * 0.5, TBHudParts.base(fb, 12, bc.y)), s4, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TBHudParts.tk("table"))
		if has_focus(): TBHudParts.focus_ring(self, r)

# ---------------------------------------------------------------- surfaces
## the ground behind the portrait tab bar, and the rail's graduated ruler (renderRail): a shallow arc of hairline with a tick every 8 units,
## brass every 5th, bulging toward the map and zero at both ends
class Surface extends Control:
	var kind: String = "card"           # card (the rail ruler) | bottom (phone tab bar)
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		match kind:
			"bottom":
				draw_rect(Rect2(Vector2.ZERO, size), TBHudParts.al(TBHudParts.tk("bar_0"), 0.98))
				draw_rect(Rect2(0, 0, size.x, 1.0), TBHudParts.tk("rule"))
				TBBezel.ruler_h(self, 8.0, size.x - 8.0, 1.0, 8.0, 5, TBHudParts.al(TBHudParts.tk("rule"), 0.8), 3.0)
			_:
				var tot: float = size.y
				var ar: float = ruler_r
				var pts := PackedVector2Array()
				var i: int = 0
				var n: int = int(floor(tot / 6.0))
				for q in n + 1:
					var y: float = minf(tot, q * 6.0)
					pts.append(Vector2(9.5 + arc_dx(y, tot, ar), y))
				draw_polyline(pts, TBTokens.BZ_RULER if not TBTokens.is_hc() else TBHudParts.tk("rule_dark"), 1.0, false)
				var maj := PackedVector2Array(); var mnr := PackedVector2Array()
				for q in int(floor(tot / 8.0)) + 1:
					var o: float = 9.5 + arc_dx(q * 8.0, tot, ar)
					var l: float = 6.5 if q % 5 == 0 else 3.5
					if q % 5 == 0: maj.append(Vector2(o - l, q * 8.0)); maj.append(Vector2(o, q * 8.0))
					else: mnr.append(Vector2(o - l, q * 8.0)); mnr.append(Vector2(o, q * 8.0))
				for i2 in range(0, mnr.size() - 1, 2): draw_line(mnr[i2], mnr[i2 + 1], TBBezel.BRASS_LO, 1.0, false)
				for i3 in range(0, maj.size() - 1, 2): draw_line(maj[i3], maj[i3 + 1], TBBezel.BRASS, 1.0, false)

	var ruler_r: float = 560.0
	## how far right a rail point `y` (in a rail `h` tall) sits: a shallow circle bulging toward the map, zero at both ends
	static func arc_dx(y: float, h: float, ar: float = 560.0) -> float:
		var half: float = h * 0.5
		var t: float = clampf(y - half, -half, half)
		return sqrt(ar * ar - t * t) - sqrt(ar * ar - half * half)

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
	var year_phase: float = 0.5             # how far through the year (two turns a year: 0.5, then 1.0); the red arc and the hand
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
		var brass: Color = TBHudParts.tk("brass_lt")
		var rust: Color = TBHudParts.tk("neg_bar")
		var on: Color = TBHudParts.tk("cream")
		var face: Color = TBHudParts.tk("bar_2") if (hover and not dead) else TBHudParts.tk("bar_0")
		if state == S.OVER: on = TBHudParts.tk("ink_off")
		# attention: a slow 2 s glow ring
		if attention > 0 and state == S.IDLE:
			var k: float = 0.5 + 0.5 * sin(_t * TAU / 2.0) if _animated() else 0.6
			draw_arc(c, rad + 4.0 + 4.0 * k, 0.0, TAU, 48, TBHudParts.al(brass, 0.25 + 0.25 * k), 3.0, true)
		var cc: Vector2 = c + Vector2(0, oy)
		var fr: float = BZ.ring(self, cc, rad, 60, face, true, true)          # the End Turn dial keeps the heavy band
		var arc_r: float = fr - 5.0
		var phase: float = clampf(year_phase, 0.0, 1.0)
		draw_arc(cc, arc_r, 0.0, TAU, 48, TBHudParts.al(BZ.TRACK, 0.9), 2.6, true)
		if state == S.HINT:
			var left: float = hint_left if _animated() else 1.0
			draw_arc(cc, arc_r, -PI * 0.5, -PI * 0.5 + TAU * left, 40, brass, 3.0, true)
		elif state == S.BUSY or state == S.WAIT:
			var a0: float = _t * TAU / 1.1 if _animated() else 0.0
			draw_arc(cc, arc_r, a0, a0 + deg_to_rad(250.0 if not _animated() else 110.0), 28, brass, 3.0, true)
		elif state != S.OVER:
			draw_arc(cc, arc_r, -PI * 0.5, -PI * 0.5 + TAU * maxf(phase, 0.04), 40, rust, 2.8, true)
		# the hand: the calendar position, or a full turn while the turn resolves
		var ha: float = (_t * TAU / 1.6 if (state == S.BUSY and _animated()) else TAU * phase) - PI * 0.5
		var hd := Vector2(cos(ha), sin(ha))
		draw_line(cc + hd * (fr * 0.52), cc + hd * (fr - 3.0), rust, 2.0, true)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(-4.5, -rad + 3.0), cc + Vector2(4.5, -rad + 3.0), cc + Vector2(0, -rad + 10.0)]), rust)
		# content: the turn number, chevrons while seats pass
		var fb: Font = K.body_b()
		var z: int = TBHudParts.fs(24.0 if not (compact or narrow) else 20.0)
		if state == S.HINT:
			TBHudParts.chev(self, Vector2(cc.x - 3.0, cc.y), 16.0, on, 2.2); TBHudParts.chev(self, Vector2(cc.x + 6.0, cc.y), 16.0, on, 2.2)
		elif state == S.SEAT:
			var tt: String = seat_text if seat_text != "" else "›"
			draw_string(fb, Vector2(cc.x - TBHudParts.tw(fb, tt, z) * 0.5, TBHudParts.base(fb, z, cc.y)), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, z, on)
		else:
			var tt2: String = str(turn_no) if turn_no > 0 else ""
			if tt2 != "":
				var cf: Font = K.tracked(K.display(), 1)
				var tz: int = TBHudParts.fs(12.0)
				if not (compact or narrow):
					draw_string(cf, Vector2(cc.x - TBHudParts.tw(cf, "TURN", tz) * 0.5, TBHudParts.base(cf, tz, cc.y - fr * 0.42)), "TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, tz, TBHudParts.tk("smoke"))
				draw_string(fb, Vector2(cc.x - TBHudParts.tw(fb, tt2, z) * 0.5, TBHudParts.base(fb, z, cc.y + (fr * 0.12 if not (compact or narrow) else 0.0))), tt2, HORIZONTAL_ALIGNMENT_LEFT, -1, z, on)
			else:
				TBHudParts.chev(self, Vector2(cc.x - 3.0, cc.y), 18.0, on, 2.4); TBHudParts.chev(self, Vector2(cc.x + 7.0, cc.y), 18.0, on, 2.4)
		# label under the circle
		var f: Font = K.tracked(K.display(), 1)
		var fz: int = TBHudParts.fs(12.0)
		var cap: String = (caption.to_upper() if TBI18n.lang != "ru" else caption) if caption_inside else ""
		if cap != "":
			TBHudParts.txt_o(self, f, Vector2((size.x - TBHudParts.tw(f, cap, fz)) * 0.5, diameter() + 16.0), cap, fz, TBHudParts.tk("cream") if state != S.OVER else TBHudParts.tk("ink_off"))
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
				items = [[L.SELF_COL, T.call("leg_self")], [L.REL_COL[0], T.call("rel_peace")], [L.REL_COL[1], T.call("rel_war")], [L.REL_COL[2], T.call("rel_nap")], [L.REL_COL[3], T.call("rel_ally")], [L.REL_COL[4], T.call("rel_marriage")]]
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
