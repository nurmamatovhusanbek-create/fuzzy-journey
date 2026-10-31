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
var _sig_t := 0.0
var _rel_sig := 0
var _live := 0                           # routes drawn in the last frame (a map with none costs nothing)
const SEG := 28

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func attach(view: TBMapView) -> void: map = view
func set_game(game: TBGame) -> void:
	g = game; _seen.clear(); queue_redraw()

var _sig := 0
var _anim := false
var _hits: Array = []                     # [{kind, runs}] the lines drawn last frame (Routes lens), for picking one with the pointer

## the kind of the route line nearest to `pos` (control-local px) within a few px, or ""
func pick_route(pos: Vector2) -> String:
	var best := 9.0; var kind := ""
	for h in _hits:
		for r in (h["runs"] as Array):
			var run: PackedVector2Array = r
			for i in run.size() - 1:
				var d: float = Geometry2D.get_closest_point_to_segment(pos, run[i], run[i + 1]).distance_to(pos)
				if d < best: best = d; kind = String(h["kind"])
	return kind

func _process(d: float) -> void:
	if g == null or not is_visible_in_tree() or g.human_id <= 0: return
	_t += d
	for k in _seen.keys(): _seen[k] = float(_seen[k]) + d
	# a new pact, trade deal or war shows up at once (it used to wait for the camera to move), the camera moves the lines, and while a line grows in or a load travels it keeps drawing
	_sig_t += d
	if _sig_t >= 0.15 or _rel_sig == 0:
		_sig_t = 0.0; _rel_sig = hash([hash(g.rel), hash(g.trade)])                    # two big arrays: hashing them every frame cost more than drawing the lines
	var sig: int = hash([_rel_sig, g.human_id, map.lon0, map.lat0, map.zoom, map.size, map.mode, g.turn, map.lenses.mode, map.lenses.route_kind, _march_sig()])
	if sig != _sig: _sig = sig; queue_redraw()
	elif _anim and K.motion_ok(): queue_redraw()                     # only a line growing in or a trade load on its way needs frames; a still route is not redrawn

## capital of n as a unit vector and lon/lat degrees
func _cap(n: int) -> Array:
	var p: int = g.capital_of[n]
	if p < 0 or p >= g.P: return []
	return [g.world.lon[p], g.world.lat[p]]

## points of the great circle between two lon/lat (degrees), projected; each [Vector2, visible]
func _arc(a: Array, b: Array, bend: float) -> Array:
	if map.mode == 1: return _flat_line(a, b, bend)
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
			pts[i][0] = Vector2(pts[i][0]) + nrm * sin(PI * float(i) / SEG) * bend * (span * 0.085 if map.atlas_look() else minf(span, 600.0) * 0.12)       # demo: control point .17 x length off the chord
	return pts

## flat map: the great circle swings over the pole in Mercator, so the line is straight on the paper, the short way round the sideways wrap (x continues past the edge, never jumps)
func _flat_line(a: Array, b: Array, bend: float) -> Array:
	var pa: Vector3 = map.project(float(a[0]), float(a[1]))
	var pb: Vector3 = map.project(float(b[0]), float(b[1]))
	var xb: float = pa.x + deg_to_rad(wrapf(float(b[0]) - float(a[0]), -180.0, 180.0)) * map.flat_scale()
	var p0 := Vector2(pa.x, pa.y); var p1 := Vector2(xb, pb.y)
	var nrm: Vector2 = (p1 - p0).orthogonal().normalized() if p1.distance_to(p0) > 0.001 else Vector2.ZERO
	var span: float = p0.distance_to(p1)
	var pts: Array = []
	for i in SEG + 1:
		var f: float = float(i) / SEG
		var q: Vector2 = p0.lerp(p1, f)
		if bend != 0.0: q += nrm * sin(PI * f) * bend * minf(span, 600.0) * 0.12      # the same sideways bow as on the globe, so a pact and a trade line do not lie on top of each other
		pts.append([q, true])
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

## the standing march orders as a number (where each army stands and where it is bound), so the lines are redrawn when one steps, is given or lapses
func _march_sig() -> int:
	var h := g.marches.size()
	for m in g.marches: h = h * 31 + int(m["at"]) * 7 + int(m["to"])
	return h

var _mpath: Dictionary = {}              # at * 100000 + to -> [stamp, PackedInt32Array]: the way an order runs (worked out once per turn, not per frame)

func _march_way(m: Dictionary) -> PackedInt32Array:
	var key: int = int(m["at"]) * 100000 + int(m["to"])
	var stamp: int = g.turn * 100003 + g.occ_rev
	if _mpath.has(key) and int(_mpath[key][0]) == stamp: return _mpath[key][1]
	var pl := TBMarch.plan(g, int(m["n"]), int(m["at"]), int(m["to"]))
	var way: PackedInt32Array = pl["path"] if bool(pl["ok"]) else PackedInt32Array([int(m["at"]), int(m["to"])])
	_mpath[key] = [stamp, way]
	return way

## your armies' standing orders: a thin dashed line from where each army stands to where it is bound, held from turn to turn until it arrives (the trade route's weight, in brass)
func _draw_marches() -> void:
	if g.marches.is_empty() or map.size.x < 8.0: return
	if _mpath.size() > 64: _mpath.clear()
	var atlas: bool = map.atlas_look()
	var col: Color = TBTokens.c("brass_lt")
	var halo: Color = Color(0, 0, 0, 0)                                             # no dark casing under an army's route: one thin brass line
	col.a = 0.9
	for m in g.marches:
		if int(m["n"]) != g.human_id: continue
		var way := _march_way(m)
		var run := PackedVector2Array()
		var runs: Array = []
		for i in way.size() - 1:
			var a: int = way[i]; var b: int = way[i + 1]
			var u := _unit([g.world.lon[a], g.world.lat[a]]); var v := _unit([g.world.lon[b], g.world.lat[b]])
			var steps := 6
			for k in steps + 1:
				if k == 0 and i > 0: continue
				var w: Vector3 = _slerp(u, v, float(k) / steps) if u.dot(v) < 0.999 else u
				var pr: Vector3 = map.project(rad_to_deg(atan2(w.x, w.z)), rad_to_deg(asin(clampf(w.y, -1.0, 1.0))))
				if pr.z > 0.02:
					var q := Vector2(pr.x, pr.y)
					if run.size() > 0 and absf(run[run.size() - 1].x - q.x) > map.size.x * 0.5:             # flat map: across the date line
						if run.size() > 1: runs.append(run)
						run = PackedVector2Array()
					run.append(q)
				else:
					if run.size() > 1: runs.append(run)
					run = PackedVector2Array()
		if run.size() > 1: runs.append(run)
		for r in runs: _dashed(r, halo, col, 1.8 if atlas else 2.0, 3.0 if atlas else 8.0, 6.0 if atlas else 7.0)
		var td: Vector3 = map.project(g.world.lon[int(m["to"])], g.world.lat[int(m["to"])])
		if td.z > 0.02:                                                                                # the end of the way: an arrowhead along the last stride, and the strides still to walk
			var c := Vector2(td.x, td.y)
			var pv: Vector3 = map.project(g.world.lon[way[maxi(0, way.size() - 2)]], g.world.lat[way[maxi(0, way.size() - 2)]])
			var dir: Vector2 = (c - Vector2(pv.x, pv.y)).normalized() if pv.z > 0.02 and Vector2(pv.x, pv.y).distance_to(c) > 2.0 else Vector2.ZERO
			if dir == Vector2.ZERO:
				var sz := 4.5
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz, 0), c + Vector2(0, sz), c + Vector2(-sz, 0)]), TBTokens.c("bar_0"))
				draw_polyline(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz, 0), c + Vector2(0, sz), c + Vector2(-sz, 0), c + Vector2(0, -sz)]), col, 1.4, true)
			else:
				var nrm: Vector2 = dir.orthogonal()
				var head := PackedVector2Array([c + dir * 2.0, c - dir * 9.0 + nrm * 5.5, c - dir * 5.0, c - dir * 9.0 - nrm * 5.5])
				draw_colored_polygon(head, TBTokens.c("bar_0"))
				draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), col, 1.5, true)
			var left: int = way.size() - 1                                                              # one province a turn: this many turns to go
			if left > 1:
				var f: Font = K.body_b(); var lz := 13
				var tx: String = str(left)
				var tp: Vector2 = c + Vector2(8.0, -8.0)
				draw_string_outline(f, tp, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, 4, TBTokens.HALO)
				draw_string(f, tp, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, TBTokens.c("brass_lt"))

func _draw() -> void:
	if g == null or map == null or g.human_id <= 0 or not map.is_inside_tree(): return
	_draw_marches()
	if map.lenses.mode != "routes": return                                      # treaty and trade lines are a lens, not the default map
	if map.size.x < 8.0: return
	var me: int = g.human_id
	var a: Array = _cap(me)
	if a.is_empty(): return
	var alive_keys: Dictionary = {}
	_live = 0; _anim = false; _hits.clear()
	for o in range(1, g.N1):
		if o == me or g.alive[o] == 0 or o == g.rebel: continue
		var b: Array = _cap(o)
		if b.is_empty(): continue
		var rel: int = g.get_rel(me, o)
		if rel == D.REL_WAR: _route(a, b, "war", "w%d" % o, 0.0, alive_keys, 0)
		elif rel == D.REL_ALLY: _route(a, b, "ally", "a%d" % o, 1.0, alive_keys, 0)
		elif rel == D.REL_NAP: _route(a, b, "nap", "n%d" % o, 1.0, alive_keys, 0)
		elif rel == D.REL_MARRIAGE: _route(a, b, "marry", "m%d" % o, 1.0, alive_keys, 0)
		if g.rules >= 1 and TBTrade.has(g, me, o): _route(a, b, "trade", "t%d" % o, -1.0, alive_keys, TBTrade.value(g, o, me), TBTrade.risk(g, me, o))
	for k in _seen.keys():
		if not alive_keys.has(k): _seen.erase(k)

## flat map: the world repeats sideways, so a line is drawn in every copy of it that reaches the screen (a route from Asia to America leaves one edge and arrives from the other)
func _route(a: Array, b: Array, kind: String, key: String, bend: float, alive: Dictionary, income: int, risk: String = "") -> void:
	if map.mode != 1:
		_route_at(a, b, kind, key, bend, alive, income, risk, 0.0); return
	var world_w: float = TAU * map.flat_scale()
	var xa: float = map.project(float(a[0]), float(a[1])).x
	var xb: float = xa + deg_to_rad(wrapf(float(b[0]) - float(a[0]), -180.0, 180.0)) * map.flat_scale()
	var shown := false
	for dx in [0.0, -world_w, world_w]:
		if maxf(xa, xb) + dx >= -20.0 and minf(xa, xb) + dx <= map.size.x + 20.0:
			_route_at(a, b, kind, key, bend, alive, income, risk, dx); shown = true
	if not shown: alive[key] = true

func _route_at(a: Array, b: Array, kind: String, key: String, bend: float, alive: Dictionary, income: int, risk: String, dx: float) -> void:
	alive[key] = true; _live += 1
	if not _seen.has(key): _seen[key] = 0.0 if K.motion_ok() else 99.0
	var grow: float = clampf(float(_seen[key]) / 1.3, 0.0, 1.0)
	if grow < 1.0 or kind == "trade": _anim = true
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var pts: Array = _arc(a, b, bend)
	if dx != 0.0:
		for i in pts.size(): pts[i][0] = Vector2(pts[i][0]) + Vector2(dx, 0.0)
	var atlas: bool = map.atlas_look()
	var col: Color = TBTokens.c("brass_lt")
	var w := 2.0
	match kind:
		"war": col = TBTokens.MAP_BAD if atlas else TBTokens.c("neg_bar")
		"trade": col = TBTokens.c("warn") if risk != "" else TBTokens.c("pos_bar")                      # a route that is about to lapse is drawn amber
		"ally": w = 3.2
		"nap": w = 1.8
		"marry": w = 2.2
	var halo: Color = TBTokens.with_a(TBTokens.HALO, 0.7)
	var picked: String = map.lenses.route_kind
	var recede: bool = picked != "" and picked != kind                            # another kind of route is picked: this one fades
	if atlas:                                                                    # the demo's route group: no casing; pact #E5C77A 2.2 .9, trade #69B3A2 1.8 dashed "3 6" .9, war #D2603F 2 dotted "2 7" .85
		halo = Color(0, 0, 0, 0)
		match kind:
			"war": col.a = 0.85; w = 2.0
			"trade": col.a = 0.9; w = 1.8
			"ally": col.a = 0.9; w = 3.0
			"nap": col.a = 0.9; w = 2.2
			"marry": col.a = 0.9; w = 2.2
			_: col.a = 0.9; w = 2.2
	if recede: col.a *= 0.22; halo.a = 0.0
	elif picked == kind: w += 1.2
	var last: int = int(round(SEG * grow))
	var run: PackedVector2Array = PackedVector2Array()
	var runs: Array = []
	for i in last + 1:
		if bool(pts[i][1]):
			if run.size() > 0 and map.mode == 0 and absf(run[run.size() - 1].x - Vector2(pts[i][0]).x) > map.size.x * 0.5:       # flat map: the arc crossed the date line
				if run.size() > 1: runs.append(run)
				run = PackedVector2Array()
			run.append(pts[i][0])
		elif run.size() > 1: runs.append(run); run = PackedVector2Array()
		else: run = PackedVector2Array()
	if run.size() > 1: runs.append(run)
	_hits.append({"kind": kind, "runs": runs})
	for r in runs:
		var rr: PackedVector2Array = r
		match kind:
			"war":
				_dotted(rr, halo, col, 2.6 if atlas else 3.5, 9.0)
			"trade":
				_dashed(rr, halo, col, w, 3.0 if atlas else 10.0, 6.0 if atlas else 7.0)
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
			var s: float = (7.07 if kind != "nap" else 5.5) if map.atlas_look() else (5.5 if kind != "nap" else 4.0)
			draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -s), mp + Vector2(s, 0), mp + Vector2(0, s), mp + Vector2(-s, 0)]), TBTokens.c("bar_0"))
			var ring := PackedVector2Array([mp + Vector2(0, -s), mp + Vector2(s, 0), mp + Vector2(0, s), mp + Vector2(-s, 0), mp + Vector2(0, -s)])
			draw_polyline(ring, col, 1.6, true)
		if kind == "trade":
			var f: Font = K.body_b()
			var tx: String = ("+%d !" % income) if risk != "" else "+%d" % income
			var lz: int = 13 if map.atlas_look() else 14
			draw_string_outline(f, mp + Vector2(-f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz).x * 0.5, -9.0 if map.atlas_look() else -10.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, 3 if map.atlas_look() else 4, TBTokens.HALO)
			draw_string(f, mp + Vector2(-f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz).x * 0.5, -9.0 if map.atlas_look() else -10.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, TBTokens.c("brass_lt"))
			if K.motion_ok():
				for ph in [0.0, 0.5]:                                  # gold goes out, goods come back
					var q: float = fposmod(_t * 0.12 + ph, 1.0)
					var p1: Vector2 = _at(pts, q)
					if p1 != Vector2.INF:
						draw_circle(p1, 4.2, TBTokens.HALO); draw_circle(p1, 3.4 if map.atlas_look() else 3.0, TBTokens.c("brass_lt"))
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
