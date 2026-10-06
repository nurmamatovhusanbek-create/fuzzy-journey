## Title-screen and setup parts (main-menu.md, nation-pick.md): the turning bezel ring around the globe, entry plates, the tools row,
## the language switch, the three-step pips and the era chronology rail. Light-on-dark text sits directly on the dimmed globe (no paper card).
class_name TBMenuParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## graduated bezel (like an armillary / compass ring) that turns with the globe; a flat dark disc under the text keeps it readable
class Bezel extends Control:
	var map: TBMapView
	var dim := 1.0                          # 0.35 while a panel is open
	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if map == null: return
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.44 * map.zoom
		var spin := -map.lon0
		var gold: Color = TBTokens.c("brass_lt")
		var a: float = dim
		draw_circle(c, R * 1.0, TBTokens.ca("table", 0.78 * a))          # flat dark disc: text never sits on bright land
		draw_arc(c, R * 1.06, 0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.6 * a), 1.0, true)
		draw_arc(c, R * 1.075, 0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.25 * a), 1.0, true)
		for i in 120:
			var ang := i * TAU / 120.0 + spin
			var d := Vector2(cos(ang), sin(ang))
			var big := i % 10 == 0
			var mid := i % 5 == 0
			draw_line(c + d * R * 1.06, c + d * R * (1.103 if big else (1.088 if mid else 1.075)), Color(gold.r, gold.g, gold.b, (0.85 if big else 0.5) * a), 1.0, true)
		for q in 4:                                                          # four fixed lubber marks (N/E/S/W)
			var ang2 := q * PI * 0.5 - PI * 0.5
			var d2 := Vector2(cos(ang2), sin(ang2))
			var p := c + d2 * R * 1.06
			draw_colored_polygon(PackedVector2Array([p, p + d2.rotated(0.09) * R * 0.045, p + d2.rotated(-0.09) * R * 0.045]), Color(gold.r, gold.g, gold.b, 0.95 * a))

## entry plate: dark glass (alpha >= 0.8) with a 1 px brass border; primary = brass fill; diamonds flank it on hover and focus
class Plate extends Button:
	var primary := false
	var subline := ""
	var reason := ""
	var _ttl := ""
	func _init(title_text: String, sub: String, is_primary: bool, cb: Callable, why_disabled: String = "") -> void:
		_ttl = title_text; subline = sub; primary = is_primary; reason = why_disabled
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		var hh: int = 64 if sub != "" or why_disabled != "" else 56
		custom_minimum_size = Vector2(340, TBKit.dp(hh))
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		if why_disabled != "":
			disabled = true; tooltip_text = why_disabled
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, title_text, "button", sub if why_disabled == "" else why_disabled)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var w := size.x; var h := size.y
		var hot := (is_hovered() or has_focus()) and not disabled
		var pressed_now := get_draw_mode() == BaseButton.DRAW_PRESSED
		var fill: Color
		var line: Color = TBTokens.c("brass_lt") if hot else TBTokens.ca("brass_lt", 0.7)
		if primary:
			fill = TBTokens.c("brass_press" if pressed_now else ("brass_hover" if hot else "brass"))
			line = TBTokens.c("brass_ink")
		else:
			fill = TBTokens.ca("bar_2" if hot else "bar_0", 0.9)
		if disabled: fill.a = 0.6
		draw_style_box(TBFrame.plate(fill, line, 4, 0, 0, 0, false, 2 if has_focus() and TBFrame.kbd_nav else 1), Rect2(0, 0, w, h))
		var ink: Color = TBTokens.c("ink_0") if primary else (TBTokens.c("smoke") if disabled else TBTokens.c("cream"))
		var f := TBKit.body_b()
		var fsz := TBKit.fs(20)
		var tw: float = f.get_string_size(_ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var sub: String = reason if reason != "" else subline
		var two := sub != ""
		var ty: float = roundf(h * 0.5 - (9.0 if two else 0.0) + f.get_ascent(fsz) * 0.5 - 1.0)
		draw_string(f, Vector2(roundf((w - minf(tw, w - 48.0)) * 0.5), ty), _ttl, HORIZONTAL_ALIGNMENT_LEFT, w - 48.0, fsz, ink)
		if two:
			var sf := TBKit.body()
			var ssz := TBKit.fs(13)
			var sw: float = sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
			draw_string(sf, Vector2(roundf((w - minf(sw, w - 32.0)) * 0.5), roundf(h * 0.5 + 12.0 + sf.get_ascent(ssz) * 0.5 - 1.0)), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 32.0, ssz, ink if primary else TBTokens.c("smoke"))
		if hot:                                                              # flanking diamonds on hover and focus
			var col: Color = TBTokens.c("ink_0") if primary else TBTokens.c("brass_lt")
			var cy := h * 0.5
			for s in [-1.0, 1.0]:
				var x: float = w * 0.5 + s * (minf(tw, w - 48.0) * 0.5 + 18.0)
				if absf(x - w * 0.5) < w * 0.5 - 12.0:
					draw_colored_polygon(PackedVector2Array([Vector2(x - 5, cy), Vector2(x, cy - 5), Vector2(x + 5, cy), Vector2(x, cy + 5)]), col)

## tools row chip: glyph + label on dark furniture, 48 high
class ToolChip extends Button:
	var glyph := ""
	var _lbl := ""
	func _init(g: String, label_text: String, cb: Callable) -> void:
		glyph = g; _lbl = label_text; text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		var f := TBKit.body_b()
		var w: float = f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(14)).x + 56.0
		custom_minimum_size = Vector2(maxf(w, 96.0), TBKit.touch())
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, label_text, "button")
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var hot := is_hovered() or get_draw_mode() == BaseButton.DRAW_PRESSED
		draw_style_box(TBFrame.plate(TBTokens.ca("bar_2" if hot else "bar_1", 0.92), TBTokens.ca("rule_dark", 0.8), 4, 0, 0, 0), Rect2(0, 0, size.x, size.y))
		TBGlyph.draw(self, glyph, Vector2(26, roundf(size.y * 0.5)), 20.0, TBTokens.c("brass_lt"))
		var f := TBKit.body_b()
		draw_string(f, Vector2(46, roundf(size.y * 0.5 + f.get_ascent(TBKit.fs(14)) * 0.5 - 1.0)), _lbl, HORIZONTAL_ALIGNMENT_LEFT, size.x - 52.0, TBKit.fs(14), TBTokens.c("cream"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(true, 4, 0), Rect2(0, 0, size.x, size.y))

## EN | RU | UZ in one chip: one tap, live
class LangSwitch extends HBoxContainer:
	signal chosen(code: String)
	func _init(cur: String) -> void:
		add_theme_constant_override("separation", 0)
		var codes := ["en", "ru", "uz"]
		for i in 3:
			var code: String = codes[i]
			var b := Button.new(); b.text = code.to_upper(); b.focus_mode = Control.FOCUS_ALL; b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			b.custom_minimum_size = Vector2(52, TBKit.touch())
			var on: bool = code == cur
			var mask: int = (TBFrame.TL | TBFrame.BL if i == 0 else 0) | (TBFrame.TR | TBFrame.BR if i == 2 else 0)
			var fill: String = "brass" if on else "bar_1"
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, TBFrame.plate(TBTokens.c(fill) if (on or st == "normal") else TBTokens.c("bar_2"), TBTokens.ca("rule_dark", 0.8), 4, 0, 4, 6, false, 1, mask))
			b.add_theme_stylebox_override("focus", TBFrame.focus(true, 4, 0))
			var tc: Color = TBTokens.c("ink_0") if on else TBTokens.c("cream")
			for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: b.add_theme_color_override(fc, tc)
			b.pressed.connect(func(): chosen.emit(code))
			TBKit.a11y(b, {"en": "English", "ru": "Русский", "uz": "O‘zbekcha"}[code], "button")
			add_child(b)

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
