## How many soldiers: one control for sending an army and for raising recruits (rules 4: design in docs/WAR_DESIGN.md section 2).
## [-] [slider] [+]  a typed number  and the quick shares 25 / 50 / 75 / 100 %. Everything keeps `value` inside `lo .. hi`; every change emits `changed(n)`.
## Pure view: it never touches the game, the owner reads `value` and decides what the number means.
class_name TBTroopPicker
extends VBoxContainer

const CC = preload("res://src/ui/cmd_card.gd")

signal changed(n: int)

var lo := 1
var hi := 1
var value := 1
var compact := false                   # no steppers: the slider and the number fit a narrow chip
var caption := ""                       # what the number is ("Send", "Recruit"): the accessible name of the slider and the field
var _slider: HSlider
var _edit: LineEdit
var _of: Label
var _seg: CC.ShareSeg
var _minus: Button
var _plus: Button

func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

## (re)build for a range and a start value; safe to call again when the army or the pool changes
func setup(lo_: int, hi_: int, start: int, name_: String = "", compact_: bool = false) -> void:
	lo = maxi(0, lo_); hi = maxi(lo, hi_); caption = name_; compact = compact_
	for c in get_children(): c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_minus = TBKit.button("−", func(): nudge(-coarse()))
	_plus = TBKit.button("+", func(): nudge(coarse()))
	for b in [_minus, _plus]: (b as Control).custom_minimum_size = Vector2(TBKit.touch(), TBKit.touch())
	TBKit.a11y(_minus, TBI18n.T("step_down", {"s": caption}), "button")
	TBKit.a11y(_plus, TBI18n.T("step_up", {"s": caption}), "button")
	_slider = TBKit.slider(float(lo), float(maxi(hi, lo + 1)), 1.0, float(clampi(start, lo, hi)), Callable(), caption)
	_slider.editable = hi > lo
	_slider.value_changed.connect(func(v: float): _apply(int(round(v)), "slider"))
	_edit = LineEdit.new()
	_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_edit.custom_minimum_size = Vector2(maxf(64.0, TBKit.mono_b().get_string_size(str(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(15)).x + 28.0), 34.0)          # the one control height of the card (the share buttons and the verbs are 34 too)
	_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	for sbn in ["normal", "focus", "read_only"]:                                    # the engine centres the line box, and a figure stands on the baseline: lift it so the figure itself is in the middle of the field
		var sb: StyleBox = _edit.get_theme_stylebox(sbn).duplicate()
		sb.content_margin_bottom = maxf(sb.content_margin_bottom, 0.0) + 3.0 * maxf(1.0, TBKit.text_scale)
		_edit.add_theme_stylebox_override(sbn, sb)
	_edit.select_all_on_focus = true
	_edit.max_length = 6
	_edit.text_changed.connect(_on_text)
	_edit.text_submitted.connect(func(_t: String): _commit_text())
	_edit.focus_exited.connect(_commit_text)
	TBKit.a11y(_edit, caption, "")
	_of = TBKit.num("", 14, TBTokens.c("ink_1"))
	_of.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_minus.visible = not compact; _plus.visible = not compact
	var sm := MarginContainer.new(); sm.size_flags_horizontal = Control.SIZE_EXPAND_FILL                      # the thumb at either end keeps clear of the stepper plates
	sm.add_theme_constant_override("margin_left", 14); sm.add_theme_constant_override("margin_right", 14)
	sm.add_child(_slider)
	row.add_child(_minus); row.add_child(sm); row.add_child(_plus); row.add_child(_edit); row.add_child(_of)
	_seg = CC.ShareSeg.new()
	_seg.cell_h = 34; _seg.cell_w = 40.0
	for i in 4: _seg.off[i] = i > 0 and _share_n(i) == _share_n(i - 1)      # a preset that lands on the same number as the one before it is no choice
	_seg.chosen.connect(func(f: float): _apply(clampi(hi if f >= 0.999 else int(floor(float(hi) * f)), lo, hi), "preset"))
	var seg_row := HBoxContainer.new()
	_seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL                      # the four presets share the whole width: equal cells from the left edge to the right one, like every other row
	seg_row.add_child(_seg)
	add_child(row); add_child(seg_row)
	value = clampi(start, lo, hi)
	_show()

func coarse() -> int: return maxi(1, int(round(float(hi - lo) / 20.0)))        # the steppers move about 5 % of the range; the typed number and the slider are exact

func nudge(d: int) -> void: _apply(value + d, "step")

func set_value(n: int) -> void:
	value = clampi(n, lo, hi); _show()

func _share_n(i: int) -> int:
	if i >= 3: return hi
	return clampi(int(floor(float(hi) * CC.ShareSeg.FRACS[i])), lo, hi)

func _apply(n: int, _src: String) -> void:
	var v := clampi(n, lo, hi)
	var moved := v != value
	value = v
	_show()
	if moved: changed.emit(value)

func _show() -> void:
	if _slider == null: return
	_slider.set_value_no_signal(float(value))
	if not _edit.has_focus() or _edit.text == "": _edit.text = str(value)
	_of.text = "/ %s" % TBKit.fmt(hi)
	_minus.disabled = value <= lo or hi <= lo
	_plus.disabled = value >= hi or hi <= lo
	_seg.set_current(float(value) / float(maxi(1, hi)))
	TBKit.a11y(_slider, "%s %s" % [caption, TBKit.fmt(value)], "slider")

## digits only; a number beyond the range is shown as the range allows once the field is left
func _on_text(t: String) -> void:
	var clean := ""
	for ch in t:
		if ch >= "0" and ch <= "9": clean += ch
	if clean != t:
		var pos := _edit.caret_column
		_edit.text = clean; _edit.caret_column = mini(pos, clean.length())
	if clean != "" and int(clean) >= lo and int(clean) <= hi: _apply(int(clean), "typed")      # a number inside the range follows as you type

func _commit_text() -> void:
	if _edit == null: return
	var t := _edit.text
	_apply(int(t) if t != "" else value, "typed")
	_edit.text = str(value)
