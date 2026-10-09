## Treaty and trade routes on the map (Bezel): a curve from your capital to theirs for every pact, trade deal and war you have.
## pact = brass line with a diamond seal, alliance = a thicker line, marriage = a double line, trade = teal dashes with gold loads moving along it
## and the income in gold, war = rust dots. New routes draw themselves in. Pure view: it reads the game and never changes it.
class_name TBMapRoutes
extends Control

const D = preload("res://src/engine/data.gd")
const K = preload("res://src/ui/ui_kit.gd")

var map: TBMapView
var g: TBGame
var _seen: Dictionary = {}               # route key -> seconds since it appeared
var _t := 0.0
var _live := 0                           # routes drawn in the last frame (a map with none costs nothing)
const SEG := 28

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func attach(view: TBMapView) -> void: map = view
func set_game(game: TBGame) -> void:
	g = game; _seen.clear(); queue_redraw()

func _process(d: float) -> void:
	if g == null or not is_visible_in_tree() or g.human_id <= 0: return
	_t += d
	for k in _seen.keys(): _seen[k] = float(_seen[k]) + d
	if _live > 0 or not _seen.is_empty(): queue_redraw()

## capital of n as a unit vector and lon/lat degrees
func _cap(n: int) -> Array:
	var p: int = g.capital_of[n]
	if p < 0 or p >= g.P: return []
	return [g.world.lon[p], g.world.lat[p]]

## points of the great circle between two lon/lat (degrees), projected; each [Vector2, visible]
func _arc(a: Array, b: Array, bend: float) -> Array:
	var u := _unit(a); var v := _unit(b)
	var ang: float = acos(clampf(u.dot(v), -1.0, 1.0))
	var via := Vector3.ZERO                  # exactly opposite capitals have no single great circle: go by way of a point a quarter turn off
	if ang > PI - 0.01:
		via = u.cross(Vector3.UP)
		if via.length() < 0.01: via = u.cross(Vector3.RIGHT)
		via = via.normalized()
	var pts: Array = []
	for i in SEG + 1:
		var f: float = float(i) / SEG
		var w: Vector3
		if via != Vector3.ZERO: w = _slerp(u, via, f * 2.0) if f < 0.5 else _slerp(via, v, f * 2.0 - 1.0)
		elif ang < 0.001: w = u.lerp(v, f)
		else: w = (u * sin((1.0 - f) * ang) + v * sin(f * ang)) / sin(ang)
		var lat: float = rad_to_deg(asin(clampf(w.y, -1.0, 1.0)))
		var lon: float = rad_to_deg(atan2(w.x, w.z))
		var pr: Vector3 = map.project(lon, lat)
		pts.append([Vector2(pr.x, pr.y), pr.z > 0.02])
	if bend != 0.0 and pts.size() > 2:                               # lateral offset in screen space so a pact and a trade line do not lie on top of each other
		var p0: Vector2 = pts[0][0]; var p1: Vector2 = pts[SEG][0]
		var nrm: Vector2 = (p1 - p0).orthogonal().normalized()
		var span: float = (p1 - p0).length()
		for i in pts.size():
			pts[i][0] = Vector2(pts[i][0]) + nrm * sin(PI * float(i) / SEG) * bend * minf(span, 600.0) * 0.12
	return pts

## slerp between two unit vectors a quarter turn apart (never degenerate)
static func _slerp(a: Vector3, b: Vector3, f: float) -> Vector3:
	var ang: float = acos(clampf(a.dot(b), -1.0, 1.0))
	if ang < 0.001: return a
	return (a * sin((1.0 - f) * ang) + b * sin(f * ang)) / sin(ang)

static func _unit(ll: Array) -> Vector3:
	var lon: float = deg_to_rad(float(ll[0])); var lat: float = deg_to_rad(float(ll[1]))
	var cl: float = cos(lat)
	return Vector3(cl * sin(lon), sin(lat), cl * cos(lon))

func _draw() -> void:
	if g == null or map == null or g.human_id <= 0 or not map.is_inside_tree(): return
	if map.size.x < 8.0: return
	var me: int = g.human_id
	var a: Array = _cap(me)
	if a.is_empty(): return
	var alive_keys: Dictionary = {}
	_live = 0
	for o in range(1, g.N1):
		if o == me or g.alive[o] == 0 or o == g.rebel: continue
		var b: Array = _cap(o)
		if b.is_empty(): continue
		var rel: int = g.get_rel(me, o)
		if rel == D.REL_WAR: _route(a, b, "war", "w%d" % o, 0.0, alive_keys, 0)
		elif rel == D.REL_ALLY: _route(a, b, "ally", "a%d" % o, 1.0, alive_keys, 0)
		elif rel == D.REL_NAP: _route(a, b, "nap", "n%d" % o, 1.0, alive_keys, 0)
		elif rel == D.REL_MARRIAGE: _route(a, b, "marry", "m%d" % o, 1.0, alive_keys, 0)
		if g.rules >= 1 and TBTrade.has(g, me, o): _route(a, b, "trade", "t%d" % o, -1.0, alive_keys, TBTrade.value(g, o))
	for k in _seen.keys():
		if not alive_keys.has(k): _seen.erase(k)

func _route(a: Array, b: Array, kind: String, key: String, bend: float, alive: Dictionary, income: int) -> void:
	alive[key] = true; _live += 1
	if not _seen.has(key): _seen[key] = 0.0 if K.motion_ok() else 99.0
	var grow: float = clampf(float(_seen[key]) / 1.3, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var pts: Array = _arc(a, b, bend)
	var col: Color = TBTokens.c("brass_lt")
	var w := 2.0
	match kind:
		"war": col = TBTokens.c("neg_bar")
		"trade": col = TBTokens.c("pos_bar")
		"ally": w = 3.2
		"nap": w = 1.8
		"marry": w = 2.2
	var halo: Color = TBTokens.with_a(TBTokens.HALO, 0.7)
	var last: int = int(round(SEG * grow))
	var run: PackedVector2Array = PackedVector2Array()
	var runs: Array = []
	for i in last + 1:
		if bool(pts[i][1]):
			if run.size() > 0 and absf(run[run.size() - 1].x - Vector2(pts[i][0]).x) > map.size.x * 0.5:       # flat map: the arc crossed the date line
				if run.size() > 1: runs.append(run)
				run = PackedVector2Array()
			run.append(pts[i][0])
		elif run.size() > 1: runs.append(run); run = PackedVector2Array()
		else: run = PackedVector2Array()
	if run.size() > 1: runs.append(run)
	for r in runs:
		var rr: PackedVector2Array = r
		match kind:
			"war":
				_dotted(rr, halo, col, 3.5, 9.0)
			"trade":
				_dashed(rr, halo, col, w, 10.0, 7.0)
			"nap":
				_dashed(rr, halo, col, w, 12.0, 5.0)
			"marry":
				draw_polyline(rr, halo, w + 3.0, true); draw_polyline(rr, col, w, true)
				draw_polyline(rr, TBTokens.c("bar_0"), 0.8, true)
			_:
				draw_polyline(rr, halo, w + 3.0, true); draw_polyline(rr, col, w, true)
	if grow < 1.0: return
	# midpoint seal / income / moving loads
	var mid: int = SEG / 2
	var mp: Vector2 = pts[mid][0]
	if bool(pts[mid][1]) and bool(pts[0][1]) or bool(pts[mid][1]):
		if kind != "war":
			var s: float = 5.5 if kind != "nap" else 4.0
			draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -s), mp + Vector2(s, 0), mp + Vector2(0, s), mp + Vector2(-s, 0)]), TBTokens.c("bar_0"))
			var ring := PackedVector2Array([mp + Vector2(0, -s), mp + Vector2(s, 0), mp + Vector2(0, s), mp + Vector2(-s, 0), mp + Vector2(0, -s)])
			draw_polyline(ring, col, 1.6, true)
		if kind == "trade":
			var f: Font = K.body_b()
			var tx: String = "+%d" % income
			draw_string_outline(f, mp + Vector2(-f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -10.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, TBTokens.HALO)
			draw_string(f, mp + Vector2(-f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -10.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TBTokens.c("brass_lt"))
			if K.motion_ok():
				for ph in [0.0, 0.5]:                                  # gold goes out, goods come back
					var q: float = fposmod(_t * 0.12 + ph, 1.0)
					var p1: Vector2 = _at(pts, q)
					if p1 != Vector2.INF:
						draw_circle(p1, 4.2, TBTokens.HALO); draw_circle(p1, 3.0, TBTokens.c("brass_lt"))
				var p2: Vector2 = _at(pts, 1.0 - fposmod(_t * 0.12 + 0.25, 1.0))
				if p2 != Vector2.INF:
					draw_circle(p2, 4.0, TBTokens.HALO); draw_circle(p2, 2.8, TBTokens.c("pos_bar"))

func _at(pts: Array, f: float) -> Vector2:
	var i: int = clampi(int(f * SEG), 0, SEG - 1)
	if not (bool(pts[i][1]) and bool(pts[i + 1][1])): return Vector2.INF
	return Vector2(pts[i][0]).lerp(Vector2(pts[i + 1][0]), f * SEG - i)

func _dashed(pl: PackedVector2Array, halo: Color, col: Color, w: float, on: float, off: float) -> void:
	var carry := 0.0
	var drawing := true
	for i in pl.size() - 1:
		var a: Vector2 = pl[i]; var b: Vector2 = pl[i + 1]
		var seg: float = a.distance_to(b)
		if seg < 0.01: continue
		var dir: Vector2 = (b - a) / seg
		var pos := 0.0
		while pos < seg:
			var rem: float = (on if drawing else off) - carry
			var step: float = minf(rem, seg - pos)
			if drawing:
				draw_line(a + dir * pos, a + dir * (pos + step), halo, w + 3.0)
				draw_line(a + dir * pos, a + dir * (pos + step), col, w)
			pos += step; carry += step
			if carry >= (on if drawing else off) - 0.001: carry = 0.0; drawing = not drawing

func _dotted(pl: PackedVector2Array, halo: Color, col: Color, r: float, gap: float) -> void:
	var carry := 0.0
	for i in pl.size() - 1:
		var a: Vector2 = pl[i]; var b: Vector2 = pl[i + 1]
		var seg: float = a.distance_to(b)
		if seg < 0.01: continue
		var dir: Vector2 = (b - a) / seg
		var pos: float = gap - carry if carry > 0.0 else 0.0
		while pos <= seg:
			draw_circle(a + dir * pos, r * 0.5 + 1.2, halo); draw_circle(a + dir * pos, r * 0.5, col)
			pos += gap
		carry = fposmod(seg - (pos - gap), gap)
