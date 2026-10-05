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
	if map == null or g == null or g.human_id == 0 or hidden_while_dragging: return
	var font := ThemeDB.fallback_font
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
			var star := g.capital[p] != 0
			if not zoomed and not star and not (o == me and map.zoom >= 1.4): continue
			var pr := _project(p, c0, s0, sl, cl, R, cx, cy)
			if pr.z < 0.08: continue
			vis.append([p, pr.x, pr.y, 0 if o == me else (1 if star else 2)])
	else:
		for p in g.P:
			var o := g.owner[p]
			if o == 0: continue
			var star := g.capital[p] != 0
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
			draw_string(font, pos + Vector2(-6, 5), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95)); drawn += 1; continue
		var a := g.army[p]
		if a <= 0: continue
		var txt := TBKit.fmt(a)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
		var rect := Rect2(pos - Vector2(tw * 0.5, 8), Vector2(tw, 16))
		var bg := Color(0.08, 0.25, 0.12, 0.88) if o == me else (Color(0.4, 0.09, 0.09, 0.88) if g.get_rel(me, o) == 1 else Color(0.06, 0.08, 0.13, 0.82))
		draw_rect(rect, bg, true)
		draw_string(font, pos + Vector2(-tw * 0.5 + 5, 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		drawn += 1
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
