## The tag card beside a selected province or nation (b_demo.html placeTag): a notched plate 250 units wide with the caps line, the name in Cinzel, the italic line,
## small stat cells and a link row, joined to the ring by a brass hairline. Province: Pop / Stable / Happy, link "Dossier". Nation: Army / Relation, link "Open nation card".
class_name TBTagCard
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

signal link_pressed

## one stat cell: bordered well, figure Alegreya 700 18 (line height 1), caps 8.5, an optional 3 unit bar
class Cell extends Control:
	var value := ""
	var cap := ""
	var bar := 0.0
	var bar_col := Color.WHITE
	var val_col := Color.WHITE
	var cap_em := 0.2
	func _init(v: String, c: String, b: float = 0.0, bc: Color = Color.WHITE, vc: Color = Color.WHITE, em: float = 0.2) -> void:
		value = v; cap = c; bar = b; bar_col = bc; val_col = vc; cap_em = em
		size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 5.0 + 18.0 + _cap_h() + 4.0 + (7.0 if b > 0.0 else 0.0) + 2.0)
	func _cap_h() -> float:
		var f: Font = TBKit.cinzel(700)
		return roundf(TBBz.ascent(f, 8.5)) + roundf(TBBz.descent(f, 8.5))
	func _draw() -> void:
		var ci := get_canvas_item()
		draw_rect(Rect2(0, 0, size.x, size.y), TBTokens.BZ_WELL)
		draw_rect(Rect2(0.5, 0.5, size.x - 1.0, size.y - 1.0), TBTokens.BZ_TRACK_LINE, false, 1.0)
		var fb: Font = TBKit.alegreya(700); var fc: Font = TBKit.cinzel(700)
		var vw: float = TBBz.tw(fb, value, 18.0)
		TBBz.text(ci, fb, Vector2((size.x - vw) * 0.5, 1.0 + 5.0 + 13.5), value, 18.0, val_col)
		var cw: float = TBBz.tw(fc, cap, 8.5, 8.5 * cap_em) - 8.5 * cap_em
		TBBz.text(ci, fc, Vector2((size.x - cw) * 0.5, 1.0 + 5.0 + 18.0 + roundf(TBBz.ascent(fc, 8.5)) + 1.0), cap, 8.5, TBTokens.BZ_DIM, 8.5 * cap_em)
		if bar > 0.0:
			var y: float = size.y - 1.0 - 4.0 - 3.0 + 3.0
			draw_rect(Rect2(3, y, size.x - 6, 3), TBTokens.BZ_TRACK)
			draw_rect(Rect2(3, y, (size.x - 6) * clampf(bar, 0.0, 1.0), 3), bar_col)

## "Dossier ›": a ruled top edge, Cinzel 600 12 tracked .18em in brass
class Link extends Control:
	signal pressed
	var text := ""
	var _hover := false
	func _init(t: String) -> void:
		text = t; focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 7.0 + 15.0)
		mouse_entered.connect(func(): _hover = true; queue_redraw()); mouse_exited.connect(func(): _hover = false; queue_redraw())
	func _draw() -> void:
		var ci := get_canvas_item()
		draw_rect(Rect2(0, 0, size.x, 1), TBTokens.BZ_TAG_LINE)
		var f: Font = TBKit.cinzel(700)
		var col: Color = TBTokens.BZ_IVORY if _hover else TBTokens.c("brass")
		TBBz.text(ci, f, Vector2(0, 7.0 + 12.0), text.to_upper() if TBI18n.lang != "ru" else text, 12.0, col, 12.0 * 0.18)
		TBBz.text(ci, f, Vector2(size.x - TBBz.tw(f, "›", 12.0), 7.0 + 12.0), "›", 12.0, col)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed: pressed.emit(); accept_event()
		elif e.is_action_pressed("ui_accept"): pressed.emit(); accept_event()

func _init() -> void:
	add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(250, 0)

func _margin(v: Control, top: float, bottom: float) -> MarginContainer:
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", int(top)); m.add_theme_constant_override("margin_bottom", int(bottom)); m.mouse_filter = Control.MOUSE_FILTER_IGNORE; m.add_child(v); return m

## prov: {name, owner_name, own (bool), pop, stab, happy, link}   nation: {state, name, ruler, army, rel, rel_col, link}
func build_province(d: Dictionary) -> TBTagCard:
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 15); pad.add_theme_constant_override("margin_right", 15)
	pad.add_theme_constant_override("margin_top", 14); pad.add_theme_constant_override("margin_bottom", 12); add_child(pad)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); pad.add_child(v)
	var c := K.caps(T.call("tag_province"), 10, TBTokens.c("brass")); (c as TBBz.TLabel).px = 11.0; (c as TBBz.TLabel).refit(); v.add_child(c)
	var t := K.title(String(d["name"]), 21, Color.TRANSPARENT, 0.05, 21.0 * 1.05); v.add_child(_margin(t, 3, 1))
	var owner_col: String = "#D2A05A" if bool(d["own"]) else "#A89C80"
	v.add_child(K.para_bz("[i][color=%s]%s[/color] · %s[/i]" % [owner_col, d["owner_name"], d["tag"]], 14.0, 1.2))
	var cells := HBoxContainer.new(); cells.add_theme_constant_override("separation", 5); cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.add_child(Cell.new(String(d["pop"]), T.call("tag_pop"), 0.0, Color.WHITE, TBTokens.BZ_IVORY))
	cells.add_child(Cell.new("%d%%" % int(d["stab"]), T.call("tag_stable"), float(d["stab"]) / 100.0, TBTokens.BZ_GOOD, TBTokens.BZ_IVORY))
	cells.add_child(Cell.new("%d%%" % int(d["happy"]), T.call("tag_happy"), float(d["happy"]) / 100.0, TBTokens.c("brass"), TBTokens.BZ_IVORY))
	v.add_child(_margin(cells, 9, 8))
	var l := Link.new(T.call("tag_dossier")); l.pressed.connect(func(): link_pressed.emit()); v.add_child(l)
	return self

func build_nation(d: Dictionary) -> TBTagCard:
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 15); pad.add_theme_constant_override("margin_right", 15)
	pad.add_theme_constant_override("margin_top", 14); pad.add_theme_constant_override("margin_bottom", 12); add_child(pad)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); pad.add_child(v)
	var c := K.caps(String(d["state"]), 10, TBTokens.c("brass")); (c as TBBz.TLabel).px = 11.0; (c as TBBz.TLabel).refit(); v.add_child(c)
	var t := K.title(String(d["name"]), 20, Color.TRANSPARENT, 0.06, 20.0 * 1.1); v.add_child(_margin(t, 3, 1))
	v.add_child(K.para_bz("[i]%s[/i]" % d["ruler"], 14.0, 1.2))
	var cells := HBoxContainer.new(); cells.add_theme_constant_override("separation", 5); cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.add_child(Cell.new(String(d["army"]), T.call("cap_army"), 0.0, Color.WHITE, TBTokens.BZ_IVORY))
	cells.add_child(Cell.new(String(d["rel"]), T.call("tag_relation"), 0.0, Color.WHITE, d["rel_col"]))
	v.add_child(_margin(cells, 9, 8))
	var l := Link.new(T.call("tag_open_nation")); l.pressed.connect(func(): link_pressed.emit()); v.add_child(l)
	return self
