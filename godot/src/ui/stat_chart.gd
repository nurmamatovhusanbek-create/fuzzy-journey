## Line chart for the statistics screen: faint ruled grid, mono axis labels, one line per power, emphasised endpoint.
class_name TBStatChart
extends Control

const K = preload("res://src/ui/ui_kit.gd")
var series: Array = []      # [{name, color, pts: [[x, y]...], bold}]
var x_label := Callable()   # turn -> text

func _init() -> void:
	custom_minimum_size = Vector2(0, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var pad_l := 48.0; var pad_r := 14.0; var pad_t := 10.0; var pad_b := 24.0
	var r := Rect2(pad_l, pad_t, size.x - pad_l - pad_r, size.y - pad_t - pad_b)
	var xmin := 1e18; var xmax := -1e18; var ymax := 0.0
	for s in series:
		for p in s["pts"]:
			xmin = minf(xmin, p[0]); xmax = maxf(xmax, p[0]); ymax = maxf(ymax, p[1])
	if xmax <= xmin or ymax <= 0.0:
		draw_string(K.display(), Vector2(pad_l + 10, size.y * 0.5), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.DIM); return
	var nice := _nice(ymax)
	var f := K.mono()
	for i in 5:
		var t := i / 4.0
		var y := r.end.y - t * r.size.y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.83, 0.63, 0.09, 0.16 if i > 0 else 0.5), 1.0)
		var lab := _fmt(nice * t)
		draw_string(f, Vector2(r.position.x - 6 - f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, y + 4), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.DIM)
	for i in 4:
		var t := i / 3.0
		var x := r.position.x + t * r.size.x
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 4), Color(0.83, 0.63, 0.09, 0.5), 1.0)
		var xl: String = x_label.call(xmin + (xmax - xmin) * t) if x_label.is_valid() else str(int(xmin + (xmax - xmin) * t))
		var w := f.get_string_size(xl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2(clampf(x - w * 0.5, 0.0, size.x - w), size.y - 6), xl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.DIM)
	for s in series:
		var pts := PackedVector2Array()
		for p in s["pts"]:
			pts.append(Vector2(r.position.x + (p[0] - xmin) / (xmax - xmin) * r.size.x, r.end.y - p[1] / nice * r.size.y))
		if pts.size() >= 2: draw_polyline(pts, s["color"], 3.0 if s["bold"] else 1.8, true)
		if pts.size() >= 1:
			draw_circle(pts[pts.size() - 1], 4.0 if s["bold"] else 3.0, s["color"])
			if s["bold"]: draw_arc(pts[pts.size() - 1], 7.0, 0, TAU, 16, Color(s["color"].r, s["color"].g, s["color"].b, 0.5), 1.0, true)

static func _nice(v: float) -> float:
	var e := pow(10.0, floorf(log(v) / log(10.0)))
	for m in [1.0, 2.0, 4.0, 8.0, 10.0]:
		if m * e >= v: return m * e
	return v

static func _fmt(v: float) -> String:
	if v >= 1000000.0: return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0: return "%dk" % int(v / 1000.0)
	if v >= 1000.0: return "%.1fk" % (v / 1000.0)
	if v < 10.0 and v != floorf(v): return "%.1f" % v
	return str(int(v))
