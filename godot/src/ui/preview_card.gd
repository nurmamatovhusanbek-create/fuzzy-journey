## The attack / move preview beside the target (b_demo.html showPreview): a notched plate 340 wide with the win dial, ATTACK in red caps, the target's name, three stat cells,
## and the red Attack button (with Enter) next to Cancel. Same API the order flow used: confirmed / cancelled signals and setup(place, kind, info, moves, send).
class_name TBPreviewCard
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

signal confirmed
signal cancelled

var _cap: TBBz.TLabel
var _name: TBBz.TLabel
var _sub: Control
var _sub_slot: VBoxContainer
var _dial_slot: Control
var _cells: HBoxContainer
var _ok: Button
var _cancel: Button
var _is_attack := true

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	custom_minimum_size = Vector2(340, 0)
	add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 17); pad.add_theme_constant_override("margin_right", 17)
	pad.add_theme_constant_override("margin_top", 15); pad.add_theme_constant_override("margin_bottom", 15)
	add_child(pad)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); pad.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 10); v.add_child(head)
	_dial_slot = Control.new(); _dial_slot.custom_minimum_size = Vector2(104.0 - 8.0, 104.0 - 10.0); _dial_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head.add_child(_dial_slot)
	_sub_slot = VBoxContainer.new(); _sub_slot.add_theme_constant_override("separation", 0); _sub_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _sub_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head.add_child(_sub_slot)
	_cap = K.caps("", 10) as TBBz.TLabel; _sub_slot.add_child(_cap)
	_name = K.title("", 19, Color.TRANSPARENT, 0.06, 19.0 * 1.1) as TBBz.TLabel; _sub_slot.add_child(_name)
	var sm := MarginContainer.new(); sm.name = "SubMargin"; _sub_slot.add_child(sm)
	_cells = HBoxContainer.new(); _cells.add_theme_constant_override("separation", 5)
	var cm := MarginContainer.new(); cm.add_theme_constant_override("margin_top", 8); cm.add_theme_constant_override("margin_bottom", 11); cm.add_child(_cells); v.add_child(cm)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	_ok = K.danger(T.call("pv_attack"), func(): confirmed.emit(), "attack"); _ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_ok as TBBz.Btn).kbd = "↵"
	row.add_child(_ok)
	_cancel = K.button(T.call("pv_cancel"), func(): cancelled.emit()); row.add_child(_cancel)

func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER): pass     # Enter is owned by the order flow (confirm)

## kind: "attack" | anything else (a plain move); info: TBGame.combat_preview
func setup(place: String, kind: String, info: Dictionary, moves: int, send: int) -> void:
	_is_attack = kind == "attack"
	_name.text = place; _name.refit()
	_cap.text = T.call("pv_cap_attack") if _is_attack else T.call("pv_cap_move"); _cap.refit()
	_cap.add_theme_color_override("font_color", TBTokens.BZ_BAD if _is_attack else TBTokens.c("brass"))
	for c in _dial_slot.get_children(): c.queue_free()
	var sm: MarginContainer = _sub_slot.get_node("SubMargin")
	for c in sm.get_children(): c.queue_free()
	for c in _cells.get_children(): c.queue_free()
	var win := true
	var share := 1.0
	if _is_attack:
		win = bool(info["win"])
		share = clampf(float(info["atk"]) / maxf(0.01, float(info["atk"]) + float(info["dfn"])), 0.0, 1.0)
		var col: Color = TBTokens.BZ_GOOD if share > 0.6 else (TBTokens.c("warn") if share > 0.45 else TBTokens.BZ_BAD)
		var dial := K.gauge(40.0, "%d%%" % int(roundf(share * 100.0)), T.call("pv_odds").to_upper() if TBI18n.lang != "ru" else T.call("pv_odds"), share, col)
		dial.position = Vector2(-8.0, -4.0); _dial_slot.add_child(dial)
		var line: String = T.call("cc_victory", {"k": int(info.get("hold", 0)), "l": int(info.get("lost", 0))}) if win else T.call("cc_defeat", {"a": int(info["lost"])})
		sm.add_child(K.para_bz("[i]%s[/i]" % line, 14.0, 1.2))
		_cells.add_child(_cell(K.fmt(float(info["send"])), T.call("pv_your_army")))
		_cells.add_child(_cell(K.fmt(float(info["defenders"])), T.call("pv_defenders")))
		_cells.add_child(_cell("−%d" % int(info["lost"]), T.call("pv_exp_loss")))
	else:
		var dial2 := K.gauge(40.0, K.fmt(float(send)), T.call("pv_men").to_upper() if TBI18n.lang != "ru" else T.call("pv_men"), 1.0, TBTokens.c("brass"))
		dial2.position = Vector2(-8.0, -4.0); _dial_slot.add_child(dial2)
		sm.add_child(K.para_bz("[i]%s[/i]" % T.call("pv_move_line", {"m": moves}), 14.0, 1.2))
		_cells.add_child(_cell(K.fmt(float(send)), T.call("pv_your_army")))
		_cells.add_child(_cell(str(moves), T.call("pv_moves")))
	(_ok as TBBz.Btn).glyph = "attack" if _is_attack else "move"
	_ok.text = T.call("pv_attack") if _is_attack else T.call("move")
	(_ok as TBBz.Btn)._refit()
	reset_size()

func _cell(v: String, c: String) -> Control:
	return TBTagCard.Cell.new(v, c, 0.0, Color.WHITE, TBTokens.BZ_IVORY, 0.1)
