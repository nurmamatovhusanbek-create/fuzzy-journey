## In-game HUD: resource chips, lens picker, end-turn button, toast log. Pure view; emits signals.
class_name TBHud
extends Control

signal end_turn_pressed
signal lens_selected(name: String)
signal nations_pressed
signal wars_pressed
signal budget_pressed
signal save_pressed
signal settings_pressed

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

var g: TBGame
var _chips := {}
var _toasts: VBoxContainer
var end_btn: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build() -> void:
	for c in get_children(): c.queue_free()
	_chips.clear()
	# top bar: wraps onto several rows on narrow (portrait) screens
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", K._box(Color(0.05, 0.07, 0.12, 0.88), K.LINE, 0, 6))
	add_child(top)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10); row.add_theme_constant_override("v_separation", 4)
	top.add_child(row)
	var nat := K.hbox(6)
	nat.add_child(K.color_chip(0)); _chips["swatch"] = nat.get_child(0)
	var nl := K.label("", 16, K.GOLD2); nat.add_child(nl); _chips["nation"] = nl
	row.add_child(nat)
	for key in ["date", "gold", "man", "mp", "lands"]:
		var l := K.label("", 15); row.add_child(l); _chips[key] = l
	var wars := K.button("", func(): wars_pressed.emit()); wars.custom_minimum_size = Vector2(0, K.MIN_TOUCH - 8); row.add_child(wars); _chips["wars"] = wars
	# map lens picker (one compact dropdown instead of a tall button column)
	var lens := OptionButton.new()
	lens.focus_mode = Control.FOCUS_NONE
	lens.custom_minimum_size = Vector2(140, K.MIN_TOUCH - 8)
	for i in TBLenses.NAMES.size():
		lens.add_item(T.call("lens_" + TBLenses.NAMES[i]), i)
	lens.item_selected.connect(func(idx: int): lens_selected.emit(TBLenses.NAMES[lens.get_item_id(idx)]))
	row.add_child(lens)
	for spec in [["nations", T.call("nations"), nations_pressed], ["budget", T.call("budget"), budget_pressed], ["save", T.call("save"), save_pressed], ["settings", "⚙", settings_pressed]]:
		var b := K.button(spec[1]); b.custom_minimum_size = Vector2(0, K.MIN_TOUCH - 8); b.pressed.connect(func(): spec[2].emit()); row.add_child(b)
	# toasts
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toasts.offset_left = 10; _toasts.offset_right = 360; _toasts.offset_bottom = -78; _toasts.offset_top = -78
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_toasts)
	# end turn
	end_btn = K.button(T.call("end_turn") + " ▸", func(): end_turn_pressed.emit(), true)
	end_btn.add_theme_font_size_override("font_size", 18)
	end_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	end_btn.offset_left = -214; end_btn.offset_right = -12; end_btn.offset_top = -72; end_btn.offset_bottom = -12
	add_child(end_btn)

func refresh() -> void:
	if g == null or _chips.is_empty(): return
	var n := g.human_id
	var inc := g.income(n)
	_chips["swatch"].color = Color.hex((g.color[n] << 8) | 0xFF)
	_chips["nation"].text = g.nat_name[n]
	_chips["date"].text = "%s %d · %s %s" % [T.call("turn"), g.turn, TBData.MONTHS[g.month_idx], _year(g.year)]
	var net: int = inc["net"]
	_chips["gold"].text = "%s %s (%s%d)" % [T.call("gold"), K.fmt(g.gold[n]), "+" if net >= 0 else "", net]
	_chips["man"].text = "%s %s/%s" % [T.call("hud_man"), K.fmt(g.manpower[n]), K.fmt(inc["manCap"])]
	_chips["mp"].text = "MP %d · DP %d%s" % [int(g.mp[n]), int(g.dp[n]), (" · %s %d" % [T.call("hud_intel"), int(g.intel[n])]) if g.rules >= 1 else ""]
	var lvl: float = g.tech_level[n]
	_chips["lands"].text = "%s %d · %s %.1f" % [T.call("hud_prov"), inc["lands"], T.call("era_name_%d" % g.era[n]), lvl]
	var wc := 0
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == 1: wc += 1
	_chips["wars"].text = "⚔ %d" % wc
	_chips["wars"].visible = wc > 0
	_chips["wars"].add_theme_color_override("font_color", K.RED.lightened(0.3))

static func _year(y: int) -> String:
	return "%d BC" % -y if y < 0 else "%d AD" % y

func toast(msg: String, bad: bool = false) -> void:
	if _toasts == null: return
	var l := PanelContainer.new()
	var t := K.label(msg, 14, K.RED.lightened(0.3) if bad else K.TEXT)
	l.add_child(t)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6: _toasts.get_child(0).queue_free(); break
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func set_busy(b: bool) -> void:
	if end_btn: end_btn.disabled = b
