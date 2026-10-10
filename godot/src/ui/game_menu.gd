## The in-game menu popover under the gear (b_demo.html toggleMenu): Resume / Save game / Load game / Settings / Main menu with their keys, the interface size S / M / L,
## and the build line. A notched plate 260 units wide (220 on a phone), no scrim; a press outside closes it.
class_name TBGameMenu
extends Control

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

signal picked(id: String)
signal size_picked(key: String)

class IconCtl extends Control:
	var icon := ""
	func _init(i: String) -> void:
		icon = i; custom_minimum_size = Vector2(18, 18); size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void: TBBzIcons.draw(self, icon, size * 0.5, 18.0, TBTokens.c("brass_lt"))

var _plate: PanelContainer
var _ui_key := "normal"
var _keys := {}

## items: [[icon, label key, id, key hint]]
func setup(ui_key: String, build_text: String) -> TBGameMenu:
	_ui_key = ui_key
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ph: bool = K.is_phone(self)
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	_plate.custom_minimum_size = Vector2(220.0 if ph else 260.0, 0)
	add_child(_plate)
	var pad := MarginContainer.new(); for s in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_" + s, 7)
	_plate.add_child(pad)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); pad.add_child(v)
	for it in [["check", "gm_resume", "resume", "Esc"], ["save", "gm_save", "save", "S"], ["load", "gm_load", "load", "L"], ["settings", "gm_settings", "settings", ""], ["flag", "gm_main", "main", ""]]:
		var id: String = it[2]
		var row := K.row_box(12.0, 8.0 if ph else 10.0, func(): picked.emit(id), false)
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(hb)
		hb.add_child(IconCtl.new(it[0]))
		var t := K.title(T.call(it[1]), 13, Color.TRANSPARENT, 0.14, 0.0); (t as TBBz.TLabel).px = 12.5; (t as TBBz.TLabel).refit(); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(t)
		if String(it[3]) != "":
			var k := TBBz.TLabel.new(TBKit.jbm(), 10.5, 0.0); k.text = it[3]; k.add_theme_color_override("font_color", TBTokens.BZ_DIM2); k.mouse_filter = Control.MOUSE_FILTER_IGNORE; k.refit(); hb.add_child(k)
			_keys[String(it[3])] = id
		v.add_child(row)
	var sep := MarginContainer.new(); sep.add_theme_constant_override("margin_top", 4)
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 0)
	var line := ColorRect.new(); line.color = TBTokens.BZ_PANE_LINE; line.custom_minimum_size = Vector2(0, 1); sv.add_child(line)
	var sm := MarginContainer.new(); sm.add_theme_constant_override("margin_left", 12); sm.add_theme_constant_override("margin_right", 12); sm.add_theme_constant_override("margin_top", 8); sm.add_theme_constant_override("margin_bottom", 6)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0)
	var cap := K.caps(T.call("gm_size"), 11); var cm := MarginContainer.new(); cm.add_theme_constant_override("margin_bottom", 6); cm.add_child(cap); col.add_child(cm)
	var seg := HBoxContainer.new(); seg.add_theme_constant_override("separation", 6)
	for sz in [["S", "small"], ["M", "normal"], ["L", "large"]]:
		var key: String = sz[1]
		var b: Button = K.button(sz[0], func(): size_picked.emit(key), key == _ui_key, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.add_child(b)
	col.add_child(seg); sm.add_child(col); sv.add_child(sm); sep.add_child(sv); v.add_child(sep)
	var bl := TBBz.TLabel.new(TBKit.jbm(), 10.0, 0.0); bl.text = build_text; bl.add_theme_color_override("font_color", TBTokens.BZ_DIM2); bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; bl.refit()
	var bm := MarginContainer.new(); bm.add_theme_constant_override("margin_left", 12); bm.add_theme_constant_override("margin_right", 12); bm.add_theme_constant_override("margin_top", 2); bm.add_theme_constant_override("margin_bottom", 4)
	bl.size_flags_horizontal = Control.SIZE_SHRINK_END; bm.add_child(bl); v.add_child(bm)
	_plate.size = _plate.get_combined_minimum_size()
	var vs: Vector2 = get_viewport_rect().size
	var m: float = 8.0 if ph else 28.0
	_plate.position = Vector2(vs.x - (m + (52.0 if ph else 100.0)) - _plate.size.x, m + (46.0 if ph else 80.0) + 1.0).floor()
	return self

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if not Rect2(_plate.position, _plate.size).has_point(e.position): picked.emit("resume")
		accept_event()

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode == KEY_ESCAPE: picked.emit("resume"); get_viewport().set_input_as_handled()
	elif e.keycode == KEY_S and _keys.has("S"): picked.emit("save"); get_viewport().set_input_as_handled()
	elif e.keycode == KEY_L and _keys.has("L"): picked.emit("load"); get_viewport().set_input_as_handled()
