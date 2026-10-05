## Selected-province panel (right side on wide screens, bottom sheet on portrait). Emits command dictionaries.
class_name TBProvincePanel
extends PanelContainer

signal command(cmd: Dictionary)
signal move_requested(p: int)
signal closed
signal nation_requested(n: int)

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const D = preload("res://src/engine/data.gd")

var g: TBGame
var p := -1
var _body: VBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(330, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_body = K.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	visible = false

func layout_for(vp: Vector2) -> void:
	if vp.x >= vp.y:   # landscape: right side
		set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		offset_left = -350; offset_right = -10; offset_top = 76; offset_bottom = -116
	else:              # portrait: bottom sheet
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		offset_left = 6; offset_right = -6; offset_top = -430; offset_bottom = -100

func show_province(game: TBGame, province: int) -> void:
	g = game; p = province
	if p < 0:
		visible = false; return
	visible = true
	rebuild()

func rebuild() -> void:
	if p < 0 or g == null: return
	for c in _body.get_children(): c.queue_free()
	var w := g.world
	var me := g.human_id
	var o := g.owner[p]
	var mine := o == me
	var rel := g.get_rel(me, o) if (o != 0 and not mine) else -1
	var head := K.hbox(8)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tcol.add_theme_constant_override("separation", 0)
	var title := K.title(TBI18n.place(w.name[p]), 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.custom_minimum_size = Vector2(120, 0)
	tcol.add_child(title)
	if g.capital[p] != 0:
		var cp := K.caps(T.call("capital"), 10, K.GOLD2); tcol.add_child(cp)
	head.add_child(tcol)
	head.add_child(K.icon_button("close", func(): closed.emit(), 40))
	_body.add_child(head)
	_body.add_child(K.ornament())
	var sub := K.hbox(8)
	if o != 0:
		sub.add_child(TBFlags.chip(g, o))
		var nb := Button.new(); nb.text = g.dname(o) + "  ›"; nb.flat = true; nb.focus_mode = Control.FOCUS_NONE
		nb.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); nb.add_theme_stylebox_override("hover", StyleBoxEmpty.new()); nb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		nb.add_theme_font_size_override("font_size", 15); nb.add_theme_color_override("font_color", K.TEXT); nb.add_theme_color_override("font_hover_color", K.GOLD2)
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT; nb.custom_minimum_size = Vector2(0, 32); nb.pressed.connect(func(): nation_requested.emit(o))
		sub.add_child(nb)
		var tag := ""; var tc := K.DIM
		if rel == D.REL_WAR: tag = T.call("war"); tc = K.RED
		elif rel == D.REL_ALLY: tag = T.call("ally"); tc = Color(0.55, 0.72, 1.0)
		elif rel == D.REL_NAP: tag = T.call("nap"); tc = Color(0.5, 0.86, 0.89)
		elif g.overlord[o] != 0: tag = T.call("vassal")
		if tag != "": sub.add_child(K.caps(tag, 10, tc))
	else:
		sub.add_child(K.caps(T.call("neutral"), 11, K.DIM))
	_body.add_child(sub)
	if g.occupier[p] != 0:
		_body.add_child(K.label(T.call("occupied_by", {"nation": g.dname(g.occupier[p])}), 13, K.RED))
	var bname: String = T.call("none")
	if g.building[p] != 0: bname = "%s %d" % [T.call("b_" + D.BUILDINGS[g.building[p] - 1]["id"]), g.b_level[p]]
	elif g.b_building[p] != 0: bname = "%s · %d" % [T.call("b_" + D.BUILDINGS[g.b_building[p] - 1]["id"]), g.b_turns[p]]
	var stats := K.vbox(6)
	stats.add_child(K.row(T.call("army"), K.fmt(g.army[p]), K.GOLD2))
	stats.add_child(K.row(T.call("pop"), K.fmt(g.pop[p] * 1000)))
	stats.add_child(K.row(T.call("dev"), "", K.TEXT, K.Pips.new(g.dev[p])))
	stats.add_child(K.row(T.call("econ"), "", K.TEXT, K.Pips.new(g.econ[p])))
	stats.add_child(K.row(T.call("terrain"), T.call("t_" + D.TERRAIN_ID[g.terrain[p]])))
	stats.add_child(K.row(T.call("building"), bname))
	stats.add_child(K.meter_row(T.call("stability"), g.stab[p], K.GREEN if g.stab[p] >= 50 else (K.GOLD2 if g.stab[p] >= 30 else K.RED)))
	stats.add_child(K.meter_row(T.call("happiness"), g.happy[p], K.GREEN if g.happy[p] >= 50 else (K.GOLD2 if g.happy[p] >= 30 else K.RED)))
	var act := HFlowContainer.new(); act.add_theme_constant_override("h_separation", 6); act.add_theme_constant_override("v_separation", 6)
	var portrait := get_viewport_rect().size.y > get_viewport_rect().size.x
	if not portrait: _body.add_child(stats)
	_body.add_child(K.section(T.call("actions")))
	_body.add_child(act)
	if portrait: _body.add_child(stats)       # on a phone the actions come first; the sheet scrolls to the figures
	if mine:
		act.add_child(K.button(T.call("recruit") + " +15", func(): command.emit({"cmd": "recruit", "p": p, "amount": 15})))
		act.add_child(K.button(T.call("hire") + " +40 (%dg)" % int(ceil(40 * 5.0 * float(D.REGIMES[g.regime[me]]["recruitCost"]))), func(): command.emit({"cmd": "hire", "p": p, "amount": 40})))
		if g.army[p] > 1: act.add_child(K.button(T.call("move"), func(): move_requested.emit(p)))
		var ob := OptionButton.new(); ob.custom_minimum_size = Vector2(150, K.MIN_TOUCH); ob.focus_mode = Control.FOCUS_NONE
		ob.add_item(T.call("build") + "…", 0)
		for i in D.BUILDINGS.size():
			var b: Dictionary = D.BUILDINGS[i]
			var cur: int = g.b_level[p] if g.building[p] == i + 1 else 0
			if g.building[p] != 0 and g.building[p] != i + 1: continue
			if cur >= int(b["maxLevel"]): continue
			ob.add_item("%s L%d · %dg" % [T.call("b_" + b["id"]), cur + 1, int(b["cost"][cur])], i + 1)
		ob.item_selected.connect(func(idx: int): if ob.get_item_id(idx) > 0: command.emit({"cmd": "build", "p": p, "b": ob.get_item_id(idx)}))
		act.add_child(ob)
	elif o == 0:
		act.add_child(K.button(T.call("colonize"), func(): command.emit({"cmd": "colonize", "p": p})))
	else:
		if rel == D.REL_WAR:
			act.add_child(K.button(T.call("white_peace"), func(): command.emit({"cmd": "peace", "t": o, "kind": "white"})))
			act.add_child(K.button(T.call("demand_land"), func(): command.emit({"cmd": "peace", "t": o, "kind": "cede"})))
		else:
			var wb := K.button(T.call("declare_war"), func(): command.emit({"cmd": "declareWar", "t": o}))
			wb.add_theme_color_override("font_color", K.RED.lightened(0.3)); act.add_child(wb)
			if rel == D.REL_PEACE:
				act.add_child(K.button(T.call("propose_nap"), func(): command.emit({"cmd": "nap", "t": o})))
				act.add_child(K.button(T.call("propose_ally"), func(): command.emit({"cmd": "ally", "t": o})))
			if rel == D.REL_NAP or rel == D.REL_ALLY:
				act.add_child(K.button(T.call("break_pact"), func(): command.emit({"cmd": "breakPact", "t": o})))
