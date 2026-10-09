## The command ring (Bezel): the selected province's verbs as brass medallions on a graduated ring around it, the army in the middle.
## It mirrors the inspector's verb list (same ids, same costs, same hotkeys): a press runs the panel's own verb. Pure view over TBProvincePanel.
class_name TBMapRing
extends Control

signal pressed(idx: int)
signal hovered(idx: int)

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")
const BZ = preload("res://src/ui/bezel.gd")

var map: TBMapView
var g: TBGame
var avoid_fn: Callable = Callable()              # () -> Array of global Rect2 the ring keeps clear of (inspector, rail, bar)
var subject := -1
var verbs: Array = []                            # [{id, glyph, label, can, why, primary, danger, hot}]
var armed := false                               # false while an order is being previewed / confirmed: the ring steps aside
var _hover := -1
var _t := 0.0
var _c := Vector2.ZERO                           # ring centre, local
var _spots: Array = []                           # [{p: Vector2, r: float}] per verb, local

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func show_verbs(p: int, list: Array) -> void:
	subject = p; verbs = list
	_t = 0.0
	visible = p >= 0 and not list.is_empty() and not armed
	_hover = -1
	set_process(visible); queue_redraw()

func clear() -> void:
	subject = -1; verbs = []; visible = false; set_process(false)

func set_armed(a: bool) -> void:
	armed = a
	visible = subject >= 0 and not verbs.is_empty() and not armed
	set_process(visible); queue_redraw()

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _radius() -> float:
	var vh: float = size.y
	return clampf(vh * 0.12, 58.0, 92.0)

## where the province sits on screen (ring-local coordinates), or Vector2.INF when it is on the far side of the globe
func _anchor() -> Vector2:
	if g == null or map == null or subject < 0 or subject >= g.P: return Vector2.INF
	var pr: Vector3 = map.project(g.world.lon[subject], g.world.lat[subject])
	if pr.z <= 0.05: return Vector2.INF
	return Vector2(pr.x, pr.y) + map.global_position - global_position

func _layout() -> void:
	_spots.clear()
	var a: Vector2 = _anchor()
	if a == Vector2.INF: _c = Vector2.INF; return
	var R: float = _radius()
	var n: int = verbs.size()
	var reach: float = R + 56.0
	var c: Vector2 = a
	# keep the whole ring on screen and out of the interface
	c.x = clampf(c.x, reach, size.x - reach); c.y = clampf(c.y, reach + 70.0, size.y - reach - 20.0)
	if avoid_fn.is_valid():
		for r in avoid_fn.call():
			var rc := Rect2((r as Rect2).position - global_position, (r as Rect2).size)
			if Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0).intersects(rc):
				if rc.position.x > c.x: c.x = minf(c.x, rc.position.x - reach - 4.0)
				elif rc.end.x < c.x: c.x = maxf(c.x, rc.end.x + reach + 4.0)
	_c = c
	for i in n:
		var ang: float = -PI * 0.5 + TAU * float(i) / maxf(1.0, float(n))
		var prim: bool = bool(verbs[i].get("primary", false)) and i == 0
		var rr: float = (28.0 if prim else 23.0) * clampf(R / 88.0, 0.8, 1.0)
		_spots.append({"p": c + Vector2(cos(ang), sin(ang)) * R, "r": rr, "a": ang})

func _has_point(pt: Vector2) -> bool:
	if not visible or _c == Vector2.INF: return false
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		if pt.distance_to(s["p"]) <= maxf(float(s["r"]), P.touch() * 0.5): return true
	return false

func _idx_at(pt: Vector2) -> int:
	var best := -1; var bd := 1e9
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		var d: float = pt.distance_to(s["p"])
		if d <= maxf(float(s["r"]), P.touch() * 0.5) and d < bd: bd = d; best = i
	return best

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var i := _idx_at((e as InputEventMouseMotion).position)
		if i != _hover:
			_hover = i; hovered.emit(i if i >= 0 else 0); queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed:
		var j := _idx_at((e as InputEventMouseButton).position)
		if j >= 0: pressed.emit(j); accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _idx_at((e as InputEventMouseButton).position) >= 0: accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1; queue_redraw()

func _draw() -> void:
	if g == null or map == null or verbs.is_empty(): return
	_layout()
	if _c == Vector2.INF: return
	var R: float = _radius()
	var n: int = verbs.size()
	var grow: float = 1.0 if not K.motion_ok() else 1.0 - pow(1.0 - clampf(_t / 0.22, 0.0, 1.0), 3.0)
	# the dial: a translucent disc, a brass track with graduated marks
	draw_circle(_c, (R + 30.0) * grow, TBTokens.ca("bar_0", 0.42))
	draw_arc(_c, R * grow, 0.0, TAU, 72, TBTokens.ca("rule", 0.9), 1.5, true)
	BZ.ticks(self, _c, (R - 3.0) * grow, 72, 4.0, 6, TBTokens.ca("rule", 0.8), 1.0)
	# the centre: the army (or nothing for empty ground)
	var cr: float = 33.0 * grow
	var fr: float = BZ.ring(self, _c, cr, 36, TBTokens.c("bar_0"))
	var army: int = g.army[subject] if subject >= 0 and subject < g.P else 0
	var fb: Font = K.body_b()
	var z: int = P.fs(20.0)
	var tx: String = K.fmt(float(army))
	if grow > 0.5:
		draw_string(fb, Vector2(_c.x - P.tw(fb, tx, z) * 0.5, P.base(fb, z, _c.y + 3.0)), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, z, TBTokens.c("cream"))
		if R >= 80.0:
			var cf: Font = K.tracked(K.display(), 1)
			var cz: int = P.fs(12.0)
			var cap: String = TBI18n.T("army").to_upper()
			draw_string(cf, Vector2(_c.x - P.tw(cf, cap, cz) * 0.5, P.base(cf, cz, _c.y - fr * 0.58)), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cz, TBTokens.c("smoke"))
	for i in n:
		var st: float = clampf((_t - 0.04 * i) / 0.2, 0.0, 1.0) if K.motion_ok() else 1.0
		var k: float = 1.0 - pow(1.0 - st, 3.0)
		if k <= 0.0: continue
		var v: Dictionary = verbs[i]
		var s: Dictionary = _spots[i]
		var pp: Vector2 = _c + (Vector2(s["p"]) - _c) * k
		var rr: float = float(s["r"]) * (0.5 + 0.5 * k)
		var ok: bool = bool(v["can"]["ok"])
		var prim: bool = bool(v.get("primary", false)) and i == 0
		var danger: bool = bool(v.get("danger", false))
		var hot: bool = i == _hover
		var face: Color = TBTokens.c("act") if (prim and ok) else (TBTokens.c("bar_2") if hot else TBTokens.c("bar_0"))
		if not ok: face = TBTokens.c("bar_0")
		var fr2: float = BZ.ring(self, pp, rr, 0 if rr < 22.0 else 30, face)
		var ink: Color = TBTokens.c("on_act") if (prim and ok) else (TBTokens.c("neg_bar") if danger else TBTokens.c("brass_lt"))
		if not ok: ink = TBTokens.c("ink_off")
		P.icon(self, String(v["glyph"]), pp, fr2 * 1.25, ink, 1.7)
		if hot or has_focus():
			draw_arc(pp, rr + 2.5, 0.0, TAU, 36, TBTokens.c("cream"), 1.6, true)
		if not ok: TBHudParts.icon(self, "lock", pp + Vector2(rr * 0.6, rr * 0.6), 11.0, TBTokens.c("neg_bar"), 1.4)
		# the label sits outside the medallion, on the side facing away from the centre
		if st >= 0.6:
			var lf: Font = K.tracked(K.display(), 1)
			var lz: int = P.fs(12.0)
			var lab: String = String(v["label"])
			lab = lab.to_upper() if TBI18n.lang != "ru" else lab
			lab = P.fit(lf, lab, lz, 150.0)
			var lw: float = P.tw(lf, lab, lz)
			var dir := Vector2(cos(float(s["a"])), sin(float(s["a"])))
			var lp: Vector2
			if absf(dir.x) < 0.3: lp = Vector2(pp.x - lw * 0.5, pp.y + dir.y * (rr + 16.0) + (0.0 if dir.y > 0.0 else 0.0))
			elif dir.x > 0.0: lp = Vector2(pp.x + rr + 6.0, pp.y + 4.0)
			else: lp = Vector2(pp.x - rr - 6.0 - lw, pp.y + 4.0)
			var col: Color = TBTokens.c("cream") if (ok and (hot or prim)) else (TBTokens.c("smoke") if ok else TBTokens.c("ink_off"))
			P.txt_o(self, lf, lp, lab, lz, col)
