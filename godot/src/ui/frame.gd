## Cartouche frame: a chamfered, double-ruled panel in the manner of an engraved map border. Drawn as a StyleBox so every
## PanelContainer / Button in the theme can use it. Asymmetric notches (large top-left / bottom-right) keep it from reading
## as a plain rounded box.
class_name TBFrame
extends StyleBox

var fill := Color(0.047, 0.078, 0.149, 0.93)
var rule := Color(0.83, 0.63, 0.09, 0.62)
var rule2 := Color(0.83, 0.63, 0.09, 0.24)
var cut_a := 10.0            # top-left and bottom-right notch
var cut_b := 3.0             # top-right and bottom-left notch
var double_rule := true
var corner_ticks := true
var rule_w := 1.0
var hatch := false          # faint engraved diagonal hatching on large panels

static func make(fill_c: Color, rule_c: Color, notch: float = 10.0, double: bool = true, pad_x: float = 16.0, pad_y: float = 12.0) -> TBFrame:
	var f := TBFrame.new()
	f.fill = fill_c; f.rule = rule_c; f.rule2 = Color(rule_c.r, rule_c.g, rule_c.b, rule_c.a * 0.4)
	f.cut_a = notch; f.cut_b = maxf(2.0, notch * 0.3); f.double_rule = double; f.corner_ticks = double; f.hatch = double
	f.set_content_margin(SIDE_LEFT, pad_x); f.set_content_margin(SIDE_RIGHT, pad_x)
	f.set_content_margin(SIDE_TOP, pad_y); f.set_content_margin(SIDE_BOTTOM, pad_y)
	return f

func _outline(r: Rect2, inset: float) -> PackedVector2Array:
	var a := maxf(0.0, cut_a - inset * 0.6); var b := maxf(0.0, cut_b - inset * 0.6)
	var x0 := r.position.x + inset; var y0 := r.position.y + inset
	var x1 := r.end.x - inset; var y1 := r.end.y - inset
	return PackedVector2Array([
		Vector2(x0 + a, y0), Vector2(x1 - b, y0), Vector2(x1, y0 + b),
		Vector2(x1, y1 - a), Vector2(x1 - a, y1), Vector2(x0 + b, y1),
		Vector2(x0, y1 - b), Vector2(x0, y0 + a)])

func _draw(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2(1, 1))
	var o := _outline(r, 0.0)
	RenderingServer.canvas_item_add_polygon(ci, o, PackedColorArray([fill]))
	if hatch and r.size.x > 160 and r.size.y > 100:
		var hc := Color(rule2.r, rule2.g, rule2.b, 0.07)
		var x0 := r.position.x + 6.0; var y0 := r.position.y + 6.0; var x1 := r.end.x - 6.0; var y1 := r.end.y - 6.0
		var d := 14.0
		var k := x0 - (y1 - y0)
		while k < x1:
			# line y = y0 + (x - k): from (max(k,x0), ...) clipped to the rect
			var ax := maxf(k, x0); var bx := minf(k + (y1 - y0), x1)
			if bx > ax: RenderingServer.canvas_item_add_line(ci, Vector2(ax, y0 + (ax - k)), Vector2(bx, y0 + (bx - k)), hc, 1.0, false)
			k += d
	var closed := o.duplicate(); closed.append(o[0])
	RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([rule]), rule_w, true)
	if double_rule and r.size.x > 40 and r.size.y > 28:
		var i := _outline(r, 4.0)
		var ic := i.duplicate(); ic.append(i[0])
		RenderingServer.canvas_item_add_polyline(ci, ic, PackedColorArray([rule2]), 1.0, true)
	if corner_ticks and r.size.x > 60 and r.size.y > 40:
		# registration ticks that poke outside the inner rule at the two sharp corners
		var t := 5.0
		var tr := Vector2(r.end.x - 4.0, r.position.y + 4.0 + cut_b)
		var bl := Vector2(r.position.x + 4.0, r.end.y - 4.0 - cut_b)
		RenderingServer.canvas_item_add_line(ci, tr + Vector2(-t, 0), tr, rule, 1.0, true)
		RenderingServer.canvas_item_add_line(ci, bl, bl + Vector2(t, 0), rule, 1.0, true)
