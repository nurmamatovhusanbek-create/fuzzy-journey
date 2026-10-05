## Shared UI factory: theme + small widget helpers (touch-friendly sizes).
class_name TBKit
extends RefCounted

const BG := Color(0.071, 0.102, 0.169)
const PANEL := Color(0.075, 0.106, 0.169, 0.96)
const PANEL2 := Color(0.094, 0.133, 0.227)
const LINE := Color(0.153, 0.204, 0.31)
const TEXT := Color(0.9, 0.92, 0.96)
const DIM := Color(0.55, 0.6, 0.71)
const GOLD := Color(0.88, 0.714, 0.227)
const GOLD2 := Color(0.953, 0.773, 0.322)
const RED := Color(0.88, 0.32, 0.25)
const GREEN := Color(0.275, 0.765, 0.42)
const MIN_TOUCH := 44

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, _box(PANEL2, LINE, 8))
		t.set_stylebox("hover", cls, _box(PANEL2.lightened(0.08), Color(0.23, 0.3, 0.46), 8))
		t.set_stylebox("pressed", cls, _box(PANEL2.darkened(0.1), GOLD, 8))
		t.set_stylebox("disabled", cls, _box(PANEL2.darkened(0.2), LINE, 8))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, DIM)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 10))
	t.set_stylebox("panel", "Panel", _box(PANEL, LINE, 10))
	t.set_stylebox("normal", "LineEdit", _box(PANEL2, LINE, 8))
	return t

static func _box(bg: Color, border: Color, radius: int, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4; s.content_margin_right = pad + 4
	s.content_margin_top = pad; s.content_margin_bottom = pad
	return s

static func primary_style() -> StyleBoxFlat:
	var s := _box(Color(0.82, 0.62, 0.14), GOLD2, 8, 10)
	return s

static func button(text: String, cb: Callable = Callable(), primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", primary_style())
		b.add_theme_stylebox_override("hover", primary_style())
		b.add_theme_stylebox_override("pressed", _box(Color(0.7, 0.52, 0.1), GOLD2, 8, 10))
		b.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
		b.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.02))
	if cb.is_valid(): b.pressed.connect(cb)
	return b

static func label(text: String, size: int = 0, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0: l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
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

## centered modal card over a dim backdrop; returns [backdrop, content_vbox]
static func modal(parent: Control, title: String = "", width: int = 520) -> Array:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06, 0.82)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 24, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(scroll)
	var v := vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	if title != "": v.add_child(label(title, 22, GOLD2))
	parent.add_child(back)
	# a ScrollContainer reports zero height: size it to its content, capped to the viewport
	var fit := func():
		var cap := parent.get_viewport_rect().size.y * 0.88
		scroll.custom_minimum_size.y = minf(v.get_combined_minimum_size().y + 4, cap)
	v.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return [back, v]
