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
		offset_left = -346; offset_right = -8; offset_top = 64; offset_bottom = -84
	else:              # portrait: bottom sheet
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		offset_left = 6; offset_right = -6; offset_top = -330; offset_bottom = -76

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
	var head := K.hbox(6)
	var title := K.label(("★ " if g.capital[p] != 0 else "") + w.name[p], 20, K.GOLD2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := K.button("✕", func(): closed.emit()); x.custom_minimum_size = Vector2(40, 40)
	head.add_child(x)
	_body.add_child(head)
	var sub := K.hbox(6)
	if o != 0:
		sub.add_child(K.color_chip(g.color[o]))
		sub.add_child(K.label(g.nat_name[o], 15))
		var inf := K.button("ℹ", func(): nation_requested.emit(o)); inf.custom_minimum_size = Vector2(36, 32); sub.add_child(inf)
		if rel == D.REL_WAR: sub.add_child(K.label("⚔ " + T.call("war"), 13, K.RED))
		elif rel == D.REL_ALLY: sub.add_child(K.label("🤝 " + T.call("ally"), 13, Color(0.55, 0.72, 1.0)))
		elif rel == D.REL_NAP: sub.add_child(K.label(T.call("nap"), 13, Color(0.5, 0.86, 0.89)))
		if g.overlord[o] != 0: sub.add_child(K.label(T.call("vassal"), 13, K.DIM))
	else:
		sub.add_child(K.label(T.call("neutral"), 15, K.DIM))
	_body.add_child(sub)
	if g.occupier[p] != 0:
		_body.add_child(K.label(T.call("occupied_by", {"nation": g.nat_name[g.occupier[p]]}), 13, K.RED))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	_body.add_child(grid)
	var bname: String = T.call("none")
	if g.building[p] != 0: bname = "%s %d" % [T.call("b_" + D.BUILDINGS[g.building[p] - 1]["id"]), g.b_level[p]]
	elif g.b_building[p] != 0: bname = "⏳ %s (%d)" % [T.call("b_" + D.BUILDINGS[g.b_building[p] - 1]["id"]), g.b_turns[p]]
	for row in [[T.call("army"), K.fmt(g.army[p])], [T.call("pop"), K.fmt(g.pop[p] * 1000)], [T.call("dev"), "%d/5" % g.dev[p]], ["Econ", "%d/5" % g.econ[p]],
			[T.call("stability"), str(g.stab[p])], [T.call("happiness"), str(g.happy[p])], [T.call("terrain"), T.call("t_" + D.TERRAIN_ID[g.terrain[p]])], [T.call("building"), bname]]:
		grid.add_child(K.label(row[0], 13, K.DIM)); grid.add_child(K.label(row[1], 14))
	var bar := ProgressBar.new(); bar.max_value = 100; bar.value = g.stab[p]; bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 6)
	_body.add_child(bar)
	var act := HFlowContainer.new(); act.add_theme_constant_override("h_separation", 6); act.add_theme_constant_override("v_separation", 6)
	_body.add_child(act)
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
