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
	var same: bool = p == subject and visible and _same_ids(list)         # a rebuild of the same ring (a hover, a refresh) must not replay the pop-in
	subject = p; verbs = list
	if not same: _t = 0.0
	visible = p >= 0 and (not list.is_empty() or _is_armed())
	_hover = -1
	set_process(p >= 0); queue_redraw()

func _same_ids(list: Array) -> bool:
	if list.size() != verbs.size(): return false
	for i in list.size():
		if String(list[i]["id"]) != String(verbs[i]["id"]): return false
	return true

func clear() -> void:
	subject = -1; verbs = []; visible = false; set_process(false)

func set_armed(a: bool) -> void:
	armed = a
	visible = subject >= 0 and (not verbs.is_empty() or _is_armed())
	set_process(subject >= 0); queue_redraw()

func _process(d: float) -> void:
	var want: bool = subject >= 0 and (not verbs.is_empty() or _is_armed())       # while an order is previewed the panel sends no verbs: the armed medallion stays
	if want != visible: visible = want; _t = 0.0
	_t += d
	queue_redraw()

## the demo's ring metrics (desktop stage: R 88; phone stage: rs .66, no verb labels)
func _rs() -> float: return 0.66 if size.y < 560.0 else 1.0
func _radius() -> float: return 88.0 * _rs()
## orders armed (a target is being chosen / previewed): the ring becomes the demo's instrument medallion
func _is_armed() -> bool: return armed or (map != null and map.labels != null and map.labels.order_committed())

## the province the ring is drawn at: the selection, or (armed medallion) the army that is ordered
func _subj() -> int:
	if _is_armed() and map != null and map.labels != null:
		var f: int = map.labels.order_from()
		if f >= 0: return f
	return subject

## where the province sits on screen (ring-local coordinates), or Vector2.INF when it is on the far side of the globe
func _anchor() -> Vector2:
	var sj: int = _subj()
	if g == null or map == null or sj < 0 or sj >= g.P: return Vector2.INF
	var pr: Vector3 = map.project(g.world.lon[sj], g.world.lat[sj])
	if pr.z <= 0.05: return Vector2.INF
	return Vector2(pr.x, pr.y) + map.global_position - global_position

func _layout() -> void:
	_spots.clear()
	var a: Vector2 = _anchor()
	if a == Vector2.INF: _c = Vector2.INF; return
	var R: float = _radius()
	var n: int = verbs.size()
	var reach: float = R + 56.0
	if a.x < -40.0 or a.y < -40.0 or a.x > size.x + 40.0 or a.y > size.y + 40.0:          # the province is not on screen: no ring for it
		_c = Vector2.INF; return
	var c: Vector2 = a
	# keep the whole ring on screen: below the top bar, above the bottom row
	c.x = clampf(c.x, reach, maxf(reach, size.x - reach)); c.y = clampf(c.y, minf(reach + 70.0, size.y * 0.5), maxf(reach + 70.0, size.y - reach - 20.0))
	if avoid_fn.is_valid():                  # the inspector and the rail are tall rectangles: slide sideways clear of them
		for r in avoid_fn.call():
			var rc := Rect2((r as Rect2).position - global_position, (r as Rect2).size)
			if rc.size.y < 140.0: continue
			if Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0).intersects(rc):
				if rc.position.x > c.x: c.x = minf(c.x, rc.position.x - reach - 4.0)
				elif rc.end.x < c.x: c.x = maxf(c.x, rc.end.x + reach + 4.0)
	c.x = clampf(c.x, reach * 0.5, size.x - reach * 0.5)
	_c = c
	for i in n:
		var ang: float = -PI * 0.5 + TAU * float(i) / maxf(1.0, float(n))
		var prim: bool = bool(verbs[i].get("primary", false)) and i == 0
		var rr: float = (28.0 if prim else 23.0) * _rs()
		_spots.append({"p": c + Vector2(cos(ang), sin(ang)) * R, "r": rr, "a": ang})

func _has_point(pt: Vector2) -> bool:
	if not visible or _c == Vector2.INF or _is_armed(): return false
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		if pt.distance_to(s["p"]) <= maxf(float(s["r"]), P.touch() * 0.5): return true
	return false

func _idx_at(pt: Vector2) -> int:
	var best := -1; var bd := 1e9
	if _is_armed(): return -1
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

## the demo's ring icons (IC.move / recruit / build / fortify / attack, 24 box, stroke 2 round): true when drawn, false for a verb the demo has no icon for
func _demo_icon(id: String, c: Vector2, px: float, col: Color, w: float) -> bool:
	var u := px / 24.0
	var paths: Array = []                         # polylines in 24-box coordinates
	var closed: Array = []
	match id:
		"move": paths = [[Vector2(3, 12), Vector2(19, 12)], [Vector2(13, 6), Vector2(19, 12), Vector2(13, 18)]]
		"attack": paths = [[Vector2(4, 20), Vector2(16, 8)], [Vector2(16, 8), Vector2(12, 8)], [Vector2(16, 8), Vector2(16, 12)], [Vector2(20, 20), Vector2(8, 8)], [Vector2(8, 8), Vector2(12, 8)], [Vector2(8, 8), Vector2(8, 12)]]
		"recruit":
			draw_arc(c, 9.0 * u, 0.0, TAU, 32, col, w, true)
			paths = [[Vector2(12, 7.5), Vector2(12, 16.5)], [Vector2(7.5, 12), Vector2(16.5, 12)]]
		"build":
			paths = [[Vector2(4, 20), Vector2(4, 10), Vector2(12, 4), Vector2(20, 10), Vector2(20, 20), Vector2(4, 20)], [Vector2(10, 20), Vector2(10, 14), Vector2(14, 14), Vector2(14, 20)]]
		"fortify":
			paths = [[Vector2(4, 20), Vector2(4, 7), Vector2(7, 7), Vector2(7, 10), Vector2(9.5, 10), Vector2(9.5, 7), Vector2(14.5, 7), Vector2(14.5, 10), Vector2(17, 10), Vector2(17, 7), Vector2(20, 7), Vector2(20, 20), Vector2(4, 20)], [Vector2(10, 20), Vector2(10, 16), Vector2(14, 16), Vector2(14, 20)]]
		_: return false
	for pl in paths:
		var pts := PackedVector2Array()
		for q in pl: pts.append(c + (q - Vector2(12, 12)) * u)
		draw_polyline(pts, col, w, true)
		draw_circle(pts[0], w * 0.5, col); draw_circle(pts[pts.size() - 1], w * 0.5, col)
	return true

const BRASS_A := Color("EBCF85"); const BRASS_B := Color("B38F3E"); const BRASS_C := Color("6F5A27")

## the demo's gBrass: a linear gradient from the top left (#EBCF85) through #B38F3E to the bottom right (#6F5A27) over the ring's bounding box
static func _gbrass(a: float) -> Color:
	var t: float = (2.0 + cos(a) + sin(a)) * 0.25
	return BRASS_A.lerp(BRASS_B, t * 2.0) if t < 0.5 else BRASS_B.lerp(BRASS_C, (t - 0.5) * 2.0)

## graduated marks (the demo's tickMarks): `n` marks from radius r inwards, every `major`-th 1.7 x longer
func _ticks(c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n) - PI * 0.5
		var l: float = len_px * (1.7 if i % major == 0 else 1.0)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r); pts.append(c + d * (r - l))
	draw_multiline(pts, col, w)

## dotted circle (stroke-dasharray "1 5"): dashes of 1 unit every 6 along the circumference, starting at `rot`
func _dots(c: Vector2, r: float, col: Color, w: float, dash: float, gap: float, rot: float = 0.0) -> void:
	var n: int = int(TAU * r / (dash + gap))
	var da: float = dash / r
	for i in n:
		var a: float = rot + float(i) * (dash + gap) / r
		draw_arc(c, r, a, a + da, 2, col, w, true)

func _draw() -> void:
	if g == null or map == null or not visible: return
	_layout()
	if _c == Vector2.INF: return
	var rs: float = _rs()
	var R: float = _radius()
	var n: int = verbs.size()
	var grow: float = 1.0 if not K.motion_ok() else 1.0 - pow(1.0 - clampf(_t / 0.22, 0.0, 1.0), 3.0)
	var army: int = g.army[_subj()] if _subj() >= 0 and _subj() < g.P else 0
	var fb: Font = K.body_b()
	var tx: String = K.fmt(float(army))
	if _is_armed():
		# orders armed: a dark disc, the instrument medallion (r 40) with the army, and a dashed ring turning once per 12 s
		draw_circle(_c, 54.0 * rs * grow, Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.45))
		var mr: float = 40.0 * rs * grow
		draw_circle(_c, mr + 2.0, Color(5.0 / 255.0, 4.0 / 255.0, 3.0 / 255.0, 0.35))
		draw_circle(_c, mr, Color("0f0c09"))
		draw_arc(_c, mr - 0.7, 0.0, TAU, 64, Color(0.788, 0.635, 0.294, 0.85), 1.3, true)
		_ticks(_c, mr - 3.0, 36, 3.2, 5, Color("8f7637"), 0.7)
		var z2: int = P.fs(26.0 * rs)
		if grow > 0.5: draw_string(fb, Vector2(_c.x - P.tw(fb, tx, z2) * 0.5, _c.y + 8.0 * rs), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, TBTokens.c("cream"))
		_dots(_c, 50.0 * rs * grow, Color("E5C77A"), 1.0, 2.0, 5.0, (Time.get_ticks_msec() / 12000.0 * TAU) if K.motion_ok() else 0.0)
		return
	# the dial: a translucent disc, a brass gradient band with graduated marks, a dotted outer ring
	draw_circle(_c, (R + 22.0 * rs) * grow, Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.5))
	var seg: int = 72
	for i in seg:
		var a0: float = TAU * float(i) / seg
		var a1: float = a0 + TAU / seg + 0.03
		draw_arc(_c, R * grow, a0, a1, 3, _gbrass((a0 + a1) * 0.5), 10.0 * rs, true)
	draw_arc(_c, (R - 5.0 * rs) * grow, 0.0, TAU, 72, Color("0f0c09"), 2.0, true)
	_ticks(_c, (R - 6.0 * rs) * grow, 72, 5.0 * rs, 6, Color("C9A24B"), 0.8)
	_dots(_c, (R + 8.0 * rs) * grow, Color(0.788, 0.635, 0.294, 0.7), 0.6, 1.0, 5.0)
	# the centre: the army
	var cr: float = 44.0 * rs * grow
	draw_circle(_c, cr, Color(15.0 / 255.0, 12.0 / 255.0, 9.0 / 255.0, 0.92))
	draw_arc(_c, cr, 0.0, TAU, 48, Color("7F6A33"), 1.0, true)
	if grow > 0.5:
		var z: int = P.fs(30.0 * rs)
		draw_string(fb, Vector2(_c.x - P.tw(fb, tx, z) * 0.5, _c.y + 9.0 * rs), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, z, TBTokens.c("cream"))
		var cf: Font = K.tracked(K.display(), 3)
		var cz: int = maxi(1, int(round(8.5 * rs)))
		var cap: String = TBI18n.T("army").to_upper()
		draw_string(cf, Vector2(_c.x - P.tw(cf, cap, cz) * 0.5, _c.y - 17.0 * rs), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cz, Color("C9A24B"))
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
		if hot and ok:                                                       # .rv:hover  drop-shadow(0 0 8px rgba(229,199,122,.7))
			for gi in 4: draw_circle(pp, rr + 4.0 + 8.0 - float(gi) * 2.5, Color(0.898, 0.78, 0.478, 0.12))
		draw_circle(pp, rr + 4.0, Color("0b0907"))
		var face: Color = Color("C9A24B") if (prim and ok) else Color("1d1812")
		var edge: Color = Color("F1DB9C") if (prim and ok) else Color("B38F3E")
		draw_circle(pp, rr, face)
		draw_arc(pp, rr, 0.0, TAU, 40, edge, 2.0, true)
		var ink: Color = Color("14100b") if (prim and ok) else (TBTokens.c("neg_bar") if danger else Color("E5C77A"))
		if not ok: ink = TBTokens.c("ink_off")
		var ipx: float = 24.0 * (1.1 if prim else 0.95) * rs
		if not _demo_icon(String(v["id"]), pp, ipx, ink, 2.0 * 1.0): P.icon(self, String(v["glyph"]), pp, ipx, ink, 2.0)
		if hot or has_focus():
			draw_arc(pp, rr + 5.5, 0.0, TAU, 36, TBTokens.c("cream"), 1.6, true)
		if not ok: TBHudParts.icon(self, "lock", pp + Vector2(rr * 0.6, rr * 0.6), 11.0, TBTokens.c("neg_bar"), 1.4)
		# labels (desktop stage only): Cinzel 700 12 / ls 2.4, #EFE6CF over a 4 wide #05070a stroke, outside the medallion on the side facing away from the centre
		if st >= 0.6 and rs >= 1.0:
			var lf: Font = K.tracked(K.display(), 2)
			var lz: int = P.fs(12.0)
			var lab: String = String(v["label"])
			lab = lab.to_upper() if TBI18n.lang != "ru" else lab
			lab = P.fit(lf, lab, lz, 150.0)
			var lw: float = P.tw(lf, lab, lz)
			var dir := Vector2(cos(float(s["a"])), sin(float(s["a"])))
			var lp: Vector2
			if absf(dir.x) < 0.3: lp = Vector2(pp.x - lw * 0.5, pp.y - (34.0 + 8.0) if dir.y < 0.0 else pp.y + 34.0 + 19.0)
			elif dir.x > 0.0: lp = Vector2(pp.x + 34.0 + 10.0, pp.y + 5.0)
			else: lp = Vector2(pp.x - 34.0 - 10.0 - lw, pp.y + 5.0)
			var col: Color = Color("EFE6CF") if ok else TBTokens.c("ink_off")
			draw_string_outline(lf, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, 4, Color("05070a"))
			draw_string(lf, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, col)
