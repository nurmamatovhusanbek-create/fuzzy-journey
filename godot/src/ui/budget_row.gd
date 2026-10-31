## One policy of the Budget window in the V1 ledger layout (docs/UI_STANDARD.md): [icon] [name + the whole effect line] [slider] [now] [- +].
## Wide: every part has a fixed column, so the four rows line up exactly; narrow (a phone): the name line, then [- slider +] beneath it. The effect line is never cut.
class_name TBBudgetRow
extends VBoxContainer

const K = preload("res://src/ui/ui_kit.gd")
const ICON_W := 36.0
const SLIDER_W := 232.0
const VAL_W := 60.0
const STEP := 30.0                      # one square stepper: the same 28-30 high plate as every segmented cell
const ROW_H := 80.0                    # room for a two-line effect: every row is this tall, so the four rows keep an even pitch

signal changed(v: float)

var slider: TBBzParts.BzSlider
var val: TBBz.TLabel
var eff: TBBz.TLabel
var _effect := Callable()
var _step := 5.0
var _caption := ""

func _init(icon: String, caption: String, value: float, effect: Callable, zone_from: float, stacked: bool, step_v: float = 5.0) -> void:
	_effect = effect; _step = step_v; _caption = caption
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ring := K.ring_icon(icon, 34)
	ring.custom_minimum_size = Vector2(ICON_W, ICON_W); ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap := K.title(caption, 12, TBTokens.c("ink_0"), 0.14, 0.0)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cap.custom_minimum_size.x = 40
	col.add_child(cap)
	eff = TBBz.TLabel.new(TBKit.alegreya(400, true), 14.0, 0.0)
	eff.add_theme_color_override("font_color", TBKit.DIM); eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL; eff.custom_minimum_size.x = 40
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(eff)
	val = TBBz.TLabel.new(TBKit.alegreya(700), 22.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; val.add_theme_color_override("font_color", TBTokens.c("ink_0"))
	val.custom_minimum_size.x = VAL_W; val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider = TBBzParts.BzSlider.new()
	slider.min_value = 0; slider.max_value = 100; slider.step = step_v; slider.value = value; slider.zone_from = zone_from
	TBKit.a11y(slider, caption, "slider")
	var minus := _stepper("−", -1); var plus := _stepper("+", 1)
	TBKit.a11y(minus, TBI18n.T("step_down", {"s": caption}), "button"); TBKit.a11y(plus, TBI18n.T("step_up", {"s": caption}), "button")
	var box := MarginContainer.new(); box.add_theme_constant_override("margin_top", 8); box.add_theme_constant_override("margin_bottom", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if stacked:
		var v := K.vbox(6); box.add_child(v)
		var top := K.hbox(12); top.add_child(ring); top.add_child(col); top.add_child(val); v.add_child(top)
		var low := K.hbox(8); low.add_child(minus); low.add_child(slider); low.add_child(plus); v.add_child(low)
	else:
		var r := K.hbox(16); box.add_child(r)
		box.custom_minimum_size.y = ROW_H
		slider.custom_minimum_size.x = SLIDER_W; slider.size_flags_horizontal = Control.SIZE_SHRINK_END
		var steps := K.hbox(4); steps.add_child(minus); steps.add_child(plus); steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER; steps.custom_minimum_size.x = STEP * 2.0 + 4.0; steps.size_flags_horizontal = Control.SIZE_SHRINK_END
		r.add_child(ring); r.add_child(col); r.add_child(slider); r.add_child(val); r.add_child(steps)
	add_child(box)
	add_child(HSeparator.new())
	slider.value_changed.connect(func(v: float): _refresh(); changed.emit(v))
	_refresh()

func _stepper(t: String, dir: int) -> Button:
	var b := SquareBtn.new(t)
	b.pressed.connect(func(): slider.value = clampf(slider.value + dir * _step, slider.min_value, slider.max_value))
	return b

## a stepper plate of one exact size (30 x 28, never wider than its glyph needs): the same shape in every row, so the columns cannot drift
class SquareBtn extends Button:
	var _glyph := ""
	func _init(g: String) -> void:
		_glyph = g
		custom_minimum_size = Vector2(30.0, 28.0); size_flags_horizontal = Control.SIZE_SHRINK_CENTER; size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE; flat = true; clip_contents = true
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		add_theme_font_size_override("font_size", 1)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]: add_theme_color_override(fc, Color.TRANSPARENT)
		text = ""
	func _has_point(p: Vector2) -> bool:
		var grow: float = maxf((float(TBKit.touch()) - 28.0) * 0.5, 0.0)
		return Rect2(-grow, -grow, size.x + 2.0 * grow, size.y + 2.0 * grow).has_point(p)
	func _draw() -> void:
		var hot := is_hovered() or has_focus()
		var fill: Color = TBTokens.c("paper_2") if is_pressed() else (TBTokens.c("paper_hover") if hot else TBTokens.c("paper_1"))
		draw_rect(Rect2(Vector2.ZERO, size), TBTokens.c("brass") if hot else TBTokens.c("rule"), true)
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), fill, true)
		var f: Font = TBKit.body_b()
		var fs := TBKit.fs(16)
		var w := f.get_string_size(_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + f.get_ascent(fs) * 0.5 - 2.0), _glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TBTokens.c("ink_0"))

func _refresh() -> void:
	val.text = "%d%%" % int(slider.value); val.refit()
	if _effect.is_valid():
		eff.text = String(_effect.call(slider.value)); eff.refit()

## the game changed the figure (a preset, Revert): move the slider without telling anyone, redraw the effect line
func set_value(v: float) -> void:
	slider.set_value_no_signal(v)
	slider.queue_redraw()
	_refresh()
