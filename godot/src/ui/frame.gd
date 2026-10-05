## Surfaces of the "cartographer's table".
##   SHEET   a laid-paper document with a soft shadow, uneven cut edges, an inked double rule and brass corner guards
##   CHIT    a small paper slip (buttons, toasts, tooltips)
##   WAX     a wax-seal button / stamp: red, organic outline, embossed rim
##   LEATHER the umber instrument strip of the HUD with brass rules and studs
## All are StyleBoxes, so every PanelContainer / Button in the theme can use them.
class_name TBFrame
extends StyleBox

enum Kind { SHEET, CHIT, WAX, LEATHER }

const INK := Color(0.165, 0.125, 0.082)
const PAPER := Color(0.918, 0.862, 0.735)
const BRASS := Color(0.62, 0.45, 0.13)

var kind: int = Kind.SHEET
var tint := PAPER
var ink := INK
var accent := BRASS            # corner guards / studs
var shadow := 1.0              # 0 = none
var sunk := false              # pressed: slightly darker, no lift
var alert := false             # red border (warnings, bad news)
var seed_v := 7

static func make(fill_c: Color, rule_c: Color, _notch: float = 10.0, double: bool = true, pad_x: float = 16.0, pad_y: float = 12.0) -> TBFrame:
	var f := TBFrame.new()
	f.kind = Kind.SHEET if double else Kind.CHIT
	if fill_c.get_luminance() > 0.5: f.tint = Color(fill_c.r, fill_c.g, fill_c.b, 1.0)
	f.alert = rule_c.r > rule_c.g * 1.8 and rule_c.r > rule_c.b * 1.8
	f.shadow = 1.0 if double else 0.55
	f._margins(pad_x, pad_y)
	return f

static func sheet(pad_x: float = 20.0, pad_y: float = 16.0, tint_c: Color = PAPER) -> TBFrame:
	var f := TBFrame.new(); f.kind = Kind.SHEET; f.tint = tint_c; f._margins(pad_x, pad_y); return f

static func chit(tint_c: Color = PAPER, pad_x: float = 14.0, pad_y: float = 8.0, is_alert: bool = false) -> TBFrame:
	var f := TBFrame.new(); f.kind = Kind.CHIT; f.tint = tint_c; f.shadow = 0.55; f.alert = is_alert; f._margins(pad_x, pad_y); return f

static func wax(pad_x: float = 16.0, pad_y: float = 10.0, pressed: bool = false) -> TBFrame:
	var f := TBFrame.new(); f.kind = Kind.WAX; f.sunk = pressed; f._margins(pad_x, pad_y); return f

static func leather(pad_x: float = 12.0, pad_y: float = 6.0) -> TBFrame:
	var f := TBFrame.new(); f.kind = Kind.LEATHER; f.tint = Color(0.20, 0.145, 0.095); f.ink = Color(0.04, 0.03, 0.02); f.accent = Color(0.85, 0.66, 0.28); f._margins(pad_x, pad_y); return f

func _margins(px: float, py: float) -> void:
	set_content_margin(SIDE_LEFT, px); set_content_margin(SIDE_RIGHT, px)
	set_content_margin(SIDE_TOP, py); set_content_margin(SIDE_BOTTOM, py)

func _poly(ci: RID, pts: PackedVector2Array, col: Color) -> void:
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([col]))

func _textured(ci: RID, pts: PackedVector2Array, r: Rect2, tex_kind: int, col: Color) -> void:
	var uvs := PackedVector2Array()
	for p in pts: uvs.append(Vector2((p.x - r.position.x) / maxf(1.0, r.size.x), (p.y - r.position.y) / maxf(1.0, r.size.y)))
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([col]), uvs, TBPaper.texture(tex_kind).get_rid())

func _line(ci: RID, pts: PackedVector2Array, col: Color, w: float, closed: bool = true) -> void:
	var p := pts
	if closed:
		p = pts.duplicate(); p.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, p, PackedColorArray([col]), w, true)

func _draw(ci: RID, rect: Rect2) -> void:
	match kind:
		Kind.SHEET: _draw_sheet(ci, rect)
		Kind.CHIT: _draw_chit(ci, rect)
		Kind.WAX: _draw_wax(ci, rect)
		Kind.LEATHER: _draw_leather(ci, rect)

func _draw_sheet(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(1.5, 1.5), rect.size - Vector2(3, 3))
	var seed_i := int(r.size.x) * 31 + int(r.size.y) + seed_v
	if shadow > 0.0 and r.size.x > 24:
		for k in 3:
			var o := Vector2(2.0 + k * 1.6, 3.0 + k * 2.2)
			_poly(ci, TBPaper.ragged(Rect2(r.position + o, r.size).grow(k * 0.8), 0.0, 400.0, 1, 2.0), Color(0.02, 0.01, 0.0, 0.2 * shadow))
	var edge := TBPaper.ragged(r, 1.5, 36.0, seed_i, 2.5)
	_textured(ci, edge, r, TBPaper.SHEET, tint)
	# aged margins: concentric translucent strokes darken the rim
	for k in 4:
		var inset := Rect2(r.position + Vector2(k * 1.6, k * 1.6), r.size - Vector2(k * 3.2, k * 3.2))
		if inset.size.x > 4 and inset.size.y > 4: _line(ci, TBPaper.ragged(inset, 0.0, 400.0, 1, 2.0), Color(0.35, 0.22, 0.08, 0.10 - k * 0.02), 2.2)
	_line(ci, edge, Color(ink.r, ink.g, ink.b, 0.45), 1.0)
	if r.size.x > 90 and r.size.y > 60:
		var rc := ink if not alert else Color(0.62, 0.14, 0.1)
		var i1 := Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 16))
		_line(ci, TBPaper.ragged(i1, 0.0, 400.0, 1, 0.0), Color(rc.r, rc.g, rc.b, 0.62), 1.4)
		var i2 := Rect2(r.position + Vector2(11.5, 11.5), r.size - Vector2(23, 23))
		_line(ci, TBPaper.ragged(i2, 0.0, 400.0, 1, 0.0), Color(rc.r, rc.g, rc.b, 0.28), 0.8)
		# brass corner guards: small folded triangles
		var s := 13.0
		for c in 4:
			var cx := r.position.x if c % 2 == 0 else r.end.x
			var cy := r.position.y if c < 2 else r.end.y
			var sx := 1.0 if c % 2 == 0 else -1.0
			var sy := 1.0 if c < 2 else -1.0
			var tri := PackedVector2Array([Vector2(cx, cy), Vector2(cx + sx * s, cy), Vector2(cx, cy + sy * s)])
			_poly(ci, tri, Color(accent.r, accent.g, accent.b, 0.95))
			_line(ci, tri, Color(0.25, 0.17, 0.05, 0.8), 0.8)
			_line(ci, PackedVector2Array([Vector2(cx + sx * 3.0, cy + sy * 6.5), Vector2(cx + sx * 6.5, cy + sy * 3.0)]), Color(1.0, 0.92, 0.6, 0.6), 0.8, false)

func _draw_chit(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2.5, 3.0))
	if sunk: r.position += Vector2(0.0, 1.0)
	var seed_i := int(rect.size.x) * 17 + int(rect.size.y) * 3 + seed_v
	if shadow > 0.0 and not sunk:
		_poly(ci, TBPaper.ragged(Rect2(r.position + Vector2(1.2, 2.0), r.size), 0.0, 400.0, 1, 1.5), Color(0.02, 0.01, 0.0, 0.26 * shadow))
	var pts := TBPaper.ragged(r, 0.9, 30.0, seed_i, 1.8)
	var col := tint if not sunk else tint.darkened(0.12)
	_textured(ci, pts, r, TBPaper.SHEET, col)
	_line(ci, pts, Color((Color(0.62, 0.14, 0.1) if alert else ink).r, (Color(0.62, 0.14, 0.1) if alert else ink).g, (Color(0.62, 0.14, 0.1) if alert else ink).b, 0.75 if alert else 0.55), 1.1)
	if r.size.x > 40 and r.size.y > 22:
		_line(ci, PackedVector2Array([r.position + Vector2(3.5, r.size.y - 3.5), r.position + Vector2(r.size.x - 3.5, r.size.y - 3.5)]), Color(ink.r, ink.g, ink.b, 0.18), 0.8, false)

func _draw_wax(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(1.5, 1.0), rect.size - Vector2(3, 4.0))
	var seed_i := int(rect.size.x) * 13 + int(rect.size.y) + seed_v
	var rad := minf(r.size.y * 0.42, 12.0)
	# a stamp of wax: rounded body with a gently uneven edge, a pressed inner ring, a lit upper rim
	var outer := TBPaper.stamp(r, rad, 0.9, seed_i)
	if not sunk: _poly(ci, TBPaper.stamp(Rect2(r.position + Vector2(1.0, 2.2), r.size), rad, 0.9, seed_i), Color(0.02, 0.0, 0.0, 0.32))
	var base := Color(0.64, 0.15, 0.12) if not sunk else Color(0.5, 0.1, 0.08)
	_textured(ci, outer, r, TBPaper.WAX, base)
	_line(ci, outer, Color(0.26, 0.04, 0.03, 0.9), 1.2)
	var ring := Rect2(r.position + Vector2(3.5, 3.5), r.size - Vector2(7, 7))
	_line(ci, TBPaper.stamp(ring, rad - 2.5, 0.35, seed_i + 5), Color(0.33, 0.05, 0.04, 0.5), 1.1)
	_line(ci, PackedVector2Array([r.position + Vector2(rad, 1.8), Vector2(r.end.x - rad, r.position.y + 1.8)]), Color(1.0, 0.7, 0.6, 0.30), 1.2, false)

func _draw_leather(ci: RID, rect: Rect2) -> void:
	var r := rect
	_textured(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), r, TBPaper.LEATHER, tint)
	# stitching and brass rules along the lower edge
	_line(ci, PackedVector2Array([Vector2(r.position.x, r.end.y - 1.5), Vector2(r.end.x, r.end.y - 1.5)]), Color(accent.r, accent.g, accent.b, 0.95), 2.0, false)
	_line(ci, PackedVector2Array([Vector2(r.position.x, r.end.y - 5.0), Vector2(r.end.x, r.end.y - 5.0)]), Color(accent.r, accent.g, accent.b, 0.35), 1.0, false)
	var x := r.position.x + 6.0
	while x < r.end.x - 4.0:
		_line(ci, PackedVector2Array([Vector2(x, r.end.y - 9.0), Vector2(x + 3.0, r.end.y - 9.0)]), Color(0.9, 0.78, 0.5, 0.22), 1.0, false)
		x += 8.0
	_line(ci, PackedVector2Array([r.position + Vector2(0, 1), Vector2(r.end.x, r.position.y + 1)]), Color(1, 1, 1, 0.06), 1.0, false)
