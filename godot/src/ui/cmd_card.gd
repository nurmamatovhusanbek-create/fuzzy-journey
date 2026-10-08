## Widgets of the command card and the order preview (design/ux/command-card.md, art bible 3.1 / 7.5): flat chamfered paper plates,
## info chips, verb buttons, the send-share segmented control, meters and pips. Colours come ONLY from TBTokens (no Color literals);
## polygons are cached per size so nothing is allocated while drawing.
## Built here (not on the foundation kit) so it works before TBFrame.plate / K.command_card exist; swap PlateBox for TBFrame.plate later.
class_name TBCmdCard
extends RefCounted

static var text_scale := 1.0                     # text-size setting (A11Y-TXT-001): 1.0 / 1.25 / 1.5 / 2.0
static var show_hotkeys := not (OS.get_name() in ["Android", "iOS"])
## a font size through the text scale, never below the 12 px floor (A11Y-TXT-002)
static func fs(px: int) -> int: return maxi(12, int(round(px * text_scale)))
## pull the player's text scale from the kit (called by the card before every rebuild)
static func sync_settings() -> void:
	text_scale = clampf(float(TBHudParts.kit("text_scale", 1.0)), 1.0, 2.0)
static func touch() -> float: return TBHudParts.touch()
static func tk(name: String) -> Color: return TBTokens.c(name)

## 8-point chamfered rectangle
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.5)
	if c < 0.5: return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var x0 := r.position.x; var y0 := r.position.y; var x1 := r.end.x; var y1 := r.end.y
	return PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])

## the pluralised unit key suffix for a count: en/uz "1" | "5", ru "1" | "2" | "5"
static func plural(n: int) -> String:
	if TBI18n.lang == "ru":
		var m10 := n % 10; var m100 := n % 100
		if m10 == 1 and m100 != 11: return "1"
		if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14): return "2"
		return "5"
	return "1" if n == 1 else "5"

static func gold(n: int) -> String: return "%d %s" % [n, TBI18n.T("u_gold")]

static func unit(n: int, base: String) -> String:
	var key := "%s_%s" % [base, plural(n)]
	return "%d %s" % [n, TBI18n.T(key) if TBI18n.has_key(key) else TBI18n.T(base + "_5")]

# ---------------------------------------------------------------- glyphs
## ids the foundation kit (TBGlyph) adds for the redo. Until it has them they are drawn here so the card never shows a placeholder
## circle; every other id goes straight to TBGlyph. Set USE_KIT_GLYPHS to true once TBGlyph carries them (art bible 7.3).
const USE_KIT_GLYPHS := false
const LOCAL_GLYPHS := ["tri_up", "tri_down", "warning", "info", "link", "lock", "check", "supply", "revolt", "capital", "general_star", "arrowhead", "filter", "hammer"]

static func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 10: p.append(c + Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * r * (1.0 if i % 2 == 0 else 0.42))
	return p

static func glyph(ci: CanvasItem, id: String, c: Vector2, size_px: float, col: Color, w: float = 1.6) -> void:
	if USE_KIT_GLYPHS or not (id in LOCAL_GLYPHS):
		TBGlyph.draw(ci, id, c, size_px, col, w)
		return
	var r := size_px * 0.5
	match id:
		"tri_up": ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.7) * r, c + Vector2(0.8, 0.6) * r, c + Vector2(-0.8, 0.6) * r]), col)
		"tri_down": ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0.7) * r, c + Vector2(0.8, -0.6) * r, c + Vector2(-0.8, -0.6) * r]), col)
		"warning":
			var t := PackedVector2Array([c + Vector2(0, -0.8) * r, c + Vector2(0.9, 0.7) * r, c + Vector2(-0.9, 0.7) * r, c + Vector2(0, -0.8) * r])
			ci.draw_polyline(t, col, w, true)
			ci.draw_line(c + Vector2(0, -0.3) * r, c + Vector2(0, 0.2) * r, col, w, true)
			ci.draw_circle(c + Vector2(0, 0.48) * r, maxf(0.9, w * 0.5), col)
		"info":
			ci.draw_arc(c, r * 0.85, 0.0, TAU, 24, col, w, true)
			ci.draw_line(c + Vector2(0, -0.05) * r, c + Vector2(0, 0.45) * r, col, w, true)
			ci.draw_circle(c + Vector2(0, -0.38) * r, maxf(0.9, w * 0.5), col)
		"link":
			ci.draw_arc(c + Vector2(-0.38, 0) * r, r * 0.5, 0.0, TAU, 16, col, w, true)
			ci.draw_arc(c + Vector2(0.38, 0) * r, r * 0.5, 0.0, TAU, 16, col, w, true)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.05) * r, Vector2(1.2, 0.85) * r), col, false, w)
			ci.draw_arc(c + Vector2(0, -0.05) * r, r * 0.4, PI, TAU, 10, col, w, true)
		"check": ci.draw_polyline(PackedVector2Array([c + Vector2(-0.7, 0.05) * r, c + Vector2(-0.25, 0.55) * r, c + Vector2(0.75, -0.55) * r]), col, w * 1.2, true)
		"supply":
			ci.draw_rect(Rect2(c + Vector2(-0.75, -0.45) * r, Vector2(1.5, 1.0) * r), col, false, w)
			ci.draw_line(c + Vector2(-0.75, -0.45) * r, c + Vector2(0.75, 0.55) * r, col, w * 0.8, true)
			ci.draw_line(c + Vector2(0.75, -0.45) * r, c + Vector2(-0.75, 0.55) * r, col, w * 0.8, true)
		"revolt": ci.draw_polyline(PackedVector2Array([c + Vector2(0.35, -0.9) * r, c + Vector2(-0.4, 0.05) * r, c + Vector2(0.2, 0.05) * r, c + Vector2(-0.35, 0.9) * r]), col, w * 1.1, true)
		"capital":
			ci.draw_arc(c, r * 0.9, 0.0, TAU, 24, col, w, true)
			ci.draw_rect(Rect2(c - Vector2(0.38, 0.38) * r, Vector2(0.76, 0.76) * r), col)
		"general_star": ci.draw_colored_polygon(_star_pts(c, r), col)
		"arrowhead": ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7, -0.65) * r, c + Vector2(0.85, 0) * r, c + Vector2(-0.7, 0.65) * r, c + Vector2(-0.3, 0) * r]), col)
		"hammer":
			ci.draw_line(c + Vector2(-0.7, 0.8) * r, c + Vector2(0.35, -0.25) * r, col, w * 1.1, true)
			ci.draw_rect(Rect2(c + Vector2(-0.05, -0.85) * r, Vector2(0.95, 0.55) * r), col)
		"filter": ci.draw_polyline(PackedVector2Array([c + Vector2(-0.8, -0.7) * r, c + Vector2(0.8, -0.7) * r, c + Vector2(0.12, 0.05) * r, c + Vector2(0.12, 0.8) * r, c + Vector2(-0.12, 0.65) * r, c + Vector2(-0.12, 0.05) * r, c + Vector2(-0.8, -0.7) * r]), col, w, true)

# ---------------------------------------------------------------- the flat plate (paper document / dark furniture)
class PlateBox extends StyleBox:
	var fill := "paper_0"
	var fill_a := 1.0
	var border := "rule"
	var cut := 4.0
	var elev := 0                               # 0 none, 1 = one hard shadow (0, 3) at black 26 %
	var bar := ""                               # optional 3 px left bar token (recommended / armed)
	var outline := ""                           # optional extra 2 px outline token (armed, focus)
	var _size := Vector2(-1, -1)
	var _mode := -1
	var _poly := PackedVector2Array()
	var _line := PackedVector2Array()
	var _shadow := PackedVector2Array()
	var _out := PackedVector2Array()
	var _c_fill := PackedColorArray()
	var _c_shadow := PackedColorArray()
	var _c_bar := PackedColorArray()
	var _col_border := Color.TRANSPARENT
	var _col_out := Color.TRANSPARENT
	var _bar_rect := PackedVector2Array()

	func _init(f: String = "paper_0", b: String = "rule", c: float = 4.0, e: int = 0) -> void:
		fill = f; border = b; cut = c; elev = e

	func _rebuild(r: Rect2) -> void:
		_size = r.size; _mode = TBTokens.sig()
		var rr := Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1, 1 + (3 if elev > 0 else 0)))
		_poly = TBCmdCard.chamfer(rr, cut)
		_line = _poly.duplicate(); _line.append(_poly[0])
		_shadow = TBCmdCard.chamfer(Rect2(rr.position + Vector2(0, 3), rr.size), cut) if elev > 0 else PackedVector2Array()
		var f := TBCmdCard.tk(fill); f.a = fill_a
		_c_fill = PackedColorArray([f])
		var sh := TBTokens.ca("table", TBTokens.SHADOW_A[1])
		_c_shadow = PackedColorArray([sh])
		_col_border = TBCmdCard.tk(border) if border != "" else Color.TRANSPARENT
		if bar != "":
			_c_bar = PackedColorArray([TBCmdCard.tk(bar)])
			_bar_rect = PackedVector2Array([rr.position + Vector2(0, cut * 0.5), rr.position + Vector2(3, cut * 0.5), rr.position + Vector2(3, rr.size.y - cut * 0.5), rr.position + Vector2(0, rr.size.y - cut * 0.5)])
		if outline != "":
			_col_out = TBCmdCard.tk(outline)
			var o := TBCmdCard.chamfer(rr.grow(-2.0), maxf(1.0, cut - 2.0))
			_out = o.duplicate(); _out.append(o[0])

	func _draw(ci: RID, rect: Rect2) -> void:
		if rect.size != _size or TBTokens.sig() != _mode: _rebuild(rect)
		if elev > 0: RenderingServer.canvas_item_add_polygon(ci, _shadow, _c_shadow)
		RenderingServer.canvas_item_add_polygon(ci, _poly, _c_fill)
		if border != "": RenderingServer.canvas_item_add_polyline(ci, _line, PackedColorArray([_col_border]), 1.0, false)
		if bar != "": RenderingServer.canvas_item_add_polygon(ci, _bar_rect, _c_bar)
		if outline != "": RenderingServer.canvas_item_add_polyline(ci, _out, PackedColorArray([_col_out]), 2.0, false)

	func force_rebuild() -> void: _size = Vector2(-1, -1)

static func plate(fill: String = "paper_0", border: String = "rule", cut: float = 4.0, elev: int = 0) -> PlateBox:
	return PlateBox.new(fill, border, cut, elev)

# ---------------------------------------------------------------- info chip (icon + caption + value)
class InfoChip extends Control:
	var glyph := ""
	var caption := ""
	var value := ""
	var tone := ""                              # "" | "neg" | "warn" | "info"
	var compact := false
	var tip := ""
	var _box_n: PlateBox
	var _box_t: PlateBox
	func _init(g: String, cap: String, val: String, t: String = "", tooltip: String = "") -> void:
		glyph = g; caption = cap; value = val; tone = t; tip = tooltip
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = tooltip if tooltip != "" else ("%s %s" % [cap, val]).strip_edges()
		focus_mode = Control.FOCUS_NONE
		_box_n = TBCmdCard.plate("paper_1", "", TBTokens.CUT_CHIP)
		_box_t = TBCmdCard.plate("paper_1", "neg" if t == "neg" else ("warn" if t == "warn" else "info"), TBTokens.CUT_CHIP)
	func _fonts() -> Array: return [TBKit.body(), TBKit.mono_b()]
	func _widths() -> Vector2:
		var f: Font = TBKit.body(); var m: Font = TBKit.mono_b()
		var cw := 0.0 if (compact or caption == "") else f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13)).x + 4.0
		var vw := m.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(14)).x if (value != "" and (value.length() < 9 or not value.contains(" "))) else TBKit.body_b().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(14)).x
		return Vector2(cw, vw)
	func _get_minimum_size() -> Vector2:
		var w := _widths()
		return Vector2(6.0 + (16.0 + 4.0 if glyph != "" else 0.0) + w.x + w.y + 6.0, 28.0)
	func set_compact(c: bool) -> void:
		if compact == c: return
		compact = c; update_minimum_size(); queue_redraw()
	func _draw() -> void:
		(_box_t if tone != "" else _box_n).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var x := 6.0
		var ink := TBCmdCard.tk("ink_0"); var sub := TBCmdCard.tk("ink_1")
		var base := size.y * 0.5 + 5.0
		if glyph != "":
			var gc := ink
			if tone == "neg": gc = TBCmdCard.tk("neg")
			elif tone == "warn": gc = TBCmdCard.tk("warn")
			TBCmdCard.glyph(self, glyph, Vector2(x + 8.0, size.y * 0.5), 15.0, gc, 1.5)
			x += 20.0
		if not compact and caption != "":
			var f: Font = TBKit.body()
			draw_string(f, Vector2(x, base), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13), sub)
			x += f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13)).x + 4.0
		var vf: Font = TBKit.mono_b() if (value.length() < 9 or not value.contains(" ")) else TBKit.body_b()
		draw_string(vf, Vector2(x, base), value, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(14), ink)

# ---------------------------------------------------------------- verb button (icon + label + hotkey badge; "blocked" keeps it tappable)
class VerbBtn extends Button:
	var verb_id := ""
	var glyph := ""
	var label := ""
	var hot := ""
	var primary := false
	var danger := false
	var blocked := false
	var short_form := false                    # icon only (landscape phone strip): the label shows on focus / in the cost line
	var sub_gold := 0
	var sub_moves := 0
	var sub_dp := 0
	var aoc := true                            # Age-of-Civilizations action button: label centred, hotkey top-right, glyph bottom-right
	var _bn: PlateBox
	var _bh: PlateBox
	var _bp: PlateBox
	var _bb: PlateBox
	var _bf: PlateBox
	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		toggle_mode = false
		for st in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		clip_text = false
	func setup(id: String, g: String, text: String, hotkey: String, is_primary: bool, is_danger: bool) -> VerbBtn:
		verb_id = id; glyph = g; label = text; hot = hotkey; primary = is_primary; danger = is_danger
		_make_boxes()
		return self
	func _make_boxes() -> void:
		var fills := ["paper_1", "paper_hover", "paper_2"]
		var border := "rule"
		if primary: fills = ["brass", "brass_hover", "brass_press"]; border = "brass_ink"
		elif danger: fills = ["wax", "wax_hover", "wax_press"]; border = "wax_rim"
		_bn = TBCmdCard.plate(fills[0], border, TBTokens.CUT)
		_bh = TBCmdCard.plate(fills[1], border, TBTokens.CUT)
		_bp = TBCmdCard.plate(fills[2], border, TBTokens.CUT)
		_bb = TBCmdCard.plate("paper_1", "rule", TBTokens.CUT); _bb.fill_a = 0.6
	func set_blocked(b: bool) -> void:
		if blocked == b: return
		blocked = b; queue_redraw()
	func _get_minimum_size() -> Vector2:
		return Vector2(48.0 if short_form else 76.0, TBCmdCard.touch())
	func _text_colour() -> Color:
		if blocked: return TBCmdCard.tk("ink_off")
		if danger: return TBCmdCard.tk("on_wax")
		return TBCmdCard.tk("ink_0")
	func _draw_aoc() -> void:
		var P := TBHudParts
		var rect := Rect2(Vector2.ZERO, size)
		var shift := Vector2(0, 1) if (button_pressed and not blocked) else Vector2.ZERO
		var fill: Color = P.al(P.tk("bar_0"), 0.94)
		var edge: Color = P.tk("rule")
		if primary: edge = P.tk("brass_lt")
		if danger: edge = P.tk("wax_rim"); fill = P.al(P.tk("wax"), 0.9)
		if is_hovered() and not blocked: fill = fill.lerp(P.tk("bar_2"), 0.7); edge = P.tk("brass_lt")
		if button_pressed and not blocked: fill = fill.lerp(Color.BLACK, 0.25)
		draw_style_box(P.sbox(P.al(Color.BLACK, 0.5), Color.TRANSPARENT, P.R(8.0), 0), rect.grow(1.0))
		draw_style_box(P.sbox(fill, edge, P.R(7.0), 2), rect)
		draw_style_box(P.sbox(Color.TRANSPARENT, P.al(edge, 0.35), P.R(4.0), 1), rect.grow(-P.R(4.0)))
		var tc: Color = P.tk("ink_off") if blocked else (P.tk("on_wax") if danger else P.al(P.tk("cream"), 0.92))
		var f: Font = P.body_b()
		var fsz: int = P.fr(19.0)
		var avail: float = size.x - P.R(14.0)
		var lbl: String = label
		var longest := 0.0
		for wd in lbl.split(" "): longest = maxf(longest, f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x)
		while longest > avail and fsz > 12:
			fsz -= 1
			longest = 0.0
			for wd2 in lbl.split(" "): longest = maxf(longest, f.get_string_size(wd2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x)
		var th: float = f.get_multiline_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, avail, fsz, 2, TextServer.BREAK_WORD_BOUND).y
		if th > f.get_height(fsz) * 1.5 and fsz > 12:                  # two lines: one size down so they stay inside the plate
			fsz = maxi(12, fsz - 2)
			th = f.get_multiline_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, avail, fsz, 2, TextServer.BREAK_WORD_BOUND).y
		var y0: float = size.y * 0.56 - th * 0.5 + f.get_ascent(fsz) + shift.y
		f.draw_multiline_string(get_canvas_item(), Vector2((size.x - avail) * 0.5, y0), lbl, HORIZONTAL_ALIGNMENT_CENTER, avail, fsz, 2, tc, TextServer.BREAK_WORD_BOUND)
		if glyph != "": TBCmdCard.glyph(self, glyph, Vector2(size.x - P.R(17.0), size.y - P.R(15.0)) + shift, P.R(20.0), P.al(tc, 0.75), 1.6)
		var sub: String = ""
		if sub_gold > 0: sub = TBKit.fmt(sub_gold)
		elif sub_dp > 0: sub = "%d" % sub_dp
		elif sub_moves > 0: sub = "%d" % sub_moves
		if sub != "" and not blocked:
			var sz: int = P.fr(15.0)
			var sc2: Color = P.tk("brass_lt") if sub_gold > 0 else P.tk("smoke")
			draw_string(P.body(), Vector2(P.R(11.0), size.y - P.R(9.0)) + shift, sub, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.55, sz, sc2)
		# corner ornaments: short brass ticks on the four outer corners (AoC's gilded frame)
		var oc: Color = P.al(P.tk("brass_lt"), 0.0 if blocked else 0.6)
		var cl: float = P.R(7.0)
		for cx in [0.0, size.x]:
			for cy2 in [0.0, size.y]:
				var dx: float = cl if cx == 0.0 else -cl
				var dy: float = cl if cy2 == 0.0 else -cl
				draw_line(Vector2(cx, cy2), Vector2(cx + dx, cy2), oc, 1.5)
				draw_line(Vector2(cx, cy2), Vector2(cx, cy2 + dy), oc, 1.5)
		if blocked: TBCmdCard.glyph(self, "lock", Vector2(P.R(15.0), size.y - P.R(14.0)), P.R(15.0), tc, 1.3)
		if hot != "" and TBCmdCard.show_hotkeys:
			var hs: int = 12
			draw_string(P.body(), Vector2(size.x - P.tw(f, hot, hs) - P.R(8.0), P.R(7.0) + f.get_ascent(hs)), hot, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, P.tk("smoke"))
		if has_focus():
			draw_rect(rect.grow(-1.0), P.tk("cream"), false, 2.0)
	func _draw() -> void:
		if aoc:
			_draw_aoc()
			return
		var rect := Rect2(Vector2.ZERO, size)
		var sf := short_form and size.x < 84.0                  # icon only just while the button is narrow; wide strips show the verb
		var box := _bn
		if blocked: box = _bb
		elif button_pressed: box = _bp
		elif is_hovered(): box = _bh
		var shift := Vector2(0, 1) if (button_pressed and not blocked) else Vector2.ZERO
		box.draw(get_canvas_item(), rect)
		var tc := _text_colour()
		var gx := 18.0 if not sf else size.x * 0.5
		if glyph != "":
			var gcol := tc
			TBCmdCard.glyph(self, glyph, Vector2(gx, size.y * 0.5 - (6.0 if sf and TBCmdCard.show_hotkeys else 0.0)) + shift, 20.0, gcol, 1.7)
		if blocked: TBCmdCard.glyph(self, "lock", Vector2(size.x - 9.0, 9.0), 10.0, tc, 1.3)
		if not sf:
			var f: Font = TBKit.body_b()
			var fsz := TBCmdCard.fs(13)
			var avail := size.x - 36.0 - (0.0 if hot == "" or not TBCmdCard.show_hotkeys else 0.0)
			var lines := label
			var th := f.get_multiline_string_size(lines, HORIZONTAL_ALIGNMENT_LEFT, avail, fsz, 2).y
			var longest := 0.0
			for wd in label.split(" "): longest = maxf(longest, f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x)
			while longest > avail and fsz > TBTokens.FS_CAPTION:           # never an ellipsis on a verb: shrink to the 12 px floor, then break the word
				fsz -= 1
				longest = 0.0
				for wd2 in label.split(" "): longest = maxf(longest, f.get_string_size(wd2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x)
			th = f.get_multiline_string_size(lines, HORIZONTAL_ALIGNMENT_LEFT, avail, fsz, 3).y
			var y0 := (size.y - th) * 0.5 + f.get_ascent(fsz) + shift.y - (3.0 if hot != "" and TBCmdCard.show_hotkeys and th < 20.0 else 0.0)
			f.draw_multiline_string(get_canvas_item(), Vector2(32.0, y0), lines, HORIZONTAL_ALIGNMENT_LEFT, avail + 4.0, fsz, 3, tc, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		if hot != "" and TBCmdCard.show_hotkeys and TBCmdCard.text_scale < 1.5:
			var m: Font = TBKit.mono_b()
			var hs := TBCmdCard.fs(12)
			var bw := maxf(16.0, m.get_string_size(hot, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x + 6.0)
			var br := Rect2(size.x - bw - 4.0, size.y - float(hs) - 5.0, bw, float(hs) + 2.0)
			draw_rect(br, TBCmdCard.tk("ink_1") if not danger else TBCmdCard.tk("on_wax"), false, 1.0)
			draw_string(m, br.position + Vector2(3.0, float(hs) - 0.5), hot, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, TBCmdCard.tk("ink_1") if not danger else TBCmdCard.tk("on_wax"))
		if has_focus():
			draw_rect(rect.grow(-1.0), TBCmdCard.tk("ink_0"), false, 2.0)
			draw_rect(rect.grow(1.0), TBCmdCard.tk("paper_0"), false, 1.0)

# ---------------------------------------------------------------- send-share segmented control (25 / 50 / 75 / 100 %)
class ShareSeg extends Control:
	signal chosen(frac: float)
	const FRACS := [0.25, 0.5, 0.75, 1.0]
	var current := 1.0
	var off := [false, false, false, false]    # duplicate presets (small armies) are disabled
	var cell_h := 36.0
	var cell_w := 40.0
	var _box: PlateBox
	var _sel := PackedVector2Array()
	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		_box = TBCmdCard.plate("paper_1", "rule", TBTokens.CUT)
	func _cw() -> float: return maxf(cell_w, TBKit.mono_b().get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13)).x + 14.0)
	func _get_minimum_size() -> Vector2: return Vector2(_cw() * 4.0, cell_h)
	## the hit area is at least 48 high even where the cells are 36 (desktop pointer cards)
	func _has_point(p: Vector2) -> bool:
		var ex: float = maxf(0.0, (TBCmdCard.touch() - size.y) * 0.5)
		return Rect2(Vector2(0.0, -ex), Vector2(size.x, size.y + ex * 2.0)).has_point(p)
	func set_current(f: float) -> void:
		current = f; queue_redraw()
	func _idx_at(x: float) -> int: return clampi(int(x / (size.x / 4.0)), 0, 3)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pick(_idx_at(e.position.x)); accept_event()
		elif e is InputEventKey and e.pressed and has_focus():
			var i := FRACS.find(current)
			if e.keycode == KEY_LEFT: _pick(maxi(0, i - 1)); accept_event()
			elif e.keycode == KEY_RIGHT: _pick(mini(3, i + 1)); accept_event()
	func _pick(i: int) -> void:
		while i > 0 and off[i]: i -= 1               # a disabled duplicate resolves to the preset below it
		current = FRACS[i]; chosen.emit(current); queue_redraw()
	func _draw() -> void:
		_box.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var w := size.x / 4.0
		var f: Font = TBKit.mono_b()
		for i in 4:
			var on: bool = absf(FRACS[i] - current) < 0.001
			var r := Rect2(i * w, 0, w, size.y)
			if on:
				draw_colored_polygon(TBCmdCard.chamfer(r.grow(-1.0), 3.0 if (i == 0 or i == 3) else 0.0), TBCmdCard.tk("act"))
			elif i > 0:
				draw_line(Vector2(r.position.x + 0.5, 6.0), Vector2(r.position.x + 0.5, size.y - 6.0), TBCmdCard.tk("hair"), 1.0)
			var t := "%d" % int(FRACS[i] * 100.0) + ("%" if i == 3 else "")
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13)).x
			var c := TBCmdCard.tk("on_act") if on else (TBCmdCard.tk("ink_off") if off[i] else TBCmdCard.tk("ink_0"))
			draw_string(f, Vector2(r.position.x + (w - tw) * 0.5, size.y * 0.5 + 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(13), c)
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), TBCmdCard.tk("ink_0"), false, 2.0)

# ---------------------------------------------------------------- cost line (wraps to as many lines as it needs; the shortfall part is underlined as well as red)
class CostLine extends Control:
	var parts: Array = []                       # [{t: String, short: bool}]
	var error := false                          # a rejected command: whole line in neg with a warning glyph
	var _lines := 1
	var _w := -1.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clip_contents = true
		resized.connect(_relines)
	func _fsz() -> int: return TBCmdCard.fs(13)
	func _lh() -> float: return TBKit.body().get_height(_fsz())
	func _get_minimum_size() -> Vector2: return Vector2(40, maxf(18.0, _lines * _lh() + 2.0))
	func set_parts(p: Array, is_error: bool = false) -> void:
		parts = p; error = is_error
		var full := ""
		for q in p: full += String(q["t"])
		tooltip_text = full
		_w = -1.0
		_relines()
		queue_redraw()
	## flow the parts onto lines: [{t, short, x, y}] and the line count for the current width
	func _flow(room: float) -> Array:
		var f: Font = TBKit.body()
		var out: Array = []
		var x := 0.0; var line := 0
		for q in parts:
			var t: String = String(q["t"])
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _fsz()).x
			if x > 0.0 and x + tw > room:
				line += 1; x = 0.0
				t = t.trim_prefix(" · ").trim_prefix(" ")
				tw = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _fsz()).x
			out.append({"t": t, "short": bool(q["short"]), "x": x, "y": line, "w": tw})
			x += tw
		return out
	func _room() -> float: return maxf(40.0, (size.x if size.x > 1.0 else 300.0) - (20.0 if error else 0.0))
	func _relines() -> void:
		if absf(size.x - _w) < 0.5: return
		_w = size.x
		var fl := _flow(_room())
		var n := 1
		for q in fl: n = maxi(n, int(q["y"]) + 1)
		n = mini(n, 3)
		if n != _lines:
			_lines = n; update_minimum_size()
	func _draw() -> void:
		var f: Font = TBKit.body()
		var fsz := _fsz()
		var x0 := 0.0
		var lh := _lh()
		if error:
			TBCmdCard.glyph(self, "warning", Vector2(8.0, lh * 0.5 + 1.0), 14.0, TBCmdCard.tk("neg"), 1.5); x0 = 20.0
		var ink := TBCmdCard.tk("ink_1"); var neg := TBCmdCard.tk("neg")
		for q in _flow(maxf(40.0, size.x - x0)):
			var base: float = float(q["y"]) * lh + f.get_ascent(fsz) + 1.0
			var col := neg if (bool(q["short"]) or error) else ink
			var px: float = x0 + float(q["x"])
			draw_string(f, Vector2(px, base), String(q["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
			if bool(q["short"]): draw_line(Vector2(px, base + 2.0), Vector2(px + float(q["w"]), base + 2.0), neg, 1.0)

# ---------------------------------------------------------------- small drawn widgets for the Details drawer
class Pips extends Control:
	var n := 0
	var maxn := 5
	func _init(v: int, m: int = 5) -> void:
		n = v; maxn = m; mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(m * 12.0, 18)
	func _draw() -> void:
		for i in maxn:
			var c := Vector2(6.0 + i * 12.0, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
			if i < n: draw_colored_polygon(pts, TBCmdCard.tk("ink_0"))
			else:
				pts.append(pts[0]); draw_polyline(pts, TBCmdCard.tk("ink_off"), 1.0)

class Meter extends Control:
	var v := 0
	func _init(value: int) -> void:
		v = value; mouse_filter = Control.MOUSE_FILTER_IGNORE; custom_minimum_size = Vector2(60, 16); size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var y := size.y * 0.5 - 4.0
		var tr := Rect2(0, y, size.x, 8)
		draw_rect(tr, TBCmdCard.tk("paper_1"))
		draw_rect(tr, TBCmdCard.tk("rule"), false, 1.0)
		var col := TBCmdCard.tk("pos") if v >= 50 else (TBCmdCard.tk("warn") if v >= 30 else TBCmdCard.tk("neg"))
		var fw := (size.x - 2.0) * clampf(float(v) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(1, y + 1, fw, 6), col)
		if v < 30:                                # hatch + sign: colour is never the only carrier
			var x := 2.0
			while x < fw:
				draw_line(Vector2(x, y + 7.0), Vector2(minf(x + 6.0, fw), y + 1.0), TBCmdCard.tk("paper_0"), 1.0)
				x += 6.0
		for t in [30, 50]:
			var tx := 1.0 + (size.x - 2.0) * float(t) / 100.0
			draw_line(Vector2(tx, y - 2.0), Vector2(tx, y + 10.0), TBCmdCard.tk("ink_1"), 1.0)

## 12 px caption / figure label helpers
static func label(text: String, size_px: int, token: String, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else TBKit.body())
	l.add_theme_font_size_override("font_size", fs(size_px))
	l.add_theme_color_override("font_color", tk(token))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
