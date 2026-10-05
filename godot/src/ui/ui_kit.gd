## Shared UI factory: the "war table" design system — navy lacquer, brass rules, engraved Cinzel capitals,
## monospaced figures. Chamfered double-ruled frames instead of rounded boxes; icons are drawn, not emoji.
class_name TBKit
extends RefCounted

const BG := Color(0.024, 0.039, 0.078)          # #060a14
const PANEL := Color(0.047, 0.078, 0.149, 0.93)  # #0c1426
const PANEL2 := Color(0.075, 0.118, 0.212)      # #131e36
const LINE := Color(0.83, 0.63, 0.09, 0.34)     # brass, dim
const TEXT := Color(0.91, 0.863, 0.8)           # #e8dccc vellum
const DIM := Color(0.62, 0.58, 0.5)             # aged paper shadow
const GOLD := Color(0.83, 0.627, 0.09)          # #d4a017
const GOLD2 := Color(0.953, 0.773, 0.322)       # #f3c552
const RED := Color(0.91, 0.36, 0.29)            # #e85d4a
const CRIMSON := Color(0.776, 0.227, 0.29)      # #c63a4a
const GREEN := Color(0.42, 0.639, 0.408)        # #6ba368
const STEEL := Color(0.353, 0.439, 0.565)       # #5a7090
const MIN_TOUCH := 44

static var _fonts := {}
static func _font(file: String, fallbacks: Array = []) -> FontFile:
	if _fonts.has(file): return _fonts[file]
	var f: FontFile = load("res://assets/fonts/%s.woff2" % file)
	if f != null:
		f = f.duplicate()
		for fb in fallbacks:
			var ff: Font = load("res://assets/fonts/%s.woff2" % fb)
			if ff != null: f.fallbacks.append(ff)
	_fonts[file] = f
	return f

## engraved capitals for titles and buttons (Cinzel; Alegreya SC small capitals cover Cyrillic)
static func display() -> Font: return _font("cinzel-latin-700-normal", ["alegreya-sc-cyrillic-700-normal"])
static func display_hi() -> Font: return _font("cinzel-latin-900-normal", ["alegreya-sc-cyrillic-900-normal"])
static func display_lo() -> Font: return _font("cinzel-latin-500-normal", ["alegreya-sc-cyrillic-500-normal"])
## figures (JetBrains Mono)
static func mono() -> Font: return _font("jetbrains-mono-latin-400-normal", ["jetbrains-mono-cyrillic-400-normal"])
static func mono_b() -> Font: return _font("jetbrains-mono-latin-700-normal", ["jetbrains-mono-cyrillic-700-normal"])
static func tracked(base: Font, spacing: float) -> Font:
	var v := FontVariation.new(); v.base_font = base; v.spacing_glyph = int(spacing); return v

static var _tex := {}
static func diamond_tex(col: Color, px: int = 18) -> Texture2D:
	var key := "%s_%d" % [col.to_html(), px]
	if _tex.has(key): return _tex[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	for y in px:
		for x in px:
			var d := absf(x - c) + absf(y - c)
			if d <= c: img.set_pixel(x, y, col if d > c - 2.0 else Color(0.03, 0.05, 0.1))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, TBFrame.make(PANEL2, LINE, 7, false, 14, 8))
		t.set_stylebox("hover", cls, TBFrame.make(Color(0.12, 0.17, 0.29), Color(GOLD2.r, GOLD2.g, GOLD2.b, 0.8), 7, false, 14, 8))
		t.set_stylebox("pressed", cls, TBFrame.make(Color(0.83, 0.63, 0.09, 0.28), GOLD2, 7, false, 14, 8))
		t.set_stylebox("disabled", cls, TBFrame.make(Color(0.05, 0.07, 0.12, 0.8), Color(LINE.r, LINE.g, LINE.b, 0.16), 7, false, 14, 8))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, GOLD2)
		t.set_color("font_pressed_color", cls, GOLD2)
		t.set_color("font_disabled_color", cls, Color(DIM.r, DIM.g, DIM.b, 0.55))
		t.set_font("font", cls, display())
		t.set_font_size("font_size", cls, 14)
	t.set_stylebox("panel", "PanelContainer", TBFrame.make(PANEL, LINE, 11, true, 18, 14))
	t.set_stylebox("panel", "Panel", TBFrame.make(PANEL, LINE, 11, true, 18, 14))
	# inputs: ruled underline, no box
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.03, 0.05, 0.1, 0.7); le.border_color = LINE; le.border_width_bottom = 1
	le.content_margin_left = 10; le.content_margin_right = 10; le.content_margin_top = 8; le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", TEXT); t.set_color("caret_color", "LineEdit", GOLD2); t.set_font("font", "LineEdit", mono()); t.set_font_size("font_size", "LineEdit", 14)
	# sliders: a hairline rail with a diamond bead
	var rail := StyleBoxFlat.new(); rail.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.28); rail.content_margin_top = 1; rail.content_margin_bottom = 1
	var fill := StyleBoxFlat.new(); fill.bg_color = GOLD; fill.content_margin_top = 1; fill.content_margin_bottom = 1
	t.set_stylebox("slider", "HSlider", rail); t.set_stylebox("grabber_area", "HSlider", fill); t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		t.set_icon(icon, "HSlider", diamond_tex(GOLD2 if icon != "grabber_disabled" else DIM, 22))
	# scrollbars: slim brass thread
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.0); sb.content_margin_left = 1; sb.content_margin_right = 1
	var grab := StyleBoxFlat.new(); grab.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5); grab.content_margin_left = 1; grab.content_margin_right = 1
	t.set_stylebox("scroll", "VScrollBar", sb); t.set_stylebox("grabber", "VScrollBar", grab); t.set_stylebox("grabber_highlight", "VScrollBar", grab); t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	# popups (lens picker etc.)
	t.set_stylebox("panel", "PopupMenu", TBFrame.make(Color(0.04, 0.065, 0.125, 0.98), LINE, 8, false, 6, 6))
	var hov := StyleBoxFlat.new(); hov.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.2)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_font("font", "PopupMenu", display()); t.set_font_size("font_size", "PopupMenu", 14)
	t.set_color("font_color", "PopupMenu", TEXT); t.set_color("font_hover_color", "PopupMenu", GOLD2)
	t.set_constant("v_separation", "PopupMenu", 10)
	var sep := StyleBoxLine.new(); sep.color = LINE; sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	return t

## kept for older call sites (flat box); new code should prefer TBFrame
static func _box(bg: Color, border: Color, radius: int, pad: int = 8) -> StyleBox:
	return TBFrame.make(bg, border, float(maxi(radius, 4)), false, pad + 4, pad)

static func primary_style(pressed: bool = false) -> StyleBox:
	var f := TBFrame.make(Color(0.72, 0.53, 0.08) if pressed else Color(0.83, 0.63, 0.1), GOLD2, 8, false, 16, 10)
	f.rule2 = Color(1, 1, 1, 0.0)
	return f

static func button(text: String, cb: Callable = Callable(), primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", primary_style())
		b.add_theme_stylebox_override("hover", primary_style())
		b.add_theme_stylebox_override("pressed", primary_style(true))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(k, Color(0.06, 0.05, 0.02))
		b.add_theme_font_override("font", display_hi())
	if cb.is_valid(): b.pressed.connect(cb)
	return b

static func label(text: String, size: int = 0, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0: l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## engraved heading
static func title(text: String, size: int = 20, color: Color = GOLD2) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", tracked(display(), 1))
	return l

## figure in monospaced bold
static func num(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", mono_b())
	return l

## small tracked caption (labels above figures)
static func caps(text: String, size: int = 10, color: Color = DIM) -> Label:
	var l := label(text.to_upper() if TBI18n.lang != "ru" else text, size, color)
	l.add_theme_font_override("font", tracked(mono(), 1))
	return l

static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v

static func color_chip(rgb: int) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color.hex((rgb << 8) | 0xFF)
	c.custom_minimum_size = Vector2(14, 14)
	return c

static func fmt(v: float) -> String:
	var a := absf(v)
	if a >= 1000000.0: return "%.1fM" % (v / 1000000.0)
	if a >= 10000.0: return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))

## a thin ornamental rule: ——— ◆ ———
class OrnamentRule extends Control:
	var col := Color(0.83, 0.63, 0.09, 0.7)
	func _init() -> void:
		custom_minimum_size = Vector2(0, 12); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		TBGlyph.rule(self, 0.0, size.x, 6.0, col)


## dotted leader between a caption and its figure (ledger line)
class Leader extends Control:
	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL; custom_minimum_size = Vector2(8, 16); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y - 5.0
		var x := 2.0
		while x < size.x - 2.0:
			draw_rect(Rect2(x, y, 1.5, 1.5), Color(0.83, 0.63, 0.09, 0.32))
			x += 4.0

## n of max engraved diamonds, filled in brass
class Pips extends Control:
	var n := 0
	var maxn := 5
	var col := Color(0.953, 0.773, 0.322)
	func _init(value: int, max_value: int = 5, c: Color = Color(0.953, 0.773, 0.322)) -> void:
		n = value; maxn = max_value; col = c; custom_minimum_size = Vector2(max_value * 14, 16); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in maxn:
			var c := Vector2(7 + i * 14, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
			if i < n: draw_colored_polygon(pts, col)
			else:
				pts.append(pts[0]); draw_polyline(pts, Color(col.r, col.g, col.b, 0.35), 1.0, true)

## thin graduated meter 0..100 with a tick at 50
class Meter extends Control:
	var v := 0.0
	var col := Color(0.42, 0.64, 0.41)
	func _init(value: float, c: Color) -> void:
		v = value; col = c; custom_minimum_size = Vector2(0, 7); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y * 0.5
		draw_rect(Rect2(0, y - 1.5, size.x, 3), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(0, y - 1.5, size.x * clampf(v / 100.0, 0.0, 1.0), 3), col)
		for t in [0.25, 0.5, 0.75]: draw_line(Vector2(size.x * t, y - 4), Vector2(size.x * t, y + 4), Color(1, 1, 1, 0.14), 1.0)

## caption ........ figure
static func row(caption: String, value: String, value_col: Color = TEXT, extra: Control = null) -> HBoxContainer:
	var h := hbox(6)
	var c := label(caption, 13, DIM); h.add_child(c)
	h.add_child(Leader.new())
	if extra != null: h.add_child(extra)
	if value != "":
		var n := num(value, 14, value_col); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(n)
	return h

## caption  figure
## ▬▬▬▬▬▬▬▬▬▬▬▬▬▬ (meter)
static func meter_row(caption: String, value: float, col: Color) -> VBoxContainer:
	var v := vbox(2)
	var h := hbox(6); h.add_child(label(caption, 13, DIM)); h.add_child(Leader.new())
	h.add_child(num(str(int(value)), 14, col)); v.add_child(h)
	v.add_child(Meter.new(value, col))
	return v

## section heading: SMALL CAPS ───────
static func section(text: String) -> HBoxContainer:
	var h := hbox(8)
	h.add_child(caps(text, 10, Color(GOLD.r, GOLD.g, GOLD.b, 0.9)))
	var l := Control.new(); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.custom_minimum_size = Vector2(8, 12); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.draw.connect(func(): l.draw_line(Vector2(0, 6), Vector2(l.size.x, 6), Color(GOLD.r, GOLD.g, GOLD.b, 0.3), 1.0))
	h.add_child(l)
	return h

## square button with only a drawn glyph (close, back...)
class IconBtn extends Button:
	var glyph := "close"
	func _init(g: String, cb: Callable, px: int = 40) -> void:
		glyph = g; custom_minimum_size = Vector2(px, px); focus_mode = Control.FOCUS_NONE
		if px < 40:
			for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		if cb.is_valid(): pressed.connect(cb)
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		TBGlyph.draw(self, glyph, size * 0.5, minf(size.x, size.y) * 0.42, Color(0.953, 0.773, 0.322) if hot else Color(0.83, 0.68, 0.3), 1.6)

## text tabs with a brass underline on the current choice (replaces rows of boxed buttons)
class Segmented extends HBoxContainer:
	signal chosen(id: String)
	var current := ""
	var _btns := {}
	func setup(items: Array, cur: String) -> Segmented:
		current = cur
		add_theme_constant_override("separation", 4)
		for it in items:
			var id: String = it[0]
			var b := Button.new(); b.text = it[1]; b.flat = true; b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 40); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			b.pressed.connect(func(): current = id; chosen.emit(id); _restyle())
			b.draw.connect(func():
				if id == current:
					b.draw_line(Vector2(6, b.size.y - 3), Vector2(b.size.x - 6, b.size.y - 3), Color(0.953, 0.773, 0.322), 2.0)
					b.draw_colored_polygon(PackedVector2Array([Vector2(b.size.x * 0.5 - 4, b.size.y - 3), Vector2(b.size.x * 0.5, b.size.y - 8), Vector2(b.size.x * 0.5 + 4, b.size.y - 3)]), Color(0.953, 0.773, 0.322)))
			add_child(b); _btns[id] = b
		_restyle()
		return self
	func _restyle() -> void:
		for k in _btns:
			var on: bool = k == current
			_btns[k].add_theme_color_override("font_color", Color(0.953, 0.773, 0.322) if on else Color(0.91, 0.863, 0.8))
			_btns[k].add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
			_btns[k].queue_redraw()

## flat list row: name on the left, figure on the right, hairline below
class ListRow extends Button:
	var left := ""
	var right := ""
	var left_col := Color(0.91, 0.863, 0.8)
	func _init(l: String, r: String, cb: Callable, col: Color = Color(0.91, 0.863, 0.8)) -> void:
		left = l; right = r; left_col = col; flat = true; focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 40)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		if cb.is_valid(): pressed.connect(cb)
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		if hot: draw_rect(Rect2(0, 0, size.x, size.y - 1), Color(0.83, 0.63, 0.09, 0.12))
		var f := TBKit.display()
		draw_string(f, Vector2(6, size.y * 0.5 + 5), left, HORIZONTAL_ALIGNMENT_LEFT, size.x - 70, 15, Color(0.953, 0.773, 0.322) if hot else left_col)
		var fm := TBKit.mono_b()
		var w := fm.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(fm, Vector2(size.x - w - 8, size.y * 0.5 + 5), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.83, 0.68, 0.3))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(0.83, 0.63, 0.09, 0.18), 1.0)

static func list_row(l: String, r: String, cb: Callable, col: Color = TEXT) -> Button: return ListRow.new(l, r, cb, col)

## clickable card for event choices: title in capitals, consequence line in plain text beneath
class ChoiceCard extends PanelContainer:
	signal chosen
	var _normal: StyleBox
	var _hot: StyleBox
	func _init(title_text: String, detail: String, primary: bool) -> void:
		_normal = TBFrame.make(Color(0.83, 0.63, 0.09, 0.2) if primary else Color(0.075, 0.118, 0.212), Color(0.953, 0.773, 0.322, 0.9) if primary else Color(0.83, 0.63, 0.09, 0.34), 8, false, 14, 10)
		_hot = TBFrame.make(Color(0.83, 0.63, 0.09, 0.32), Color(0.953, 0.773, 0.322, 1.0), 8, false, 14, 10)
		add_theme_stylebox_override("panel", _normal)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := TBKit.title(title_text, 16, TBKit.GOLD2 if primary else TBKit.TEXT); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(t)
		if detail != "":
			var d := TBKit.label(detail, 13, TBKit.DIM); d.mouse_filter = Control.MOUSE_FILTER_IGNORE; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(d)
		add_child(v)
		mouse_entered.connect(func(): add_theme_stylebox_override("panel", _hot))
		mouse_exited.connect(func(): add_theme_stylebox_override("panel", _normal))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:      # touches arrive as emulated mouse clicks
			chosen.emit(); accept_event()

static func choice_card(title_text: String, detail: String, cb: Callable, primary: bool = false) -> Control:
	var c := ChoiceCard.new(title_text, detail, primary)
	c.chosen.connect(cb)
	return c

static func segmented(items: Array, current: String, cb: Callable) -> Control:
	var s := Segmented.new().setup(items, current)
	s.chosen.connect(cb)
	return s

## tiny drawn glyph followed by text
class GlyphLabel extends HBoxContainer:
	func _init(glyph: String, text: String, col: Color, size_px: int = 13) -> void:
		add_theme_constant_override("separation", 4)
		var ic := Control.new(); ic.custom_minimum_size = Vector2(size_px + 2, size_px + 2); ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER; ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): TBGlyph.draw(ic, glyph, ic.size * 0.5, float(size_px), col, 1.3))
		add_child(ic)
		var l := TBKit.num(text, size_px, col); add_child(l)

static func glyph_label(glyph: String, text: String, col: Color = GOLD2, size_px: int = 13) -> Control: return GlyphLabel.new(glyph, text, col, size_px)

static func icon_button(glyph: String, cb: Callable, px: int = 40) -> Button: return IconBtn.new(glyph, cb, px)

static func ornament() -> Control: return OrnamentRule.new()

static func glyph_label_big(glyph: String) -> Control:
	var ic := Control.new(); ic.custom_minimum_size = Vector2(30, 30); ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER; ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func(): TBGlyph.draw(ic, glyph, ic.size * 0.5, 26.0, GOLD2, 1.7))
	return ic

## centered modal card over a dim backdrop; returns [backdrop, content_vbox]
static func modal(parent: Control, title_text: String = "", width: int = 520, glyph: String = "") -> Array:
	var back := ColorRect.new()
	back.color = Color(0.012, 0.02, 0.045, 0.86)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(center)
	var card := PanelContainer.new()
	width = mini(width, int(parent.get_viewport_rect().size.x) - 20)
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var outer := vbox(10)
	card.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 36, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var footer := hbox(8)          # pinned below the scrolling body (primary actions stay visible on phones)
	outer.add_child(footer)
	var v := vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	if title_text != "":
		var t := title(title_text, 22)
		if glyph != "":
			var hh := hbox(10); hh.add_child(glyph_label_big(glyph)); hh.add_child(t); v.add_child(hh)
		else: v.add_child(t)
		v.add_child(ornament())
	parent.add_child(back)
	# a ScrollContainer reports zero height: size it to its content, capped to the viewport
	var fit := func():
		var cap := parent.get_viewport_rect().size.y * 0.86 - footer.get_combined_minimum_size().y - 12.0
		scroll.custom_minimum_size.y = minf(v.get_combined_minimum_size().y + 4, cap)
	v.minimum_size_changed.connect(fit)
	footer.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return [back, v, footer]
