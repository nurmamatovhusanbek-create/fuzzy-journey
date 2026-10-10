## Bezel drawing primitives of the UI kit, ported from the HTML demo (docs/ui_variants/src/bezel.css, b_demo.html, bezel_kit.js).
## One logical unit = one demo design unit, so every number here is the demo's number (a 32 unit button, a 1 unit brass hairline, a 22 unit blur).
##   plate    the notched panel: soft drop shadow, 1 unit lo hairline, vertical gradient, 3 unit dark inset, faint brass line at 4 units (.plate / .pin)
##   notch    button plate: 1 unit rim + fill, notch 6 (.bt), states normal / hover / pressed / disabled, variants secondary / primary / danger
##   text     exact fractional font sizes and letter-spacing: drawn at 4x and scaled back (Godot font sizes are integers)
##   disc     radial-gradient discs (ring icons, steppers, slider thumbs)
## All colours come from TBTokens. In high contrast the gradients, shadows and brass lines are dropped (flat paper plate with a 2 unit border).
class_name TBBz
extends RefCounted

const K4 := 2                              # text is rasterised at 4x and drawn at 1/4 so sizes and spacing can be fractional
const SH_SIGMA := 11.0                     # drop-shadow(0 14px 22px rgba(0,0,0,.6)): a 22 px blur is a sigma of 11
const SH_DY := 14.0
const SH_ALPHA := 0.6
const SH_M := 36                           # nine-patch margin of the shadow texture (> 3 sigma)

# ---- small helpers ---------------------------------------------------------------------------------------------------------------
## notched rectangle (45 degree corners of k units) from (x0, y0) to (x1, y1)
static func notch(x0: float, y0: float, x1: float, y1: float, k: float) -> PackedVector2Array:
	if k <= 0.0: return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	k = minf(k, minf(x1 - x0, y1 - y0) * 0.5)
	return PackedVector2Array([Vector2(x0 + k, y0), Vector2(x1 - k, y0), Vector2(x1, y0 + k), Vector2(x1, y1 - k), Vector2(x1 - k, y1), Vector2(x0 + k, y1), Vector2(x0, y1 - k), Vector2(x0, y0 + k)])

static func _pc(col: Color) -> PackedColorArray:
	return PackedColorArray([col])

## vertex colours for a vertical gradient a (at y0) -> b (at y0 + h)
static func vgrad(pts: PackedVector2Array, y0: float, h: float, a: Color, b: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(pts.size())
	for i in pts.size(): out[i] = a.lerp(b, clampf((pts[i].y - y0) / maxf(h, 1.0), 0.0, 1.0))
	return out

static func poly(ci: RID, pts: PackedVector2Array, col: Color) -> void:
	if col.a <= 0.0: return
	RenderingServer.canvas_item_add_polygon(ci, pts, _pc(col))

static func poly_g(ci: RID, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_polygon(ci, pts, cols)

## 1 unit antialiased line along the diagonal (notch) edges of a notched rectangle: the polygon fill is aliased, this softens the chamfers
static func aa_diag(ci: RID, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[(i + 1) % n]
		if absf(a.x - b.x) > 0.01 and absf(a.y - b.y) > 0.01:
			RenderingServer.canvas_item_add_line(ci, a, b, col, 1.0, true)

static var _off := Vector2.ZERO            # the active shift(): TBBz.text() draws with its own scaled transform, so it adds this origin itself
static func shift(ci: RID, off: Vector2) -> void:
	_off = off
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, off))

static func unshift(ci: RID) -> void:
	_off = Vector2.ZERO
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)

## the demo's .dis / .bt.off: opacity .4 and saturate(.3 or .4), applied to a colour
static func dim(col: Color, sat: float = 0.4, alpha: float = 0.4) -> Color:
	var l: float = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
	return Color(l + (col.r - l) * sat, l + (col.g - l) * sat, l + (col.b - l) * sat, col.a * alpha)

static func mul_rgb(col: Color, k: float) -> Color:
	return Color(col.r * k, col.g * k, col.b * k, col.a)

# ---- drop shadow -----------------------------------------------------------------------------------------------------------------
static var _shadow: ImageTexture

static func _erf(x: float) -> float:
	var s: float = signf(x)
	x = absf(x)
	var t: float = 1.0 / (1.0 + 0.3275911 * x)
	var y: float = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return s * y

static func _phi(z: float) -> float:
	return 0.5 * (1.0 + _erf(z / 1.41421356))

## a rectangle blurred by a gaussian of sigma SH_SIGMA: nine-patch source (corners keep their size, the saturated middle stretches)
static func shadow_tex() -> ImageTexture:
	if _shadow != null: return _shadow
	var m: int = SH_M
	var l: int = 2 * m
	var t: int = l + 2 * m
	var prof := PackedFloat32Array()
	prof.resize(t)
	for i in t:
		var p: float = float(i) + 0.5
		prof[i] = _phi((p - m) / SH_SIGMA) - _phi((p - m - l) / SH_SIGMA)
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	for y in t:
		for x in t: img.set_pixel(x, y, TBTokens.with_a(Color.BLACK, SH_ALPHA * prof[x] * prof[y]))
	_shadow = ImageTexture.create_from_image(img)
	return _shadow

static func draw_shadow(ci: RID, w: float, h: float, dy: float = SH_DY, k: float = 1.0) -> void:
	var m: float = float(SH_M)
	var t: float = float(4 * SH_M)
	RenderingServer.canvas_item_add_nine_patch(ci, Rect2(-m, dy - m, w + 2.0 * m, h + 2.0 * m), Rect2(0, 0, t, t), shadow_tex().get_rid(), Vector2(m, m), Vector2(m, m),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, TBTokens.with_a(Color.WHITE, k))

# ---- plate -----------------------------------------------------------------------------------------------------------------------
## the demo's plate(): `.pw` drop shadow + `.plate` (lo fill, notch c) + `.pin` (margin 1px, notch c - 1, gradient, inset 3 dark, inset 4 faint brass).
## The pin's vertical margins collapse through the plate in CSS, so the lo hairline is only the 1 unit strip at the left and right edge (the notch edges
## coincide with the pin's): top, bottom and chamfers show the pin. rect is the outer box; c = 12 for panels, 8 / 6 for tags and tooltips
static func draw_plate(ci: RID, rect: Rect2, c: float = 12.0, shadow: bool = true) -> void:
	var w: float = roundf(rect.size.x); var h: float = roundf(rect.size.y)
	if w < 4.0 or h < 4.0: return
	shift(ci, rect.position.round())
	if TBTokens.is_hc():
		var o := notch(0, 0, w, h, c)
		poly(ci, o, TBTokens.c("paper_0"))
		var closed := o.duplicate(); closed.append(o[0])
		RenderingServer.canvas_item_add_polyline(ci, closed, _pc(TBTokens.c("rule")), 4.0, false)
		unshift(ci)
		return
	if shadow: draw_shadow(ci, w, h)
	var lo: Color = TBTokens.c("rule")
	var outer := notch(0, 0, w, h, c)
	poly(ci, outer, lo)
	var n: float = c - 1.0                                  # the pin's own notch
	var pin := notch(1, 0, w - 1, h, n)
	var top: Color = TBTokens.BZ_PLATE_TOP; var bot: Color = TBTokens.BZ_PLATE_BOT
	var ph: float = h
	poly(ci, pin, TBTokens.BZ_PLATE_BOT)                    # inset 3 px ring: #13100c
	# inset rectangles are clipped by the pin's diagonal: a rect inset by a has its corner cut by n - 2a
	var line := TBTokens.BZ_PLATE_LINE
	var p3 := notch(1.0 + 3.0, 3.0, w - 1.0 - 3.0, h - 3.0, maxf(n - 6.0, 0.0))
	var g3 := vgrad(p3, 0.0, ph, top, bot)
	for i in g3.size(): g3[i] = g3[i].lerp(Color(line.r, line.g, line.b, 1.0), line.a)
	poly_g(ci, p3, g3)
	var p4 := notch(1.0 + 4.0, 4.0, w - 1.0 - 4.0, h - 4.0, maxf(n - 8.0, 0.0))
	poly_g(ci, p4, vgrad(p4, 0.0, ph, top, bot))
	unshift(ci)

class Plate extends StyleBox:
	var cut := 12.0
	var shadow := true
	func _init(c: float = 12.0, sh: bool = true) -> void:
		cut = c; shadow = sh
		content_margin_left = 1.0; content_margin_right = 1.0          # the pin's 1 unit side margin
	func _draw(ci: RID, rect: Rect2) -> void:
		TBBz.draw_plate(ci, rect, cut, shadow)

static func plate_box(c: float = 12.0, shadow: bool = true) -> StyleBox:
	return Plate.new(c, shadow)

# ---- text ------------------------------------------------------------------------------------------------------------------------
## Godot font sizes are integers and letter-spacing is an integer, the demo's are fractional (11.5, .16em). So a string is shaped once at K4 times its size
## (kerning and fallbacks included), then each glyph is placed with an exact fractional pen and drawn at 1/K4 scale.
static var _shaped := {}
static var _bold := {}
## Chromium's text is a little heavier than Godot's at the same size (gamma, LCD filtering); a touch of outline embolden evens the weight out (units of stroke)
static var emb: float = 0.10 if OS.get_environment("TB_EMB") == "" else float(OS.get_environment("TB_EMB"))
static func _bf(base: Font, ksize: int) -> Font:
	if emb <= 0.0: return base
	var key := "%d|%d" % [base.get_instance_id(), ksize]
	if _bold.has(key): return _bold[key]
	var v := FontVariation.new()
	v.base_font = base; v.variation_embolden = emb * K4 * 24.0 / float(ksize)
	_bold[key] = v
	return v

static func _glyphs(base: Font, s: String, ksize: int) -> Array:
	var key := "%d|%d|%s" % [base.get_instance_id(), ksize, s]
	if _shaped.has(key): return _shaped[key]
	if _shaped.size() > 800: _shaped.clear()
	var tl := TextLine.new()
	tl.add_string(s, _bf(base, ksize), ksize)
	var out: Array = TextServerManager.get_primary_interface().shaped_text_get_glyphs(tl.get_rid()).duplicate(true)
	_shaped[key] = out
	return out

## width of a string in units: shaped advances plus the letter-spacing after every glyph (CSS also trails the last one)
static func tw(base: Font, s: String, size: float, spacing_px: float = 0.0) -> float:
	if s == "": return 0.0
	var gl := _glyphs(base, s, roundi(size * K4))
	var w := 0.0
	var n := 0
	for g in gl:
		var rep: int = maxi(int(g.get("repeat", 1)), 1)
		w += float(g["advance"]) * rep
		if float(g["advance"]) > 0.0: n += rep
	return w / K4 + n * spacing_px

static var _met := {}
## ascent / descent per 1000 of the font's OWN face (Font.get_ascent() takes the maximum over the fallbacks, which would make Cinzel as tall as Alegreya SC)
static func _metrics(base: Font) -> Vector2:
	var id: int = base.get_instance_id()
	if _met.has(id): return _met[id]
	var rids: Array[RID] = base.get_rids()
	var ts := TextServerManager.get_primary_interface()
	var v := Vector2(ts.font_get_ascent(rids[0], 1000), ts.font_get_descent(rids[0], 1000)) if not rids.is_empty() else Vector2(base.get_ascent(1000), base.get_descent(1000))
	_met[id] = v
	return v
static func ascent(base: Font, size: float) -> float: return _metrics(base).x * size / 1000.0
static func descent(base: Font, size: float) -> float: return _metrics(base).y * size / 1000.0

## text with its baseline-left corner at p (units, in the item's own space)
static func text(ci: RID, base: Font, p: Vector2, s: String, size: float, col: Color, spacing_px: float = 0.0) -> void:
	if s == "": return
	var ks: int = roundi(size * K4)
	var gl := _glyphs(base, s, ks)
	var ts := TextServerManager.get_primary_interface()
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(Vector2(1.0 / K4, 0.0), Vector2(0.0, 1.0 / K4), p + _off))
	var pen := 0.0
	for g in gl:
		var rep: int = maxi(int(g.get("repeat", 1)), 1)
		for r in rep:
			if int(g["index"]) != 0 or float(g["advance"]) > 0.0:
				ts.font_draw_glyph(g["font_rid"], ci, int(g["font_size"]), Vector2(pen, 0.0) + Vector2(g["offset"]), int(g["index"]), col)
			pen += float(g["advance"]) + (spacing_px * K4 if float(g["advance"]) > 0.0 else 0.0)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, _off))

## baseline y that centres a line box of `line` units (CSS line-height) in [top, top + h], the way Chromium lays out a flex row:
## ascent and descent are rounded, the half-leading is added to the ascent and floored, the result is snapped to a whole unit
static func baseline(base: Font, size: float, top: float, h: float, line: float = -1.0) -> float:
	var a: float = roundf(ascent(base, size)); var d: float = roundf(descent(base, size))
	var lh: float = line if line > 0.0 else a + d
	return roundf(top + (h - lh) * 0.5 + floorf(a + (lh - (a + d)) * 0.5))

# ---- discs and rings -------------------------------------------------------------------------------------------------------------
## filled circle with a radial gradient c0 (at `hot`) -> c1 (at distance rmax from hot); a triangle fan from the hot point
static func disc(ci: RID, c: Vector2, r: float, hot: Vector2, c0: Color, c1: Color, rmax: float, n: int = 48) -> void:
	var pts := PackedVector2Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	pts.append(hot); cols.append(c0)
	for i in n:
		var a: float = TAU * i / n
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
		pts.append(p); cols.append(c0.lerp(c1, clampf(p.distance_to(hot) / rmax, 0.0, 1.0)))
	for i in n:
		idx.append(0); idx.append(1 + i); idx.append(1 + (i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)
	RenderingServer.canvas_item_add_polyline(ci, _closed_circle(c, r - 0.5, n), PackedColorArray([cols[1]]), 1.0, true)

static func _closed_circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a: float = TAU * i / n
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p

## width of an antialiased line that looks like a `w` unit stroke: Godot feathers a line by about half a unit on each side
static func aaw(w: float) -> float: return maxf(w - 0.55, 0.35) if w < 4.0 else w - 0.45
## colour of a hairline thinner than one unit: coverage becomes opacity (a 0.7 unit stroke is a 1 unit line at .7)
static func thin(col: Color, w: float) -> Color: return TBTokens.with_a(col, col.a * w) if w < 1.0 else col

## ring (stroke) of width w whose outer edge is at radius r_out
static func ring_stroke(ci: RID, c: Vector2, r_out: float, w: float, col: Color) -> void:
	RenderingServer.canvas_item_add_polyline(ci, _closed_circle(c, r_out - w * 0.5, 64), PackedColorArray([thin(col, w)]), aaw(w), true)

## `.ring`: the header icon medallion. box d (46 in headers): radial face, brass hairline 1.3 outside it, 3 unit dark shade under that
static func ring_face(ci: RID, c: Vector2, d: float, hot_k: bool = true) -> void:
	var r: float = d * 0.5
	if TBTokens.is_hc():
		disc(ci, c, r, c, TBTokens.c("paper_1"), TBTokens.c("paper_1"), r)
		ring_stroke(ci, c, r + 2.0, 2.0, TBTokens.c("ink_0"))
		return
	ring_stroke(ci, c, r + 3.0, 3.0, TBTokens.BZ_SHADE)
	ring_stroke(ci, c, r + 1.3, 1.3, TBTokens.with_a(TBTokens.c("brass"), 0.85))
	var hot := c + Vector2(d * (0.38 - 0.5), d * (0.32 - 0.5))
	var far: float = hot.distance_to(c + Vector2(d * 0.5, d * 0.5))
	disc(ci, c, r, hot, TBTokens.BZ_FACE_A, TBTokens.BZ_FACE_B, far)

## `.xbtn` / `.stp`: a plain round button: #0f0c09 face and a 1.5 unit ring outside it
static func round_btn(ci: RID, c: Vector2, d: float, ring_col: Color, hot: bool = false) -> void:
	var r: float = d * 0.5
	if TBTokens.is_hc():
		disc(ci, c, r, c, TBTokens.c("paper_1"), TBTokens.c("paper_1"), r)
		ring_stroke(ci, c, r + 2.0, 2.0, TBTokens.c("ink_0"))
		return
	ring_stroke(ci, c, r + 1.5, 1.5, ring_col)
	disc(ci, c, r, c, TBTokens.BZ_FACE_B, TBTokens.BZ_FACE_B, r)

# ---- notched button plate ---------------------------------------------------------------------------------------------------------
enum V { SEC, PRI, DNG }

## colours of a button variant and state: {tx, lo, a, b} (fill gradient a -> b; equal for flat fills)
static func btn_colors(variant: int, hot: bool) -> Dictionary:
	match variant:
		V.PRI:
			if hot: return {"tx": TBTokens.BZ_PRI_TX, "lo": TBTokens.BZ_HI, "a": TBTokens.BZ_PRI_HA, "b": TBTokens.BZ_PRI_HB}
			return {"tx": TBTokens.BZ_PRI_TX, "lo": TBTokens.BZ_PRI_B, "a": TBTokens.BZ_PRI_A, "b": TBTokens.BZ_PRI_B}
		V.DNG:
			if hot: return {"tx": TBTokens.BZ_WHITE, "lo": TBTokens.BZ_DNG_LO_HOT, "a": TBTokens.BZ_DNG_HA, "b": TBTokens.BZ_DNG_HB}
			return {"tx": TBTokens.BZ_DNG_TX, "lo": TBTokens.BZ_DNG_B, "a": TBTokens.BZ_DNG_A, "b": TBTokens.BZ_DNG_B}
	if hot: return {"tx": TBTokens.BZ_WHITE, "lo": TBTokens.c("brass"), "a": TBTokens.BZ_BTN_FILL_HOT, "b": TBTokens.BZ_BTN_FILL_HOT}
	return {"tx": TBTokens.c("brass_lt"), "lo": TBTokens.c("rule"), "a": TBTokens.BZ_BTN_FILL, "b": TBTokens.BZ_BTN_FILL}

static func btn_colors_hc(variant: int, hot: bool) -> Dictionary:
	match variant:
		V.PRI: return {"tx": TBTokens.c("on_act"), "lo": TBTokens.c("act_rim"), "a": TBTokens.c("act_hover" if hot else "act"), "b": TBTokens.c("act_hover" if hot else "act")}
		V.DNG: return {"tx": TBTokens.c("on_wax"), "lo": TBTokens.c("wax_rim"), "a": TBTokens.c("wax_hover" if hot else "wax"), "b": TBTokens.c("wax_hover" if hot else "wax")}
	return {"tx": TBTokens.c("ink_0"), "lo": TBTokens.c("ink_0"), "a": TBTokens.c("paper_hover" if hot else "paper_1"), "b": TBTokens.c("paper_hover" if hot else "paper_1")}

## `.bt`: rim polygon (notch 6) with the fill 1 unit inside it (notch 5). pressed = the fill goes brightness(.85), off = opacity .4 + saturate(.4)
static func draw_notch(ci: RID, w: float, h: float, variant: int, hot: bool, pressed: bool, off: bool, k: float = 6.0) -> Dictionary:
	var col: Dictionary = btn_colors_hc(variant, hot) if TBTokens.is_hc() else btn_colors(variant, hot)
	var lo: Color = col["lo"]; var a: Color = col["a"]; var b: Color = col["b"]
	if pressed: a = mul_rgb(a, 0.85); b = mul_rgb(b, 0.85)
	if off: lo = dim(lo); a = dim(a); b = dim(b)
	var bw: float = 2.0 if TBTokens.is_hc() else 1.0
	var o := notch(0, 0, w, h, k)
	var i := notch(bw, bw, w - bw, h - bw, k - bw)
	for s in 8:                                                  # rim: the eight quads between the two octagons (no overlap, so opacity stays exact)
		var t: int = (s + 1) % 8
		poly(ci, PackedVector2Array([o[s], o[t], i[t], i[s]]), lo)
	poly_g(ci, i, vgrad(i, bw, h - 2.0 * bw, a, b))
	return col

## keyboard focus ring of a notched control: 2 unit ring 3 units outside the plate (outline: 2px solid var(--hi); outline-offset: 3px)
static func draw_notch_focus(ci: RID, w: float, h: float, k: float = 6.0) -> void:
	var d: float = 4.0                                           # 3 offset + half of the 2 unit stroke
	var o := notch(-d, -d, w + d, h + d, k + 0.5858 * d)
	var closed := o.duplicate(); closed.append(o[0])
	RenderingServer.canvas_item_add_polyline(ci, closed, _pc(TBTokens.c("brass_lt") if not TBTokens.is_hc() else TBTokens.c("ink_0")), 2.0, true)

class Notch extends StyleBox:
	var variant := 0
	var hot := false
	var pressed := false
	var off := false
	var k := 6.0
	func _init(v: int = 0, hot_: bool = false, pressed_: bool = false, off_: bool = false, notch_: float = 6.0) -> void:
		variant = v; hot = hot_; pressed = pressed_; off = off_; k = notch_
	func _draw(ci: RID, rect: Rect2) -> void:
		TBBz.shift(ci, rect.position.round() + (Vector2(0, 1) if pressed else Vector2.ZERO))
		TBBz.draw_notch(ci, roundf(rect.size.x), roundf(rect.size.y), variant, hot, pressed, off, k)
		TBBz.unshift(ci)

# ---- button control ----------------------------------------------------------------------------------------------------------------
## `.bt`: 32 units tall (28 small), padding 14 (11), gap 7 (6), Cinzel 700 11.5 (10.5) tracked .16em, notch 6. Text is drawn here at its exact fractional size.
## Optional demo icon before the label, a dim `sub` (Alegreya 12 at .6) and a keycap after it. The hit area is the plate plus 5 units (.bt::after{inset:-5px}).
## Long labels that must wrap (autowrap_mode set by the caller) fall back to the theme's own text.
class Btn extends Button:
	var variant := 0
	var small := false
	var glyph := ""                  # demo icon id (or an old glyph name) drawn before the label
	var glyph_px := 16.0
	var sub := ""
	var kbd := ""
	var preview_state := ""          # "hover" / "pressed" / "focus": freezes a state for specimen sheets and tests
	var hold := 0.0                  # hold-to-confirm progress 0..1: a white .28 wash grows from the left (.bt .fill)
	var _key := ""
	var _native := false
	var legacy := false              # title screen: behave as a plain themed Button
	func _init(txt: String = "", v: int = 0, sm: bool = false) -> void:
		variant = v; small = sm; text = txt
		focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		_hide_native()
		_refit()
	func make_legacy() -> void:
		legacy = true
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: remove_theme_stylebox_override(st)
		remove_theme_font_size_override("font_size")
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]: remove_theme_color_override(fc)
		custom_minimum_size = Vector2(96, TBKit.touch())
		size_flags_vertical = Control.SIZE_FILL
	func _hide_native() -> void:
		add_theme_font_size_override("font_size", 1)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(fc, Color.TRANSPARENT)
	func _go_native() -> void:
		_native = true
		custom_minimum_size = Vector2(0.0, 0.0)
		var f: Font = TBKit.tracked(TBKit.cinzel(700), 2)
		add_theme_font_override("font", f); add_theme_font_size_override("font_size", TBKit.fs(12))
		var tx: Color = _col(false)["tx"]
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: add_theme_color_override(fc, tx)
		add_theme_color_override("font_disabled_color", TBBz.dim(tx))
		var states := {"normal": [false, false, false], "hover": [true, false, false], "pressed": [true, true, false], "hover_pressed": [true, true, false], "disabled": [false, false, true]}
		for st in states:
			var a: Array = states[st]
			var sb := TBBz.Notch.new(variant, a[0], a[1], a[2])
			sb.content_margin_left = 14.0; sb.content_margin_right = 14.0; sb.content_margin_top = 4.0; sb.content_margin_bottom = 4.0
			add_theme_stylebox_override(st, sb)
		queue_redraw()
	func _col(hot: bool) -> Dictionary:
		return TBBz.btn_colors_hc(variant, hot) if TBTokens.is_hc() else TBBz.btn_colors(variant, hot)
	func fsz() -> float: return TBKit.fsf(10.5 if small else 11.5)
	func _h() -> float:
		var base: float = 28.0 if small else 32.0
		var want: float = maxf(base, ceilf(fsz() + (16.0 if small else 18.0)))
		return maxf(want, float(TBKit.touch()) if TBKit.touch_large else 0.0)
	func _items() -> Dictionary:
		var f: Font = TBKit.cinzel(700)
		var s: float = fsz()
		var d := {"font": f, "size": s, "sp": TBKit.trk(s, 0.16), "gap": 6.0 if small else 7.0, "padx": 11.0 if small else 14.0}
		d["tw"] = TBBz.tw(f, text, s, d["sp"])
		d["icon"] = (glyph_px * (0.75 if small and glyph_px >= 16.0 else 1.0)) if glyph != "" else 0.0
		var sf: float = TBKit.fsf(12.0)
		d["sub_w"] = TBBz.tw(TBKit.alegreya(700), sub, sf, 0.0) if sub != "" else 0.0
		var kf: float = TBKit.fsf(10.5)
		d["kbd_w"] = (TBBz.tw(TBKit.jbm(), kbd, kf, 0.0) + 10.0) if kbd != "" else 0.0
		var n := 0
		var total := 0.0
		for k in ["icon", "tw", "sub_w", "kbd_w"]:
			if float(d[k]) > 0.0:
				n += 1; total += float(d[k])
		d["content"] = total + float(maxi(n - 1, 0)) * float(d["gap"])
		return d
	func _mk_key() -> String:
		return "%s|%s|%s|%s|%d|%f" % [text, glyph, sub, kbd, int(small), TBKit.text_scale]
	func _refit() -> void:
		var d := _items()
		_key = _mk_key()
		var minw: float = float(d["content"]) + 2.0 * float(d["padx"])
		custom_minimum_size = Vector2(minw if not _native else 0.0, _h())
	func _has_point(p: Vector2) -> bool:
		return Rect2(-5.0, -5.0, size.x + 10.0, size.y + 10.0).has_point(p)
	func _draw() -> void:
		if legacy: return
		if _mk_key() != _key: _refit()
		if autowrap_mode != TextServer.AUTOWRAP_OFF and not _native:
			_go_native.call_deferred()
			return
		var ci := get_canvas_item()
		var mode := get_draw_mode()
		if preview_state == "hover": mode = BaseButton.DRAW_HOVER
		elif preview_state == "pressed": mode = BaseButton.DRAW_PRESSED
		var off: bool = disabled
		var hot: bool = (mode == BaseButton.DRAW_HOVER or mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED) and not off
		var prs: bool = (mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED) and not off
		var w: float = roundf(size.x)
		var h: float = roundf(size.y)
		if _native:
			if has_focus() and TBFrame.kbd_nav: TBBz.draw_notch_focus(ci, w, h)
			return                                                   # the theme styleboxes draw the plate and the text
		TBBz.shift(ci, Vector2(0, 1) if prs else Vector2.ZERO)
		var col: Dictionary = TBBz.draw_notch(ci, w, h, variant, hot, prs, off)
		if hold > 0.0 and not off:
			var clip := Geometry2D.intersect_polygons(TBBz.notch(1, 1, w - 1, h - 1, 5.0), PackedVector2Array([Vector2(0, 0), Vector2(w * hold, 0), Vector2(w * hold, h), Vector2(0, h)]))
			for pg in clip: TBBz.poly(ci, pg, TBTokens.with_a(Color.WHITE, 0.28))
		var d := _items()
		var tx: Color = col["tx"]
		if off: tx = TBBz.dim(tx)
		var x: float = (w - float(d["content"])) * 0.5
		if float(d["icon"]) > 0.0:
			TBBz.unshift(ci)
			TBGlyph.draw_ic(self, glyph, Vector2(x + float(d["icon"]) * 0.5, h * 0.5 + (1.0 if prs else 0.0)), float(d["icon"]), tx)
			TBBz.shift(ci, Vector2(0, 1) if prs else Vector2.ZERO)
			x += float(d["icon"]) + float(d["gap"])
		var f: Font = d["font"]
		TBBz.text(ci, f, Vector2(x, TBBz.baseline(f, d["size"], 0, h, d["size"])), text, d["size"], tx, d["sp"])
		x += float(d["tw"]) + float(d["gap"])
		if sub != "":
			var sf: float = TBKit.fsf(12.0)
			var af: Font = TBKit.alegreya(700)
			TBBz.text(ci, af, Vector2(x, roundf(TBBz.baseline(af, sf, 0, h))), sub, sf, TBTokens.with_a(tx, tx.a * 0.6))
			x += float(d["sub_w"]) + float(d["gap"])
		if kbd != "":
			var kf: float = TBKit.fsf(10.5)
			var jf: Font = TBKit.jbm()
			var kw: float = float(d["kbd_w"])
			var kh: float = ceilf(kf * 1.32) + 2.0
			var kc: Color = TBTokens.with_a(tx, tx.a * 0.7)
			_outline(ci, Rect2(x + 0.5, (h - kh) * 0.5 + 0.5, kw - 1.0, kh - 1.0), kc)
			TBBz.text(ci, jf, Vector2(x + 5.0, roundf(TBBz.baseline(jf, kf, (h - kh) * 0.5 + 1.0, kh - 2.0))), kbd, kf, kc)
		TBBz.unshift(ci)
		if (has_focus() and TBFrame.kbd_nav) or preview_state == "focus": TBBz.draw_notch_focus(ci, w, h)
	func _outline(ci: RID, r: Rect2, c: Color) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([c]), 1.0, false)

# ---- tracked text label --------------------------------------------------------------------------------------------------------------
## A Label (so every caller keeps working: .text, alignment, colour overrides, size flags) whose text is drawn by TBBz.text at the demo's exact fractional size and
## letter-spacing. The native text is hidden (visible_characters = 0, font size 1); the label's minimum size is the exact text width x the CSS line box.
## Wrapping (autowrap_mode) falls back to the native Label so long text still wraps.
class TLabel extends Label:
	var face: Font
	var px := 12.0                   # size in units at text scale 1
	var em := 0.0                    # letter-spacing in em
	var lh := 0.0                    # CSS line-height in units (0 = the font's own line)
	var upper := false               # text-transform: uppercase (not for Cyrillic / Readable fonts)
	var base_y := -1.0               # fixed baseline (units from the label's top) for rows that align several faces on one baseline
	var _key := ""
	var _lastw := -1.0
	var wrap_ok := false              # wrap onto several lines (native text) only when the single line does not fit
	var _native := false
	func _init(f: Font, size_px: float, spacing_em: float, line_h: float = 0.0, caps: bool = false) -> void:
		face = f; px = size_px; em = spacing_em; lh = line_h; upper = caps
		visible_characters = 0
		add_theme_font_size_override("font_size", 1)
		add_theme_font_override("font", TBKit.body())
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _t() -> String:
		return text.to_upper() if (upper and TBI18n.lang != "ru" and not TBKit.readable_fonts) else text
	func fsz() -> float: return TBKit.fsf(px)
	func spacing() -> float: return TBKit.trk(fsz(), em)
	func line_h() -> float:
		if lh > 0.0: return lh * TBKit.text_scale
		return roundf(TBBz.ascent(face, fsz())) + roundf(TBBz.descent(face, fsz()))
	func exact_w() -> float: return TBBz.tw(face, _t(), fsz(), spacing())
	func _mk() -> String: return "%s|%f|%d" % [text, TBKit.text_scale, int(upper)]
	func refit() -> void:
		_key = _mk()
		if autowrap_mode != TextServer.AUTOWRAP_OFF:
			_to_native(); return
		var w: float = exact_w()
		var cur: float = custom_minimum_size.x
		var nx: float = w if (_lastw < 0.0 or is_equal_approx(cur, _lastw)) else cur
		_lastw = w
		custom_minimum_size = Vector2(nx, line_h())
	func _to_native() -> void:
		if _native: return
		_native = true
		visible_characters = -1
		if upper: text = _t()
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap_ok else autowrap_mode
		var base: Font = TBBz.fvar_int(face, spacing())
		add_theme_font_override("font", base); add_theme_font_size_override("font_size", roundi(fsz()))
		custom_minimum_size.y = 0.0
	func _draw() -> void:
		if _native: return
		if _mk() != _key: refit()
		if autowrap_mode != TextServer.AUTOWRAP_OFF:
			_to_native(); queue_redraw.call_deferred(); return
		var s: String = _t()
		if s == "": return
		if wrap_ok and autowrap_mode == TextServer.AUTOWRAP_OFF and size.x >= 40.0 and exact_w() > size.x + 0.5:
			_to_native(); queue_redraw.call_deferred(); return
		var f := face
		var z: float = fsz(); var sp: float = spacing()
		var avail: float = size.x
		var w: float = TBBz.tw(f, s, z, sp)
		if w > avail + 0.5 and text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var t := s
			while t.length() > 1 and TBBz.tw(f, t + "…", z, sp) > avail: t = t.substr(0, t.length() - 1)
			s = t + "…"; w = TBBz.tw(f, s, z, sp)
		var x := 0.0
		if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x = (avail - w) * 0.5
		elif horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x = avail - w
		var bl: float = base_y if base_y >= 0.0 else TBBz.baseline(f, z, 0.0, size.y, line_h())
		TBBz.text(get_canvas_item(), f, Vector2(x, bl), s, z, get_theme_color("font_color"), sp)

static var _fvi := {}
## integer-spaced face for native text (wrapping fallbacks)
static func fvar_int(base: Font, spacing_px: float) -> Font:
	var sp: int = roundi(spacing_px)
	if sp == 0: return base
	var key := "%d:%d" % [base.get_instance_id(), sp]
	if _fvi.has(key): return _fvi[key]
	var v := FontVariation.new()
	v.base_font = base; v.spacing_glyph = sp
	_fvi[key] = v
	return v

# ---- ticks, brass disc, focus ring at a rect ---------------------------------------------------------------------------------------
## tickMarks() of the demo kit for a full circle: n marks starting at the top, every `major`-th 1.7x longer, drawn inwards from radius r
static func ticks(ci: RID, c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = deg_to_rad(360.0 * i / n)
		var l: float = len_px * (1.7 if i % major == 0 else 1.0)
		pts.append(c + Vector2(sin(a), -cos(a)) * r); pts.append(c + Vector2(sin(a), -cos(a)) * (r - l))
	RenderingServer.canvas_item_add_multiline(ci, pts, PackedColorArray([thin(col, w)]), aaw(w), true)

## tickMarks() over an arc: a0 / span in degrees from the top, clockwise; n + 1 marks
static func ticks_arc(ci: RID, c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float, a0: float, span: float) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = deg_to_rad(a0 + span * i / n)
		var l: float = len_px * (1.7 if i % major == 0 else 1.0)
		pts.append(c + Vector2(sin(a), -cos(a)) * r); pts.append(c + Vector2(sin(a), -cos(a)) * (r - l))
	RenderingServer.canvas_item_add_multiline(ci, pts, PackedColorArray([thin(col, w)]), aaw(w), true)

## gBrass: the diagonal brass gradient (#EBCF85 -> #B38F3E -> #6F5A27) of a disc; the colour is affine in position so a fan from the centre is exact
static func brass_disc(ci: RID, c: Vector2, r: float, n: int = 48) -> void:
	var a: Color = TBTokens.BZ_PRI_A; var b: Color = TBTokens.BZ_PRI_B; var z: Color = TBTokens.BZ_BRASS_Z
	var pts := PackedVector2Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	pts.append(c); cols.append(b)
	for i in n:
		var ang: float = TAU * i / n
		var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * r
		var t: float = clampf(((p.x - (c.x - r)) + (p.y - (c.y - r))) / (4.0 * r), 0.0, 1.0)
		pts.append(p); cols.append(a.lerp(b, t * 2.0) if t < 0.5 else b.lerp(z, (t - 0.5) * 2.0))
	for i in n:
		idx.append(0); idx.append(1 + i); idx.append(1 + (i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)

static func draw_notch_focus_at(ci: RID, r: Rect2, k: float = 6.0) -> void:
	shift(ci, r.position)
	draw_notch_focus(ci, r.size.x, r.size.y, k)
	unshift(ci)

# ---- engraved well (cards) ---------------------------------------------------------------------------------------------------------
## `background:#100d0a; box-shadow:inset 0 0 0 1px <line>`: the square card of the decrees / goals / event screens; high contrast: paper plate with a 2 unit rule
class Well extends StyleBox:
	var line := Color.TRANSPARENT
	var fill := Color.TRANSPARENT
	func _init(line_col: Color, pad_x: float = 12.0, pad_y: float = 10.0, fill_col: Color = Color.TRANSPARENT) -> void:
		line = line_col; fill = fill_col if fill_col.a > 0.0 else TBTokens.BZ_WELL
		content_margin_left = pad_x; content_margin_right = pad_x; content_margin_top = pad_y; content_margin_bottom = pad_y
	func _draw(ci: RID, rect: Rect2) -> void:
		var w: float = roundf(rect.size.x)
		var h: float = roundf(rect.size.y)
		TBBz.shift(ci, rect.position.round())
		var hc: bool = TBTokens.is_hc()
		var bw: float = 2.0 if hc else 1.0
		TBBz.poly(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), TBTokens.c("paper_1") if hc else line)
		TBBz.poly(ci, PackedVector2Array([Vector2(bw, bw), Vector2(w - bw, bw), Vector2(w - bw, h - bw), Vector2(bw, h - bw)]), TBTokens.c("paper_1") if hc else fill)
		if hc: RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2(1, 1), Vector2(w - 1, 1), Vector2(w - 1, h - 1), Vector2(1, h - 1), Vector2(1, 1)]), PackedColorArray([line]), 2.0, false)
		TBBz.unshift(ci)

static func well_box(line_col: Color, pad_x: float = 12.0, pad_y: float = 10.0) -> StyleBox:
	return Well.new(line_col, pad_x, pad_y)

## a segmented-control cell as the demo's small button (`.bt.sm`, the selected one `.pri`): notched plate styleboxes, Cinzel 10.5 tracked text in capitals
static func style_cell(b: Button, on: bool) -> void:
	var v: int = V.PRI if on else V.SEC
	var sts := {"normal": [false, false], "hover": [true, false], "pressed": [true, true], "hover_pressed": [true, true]}
	for st in sts:
		var sb := Notch.new(v, sts[st][0], sts[st][1], false)
		sb.content_margin_left = 11.0; sb.content_margin_right = 11.0; sb.content_margin_top = 4.0; sb.content_margin_bottom = 4.0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", TBKit._empty)
	var c0: Dictionary = btn_colors_hc(v, false) if TBTokens.is_hc() else btn_colors(v, false)
	var c1: Dictionary = btn_colors_hc(v, true) if TBTokens.is_hc() else btn_colors(v, true)
	for fc in ["font_color", "font_focus_color"]: b.add_theme_color_override(fc, c0["tx"])
	for fc in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(fc, c1["tx"])
	b.add_theme_font_override("font", TBKit.tracked(TBKit.cinzel(700), 2)); b.add_theme_font_size_override("font_size", TBKit.fs(10.5))
	if not b.has_meta("raw"):
		b.set_meta("raw", b.text); b.text = TBKit._cap(b.text)
	b.tooltip_text = ""
	TBKit.a11y(b, String(b.get_meta("raw")), "option", TBI18n.T("a11y_selected") if on else "")
	b.queue_redraw()
