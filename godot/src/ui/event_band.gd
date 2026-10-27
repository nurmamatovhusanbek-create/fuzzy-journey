## Event pop-up parts (Path B2, docs/screens/popup_mocks/sheet_A_war_event.png): the illustration band with the engraved glyph of the event class, and the strength comparison bar
## of an ultimatum. Pure drawing; the entrance motion comes from the dialog staging (B1).
class_name TBEventBand
extends Control

var glyph := "warn"
var tone := Color.WHITE
var wash := Color.WHITE

func _init(g: String, tone_col: Color) -> void:
	glyph = g; tone = tone_col; wash = tone_col
	custom_minimum_size = Vector2(0, 104)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true

func _draw() -> void:
	var w := size.x; var h := size.y
	var c := Vector2(w * 0.5, h * 0.52)
	# ground and a coloured glow
	draw_rect(Rect2(0, 0, w, h), TBTokens.BZ_PLATE_BOT)
	for k in 8:
		var f: float = float(k) / 7.0
		draw_circle(c, (h * 1.25) * (1.0 - f * 0.8), TBTokens.with_a(wash, 0.028 + 0.012 * k))
	# engraved rays and two rings
	for i in 36:
		var a: float = float(i) / 36.0 * TAU
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 58.0, c + d * (58.0 + (h * 1.3 if i % 3 == 0 else h * 0.9)), TBTokens.with_a(tone, 0.14 if i % 3 == 0 else 0.07), 1.0)
	draw_arc(c, 66.0, 0.0, TAU, 64, TBTokens.with_a(tone, 0.22), 1.0, true)
	draw_arc(c, 82.0, 0.0, TAU, 64, TBTokens.with_a(tone, 0.12), 1.0, true)
	# the medallion
	var r: float = 38.0
	TBBezel.ring(self, c, r, 36, TBTokens.BZ_FACE, true, false, 1.0)
	draw_arc(c, r - 0.7, 0.0, TAU, 48, TBTokens.with_a(tone, 0.9), 1.4, true)
	TBGlyph.draw_ic(self, glyph, c, 40.0, tone, 1.5)
	# ruler along the bottom edge and a hairline on top
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, h), Vector2(x, h - (7.0 if int(x / 8.0) % 5 == 0 else 4.0)), TBTokens.with_a(TBTokens.BZ_LO, 0.7), 1.0)
		x += 8.0
	draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), TBTokens.with_a(TBTokens.BZ_LO, 0.8), 1.0)
	draw_line(Vector2(0, 0.5), Vector2(w, 0.5), TBTokens.with_a(TBTokens.BZ_LO, 0.5), 1.0)

## tone of an event class: what hurts is rust, what pays is brass; trade and diplomacy read blue
static func tone_of(cat: String, bad: bool) -> Color:
	var c := cat.to_lower()
	if c in ["trade", "diplomacy"]: return TBTokens.BZ_INFO
	if bad: return TBTokens.BZ_NOTICE_BAD
	return TBTokens.c("brass_lt")

## "Their strength 0 [======|--] Yours 2699": your share in brass, theirs in rust
class Versus extends Control:
	var theirs := 0
	var mine := 0
	var l_text := ""
	var r_text := ""
	func _init(their: int, my: int, left_text: String, right_text: String) -> void:
		theirs = their; mine = my; l_text = left_text; r_text = right_text
		custom_minimum_size = Vector2(0, 30); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TBKit.a11y(self, "%s %d, %s %d" % [left_text, their, right_text, my], "image")
	func _draw() -> void:
		var f := TBKit.body()
		var fsz := TBKit.fs(15)
		var lt := "%s %s" % [l_text, TBKit.fmt(theirs)]
		var rt := "%s %s" % [r_text, TBKit.fmt(mine)]
		var lw: float = f.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var rw: float = f.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var cy: float = size.y * 0.5
		var ty: float = cy + f.get_ascent(fsz) * 0.5 - 2.0
		draw_string(f, Vector2(0, ty), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, TBTokens.BZ_DIM if theirs <= mine else TBTokens.BZ_NOTICE_BAD)
		draw_string(f, Vector2(size.x - rw, ty), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, TBTokens.c("cream"))
		var x0: float = lw + 14.0; var x1: float = size.x - rw - 14.0
		if x1 - x0 < 40.0: return
		draw_rect(Rect2(x0, cy - 5.0, x1 - x0, 10.0), TBTokens.BZ_TRACK_BG)
		draw_rect(Rect2(x0, cy - 5.0, x1 - x0, 10.0), TBTokens.BZ_TRACK_LINE, false, 1.0)
		var tot: float = float(maxi(theirs + mine, 1))
		var mw: float = (x1 - x0 - 2.0) * float(mine) / tot
		draw_rect(Rect2(x0 + 1.0, cy - 4.0, mw, 8.0), TBTokens.BZ_SLIDER_FILL_A)
		draw_rect(Rect2(x0 + 1.0 + mw, cy - 4.0, (x1 - x0 - 2.0) - mw, 8.0), TBTokens.BZ_DNG_B)
