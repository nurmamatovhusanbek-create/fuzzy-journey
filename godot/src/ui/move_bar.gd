## The attack / move order as a bar docked at the bottom of the map, in the same shape as the recruit bar (docs/WAR_DESIGN.md section 2):
## [target, odds and result] [-] slider with its preset marks [+] number [confirm] [cancel]. Same API the order flow used with the old preview chip:
## setup(place, kind, info, moves, send), sync_picker(max_n, value), signals confirmed / cancelled / amount_picked(n).
class_name TBMoveBar
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

signal confirmed
signal cancelled
signal amount_picked(n: int)

var picker: TBTroopPicker                  # how many men go; built once per army, only moved afterwards so a drag is never interrupted
var _cap: TBBz.TLabel
var _name: TBBz.TLabel
var _line: Label
var _ok: Button
var _cancel: Button
var _slot: HBoxContainer
var _is_attack := true

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_" + side, 10)
	add_child(pad)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); row.alignment = BoxContainer.ALIGNMENT_CENTER; pad.add_child(row)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 1); left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.custom_minimum_size.x = 150.0 * maxf(1.0, TBKit.text_scale * 0.8)
	_cap = K.caps("", 10) as TBBz.TLabel; _cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_cap)
	_name = K.title("", 14, TBTokens.c("ink_0"), 0.12, 14.0 * 1.1) as TBBz.TLabel; _name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_name)
	_line = K.label("", 12.5, K.DIM); _line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_line)
	row.add_child(left)
	_slot = HBoxContainer.new(); _slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(_slot)
	_ok = TBRecruitCard.plate("attack", TBBz.V.DNG, func(): confirmed.emit())
	_cancel = TBRecruitCard.plate("close", TBBz.V.SEC, func(): cancelled.emit())
	for b in [_ok, _cancel]: (b as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ok); row.add_child(_cancel)

## kind: "attack" | anything else (a plain move); info: TBGame.combat_preview (empty for a move)
func setup(place: String, kind: String, info: Dictionary, moves: int, send: int) -> void:
	_is_attack = kind == "attack"
	_name.text = place; _name.refit()
	var cap: String = T.call("pv_cap_attack") if _is_attack else T.call("pv_cap_move")
	var col: Color = TBTokens.BZ_BAD if _is_attack else TBTokens.c("brass")
	var line := ""
	var tip := ""
	if _is_attack and bool(info.get("unknown", false)):
		cap += " · ?"
		line = T.call("pv_moves") + " " + str(moves)
		tip = T.call("pv_unknown_line")
	elif _is_attack:
		var share := clampf(float(info["atk"]) / maxf(0.01, float(info["atk"]) + float(info["dfn"])), 0.0, 1.0)
		col = TBTokens.BZ_GOOD if share > 0.6 else (TBTokens.c("warn") if share > 0.45 else TBTokens.BZ_BAD)
		cap += " · %d%%" % int(roundf(share * 100.0))
		var win := bool(info["win"])
		line = T.call("cc_victory", {"k": int(info.get("hold", 0)), "l": int(info.get("lost", 0))}) if win else T.call("cc_defeat", {"a": int(info["lost"])})
		tip = line
		if info.has("range"):
			var rg: Dictionary = info["range"]
			tip += "\n" + T.call("pv_range", {"b": int((rg["best"] as Dictionary)["a_left"]), "w": int((rg["worst"] as Dictionary)["a_left"])})
	else:
		line = T.call("pv_move_line", {"m": moves})
	_cap.text = cap; _cap.refit(); _cap.add_theme_color_override("font_color", col)
	_line.text = line
	tooltip_text = tip
	var v: int = TBBz.V.DNG if _is_attack else TBBz.V.PRI
	var okb := _ok as TBBz.Btn
	okb.variant = v; okb.glyph = "attack" if _is_attack else "move"
	okb.ink_nudge = Vector2(0.1, -1.4) if _is_attack else Vector2(0.75, -0.1)             # measured: these two icons' artwork sits off the middle of its box
	okb.queue_redraw()
	var verb: String = T.call("pv_attack") if _is_attack else T.call("move")
	_ok.tooltip_text = verb; TBKit.a11y(_ok, verb, "button")
	_cancel.tooltip_text = T.call("pv_cancel"); TBKit.a11y(_cancel, T.call("pv_cancel"), "button")
	reset_size()

## the troop picker: `max_n` men can go, `value` of them do. A new range rebuilds it, the same range only moves it.
func sync_picker(max_n: int, value: int) -> void:
	if max_n <= 1:
		if picker != null and is_instance_valid(picker): picker.queue_free()
		picker = null
		return
	if picker == null or not is_instance_valid(picker) or picker.hi != max_n:
		if picker != null and is_instance_valid(picker): picker.queue_free()
		picker = TBTroopPicker.new(); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slot.add_child(picker)
		picker.setup(1, max_n, value, T.call("send_share"), false, true)
		picker.changed.connect(func(n: int): amount_picked.emit(n))
	elif picker.value != value:
		picker.set_value(value)

## docked at the bottom of the map, centred, above the lens bar
func dock(host: Control) -> void:
	custom_minimum_size.x = clampf(host.size.x - 48.0, 520.0, 920.0 if TBKit.text_scale < 1.4 else 1240.0)
	reset_size()
	position = Vector2(floorf((host.size.x - size.x) * 0.5), floorf(host.size.y - size.y - 84.0))
