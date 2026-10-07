## Title-screen and setup parts (main-menu.md, nation-pick.md): the turning bezel ring around the globe, entry plates, the tools row,
## the language switch, the three-step pips and the era chronology rail. Light-on-dark text sits directly on the dimmed globe (no paper card).
class_name TBMenuParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## graduated bezel (like an armillary / compass ring) that turns with the globe; a dark disc (alpha ~0.55) dims the globe under the text but keeps it visible
class Bezel extends Control:
	var map: TBMapView
	var dim := 1.0                          # 0.35 while a panel is open
	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func ring_radius() -> float:
		return minf(size.x, size.y) * 0.44 * (map.zoom if map != null else 1.0)
	func _draw() -> void:
		if map == null: return
		var c := map.global_position - global_position + map.size * 0.5      # the globe's own centre, whatever the overlay insets are
		var R := map.radius_px()
		var spin := -map.lon0
		var a: float = dim
		var ink := TBTokens.c("table")
		# a clean black annulus swallows the shader's blue limb glow; the brass instrument ring sits exactly concentric with the globe
		draw_arc(c, R * 1.026, 0.0, TAU, 180, TBTokens.with_a(ink, 0.97 * a), R * 0.056, true)      # the annulus between globe limb and ring
		draw_circle(c, R * 1.0, TBTokens.with_a(ink, 0.50 * a))                 # dims the globe under the text; the continents stay visible
		var gold := TBTokens.c("brass_lt")
		draw_arc(c, R * 1.052, 0.0, TAU, 180, TBTokens.with_a(gold, 0.95 * a), 1.5, true)
		draw_arc(c, R * 1.092, 0.0, TAU, 180, TBTokens.with_a(gold, 0.40 * a), 1.0, true)
		for i in 72:                                                           # one tick every 5 degrees, a long one every 30
			var ang := i * TAU / 72.0 + spin
			var d := Vector2(cos(ang), sin(ang))
			var long := i % 6 == 0
			var r0 := R * 1.052
			var r1 := R * (1.092 if long else 1.072)
			draw_line(c + d * r0, c + d * r1, TBTokens.with_a(gold, (0.9 if long else 0.55) * a), 2.0 if long else 1.0, true)
		for q in 4:                                                            # fixed N / E / S / W lubber marks, so the turning ring reads as an instrument
			var ang2 := q * PI * 0.5 - PI * 0.5
			var d2 := Vector2(cos(ang2), sin(ang2))
			var p := c + d2 * R * 1.095
			var t := d2.orthogonal()
			draw_colored_polygon(PackedVector2Array([p, p + d2 * R * 0.03 + t * R * 0.014, p + d2 * R * 0.03 - t * R * 0.014]), TBTokens.with_a(gold, a))

## light text with a dark outline so it reads on any part of the globe
static func glow_text(ci: Control, f: Font, pos: Vector2, t: String, w: float, fsz: int, col: Color) -> void:
	ci.draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, w, fsz, 5, TBTokens.ca("table", 0.9))
	ci.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, w, fsz, col)

## title entry: a plain text row on the dimmed globe (cream, outlined). Only the primary / focused / hovered entry is brass; the primary also gets a 3 px brass bar.
class Plate extends Button:
	var primary := false
	var subline := ""
	var reason := ""
	var _ttl := ""
	var compact := false
	func _init(title_text: String, sub: String, is_primary: bool, cb: Callable, why_disabled: String = "", compact_mode: bool = false) -> void:
		_ttl = title_text; subline = sub; primary = is_primary; reason = why_disabled; compact = compact_mode
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		var two: bool = sub != "" or why_disabled != ""
		var hh: int = (58 if two else 40) if compact_mode else (66 if two else 52)
		custom_minimum_size = Vector2(240, maxi(hh, TBKit.touch() if not two else 0))
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		if why_disabled != "":
			disabled = true; tooltip_text = why_disabled
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, title_text, "button", sub if why_disabled == "" else why_disabled)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
	func _draw() -> void:
		var w := size.x; var h := size.y
		var hot := (is_hovered() or (has_focus() and TBFrame.kbd_nav)) and not disabled
		var lit: bool = (primary or hot) and not disabled
		var pressed_now := get_draw_mode() == BaseButton.DRAW_PRESSED
		var ink: Color = TBTokens.c("smoke") if disabled else (TBTokens.c("brass_lt") if lit else TBTokens.c("cream"))
		if pressed_now: ink = TBTokens.c("brass_hover")
		var f := TBKit.body_b()
		var fsz := TBKit.fs(20 if compact else 22)
		var maxw: float = w - 24.0
		var tw: float = minf(f.get_string_size(_ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, maxw)
		var sub: String = reason if reason != "" else subline
		var two := sub != ""
		var ty: float = roundf(h * 0.5 - (8.0 if two else 0.0) + f.get_ascent(fsz) * 0.5 - 2.0)
		TBMenuParts.glow_text(self, f, Vector2(roundf((w - tw) * 0.5), ty), _ttl, maxw, fsz, ink)
		if two:
			var sf := TBKit.body()
			var ssz := TBKit.fs(13)
			var sw: float = minf(sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x, maxw)
			TBMenuParts.glow_text(self, sf, Vector2(roundf((w - sw) * 0.5), roundf(h * 0.5 + 12.0 + sf.get_ascent(ssz) * 0.5 - 2.0)), sub, maxw, ssz, TBTokens.c("smoke"))
		if primary and not disabled:                                           # the one brass element: a 3 px bar under the primary entry
			draw_rect(Rect2(roundf((w - tw) * 0.5) - 6.0, h - 4.0, tw + 12.0, 3.0), TBTokens.c("brass_lt"))
		elif hot:
			draw_rect(Rect2(roundf((w - tw) * 0.5) - 6.0, h - 3.0, tw + 12.0, 1.0), TBTokens.c("brass_lt"))
		if has_focus() and TBFrame.kbd_nav:
			draw_style_box(TBFrame.focus(true, 4, 0), Rect2(0, 0, w, h))

## tools row entry: a small text button (glyph + label), cream on the dark ground, outlined
class ToolChip extends Button:
	var glyph := ""
	var _lbl := ""
	func _init(g: String, label_text: String, cb: Callable) -> void:
		glyph = g; _lbl = label_text; text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		var f := TBKit.body_b()
		var w: float = f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(14)).x + (40.0 if g != "" else 20.0)
		custom_minimum_size = Vector2(maxf(w, 64.0), TBKit.touch())
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, label_text, "button")
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var hot := is_hovered() or get_draw_mode() == BaseButton.DRAW_PRESSED
		var col: Color = TBTokens.c("brass_lt") if hot else TBTokens.c("cream")
		var x0: float = 10.0
		if glyph != "":
			TBGlyph.draw(self, glyph, Vector2(18, roundf(size.y * 0.5)), 18.0, col); x0 = 32.0
		var f := TBKit.body_b()
		var fsz := TBKit.fs(14)
		TBMenuParts.glow_text(self, f, Vector2(x0, roundf(size.y * 0.5 + f.get_ascent(fsz) * 0.5 - 2.0)), _lbl, size.x - x0 - 6.0, fsz, col)
		if hot: draw_rect(Rect2(x0, size.y * 0.5 + 12.0, maxf(size.x - x0 - 8.0, 8.0), 1), col)
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(true, 4, 0), Rect2(0, 0, size.x, size.y))

## EN | RU | UZ as plain text: the current language is bold cream with an underline bar, the others smoke; one tap, live
class LangSwitch extends HBoxContainer:
	signal chosen(code: String)
	class Cell extends Button:
		var on := false
		var _t := ""
		func _init(t: String, is_on: bool) -> void:
			_t = t; on = is_on; text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
			custom_minimum_size = Vector2(48, TBKit.touch())
			mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
		func _draw() -> void:
			var f := TBKit.body_b()
			var fsz := TBKit.fs(14)
			var tw: float = f.get_string_size(_t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			var col: Color = TBTokens.c("cream") if (on or is_hovered()) else TBTokens.c("smoke")
			TBMenuParts.glow_text(self, f, Vector2(roundf((size.x - tw) * 0.5), roundf(size.y * 0.5 + f.get_ascent(fsz) * 0.5 - 2.0)), _t, -1, fsz, col)
			if on: draw_rect(Rect2(roundf((size.x - tw) * 0.5) - 2.0, size.y * 0.5 + 11.0, tw + 4.0, 2.0), TBTokens.c("cream"))
			if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(true, 4, 0), Rect2(0, 0, size.x, size.y))
	func _init(cur: String) -> void:
		add_theme_constant_override("separation", 0)
		var codes := ["en", "ru", "uz"]
		for i in 3:
			var code: String = codes[i]
			var b := Cell.new(code.to_upper(), code == cur)
			b.pressed.connect(func(): chosen.emit(code))
			TBKit.a11y(b, {"en": "English", "ru": "Русский", "uz": "O‘zbekcha"}[code], "button")
			add_child(b)
			if i < 2:
				var sep := Label.new(); sep.text = "|"; sep.add_theme_color_override("font_color", TBTokens.c("smoke")); sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				add_child(sep)

## three pips: Era - Nation - Play (current one filled)
class Steps extends Control:
	var step := 0
	var compact := false
	func _init(current: int, compact_mode: bool = false) -> void:
		step = current; compact = compact_mode
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var f := TBKit.body_b()
		var w := 0.0
		for i in 3:
			w += 16.0 + (0.0 if compact else f.get_string_size(_name(i), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13)).x + 6.0) + 14.0
		custom_minimum_size = Vector2(w, 28)
	func _name(i: int) -> String: return [TBI18n.T("step_era"), TBI18n.T("step_nation"), TBI18n.T("step_play")][i]
	func _draw() -> void:
		var f := TBKit.body_b()
		var x := 0.0
		var cy := roundf(size.y * 0.5)
		var on_bar: bool = bool(get_meta("on_bar", false))
		var ink: Color = TBTokens.c("cream") if on_bar else TBTokens.c("ink_0")
		var dim: Color = TBTokens.c("smoke") if on_bar else TBTokens.c("ink_1")
		for i in 3:
			var cur: bool = i == step
			if cur: TBGlyph.draw_filled(self, "diamond", Vector2(x + 7, cy), 14.0, ink)
			else: TBGlyph.draw(self, "diamond", Vector2(x + 7, cy), 14.0, dim)
			x += 16.0
			if not compact:
				var t := _name(i)
				draw_string(f, Vector2(x, cy + f.get_ascent(TBKit.fs(13)) * 0.5 - 1.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13), ink if cur else dim)
				x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13)).x + 6.0
			x += 14.0

## one stop on the era timeline: rail, diamond node, year, name. Focusable, 36 (pointer) / 48 (touch) high.
class EraRow extends Button:
	var year_text := ""
	var name_text := ""
	var selected := false:
		set(v): selected = v; queue_redraw()
	var first := false
	var last := false
	func _init(y: String, name_value: String) -> void:
		year_text = y; name_text = name_value; text = ""; focus_mode = Control.FOCUS_ALL; flat = true
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch() if OS.has_feature("mobile") else 38)
		name = "Era"
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		TBKit.a11y(self, "%s, %s" % [y, name_value], "button")
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var ox: Color = TBTokens.c("oxblood")
		var ink: Color = TBTokens.c("ink_0")
		var rule: Color = TBTokens.c("rule")
		var hot := is_hovered() or selected
		if selected:
			draw_rect(Rect2(24, 1, size.x - 24, size.y - 2), TBTokens.c("paper_2"))
			draw_rect(Rect2(24, 1, 3, size.y - 2), ox)
		elif is_hovered(): draw_rect(Rect2(24, 1, size.x - 24, size.y - 2), TBTokens.c("paper_1"))
		var cx := 12.0; var cy := roundf(size.y * 0.5)
		if not first: draw_line(Vector2(cx, 0), Vector2(cx, cy - 7), rule, 1.0)
		if not last: draw_line(Vector2(cx, cy + 7), Vector2(cx, size.y), rule, 1.0)
		if selected: TBGlyph.draw_filled(self, "diamond", Vector2(cx, cy), 14.0, ox)
		else: TBGlyph.draw(self, "diamond", Vector2(cx, cy), 14.0, ox if hot else rule)
		var fm := TBKit.mono_b()
		draw_string(fm, Vector2(38, cy + fm.get_ascent(TBKit.fs(13)) * 0.5 - 1.0), year_text, HORIZONTAL_ALIGNMENT_LEFT, 90, TBKit.fs(13), ox if selected else TBTokens.c("ink_1"))
		var fb := TBKit.body_b()
		draw_string(fb, Vector2(134, cy + fb.get_ascent(TBKit.fs(15)) * 0.5 - 1.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 138, TBKit.fs(15), ink)
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, size.x, size.y))
