## In-game HUD: resource chips, lens picker, end-turn button, toast log. Pure view; emits signals.
class_name TBHud
extends Control

signal end_turn_pressed
signal lens_selected(name: String)
signal nations_pressed
signal budget_pressed
signal save_pressed
signal settings_pressed

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

var g: TBGame
var _chips := {}
var _toasts: VBoxContainer
var _lens_buttons := {}
var end_btn: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build() -> void:
	for c in get_children(): c.queue_free()
	_chips.clear(); _lens_buttons.clear()
	# top bar
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", K._box(Color(0.05, 0.07, 0.12, 0.88), K.LINE, 0, 6))
	add_child(top)
	var row := K.hbox(10)
	top.add_child(row)
	var nat := K.hbox(6)
	nat.add_child(K.color_chip(0)); _chips["swatch"] = nat.get_child(0)
	var nl := K.label("", 16, K.GOLD2); nat.add_child(nl); _chips["nation"] = nl
	row.add_child(nat)
	for key in ["date", "gold", "man", "mp", "dp", "lands"]:
		var l := K.label("", 15); row.add_child(l); _chips[key] = l
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
	for spec in [["nations", T.call("nations"), nations_pressed], ["budget", T.call("budget"), budget_pressed], ["save", T.call("save"), save_pressed], ["settings", "⚙", settings_pressed]]:
		var b := K.button(spec[1]); b.pressed.connect(func(): spec[2].emit()); row.add_child(b)
	# lenses (left column)
	var lens := VBoxContainer.new()
	lens.add_theme_constant_override("separation", 3)
	lens.position = Vector2(8, 66)
	add_child(lens)
	for l in TBLenses.NAMES:
		var b := K.button(T.call("lens_" + l)); b.custom_minimum_size = Vector2(130, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): lens_selected.emit(l); _mark_lens(l))
		lens.add_child(b); _lens_buttons[l] = b
	_mark_lens("political")
	# toasts
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.position = Vector2(10, -20)
	add_child(_toasts)
	# end turn
	end_btn = K.button(T.call("end_turn") + " ▸", func(): end_turn_pressed.emit(), true)
	end_btn.custom_minimum_size = Vector2(190, 56)
	end_btn.add_theme_font_size_override("font_size", 18)
	end_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	end_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN; end_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	end_btn.position = Vector2(-14, -14)
	add_child(end_btn)

func _mark_lens(name: String) -> void:
	for l in _lens_buttons:
		_lens_buttons[l].add_theme_color_override("font_color", K.GOLD2 if l == name else K.TEXT)

func refresh() -> void:
	if g == null or _chips.is_empty(): return
	var n := g.human_id
	var inc := g.income(n)
	_chips["swatch"].color = Color.hex((g.color[n] << 8) | 0xFF)
	_chips["nation"].text = g.nat_name[n]
	_chips["date"].text = "%s %d · %s %s" % [T.call("turn"), g.turn, TBData.MONTHS[g.month_idx], _year(g.year)]
	var net: int = inc["net"]
	_chips["gold"].text = "%s %s (%s%d)" % [T.call("gold"), K.fmt(g.gold[n]), "+" if net >= 0 else "", net]
	_chips["man"].text = "%s %s/%s" % [T.call("manpower"), K.fmt(g.manpower[n]), K.fmt(inc["manCap"])]
	_chips["mp"].text = "MP %d" % int(g.mp[n])
	_chips["dp"].text = "DP %d" % int(g.dp[n])
	_chips["lands"].text = "%s %d" % [T.call("lands"), inc["lands"]]

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
