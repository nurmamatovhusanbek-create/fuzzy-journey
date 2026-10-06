## Line chart for the Rankings tab: faint ruled grid, mono axis labels, one line per power with its own dash pattern and a direct end label.
class_name TBStatChart
extends Control

const K = preload("res://src/ui/ui_kit.gd")
var series: Array = []      # [{name, color, pts: [[x, y]...], bold, dash}]
var x_label := Callable()   # turn -> text
const DASHES := [[], [10, 5], [4, 4], [14, 4, 3, 4], [2, 3]]       # solid, long, short, dash-dot, dotted

func _init() -> void:
	custom_minimum_size = Vector2(0, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var pad_l := 48.0; var pad_r := 96.0; var pad_t := 10.0; var pad_b := 24.0
	if size.x < 420.0: pad_r = 64.0
	var r := Rect2(pad_l, pad_t, size.x - pad_l - pad_r, size.y - pad_t - pad_b)
	var xmin := 1e18; var xmax := -1e18; var ymax := 0.0
	for s in series:
		for p in s["pts"]:
			xmin = minf(xmin, p[0]); xmax = maxf(xmax, p[0]); ymax = maxf(ymax, p[1])
	if xmax <= xmin or ymax <= 0.0:
		draw_string(K.body(), Vector2(pad_l + 10, size.y * 0.5), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, K.fs(16), K.DIM); return
	var nice := _nice(ymax)
	var f := K.mono()
	var fsz := K.fs(12)
	var hair: Color = TBTokens.c("hair")
	for i in 5:
		var t := i / 4.0
		var y := roundf(r.end.y - t * r.size.y)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), TBTokens.c("rule") if i == 0 else hair, 1.0)
		var lab := _fmt(nice * t)
		draw_string(f, Vector2(r.position.x - 6 - f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, y + 4), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, K.DIM)
	for i in 4:
		var t := i / 3.0
		var x := roundf(r.position.x + t * r.size.x)
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 4), TBTokens.c("rule"), 1.0)
		var xl: String = x_label.call(xmin + (xmax - xmin) * t) if x_label.is_valid() else str(int(xmin + (xmax - xmin) * t))
		var w := f.get_string_size(xl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		draw_string(f, Vector2(clampf(x - w * 0.5, 0.0, size.x - w), size.y - 4), xl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, K.DIM)
	var label_ys: Array = []
	for s in series:
		var pts := PackedVector2Array()
		for p in s["pts"]:
			pts.append(Vector2(r.position.x + (p[0] - xmin) / (xmax - xmin) * r.size.x, r.end.y - p[1] / nice * r.size.y))
		var w2: float = 3.0 if s["bold"] else 2.0
		var pat: Array = DASHES[int(s.get("dash", 0)) % DASHES.size()]
		if pts.size() >= 2:
			if pat.is_empty(): draw_polyline(pts, s["color"], w2, true)
			else: _dashed(pts, s["color"], w2, pat)
		if pts.size() >= 1:
			var e: Vector2 = pts[pts.size() - 1]
			draw_circle(e, 4.0 if s["bold"] else 3.0, s["color"])
			var nm: String = s["name"]
			var ly: float = e.y + 4.0
			for oy in label_ys:
				if absf(ly - oy) < fsz: ly = oy + fsz
			label_ys.append(ly)
			var avail: float = size.x - e.x - 8.0
			if avail > 24.0: draw_string(K.body_b(), Vector2(e.x + 8.0, ly), nm, HORIZONTAL_ALIGNMENT_LEFT, avail, fsz, s["color"])

func _dashed(pts: PackedVector2Array, col: Color, w: float, pat: Array) -> void:
	var on := true
	var left: float = float(pat[0]); var pi := 0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		var d := 0.0
		while d < seg:
			var step: float = minf(left, seg - d)
			if on: draw_line(a.lerp(b, d / seg), a.lerp(b, (d + step) / seg), col, w, true)
			d += step; left -= step
			if left <= 0.001:
				pi = (pi + 1) % pat.size(); left = float(pat[pi]); on = not on

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
