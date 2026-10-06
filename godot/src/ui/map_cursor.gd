## Keyboard route to the map (A11Y-KBD-004, GES-001/002). Arrow keys move a province cursor to the neighbour nearest in that direction,
## Enter selects it (or orders the selected army there when it is a lit target), Shift+Enter orders explicitly, Esc drops the cursor, `,` `.`
## step through alerts, Shift+arrows pan, + / - zoom, Home recentres, V opens the Provinces / Armies list. The cursor is a static double ring
## with corner brackets (drawn by TBMapLabels) plus the hover card text beside it. `install(main)` adds this node and the on-screen nav pad.
class_name TBMapCursor
extends Node

static var T: Callable = TBI18n.T

var main: Node
var map: TBMapView
var flow: TBOrderFlow
var active := false              # the cursor was moved by keys and has not been applied or dropped yet
var _tip: TBMapTip

static func install(m: Node) -> TBMapCursor:
	var c := TBMapCursor.new()
	m.add_child(c); c.setup(m)
	var pad := TBNavPad.new()
	m.add_child(pad); pad.setup(m)
	return c

func setup(m: Node) -> void:
	main = m; map = m.map; flow = m.flow
	_tip = TBMapTip.new(); m.add_child(_tip)
	map.province_picked.connect(func(_p: int, _s: bool): drop())

func _live() -> bool:
	if main == null or main.mode != "game" or main.g == null or main._busy: return false
	if main._overlay.get_child_count() > 0: return false
	var f := get_viewport().gui_get_focus_owner()
	return f == null or f == map

func drop() -> void:
	if not active: return
	active = false
	if flow.focus_p == map.focus_province: flow.focus_p = -1
	map.focus_province = -1
	_tip.visible = false
	map.labels.queue_redraw()

## the neighbour of `from` nearest in screen direction `dir` (unit), or -1
func neighbour_toward(from: int, dir: Vector2) -> int:
	var g: TBGame = main.g
	var a := map.project(g.world.lon[from], g.world.lat[from])
	var best := -1; var best_s := INF
	for lim in [deg_to_rad(65.0), deg_to_rad(95.0)]:                # a tight cone first, then a wider one
		for e in range(g.nb_off[from], g.nb_off[from + 1]):
			var q: int = g.nb[e]
			var b := map.project(g.world.lon[q], g.world.lat[q])
			if b.z <= 0.05: continue
			var v := Vector2(b.x - a.x, b.y - a.y)
			var d := v.length()
			if d < 0.5: continue
			var ang := absf(v.angle_to(dir))
			if ang > lim: continue
			var s := d * (1.0 + ang * 1.6)
			if s < best_s: best_s = s; best = q
		if best >= 0: break
	return best

func _start() -> int:
	var g: TBGame = main.g
	if map.focus_province >= 0: return map.focus_province
	if main.selected >= 0: return main.selected
	return g.capital_of[g.human_id]

func move(dir: Vector2) -> void:
	var from := _start()
	if from < 0: return
	var to := from if not active else neighbour_toward(from, dir)
	if not active:
		active = true                                              # the first press only shows where the cursor starts
		if to < 0: to = from
	elif to < 0: return
	flow.g = main.g
	map.focus_province = to
	flow.focus_p = to
	var pt := map.project(main.g.world.lon[to], main.g.world.lat[to])
	var vs := map.size
	var inner := Rect2(vs * 0.18, vs * 0.64)
	if pt.z <= 0.2 or not inner.has_point(Vector2(pt.x, pt.y)): map.fly_to(main.g.world.lon[to], main.g.world.lat[to])
	map.labels.queue_redraw()
	_show_tip(to)

func _show_tip(p: int) -> void:
	if p < 0: _tip.visible = false; return
	_tip.show_for(main.g, p, flow)
	var pt := map.project(main.g.world.lon[p], main.g.world.lat[p])
	_tip.position = (Vector2(pt.x, pt.y) + Vector2(30, 24)).clamp(Vector2.ZERO, main.size - _tip.size)

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or main == null or not _live(): return
	var k: InputEventKey = e
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed: return
	var used := true
	match k.keycode:
		KEY_LEFT: _arrow(Vector2.LEFT, k.shift_pressed)
		KEY_RIGHT: _arrow(Vector2.RIGHT, k.shift_pressed)
		KEY_UP: _arrow(Vector2.UP, k.shift_pressed)
		KEY_DOWN: _arrow(Vector2.DOWN, k.shift_pressed)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: map.zoom_by(1.4, true)
		KEY_MINUS, KEY_KP_SUBTRACT: map.zoom_by(1.0 / 1.4, true)
		KEY_HOME:
			var g: TBGame = main.g
			var p: int = main.selected if main.selected >= 0 else g.capital_of[g.human_id]
			if p >= 0: map.fly_to(g.world.lon[p], g.world.lat[p])
		KEY_PERIOD: if not k.echo: main.hud.cycle_alert(1)
		KEY_COMMA: if not k.echo: main.hud.cycle_alert(-1)
		KEY_V: if not k.echo: TBMapList.open(main._overlay, main.g, map, Callable(main, "_goto_province"))
		KEY_ESCAPE:
			if active: drop()
			else: used = false
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			used = false
			if not k.echo and active and flow.mode != TBOrderFlow.Mode.PREVIEW: used = _apply(k.shift_pressed)
		_: used = false
	if used: get_viewport().set_input_as_handled()

## arrow key: the province cursor, or with Shift a camera pan (the map moves opposite to the arrow)
func _arrow(dir: Vector2, shift: bool) -> void:
	if shift: _pan(-dir)
	else: move(dir)

func _pan(dir: Vector2) -> void:
	map.drag_by(dir * minf(map.size.x, map.size.y) * 0.16)

## Enter on the cursor: order the selected army there when it is a lit target, otherwise select the province. Shift+Enter always orders.
func _apply(explicit: bool) -> bool:
	var c := map.focus_province
	if c < 0: return false
	flow.g = main.g
	active = false
	_tip.visible = false
	if flow.src >= 0 and c != flow.src and (explicit or flow.targets.has(c)):
		flow.pick(c, true, false)
	else:
		main._select(c)
	map.labels.queue_redraw()
	return true
