## Bezel kit parts built on TBBz, each a port of one block of the demo (docs/ui_variants/src/bezel.css + b_demo.html):
##   FxRow    `.x2`   leader row: italic caption ...... bold figure          Mark   `.mk` / `.chip`  engraved diamond + italic text
##   RowBox   `.row`  hover / selected row with the 3 unit brass bar          Slider `.slr` + `.stp`   track, hatched zone, ticks, thumb, numerals, steppers
##   Tbl      `.tbl`  ledger table                                           Tip    `#tip`   tooltip plate
##   Notice   `.tz`   notice: instrument medallion on a notched plate         Gauge  gaugeSvg  270 degree arc gauge
## Everything honours the text scale, Readable fonts (no tracking / caps) and high contrast (flat colours, no gradients). K.* in ui_kit.gd are the entry points.
class_name TBBzParts
extends RefCounted

## rounded rectangle polygon (corner radius r, `seg` points per corner)
static func rrect(x0: float, y0: float, x1: float, y1: float, r: float, seg: int = 6) -> PackedVector2Array:
	var p := PackedVector2Array()
	r = minf(r, minf(x1 - x0, y1 - y0) * 0.5)
	var cs := [[x1 - r, y0 + r, -PI * 0.5], [x1 - r, y1 - r, 0.0], [x0 + r, y1 - r, PI * 0.5], [x0 + r, y0 + r, PI]]
	for c in cs:
		for i in seg + 1:
			var a: float = float(c[2]) + (PI * 0.5) * i / seg
			p.append(Vector2(float(c[0]) + cos(a) * r, float(c[1]) + sin(a) * r))
	return p

## a soft round shadow / glow: stacked discs approximating a gaussian of `sigma` around radius r
static func soft_disc(ci: RID, c: Vector2, r: float, sigma: float, col: Color) -> void:
	var n := 8
	for k in n:
		var rad: float = r + sigma * (2.0 - 3.5 * (k + 0.5) / n)
		if rad <= 0.5: continue
		var pts := PackedVector2Array()
		for i in 40: pts.append(c + Vector2(cos(TAU * i / 40.0), sin(TAU * i / 40.0)) * rad)
		TBBz.poly(ci, pts, TBTokens.with_a(col, col.a / n * 1.15))

# =====================================================================================================================================
## `.x2`: padding 2 0, italic 16 dim caption, 2 unit dotted leader (margin 0 8, raised 4), bold 18 figure in the tone colour. 28 units tall.
class Leader extends Control:
	var base_y := 20.0
	func _init(by: float) -> void:
		base_y = by; size_flags_horizontal = Control.SIZE_EXPAND_FILL; custom_minimum_size = Vector2(28, 0); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var col: Color = TBTokens.BZ_DOTS if not TBTokens.is_hc() else TBTokens.c("ink_1")
		var y: float = base_y - 6.0
		var x := 8.0
		while x + 2.0 <= size.x - 8.0 + 0.01:
			draw_rect(Rect2(x, y, 2, 2), col)
			x += 4.0

class FxRow extends HBoxContainer:
	var cap: TBBz.TLabel
	var val: TBBz.TLabel
	func _init(caption: String, value: String, col: Color, extra: Control = null) -> void:
		add_theme_constant_override("separation", 0)
		var vf: Font = TBKit.alegreya(700)
		var av: float = roundf(TBBz.ascent(vf, TBKit.fsf(18.0))); var dv: float = roundf(TBBz.descent(vf, TBKit.fsf(18.0)))
		custom_minimum_size.y = 4.0 + av + dv
		var by: float = 2.0 + av
		cap = TBBz.TLabel.new(TBKit.alegreya(400), 16.0, 0.0)             # `.x2 em` is italic in its font shorthand but font-style:normal wins
		cap.base_y = by; cap.text = caption; cap.size_flags_vertical = Control.SIZE_FILL
		cap.add_theme_color_override("font_color", TBKit.DIM)
		if TBKit.text_scale >= 1.4:                    # large text in a narrow column: the caption wraps instead of pushing the panel wider
			cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cap.custom_minimum_size.x = 40; cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(cap)
		var ld := Leader.new(by); ld.size_flags_vertical = Control.SIZE_FILL
		add_child(ld)
		if extra != null: add_child(extra)
		if value != "":
			val = TBBz.TLabel.new(vf, 18.0, 0.0)
			val.base_y = by; val.text = value; val.size_flags_vertical = Control.SIZE_FILL
			val.add_theme_color_override("font_color", col)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			add_child(val)
		else:
			ld.visible = false

# =====================================================================================================================================
## `.mk` / `.chip`: no capsule, an engraved diamond (7 units, turned 45 degrees) in the tone colour, then the text in italic 15.5. `hollow` = outline only (neutral, zero).
class Mark extends Control:
	var txt := ""
	var col := Color.WHITE
	var hollow := false
	var ink := Color.TRANSPARENT
	func _init(t: String, c: Color, hol: bool = false, ink_c: Color = Color.TRANSPARENT) -> void:
		txt = t; col = c; hollow = hol; ink = ink_c
		mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = _msize()
	func _f() -> Font: return TBKit.alegreya(400, true)
	func _sz() -> float: return TBKit.fsf(15.5)
	func _lh() -> float: return roundf(TBBz.ascent(_f(), _sz())) + roundf(TBBz.descent(_f(), _sz()))
	func _msize() -> Vector2: return Vector2(15.0 + TBBz.tw(_f(), txt, _sz()), _lh())
	func _draw() -> void:
		var ci := get_canvas_item()
		var c := Vector2(3.5, size.y * 0.5)
		var h: float = 4.95
		var o := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		if not hollow: TBBz.poly(ci, o, col)
		else:
			var hi: float = 4.95 - 1.5 * 1.4142
			var i := PackedVector2Array([c + Vector2(0, -hi), c + Vector2(hi, 0), c + Vector2(0, hi), c + Vector2(-hi, 0)])
			for s in 4: TBBz.poly(ci, PackedVector2Array([o[s], o[(s + 1) % 4], i[(s + 1) % 4], i[s]]), col)
		var tc: Color = ink if ink.a > 0.0 else TBTokens.c("ink_0")
		TBBz.text(ci, _f(), Vector2(15.0, TBBz.baseline(_f(), _sz(), 0.0, size.y, _lh())), txt, _sz(), tc)

# =====================================================================================================================================
## `.row`: padding 10 12, radius 3; hover wash rgba(brass, .08), selected wash .15 plus a 3 unit brass bar on the left. Free-form content, one signal.
class RowBox extends PanelContainer:
	signal activated
	var selected := false:
		set(v): selected = v; queue_redraw()
	var preview_state := "":
		set(v): preview_state = v; queue_redraw()
	var interactive := true
	var _hover := false
	var _down := false
	func _init(pad_x: float = 12.0, pad_y: float = 10.0, cb: Callable = Callable()) -> void:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = pad_x; sb.content_margin_right = pad_x; sb.content_margin_top = pad_y; sb.content_margin_bottom = pad_y
		add_theme_stylebox_override("panel", sb)
		focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cb.is_valid(): activated.connect(cb)
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; _down = false; queue_redraw())
	func _draw() -> void:
		var ci := get_canvas_item()
		var hot: bool = _hover or preview_state == "hover"
		if TBTokens.is_hc():
			if selected: draw_rect(Rect2(Vector2.ZERO, size), TBTokens.c("paper_2")); draw_rect(Rect2(0, 0, 4, size.y), TBTokens.c("ink_0"))
			elif hot: draw_rect(Rect2(Vector2.ZERO, size), TBTokens.c("paper_hover"))
		else:
			if selected: TBBz.poly(ci, TBBzParts.rrect(0, 0, size.x, size.y, 3.0), TBTokens.BZ_ROW_ON); draw_rect(Rect2(0, 0, 3, size.y), TBTokens.c("brass"))
			elif hot: TBBz.poly(ci, TBBzParts.rrect(0, 0, size.x, size.y, 3.0), TBTokens.BZ_ROW_HOT)
		if (has_focus() and TBFrame.kbd_nav) or preview_state == "focus":
			var pts := TBBzParts.rrect(-4, -4, size.x + 4, size.y + 4, 6.0)
			pts.append(pts[0])
			RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([TBTokens.c("brass_lt") if not TBTokens.is_hc() else TBTokens.c("ink_0")]), 2.0, true)
	func _gui_input(e: InputEvent) -> void:
		if not interactive: return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _down = true
			else:
				var fire := _down and Rect2(Vector2.ZERO, size).has_point(e.position)
				_down = false
				if fire: activated.emit()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			activated.emit(); accept_event()

# =====================================================================================================================================
## `.tbl`: rows of dim 14.5 text and a bold ivory figure, 2 unit padding, a 1 unit rule above the sum row. rows: [[label, value], ..., [label, value, true]]
class Tbl extends Control:
	var rows: Array = []
	var gap := 18.0
	func _init(r: Array) -> void:
		rows = r; mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = _msize()
	func _sz() -> float: return TBKit.fsf(14.5)
	func _rh() -> float: return 4.0 + roundf(TBBz.ascent(TBKit.alegreya(400), _sz())) + roundf(TBBz.descent(TBKit.alegreya(400), _sz()))
	func _msize() -> Vector2:
		var w := 0.0
		for r in rows: w = maxf(w, TBBz.tw(TBKit.alegreya(400), String(r[0]), _sz()) + gap + TBBz.tw(TBKit.alegreya(700), String(r[1]), _sz()))
		return Vector2(w, _rh() * rows.size() + 1.0)
	func _draw() -> void:
		var ci := get_canvas_item()
		var f := TBKit.alegreya(400); var fb := TBKit.alegreya(700)
		var y := 0.0
		for r in rows:
			var sum: bool = r.size() > 2 and bool(r[2])
			if sum:
				draw_rect(Rect2(0, y, size.x, 1), TBTokens.BZ_TRACK_LINE if not TBTokens.is_hc() else TBTokens.c("ink_1")); y += 1.0
			var rh := _rh()
			var bl: float = y + 2.0 + roundf(TBBz.ascent(f, _sz()))
			TBBz.text(ci, f, Vector2(0, bl), String(r[0]), _sz(), TBTokens.c("ink_0") if sum else TBTokens.c("ink_1"))
			var vw: float = TBBz.tw(fb, String(r[1]), _sz())
			TBBz.text(ci, fb, Vector2(size.x - vw, bl), String(r[1]), _sz(), TBTokens.c("ink_0"))
			y += rh

# =====================================================================================================================================
## `#tip`: a notched plate (notch 6) with a Cinzel 12.5 title in hi, the body in Alegreya 15.5 dim (bold figures allowed through bbcode) and a mono key hint
static func tip(title: String, body: String, key: String = "", bbcode: bool = false) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TBBz.plate_box(6.0, true))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new(); m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 15); m.add_theme_constant_override("margin_right", 15)
	m.add_theme_constant_override("margin_top", 12); m.add_theme_constant_override("margin_bottom", 11)
	pc.add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.custom_minimum_size.x = 160
	m.add_child(v)
	var t := TBKit.title(title, 12, TBTokens.c("brass_lt"), 0.16, 0.0)
	if t is TBBz.TLabel: (t as TBBz.TLabel).px = 12.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(t as TBBz.TLabel).refit()
	v.add_child(t)
	var pr := Para.new(body, 15.5, 1.3, TBKit.DIM)
	pr.shrink_to = 300.0
	var b: Control = pr
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mt := MarginContainer.new(); mt.add_theme_constant_override("margin_top", 5); mt.mouse_filter = Control.MOUSE_FILTER_IGNORE; mt.add_child(b)
	v.add_child(mt)
	if key != "":
		var k := TBBz.TLabel.new(TBKit.jbm(), 10.5, 0.0)
		k.text = key; k.add_theme_color_override("font_color", TBTokens.BZ_TIP_DIM); k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mk := MarginContainer.new(); mk.add_theme_constant_override("margin_top", 7); mk.mouse_filter = Control.MOUSE_FILTER_IGNORE; mk.add_child(k)
		v.add_child(mk)
	return pc

# =====================================================================================================================================
## `.tz` notice: a 46 unit instrument medallion (brass bezel, 24 ticks, the tone-coloured icon) overlapping a notched plate (lo rim, #15110d fill), a close mark.
## kind: bad | dip | info | good. 40 units tall, 22 units of the medallion hang out to the left.
class Notice extends Control:
	signal activated
	signal dismissed
	var kind := "info"
	var icon := "info"
	var text := ""
	var closable := true
	var preview_hover := false
	var _hover := false
	var _hover_x := false
	func _init(k: String, ic: String, t: String) -> void:
		kind = k; icon = ic; text = t
		focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; _hover_x = false; queue_redraw())
		custom_minimum_size = _msize()
		TBKit.a11y(self, t, "button")
	func _f() -> Font: return TBKit.alegreya(500)
	func _sz() -> float: return TBKit.fsf(15.5)
	func _msize() -> Vector2: return Vector2(22.0 + 34.0 + TBBz.tw(_f(), text, _sz()) + 10.0 + 18.0 + 10.0 + 2.0, 40.0)
	func tone() -> Color:
		match kind:
			"bad": return TBTokens.c("neg")
			"dip": return TBTokens.c("brass_lt")
			"good": return TBTokens.c("pos")
		return TBTokens.c("info")
	func _x_rect() -> Rect2: return Rect2(size.x - 10.0 - 18.0 - 1.0, 11.0, 18.0, 18.0)
	func _draw() -> void:
		var ci := get_canvas_item()
		var hot: bool = _hover or preview_hover
		var px: float = 22.0
		var w: float = size.x - px
		var h: float = size.y
		if not TBTokens.is_hc(): TBBz.shift(ci, Vector2(px, 0)); _shadow(ci, w, h); TBBz.unshift(ci)
		TBBz.shift(ci, Vector2(px, 0))
		var lo: Color = TBTokens.c("brass") if hot else TBTokens.c("rule")
		var fill: Color = TBTokens.BZ_NOTICE_FILL if not TBTokens.is_hc() else TBTokens.c("paper_0")
		var oc := TBBz.notch(0, 0, w, h, 7.0)
		for s in 8:
			var ic2 := TBBz.notch(1, 1, w - 1, h - 1, 6.0)
			TBBz.poly(ci, PackedVector2Array([oc[s], oc[(s + 1) % 8], ic2[(s + 1) % 8], ic2[s]]), lo)
		TBBz.poly(ci, TBBz.notch(1, 1, w - 1, h - 1, 6.0), fill)
		var bl: float = TBBz.baseline(_f(), _sz(), 1.0, 38.0, _sz() * 1.1)
		TBBz.text(ci, _f(), Vector2(34.0, bl), text, _sz(), TBTokens.c("ink_0"))
		TBBz.unshift(ci)
		if closable:
			var xr: Rect2 = _x_rect()
			TBGlyph.draw_ic(self, "close", xr.get_center(), 10.0, TBTokens.BZ_WHITE if (hot and _hover_x) or (hot and false) else (TBTokens.BZ_WHITE if hot else TBTokens.c("ink_off")))
		_medallion(ci, Vector2(23.0, h * 0.5), hot)
		if has_focus() and TBFrame.kbd_nav: TBBz.draw_notch_focus_at(ci, Rect2(px, 0, w, h), 7.0)
	func _shadow(ci: RID, w: float, h: float) -> void:
		var oc := TBBz.notch(0, 0, w, h, 7.0)
		for k in 6:
			var g: float = 3.5 * (2.0 - 3.0 * (k + 0.5) / 6.0)
			var pts := PackedVector2Array()
			for p in oc: pts.append(p + Vector2(0, 5.0))
			# expand / shrink by g around the centre (cheap approximation of the 7 unit blur)
			var cen := Vector2(w * 0.5, h * 0.5 + 5.0)
			for i in pts.size(): pts[i] = cen + (pts[i] - cen) + (pts[i] - cen).normalized() * g
			TBBz.poly(ci, pts, TBTokens.with_a(Color.BLACK, 0.55 / 6.0 * 1.2))
	func _medallion(ci: RID, c: Vector2, hot: bool) -> void:
		if TBTokens.is_hc():
			TBBz.disc(ci, c, 21.0, c, TBTokens.c("paper_1"), TBTokens.c("paper_1"), 21.0)
			TBBz.ring_stroke(ci, c, 23.0, 2.0, TBTokens.c("ink_0"))
			TBGlyph.draw_ic(self, icon, c, 17.0, TBTokens.c("ink_0")); return
		var shade := TBTokens.with_a(Color.BLACK, 0.45)
		TBBz.poly(ci, _circle(c, 24.0), shade)
		TBBz.brass_disc(ci, c, 21.0)
		TBBz.poly(ci, _circle(c, 17.0), TBTokens.BZ_FACE_B)
		TBBz.ring_stroke(ci, c, 16.4 + 0.3, 0.6, TBTokens.c("brass_lt"))
		TBBz.ticks(ci, c, 16.0, 24, 2.4, 6, TBTokens.with_a(TBTokens.c("brass"), 1.0), 0.7)
		TBGlyph.draw_ic(self, icon, c, 17.0, tone())
	static func _circle(c: Vector2, r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 48: p.append(c + Vector2(cos(TAU * i / 48.0), sin(TAU * i / 48.0)) * r)
		return p
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var hx: bool = _x_rect().grow(4.0).has_point(e.position) and closable
			if hx != _hover_x: _hover_x = hx; queue_redraw()
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if closable and _x_rect().grow(4.0).has_point(e.position): dismissed.emit()
			else: activated.emit()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			activated.emit(); accept_event()
		elif e.is_action_pressed("ui_cancel") and closable:
			dismissed.emit(); accept_event()

# =====================================================================================================================================
## gaugeSvg: bezel hairline ring, a -135..135 degree track and value arc (round caps), 20 ticks, the figure and a small caption. Size 2 * (r + 12).
class Gauge extends Control:
	var r := 52.0
	var v := "100"
	var d := ""
	var f := 0.5
	var col := Color.WHITE
	func _init(radius: float, value: String, delta: String, frac: float, c: Color) -> void:
		r = radius; v = value; d = delta; f = frac; col = c
		custom_minimum_size = Vector2(2.0 * (r + 12.0), 2.0 * (r + 12.0)); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var ci := get_canvas_item()
		var c := Vector2(r + 12.0, r + 12.0)
		var ro: float = r + 8.0
		if not TBTokens.is_hc():
			TBBz.poly(ci, Notice._circle(c, ro + 2.0), TBTokens.BZ_SHADE)
			TBBz.disc(ci, c, ro, c, TBTokens.BZ_FACE_B, TBTokens.BZ_FACE_B, ro)
			TBBz.ring_stroke(ci, c, ro - 0.7 + 0.65, 1.3, TBTokens.with_a(TBTokens.c("brass"), 0.85))
		else:
			TBBz.disc(ci, c, ro, c, TBTokens.c("paper_1"), TBTokens.c("paper_1"), ro)
			TBBz.ring_stroke(ci, c, ro + 1.0, 2.0, TBTokens.c("ink_0"))
		var a0: float = deg_to_rad(-135.0 - 90.0); var a1: float = deg_to_rad(135.0 - 90.0)
		draw_arc(c, r - 6.0, a0, a1, 64, TBTokens.BZ_TRACK if not TBTokens.is_hc() else TBTokens.c("paper_2"), TBBz.aaw(3.2), true)
		var fa: float = a0 + (a1 - a0) * maxf(0.001, f)
		draw_arc(c, r - 6.0, a0, fa, maxi(8, int(64 * f)), col, TBBz.aaw(3.2), true)
		draw_circle(c + Vector2(cos(a0), sin(a0)) * (r - 6.0), 1.45, col); draw_circle(c + Vector2(cos(fa), sin(fa)) * (r - 6.0), 1.45, col)
		if not TBTokens.is_hc(): TBBz.ticks_arc(ci, c, r + 3.0, 20, 3.0, 5, TBTokens.c("rule"), 0.8, -135.0, 270.0)
		var fb: Font = TBKit.alegreya(700)
		var vs: float = TBKit.fsf((0.78 if v.length() > 3 else 1.0) * maxf(11.0, r * 0.6))
		var vw: float = TBBz.tw(fb, v, vs)
		TBBz.text(ci, fb, Vector2(c.x - vw * 0.5, c.y + r * 0.12), v, vs, TBTokens.c("ink_0"))
		if d != "":
			var ds: float = TBKit.fsf(maxf(9.0, r * 0.27)); var fr: Font = TBKit.alegreya(400)
			var dw: float = TBBz.tw(fr, d, ds)
			TBBz.text(ci, fr, Vector2(c.x - dw * 0.5, c.y + r * 0.52), d, ds, col)

# =====================================================================================================================================
## `.slr`: 44 units tall, track 10 tall at y 12 (inset 1 unit #4a3f28, radius 5) with the gold fill and a hatched danger zone, 1 unit ticks (every 5 %, brass
## at every 25 %), a 24 unit round thumb with an ivory notch and the Cinzel 9.5 numerals under it. It IS an HSlider (value, range, step, signals, keys, wheel);
## the grabber is zero wide, so the value follows the pointer across the full width exactly as the demo does.
class BzSlider extends HSlider:
	var show_nums := true
	var zone_from := -1.0            # value where the hatched zone starts (to the max); < 0 = none
	var _hot := false
	var _drag := false
	func _init() -> void:
		custom_minimum_size = Vector2(0, 44); focus_mode = Control.FOCUS_ALL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var empty := TBKit._empty
		for st in ["slider", "grabber_area", "grabber_area_highlight", "focus"]: add_theme_stylebox_override(st, empty)
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		var tex := ImageTexture.create_from_image(img)
		for ic in ["grabber", "grabber_highlight", "grabber_disabled"]: add_theme_icon_override(ic, tex)
		mouse_entered.connect(func(): _hot = true; queue_redraw())
		mouse_exited.connect(func(): _hot = false; queue_redraw())
		drag_started.connect(func(): _drag = true; queue_redraw())
		drag_ended.connect(func(_c: bool): _drag = false; queue_redraw())
		value_changed.connect(func(_v: float): queue_redraw())
	func _c(col: Color) -> Color: return TBBz.dim(col, 0.3, 0.4) if not editable else col
	func _draw() -> void:
		var ci := get_canvas_item()
		var w: float = size.x
		var ratio: float = 0.0 if max_value <= min_value else clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
		var hc: bool = TBTokens.is_hc()
		var tr := TBBzParts.rrect(0, 12, w, 22, 5.0, 8)
		var track_bg: Color = TBTokens.BZ_TRACK_BG if not hc else TBTokens.c("paper_1")
		var line: Color = TBTokens.BZ_TRACK_LINE if not hc else TBTokens.c("ink_0")
		TBBz.poly(ci, tr, _c(track_bg))
		RenderingServer.canvas_item_add_polyline(ci, TBBzParts.rrect(0.5, 12.5, w - 0.5, 21.5, 4.5, 8), PackedColorArray([_c(line)]), TBBz.aaw(1.0), true)
		var fw: float = w * ratio
		if fw > 0.5:
			for pg in Geometry2D.intersect_polygons(tr, PackedVector2Array([Vector2(0, 12), Vector2(fw, 12), Vector2(fw, 22), Vector2(0, 22)])):
				if hc: TBBz.poly(ci, pg, TBTokens.c("ink_0"))
				else: TBBz.poly_g(ci, pg, TBBz.vgrad(pg, 12.0, 10.0, _c(TBTokens.BZ_SLIDER_FILL_A), _c(TBTokens.BZ_SLIDER_FILL_B)))
		if zone_from >= 0.0 and max_value > min_value and not hc:
			var zx: float = w * clampf((zone_from - min_value) / (max_value - min_value), 0.0, 1.0)
			var box := Geometry2D.intersect_polygons(tr, PackedVector2Array([Vector2(zx, 12), Vector2(w, 12), Vector2(w, 22), Vector2(zx, 22)]))
			var per := 8.4853                                      # 6 units measured along the 135 degree gradient
			var k := 0.0
			while k < (w - zx + 10.0) + per:
				var s := PackedVector2Array([Vector2(zx + k, 12), Vector2(zx + k + per * 0.5, 12), Vector2(zx + k + per * 0.5 - 10.0, 22), Vector2(zx + k - 10.0, 22)])
				for bp in box:
					for pg in Geometry2D.intersect_polygons(s, bp): TBBz.poly(ci, pg, _c(TBTokens.BZ_ZONE))
				k += per
		# ticks: 1 unit every 5 % (lo, 4 tall), 1 unit every 25 % (brass, 8 tall) under them, one at the right edge
		var lo: Color = _c(TBTokens.c("rule")); var br: Color = _c(TBTokens.c("brass"))
		if hc: lo = TBTokens.c("ink_1"); br = TBTokens.c("ink_0")
		for q in [0.0, 0.25, 0.5, 0.75]: draw_rect(Rect2(roundf(w * q), 25, 1, 8), br)
		draw_rect(Rect2(w - 1.0, 25, 1, 8), br)
		for k2 in 20: draw_rect(Rect2(roundf(w * k2 * 0.05), 25, 1, 4), lo)
		# numerals: Cinzel 500 9.5 tracked .1em, spread edge to edge
		if show_nums:
			var f: Font = TBKit.cinzel(500)
			var z: float = TBKit.fsf(9.5); var sp: float = TBKit.trk(z, 0.1)
			var labs: Array = ["0", "25", "50", "75", "100"]
			if max_value != 100.0 or min_value != 0.0:
				labs = []
				for q2 in 5: labs.append(str(roundi(min_value + (max_value - min_value) * q2 / 4.0)))
			var ws: Array = []
			var tot := 0.0
			for t in labs:
				var tw: float = TBBz.tw(f, String(t), z, sp)
				ws.append(tw); tot += tw
			var gap: float = (w - tot) / 4.0
			var x := 0.0
			var ncol: Color = _c(TBTokens.c("ink_off"))
			var bl: float = TBBz.baseline(f, z, 32.0, 13.0, 13.0)
			for i in 5:
				TBBz.text(ci, f, Vector2(x, bl), String(labs[i]), z, ncol, sp)
				x += float(ws[i]) + gap
		# thumb
		var tc := Vector2(w * ratio, 17.0)
		var lit: bool = ((_hot or _drag or (has_focus() and TBFrame.kbd_nav)) and editable)
		if hc:
			TBBz.disc(ci, tc, 12.0, tc, TBTokens.c("paper_1"), TBTokens.c("paper_1"), 12.0)
			TBBz.ring_stroke(ci, tc, 14.0, 2.0, TBTokens.c("ink_0"))
			draw_rect(Rect2(tc.x - 1.0, 8, 2, 8), TBTokens.c("ink_0"))
		else:
			TBBzParts.soft_disc(ci, tc + Vector2(0, 3), 12.0, 3.0, _c(TBTokens.with_a(Color.BLACK, 0.6)))
			if lit: TBBzParts.soft_disc(ci, tc, 12.0, 5.0, TBTokens.with_a(TBTokens.c("brass_lt"), 0.55))
			TBBz.ring_stroke(ci, tc, 14.5, 2.5, _c(TBTokens.BZ_SHADE_40))
			TBBz.ring_stroke(ci, tc, 13.5, 1.5, _c(TBTokens.BZ_HI if lit else TBTokens.c("brass")))
			var hot := tc + Vector2(24.0 * (0.36 - 0.5), 24.0 * (0.30 - 0.5))
			TBBz.disc(ci, tc, 12.0, hot, _c(TBTokens.BZ_FACE_A), _c(TBTokens.BZ_FACE_B), 15.9)
			TBBz.poly(ci, TBBzParts.rrect(tc.x - 1.0, 8.0, tc.x + 1.0, 16.0, 1.0, 3), _c(TBTokens.c("ink_0")))
		if has_focus() and TBFrame.kbd_nav: TBBz.ring_stroke(ci, tc, 18.0, 2.0, TBTokens.c("brass_lt") if not hc else TBTokens.c("ink_0"))

## `.stp`: a 34 unit round stepper with a figure (− / +) in Alegreya 700 19; ring lo 1.5 outside, hi on hover; scale .94 while pressed
class Stp extends Button:
	var preview_state := ""
	var _txt := ""
	func _init(t: String, cb: Callable = Callable()) -> void:
		_txt = t; custom_minimum_size = Vector2(34, 34); size_flags_vertical = Control.SIZE_SHRINK_CENTER; size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE; flat = true
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		add_theme_font_size_override("font_size", 1)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]: add_theme_color_override(fc, Color.TRANSPARENT)
		text = t
		if cb.is_valid(): pressed.connect(cb)
	func _has_point(p: Vector2) -> bool:
		var grow: float = maxf((float(TBKit.touch()) - 34.0) * 0.5, 0.0)
		return Rect2(-grow, -grow, size.x + 2.0 * grow, size.y + 2.0 * grow).has_point(p)
	func _draw() -> void:
		var ci := get_canvas_item()
		var mode := get_draw_mode()
		if preview_state == "hover": mode = BaseButton.DRAW_HOVER
		elif preview_state == "pressed": mode = BaseButton.DRAW_PRESSED
		var hot: bool = (mode != BaseButton.DRAW_NORMAL and mode != BaseButton.DRAW_DISABLED)
		var prs: bool = mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
		var c := size * 0.5
		if prs: RenderingServer.canvas_item_add_set_transform(ci, Transform2D(Vector2(0.94, 0), Vector2(0, 0.94), c * 0.06))
		var off: bool = disabled
		var ring: Color = TBTokens.c("brass_lt") if hot else TBTokens.c("rule")
		TBBz.round_btn(ci, c, 34.0, TBBz.dim(ring, 0.3, 0.4) if off else ring, hot)
		var f: Font = TBKit.alegreya(700)
		var z: float = TBKit.fsf(19.0)
		var tw: float = TBBz.tw(f, _txt, z)
		var ink: Color = TBTokens.BZ_WHITE if hot else TBTokens.c("brass_lt")
		if TBTokens.is_hc(): ink = TBTokens.c("ink_0")
		if off: ink = TBBz.dim(ink, 0.3, 0.4)
		TBBz.text(ci, f, Vector2(c.x - tw * 0.5, TBBz.baseline(f, z, 0.0, size.y, z)), _txt, z, ink)
		TBBz.unshift(ci)
		if (has_focus() and TBFrame.kbd_nav) or preview_state == "focus": TBBz.ring_stroke(ci, c, 17.0 + 4.0, 2.0, TBTokens.c("brass_lt") if not TBTokens.is_hc() else TBTokens.c("ink_0"))

## the demo's slider block (`.srow`): ring icon 38, caption (Cinzel 12.5) over an italic effect line, the figure in Alegreya 25; below: [-] slider [+]
class SRow extends MarginContainer:
	signal changed(v: float)
	var slider: BzSlider
	var minus: Stp
	var plus: Stp
	var eff: TBBz.TLabel
	var val: TBBz.TLabel
	var _fmt := Callable()
	var _eff := Callable()
	func _init(icon: String, caption: String, min_v: float, max_v: float, step_v: float, value: float, fmt: Callable = Callable(), effect: Callable = Callable(), zone_from: float = -1.0) -> void:
		_fmt = fmt; _eff = effect
		add_theme_constant_override("margin_top", 2); add_theme_constant_override("margin_bottom", 2)             # `.srow{padding:2px 0}`
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new(); inner.add_theme_constant_override("separation", 6)
		add_child(inner)
		var top := TBKit.hbox(10)
		top.add_child(TBKit.ring_icon(icon, 38))
		var col := TBKit.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cap := TBKit.title(caption, 12, TBTokens.c("ink_0"), 0.14, 0.0)
		(cap as TBBz.TLabel).px = 12.5; (cap as TBBz.TLabel).refit(); cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cap.custom_minimum_size.x = 40
		col.add_child(cap)
		eff = TBBz.TLabel.new(TBKit.alegreya(400, true), 15.0, 0.0)
		eff.add_theme_color_override("font_color", TBKit.DIM); eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL; eff.custom_minimum_size.x = 40
		eff.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(eff)
		top.add_child(col)
		val = TBBz.TLabel.new(TBKit.alegreya(700), 25.0, 0.0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; val.add_theme_color_override("font_color", TBTokens.c("ink_0"))
		val.custom_minimum_size.x = 56
		top.add_child(val)
		inner.add_child(top)
		var row := TBKit.hbox(8)
		minus = Stp.new("−", func(): _nudge(-step_v))
		plus = Stp.new("+", func(): _nudge(step_v))
		TBKit.a11y(minus, TBI18n.T("step_down", {"s": caption}), "button"); TBKit.a11y(plus, TBI18n.T("step_up", {"s": caption}), "button")
		slider = BzSlider.new(); slider.min_value = min_v; slider.max_value = max_v; slider.step = step_v; slider.value = value; slider.zone_from = zone_from
		TBKit.a11y(slider, caption, "slider")
		row.add_child(minus); row.add_child(slider); row.add_child(plus)
		inner.add_child(row)
		slider.value_changed.connect(func(v: float):
			_sync(v); changed.emit(v))
		_sync(value)
	func _text(v: float) -> String: return String(_fmt.call(v)) if _fmt.is_valid() else "%d%%" % int(round(v))
	func _sync(v: float) -> void:
		val.text = _text(v); eff.text = String(_eff.call(v)) if _eff.is_valid() else ""
		TBKit.a11y(slider, "%s %s" % [String(slider.get_meta("a11y", {}).get("name", "")).get_slice(" ", 0), _text(v)], "slider")
	func _nudge(d: float) -> void:
		slider.value = clampf(slider.value + d, slider.min_value, slider.max_value)
	func set_value(v: float) -> void:
		slider.set_value_no_signal(v); _sync(v); slider.queue_redraw()

# =====================================================================================================================================
## Wrapped text at the demo's exact size and line-height (Godot Labels only take integer sizes): `[b]..[/b]`, `[i]..[/i]` and `[color=#rrggbb]..[/color]` markup,
## CSS-like line boxes (line-height `lh` x size, baseline floored in the half-leading), greedy wrapping at the control's width.
## shrink_to: > 0 makes the control as wide as its text up to that width (a tooltip's max-width), else it takes whatever width it is given.
class Para extends Control:
	var markup := ""
	var px := 16.0
	var lh := 1.3                    # line-height multiplier (0 = the font's normal line)
	var col := Color.WHITE
	var face_n: Font
	var face_b: Font
	var face_i: Font
	var shrink_to := 0.0
	var align_c := false
	var _pieces: Array = []          # [{t, st, c}] parsed once
	var _lay_w := -1.0
	var _lines: Array = []
	func _init(m: String = "", size_px: float = 16.0, line_mult: float = 1.3, c: Color = Color.TRANSPARENT) -> void:
		px = size_px; lh = line_mult; col = c if c.a > 0.0 else TBKit.DIM
		face_n = TBKit.alegreya(400); face_b = TBKit.alegreya(700); face_i = TBKit.alegreya(400, true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_markup(m)
	func set_markup(m: String) -> void:
		markup = m; _pieces = _parse(m); _lay_w = -1.0
		update_minimum_size(); queue_redraw()
	func _parse(m: String) -> Array:
		var out: Array = []
		var st := 0                  # bit 1 bold, 2 italic
		var colstack: Array = []
		var i := 0
		var cur := ""
		while i < m.length():
			if m[i] == "[":
				var j: int = m.find("]", i)
				if j > 0:
					var tag: String = m.substr(i + 1, j - i - 1)
					var hit := true
					match tag:
						"b": _flush(out, cur, st, colstack); cur = ""; st |= 1
						"/b": _flush(out, cur, st, colstack); cur = ""; st &= ~1
						"i": _flush(out, cur, st, colstack); cur = ""; st |= 2
						"/i": _flush(out, cur, st, colstack); cur = ""; st &= ~2
						"/color": _flush(out, cur, st, colstack); cur = ""; if not colstack.is_empty(): colstack.pop_back()
						_:
							if tag.begins_with("color="):
								_flush(out, cur, st, colstack); cur = ""; colstack.append(Color(tag.substr(6)))
							else: hit = false
					if hit: i = j + 1; continue
			cur += m[i]; i += 1
		_flush(out, cur, st, colstack)
		return out
	func _flush(out: Array, t: String, st: int, cs: Array) -> void:
		if t != "": out.append({"t": t, "st": st, "c": cs[cs.size() - 1] if not cs.is_empty() else Color.TRANSPARENT})
	func _sz() -> float: return TBKit.fsf(px)
	func _face(st: int) -> Font:
		if st & 1: return face_b
		if st & 2: return face_i
		return face_n
	func _lhu() -> float:
		var a: float = roundf(TBBz.ascent(face_n, _sz())); var d: float = roundf(TBBz.descent(face_n, _sz()))
		return lh * _sz() if lh > 0.0 else a + d
	## words = groups of pieces without whitespace between them
	func _words() -> Array:
		var words: Array = []
		var cur: Array = []
		for p in _pieces:
			var t: String = p["t"]
			var buf := ""
			for ch in t:
				if ch == " " or ch == "\n":
					if buf != "": cur.append({"t": buf, "st": p["st"], "c": p["c"]}); buf = ""
					if not cur.is_empty(): words.append({"p": cur, "nl": false}); cur = []
					if ch == "\n": words.append({"p": [], "nl": true})
				else: buf += ch
			if buf != "": cur.append({"t": buf, "st": p["st"], "c": p["c"]})
		if not cur.is_empty(): words.append({"p": cur, "nl": false})
		return words
	func _wlen(w: Dictionary) -> float:
		var x := 0.0
		for p in w["p"]: x += TBBz.tw(_face(int(p["st"])), String(p["t"]), _sz())
		return x
	func natural_w() -> float:
		var x := 0.0
		var sp: float = TBBz.tw(face_n, " ", _sz())
		var first := true
		for w in _words():
			if bool(w["nl"]): continue
			x += (0.0 if first else sp) + _wlen(w); first = false
		return x
	func _layout(width: float) -> void:
		if is_equal_approx(width, _lay_w): return
		_lay_w = width
		_lines = []
		var line: Array = []
		var x := 0.0
		var sp: float = TBBz.tw(face_n, " ", _sz())
		for w in _words():
			if bool(w["nl"]):
				_lines.append({"w": line, "x1": x}); line = []; x = 0.0; continue
			var ww: float = _wlen(w)
			var need: float = ww + (sp if not line.is_empty() else 0.0)
			if not line.is_empty() and x + need > width + 0.01:
				_lines.append({"w": line, "x1": x}); line = []; x = 0.0; need = ww
			var px0: float = x + (sp if not line.is_empty() else 0.0)
			line.append({"w": w, "x": px0})
			x = px0 + ww
		if not line.is_empty(): _lines.append({"w": line, "x1": x})
	func _get_minimum_size() -> Vector2:
		var w: float = size.x if size.x > 1.0 else (minf(natural_w(), shrink_to) if shrink_to > 0.0 else maxf(natural_w(), 1.0))
		if shrink_to > 0.0: w = minf(natural_w(), shrink_to)
		_layout(maxf(w, 20.0))
		return Vector2(w if shrink_to > 0.0 else 0.0, _lhu() * maxf(_lines.size(), 1))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			if not is_equal_approx(size.x, _lay_w): _lay_w = -1.0; update_minimum_size()
	func _draw() -> void:
		_layout(maxf(size.x, 20.0))
		var ci := get_canvas_item()
		var z: float = _sz()
		var L: float = _lhu()
		var a: float = roundf(TBBz.ascent(face_n, z)); var d: float = roundf(TBBz.descent(face_n, z))
		for i in _lines.size():
			var ln: Dictionary = _lines[i]
			var bl: float = roundf(i * L + floorf(a + (L - (a + d)) * 0.5))
			var off := 0.0
			if align_c: off = (size.x - float(ln["x1"])) * 0.5
			for it in ln["w"]:
				var x: float = float(it["x"]) + off
				for p in it["w"]["p"]:
					var f: Font = _face(int(p["st"]))
					var c: Color = p["c"] if Color(p["c"]).a > 0.0 else col
					TBBz.text(ci, f, Vector2(x, bl), String(p["t"]), z, c)
					x += TBBz.tw(f, String(p["t"]), z)
