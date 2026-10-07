## On-screen navigation controls (A11Y-GES-001): four pan arrows, zoom + / -, recentre and the Provinces / Armies list. Small flat dark plates in
## the bottom-left corner above the dock, so every pointer gesture (drag, pinch, wheel) has a single-tap equivalent. Shown by Settings `navpad`:
## "auto" (touch screens, text size >= 150 %, Large targets), "on" or "off". Holding a pan or zoom button repeats. Never animates the camera
## under reduced motion beyond what TBMapView already does (instant).
class_name TBNavPad
extends Control

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
static var setting := "auto"             # "auto" | "on" | "off" (main copies cfg["navpad"] here)

var main: Node
var map: TBMapView
var _btns: Array = []
var _t := 0.0

class NavBtn extends Button:
	var kind := ""
	var repeat := false
	var _hold := 0.0
	func _init(k: String, label: String, cb: Callable, rep: bool) -> void:
		kind = k; repeat = rep
		var s := TBKit.touch()
		custom_minimum_size = Vector2(s, s)
		focus_mode = Control.FOCUS_ALL; flat = true
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS if rep else BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		TBKit.a11y(self, label, "button")
		pressed.connect(cb)
		set_process(rep)
	var _cb_hold: Callable
	func _process(delta: float) -> void:
		if not button_pressed: _hold = 0.0; return
		_hold += delta
		if _hold > 0.4: pressed.emit(); _hold = 0.32          # repeat ~ 12 Hz after a short delay
	func _draw() -> void:
		var vis := mini(int(minf(size.x, size.y)) - 8, 40)
		var r := Rect2(((size - Vector2(vis, vis)) * 0.5).round(), Vector2(vis, vis))
		var down := button_pressed
		var fill := TBTokens.c("bar_2" if (down or is_hovered()) else "bar_0")
		fill.a = 0.92
		draw_style_box(TBKit.flat_plate(fill, 4), r)
		draw_rect(r, TBTokens.c("rule_dark"), false, 1.0)
		var c := r.get_center()
		var col := TBTokens.c("cream")
		var k := float(vis) * 0.22
		match kind:
			"up": draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 1.2, k * 0.8), c + Vector2(-k * 1.2, k * 0.8)]), col)
			"down": draw_colored_polygon(PackedVector2Array([c + Vector2(0, k), c + Vector2(k * 1.2, -k * 0.8), c + Vector2(-k * 1.2, -k * 0.8)]), col)
			"left": draw_colored_polygon(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(k * 0.8, k * 1.2), c + Vector2(k * 0.8, -k * 1.2)]), col)
			"right": draw_colored_polygon(PackedVector2Array([c + Vector2(k, 0), c + Vector2(-k * 0.8, k * 1.2), c + Vector2(-k * 0.8, -k * 1.2)]), col)
			"zoom_in":
				draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), col, 3.0); draw_line(c + Vector2(0, -k), c + Vector2(0, k), col, 3.0)
			"zoom_out": draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), col, 3.0)
			"home":
				draw_arc(c, k, 0.0, TAU, 20, col, 2.0, true)
				draw_line(c + Vector2(-k * 1.6, 0), c + Vector2(-k * 0.5, 0), col, 2.0); draw_line(c + Vector2(k * 0.5, 0), c + Vector2(k * 1.6, 0), col, 2.0)
				draw_line(c + Vector2(0, -k * 1.6), c + Vector2(0, -k * 0.5), col, 2.0); draw_line(c + Vector2(0, k * 0.5), c + Vector2(0, k * 1.6), col, 2.0)
			"list":
				for i in 3:
					var y := c.y + (i - 1) * k * 0.95
					draw_rect(Rect2(c.x - k * 1.3, y - 1.0, 2.0, 2.0), col)
					draw_line(Vector2(c.x - k * 0.6, y), Vector2(c.x + k * 1.4, y), col, 2.0)
		if has_focus(): draw_style_box(TBFrame.focus(true, 4, 0), r)

func setup(m: Node) -> void:
	main = m; map = m.map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2); grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	var defs := [
		["left", "nav_left", func(): _pan(Vector2(1, 0)), true], ["up", "nav_up", func(): _pan(Vector2(0, 1)), true],
		["down", "nav_down", func(): _pan(Vector2(0, -1)), true], ["right", "nav_right", func(): _pan(Vector2(-1, 0)), true],
		["zoom_in", "nav_zoom_in", func(): map.zoom_by(1.4, true), true], ["zoom_out", "nav_zoom_out", func(): map.zoom_by(1.0 / 1.4, true), true],
		["home", "nav_home", func(): recentre(), false], ["list", "nav_list", func(): open_list(), false]]
	for d in defs:
		var b := NavBtn.new(d[0], T.call(d[1]), d[2], d[3])
		grid.add_child(b); _btns.append(b)
	visible = false

## pan by a fraction of the view; dir points the way the MAP moves under the finger (so "left" shows more of the west)
func _pan(dir: Vector2) -> void:
	var step := minf(map.size.x, map.size.y) * 0.16
	map.drag_by(dir * step)

func recentre() -> void:
	var g: TBGame = main.g
	var p: int = main.selected if main.selected >= 0 else g.capital_of[g.human_id]
	if p >= 0: map.fly_to(g.world.lon[p], g.world.lat[p])

func open_list() -> void:
	TBMapList.open(main._overlay, main.g, map, Callable(main, "_goto_province"))

func _should_show() -> bool:
	if main == null or main.mode != "game" or main.g == null or not main.hud.visible: return false
	if main._overlay.get_child_count() > 0: return false
	match setting:
		"on": return true
		"off": return false
	return TBKit.text_scale >= 1.5 or TBKit.touch_large         # off by default: pinch / wheel / drag already move the map

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0: return
	_t = 0.2
	var show := _should_show()
	if visible != show: visible = show
	if not show: return
	var gr: Control = get_child(0)
	var sz := gr.get_combined_minimum_size()
	gr.size = sz
	size = sz
	# bottom-left, above the dock; slide clear of anything the HUD or the command card covers
	var vp: Vector2 = main.size
	var origin: Vector2 = main.get_global_rect().position
	var kos: Array = main.hud.keepouts()
	if main.panel.visible: kos.append(main.panel.get_global_rect())
	var pos := Vector2(12.0, vp.y - sz.y - 12.0)
	for iter in 6:
		var hit := false
		for k in kos:
			var kr := Rect2((k as Rect2).position - origin, (k as Rect2).size)
			var r := Rect2(pos, sz)
			if kr.intersects(r):
				hit = true
				if kr.end.x + 8.0 + sz.x < vp.x * 0.5 and kr.size.y < vp.y * 0.8 and kr.position.x < 120.0: pos.x = kr.end.x + 8.0      # a left rail: step right of it
				else: pos.y = kr.position.y - sz.y - 8.0
				break
		if not hit: break
	position = pos
