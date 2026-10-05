## Overlay drawn above the GPU map: army chips, capital stars, battle effects. Redraws only when the view
## or game state changed; hidden while dragging (cheap frames). Uses precomputed unit vectors (no per-province trig).
class_name TBMapLabels
extends Control

var map: TBMapView
var g: TBGame
var max_labels := 90
var _unit := PackedVector3Array()
var _fx: Array = []          # {kind, from, to, col, t0, dur}
var hidden_while_dragging := false

func attach(m: TBMapView) -> void:
	map = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func set_game(game: TBGame) -> void:
	g = game
	var w := g.world
	_unit.resize(g.P)
	for p in g.P:
		var lon := deg_to_rad(w.lon[p]); var lat := deg_to_rad(w.lat[p])
		var cl := cos(lat)
		_unit[p] = Vector3(cl * sin(lon), sin(lat), cl * cos(lon))   # x east, y north, z toward lon=0
	queue_redraw()

func add_fx(kind: String, from: int, to: int, col: Color) -> void:
	_fx.append({"kind": kind, "from": from, "to": to, "col": col, "t0": Time.get_ticks_msec(), "dur": 700 if kind == "atk" else 900})
	queue_redraw()

func _process(_d: float) -> void:
	if not _fx.is_empty(): queue_redraw()

## nation names at their centroid; bigger nations get bigger text; overlapping names are skipped
func _draw_nation_names(font: Font) -> void:
	if map.zoom > (4.0 if map.mode == 0 else 5.5): return
	font = TBKit.tracked(font, 2)
	var N1 := g.N1
	var sx := PackedFloat32Array(); sx.resize(N1)
	var sy := PackedFloat32Array(); sy.resize(N1)
	var sz := PackedFloat32Array(); sz.resize(N1)
	var cnt := PackedInt32Array(); cnt.resize(N1)
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		var u := _unit[p]
		sx[o] += u.x; sy[o] += u.y; sz[o] += u.z; cnt[o] += 1
	var order: Array = []
	for n in range(1, N1):
		if cnt[n] >= 3 and g.alive[n] != 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a, b): return cnt[a] > cnt[b])
	var placed: Array = []
	var shown := 0
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	for n in order:
		if shown >= 70: break
		var v := Vector3(sx[n], sy[n], sz[n])
		var len := v.length()
		if len < 0.0001: continue
		v /= len
		var pos: Vector2
		var depth := 1.0
		if map.mode == 0:
			var x := v.x * cl - v.z * sl
			var z0 := v.x * sl + v.z * cl
			var y := v.y * c0 - z0 * s0
			depth = v.y * s0 + z0 * c0
			if depth < 0.25: continue
			pos = Vector2(cx + R * x, cy - R * y)
		else:
			var lon := atan2(v.x, v.z); var lat := asin(clampf(v.y, -1.0, 1.0))
			var pt := map.project(rad_to_deg(lon), rad_to_deg(lat))
			pos = Vector2(pt.x, pt.y)
		if pos.x < 0 or pos.y < 0 or pos.x > map.size.x or pos.y > map.size.y: continue
		var fs := int(clampf(8.0 + sqrt(float(cnt[n])) * 1.4 * minf(map.zoom, 2.2), 10.0, 24.0))
		var txt: String = g.nat_name[n]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rect := Rect2(pos - tw * 0.5, tw).grow(3.0)
		var clash := false
		for r in placed:
			if r.intersects(rect): clash = true; break
		if clash: continue
		placed.append(rect); shown += 1
		var a := clampf(depth * 1.6, 0.35, 0.95)
		var mine: bool = n == g.human_id
		draw_string_outline(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.03, 0.07, a * 0.85))
		draw_string(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.8, 0.4, a) if mine else Color(0.94, 0.9, 0.82, a * 0.92))

func _star(pos: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 10: pts.append(pos + Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * (7.0 if i % 2 == 0 else 3.2))
	draw_colored_polygon(pts, Color(0.953, 0.773, 0.322))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.03, 0.05, 0.1), 1.2, true)

## screen position + visibility for province p given the map camera
func _project(p: int, c0: float, s0: float, sl: float, cl: float, R: float, cx: float, cy: float) -> Vector3:
	var u := _unit[p]
	# rotate: first about y by -lon0, then about x by lat0
	var x := u.x * cl - u.z * sl
	var z0 := u.x * sl + u.z * cl
	var y := u.y * c0 - z0 * s0
	var z := u.y * s0 + z0 * c0
	return Vector3(cx + R * x, cy - R * y, z)

func _draw() -> void:
	if map == null or g == null or hidden_while_dragging: return
	var font: Font = TBKit.display()
	var nfont: Font = TBKit.mono_b()
	if g.human_id == 0:                 # nation-pick screen: names only
		_draw_nation_names(font)
		return
	var vis: Array = []
	var me := g.human_id
	var zoomed := map.zoom >= (2.0 if map.mode == 0 else 2.6)
	if map.mode == 0:
		var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
		var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
		# lon0 rotation: point at lon0 maps to z=+1  =>  rotate by -lon0
		for p in g.P:
			var o := g.owner[p]
			if o == 0: continue
			var star := g.capital[p] != 0 and (map.zoom >= 1.8 or o == me)
			if not zoomed and not star and not (o == me and map.zoom >= 1.4): continue
			var pr := _project(p, c0, s0, sl, cl, R, cx, cy)
			if pr.z < 0.08: continue
			vis.append([p, pr.x, pr.y, 0 if o == me else (1 if star else 2)])
	else:
		for p in g.P:
			var o := g.owner[p]
			if o == 0: continue
			var star := g.capital[p] != 0 and (map.zoom >= 1.8 or o == me)
			if not zoomed and not star and not (o == me and map.zoom >= 2.0): continue
			var pt := map.project(g.world.lon[p], g.world.lat[p])
			if pt.x < -20 or pt.y < -20 or pt.x > map.size.x + 20 or pt.y > map.size.y + 20: continue
			vis.append([p, pt.x, pt.y, 0 if o == me else (1 if star else 2)])
	vis.sort_custom(func(a, b): return a[3] < b[3])
	var drawn := 0
	for v in vis:
		if drawn >= max_labels: break
		var p: int = v[0]
		var o := g.owner[p]
		var pos := Vector2(v[1], v[2])
		if g.capital[p] != 0 and not zoomed:
			_star(pos); drawn += 1; continue
		var a := g.army[p]
		if a <= 0: continue
		var txt := TBKit.fmt(a)
		var tw := nfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
		# heraldic plaque: dark field, rim coloured by relation, a band of the owner's colour along the top
		var rim := TBKit.GOLD2 if o == me else (TBKit.RED if g.get_rel(me, o) == 1 else Color(0.62, 0.66, 0.75, 0.9))
		var x0 := pos.x - tw * 0.5; var x1 := pos.x + tw * 0.5; var y0 := pos.y - 8.0; var y1 := pos.y + 7.0
		var shield := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(pos.x, y1 + 4.0), Vector2(x0, y1)])
		draw_colored_polygon(shield, Color(0.03, 0.05, 0.1, 0.9))
		var oc := Color.hex((g.color[o] << 8) | 0xFF)
		draw_rect(Rect2(x0 + 1, y0 + 1, tw - 2, 2.0), oc, true)
		var ring := shield.duplicate(); ring.append(shield[0])
		draw_polyline(ring, Color(rim.r, rim.g, rim.b, 0.85), 1.0, true)
		draw_string(nfont, Vector2(x0 + 5, y1 - 2.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.92, 0.85))
		drawn += 1
	_draw_nation_names(font)
	# battle effects
	var now := Time.get_ticks_msec()
	var keep: Array = []
	for f in _fx:
		var k: float = float(now - int(f["t0"])) / float(f["dur"])
		if k >= 1.0: continue
		keep.append(f)
		var pt_to := map.project(g.world.lon[f["to"]], g.world.lat[f["to"]])
		if pt_to.z <= 0.0: continue
		var col: Color = f["col"]; col.a = 1.0 - k
		if f["kind"] == "atk":
			var pt_from := map.project(g.world.lon[f["from"]], g.world.lat[f["from"]])
			if pt_from.z > 0.0:
				var tip := Vector2(pt_from.x, pt_from.y).lerp(Vector2(pt_to.x, pt_to.y), minf(1.0, k * 1.6))
				draw_line(Vector2(pt_from.x, pt_from.y), tip, col, 3.0, true)
		else:
			draw_arc(Vector2(pt_to.x, pt_to.y), 6.0 + k * 28.0, 0.0, TAU, 28, col, 2.5, true)
	_fx = keep
