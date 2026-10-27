## The new title screen's parts (docs/screens/title_mocks, layout B "Orrery" with button style 4): the star field + instrument ring with the thirteen era years, the Continue card,
## the quiet rows, the one selection bracket that glides to the focused entry, the campaign card and the wordmark. Everything is drawn in the Bezel palette (TBTokens.BZ_* / atlas tokens).
## Motion goes through TBFx: with Effects Off the bracket jumps, nothing twinkles and the Continue dive is a plain cut.
class_name TBTitleParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")

## notched plate outline (cut top-left and bottom-right), clockwise
static func notch(w: float, h: float, c: float, inset: float = 0.0) -> PackedVector2Array:
	var i := inset
	return PackedVector2Array([Vector2(i + c, i), Vector2(w - i, i), Vector2(w - i, h - i - c), Vector2(w - i - c, h - i), Vector2(i, h - i), Vector2(i, i + c)])

# ================================================================================================================================ ring, stars, atmosphere
## The title's instrument: stars, the soft atmosphere, the brass ring with its 72 ticks and (wide layout) the thirteen era years. `open` 0..1 is the dive: the ring widens and fades.
class Orrery extends Control:
	var map: TBMapView
	var dim := 1.0                          # 0.35 while a panel is open
	var wide := true                        # wide layout: ring far from the globe with era years, no dimming disc (the menu is beside the globe, not on it)
	var open := 0.0
	var eras: Array = []                    # [[id, "1804"], ...] sorted by year
	var cur_era := ""
	var stars := PackedVector2Array()       # x, y in 0..1
	var star_a := PackedFloat32Array()
	var _spin0 := INF                       # the globe's turn when the title appeared: stars drift relative to it, so a still title looks the same whatever the effects setting
	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new(); r.seed = 20260611
		for i in 170:
			stars.append(Vector2(r.randf(), r.randf())); star_a.append(0.12 + r.randf() * r.randf() * 0.7)
	func ring_scale() -> float: return 1.34 if wide else 1.052
	func _globe_c() -> Vector2: return map.global_position - global_position + map.size * 0.5
	func _draw() -> void:
		if map == null: return
		var c := _globe_c()
		var R := map.radius_px()
		var spin := -map.lon0
		var a: float = dim * (1.0 - open)
		var gold := TBTokens.c("brass_lt")
		var lo := TBTokens.BZ_LO
		# stars: fixed, a hair of parallax with the globe's turn on Full; none inside the ring
		if _spin0 == INF: _spin0 = spin
		var par: float = (spin - _spin0) * size.x * 0.012 if TBFx.level >= TBFx.FULL else 0.0
		var clear2: float = pow(R * (ring_scale() + 0.12), 2.0)
		var sc: float = maxf(1.0, size.y / 720.0 * 0.8)
		for i in stars.size():
			var p := Vector2(fposmod(stars[i].x * size.x + par * (0.4 + star_a[i]), size.x), stars[i].y * size.y)
			if p.distance_squared_to(c) < clear2: continue
			draw_rect(Rect2(p, Vector2(sc, sc) * (1.4 if star_a[i] > 0.6 else 1.0)), TBTokens.with_a(TBTokens.BZ_IVORY, star_a[i] * (0.55 + 0.45 * (1.0 - open))))
		# atmosphere: a soft blue skin just outside the limb
		var rim := TBTokens.BZ_RIM
		for k in 9:
			var f: float = float(k) / 8.0
			draw_arc(c, R * (1.004 + f * 0.075), 0.0, TAU, 96, TBTokens.with_a(rim, 0.20 * pow(1.0 - f, 2.0) * dim), maxf(R * 0.012, 1.0), true)
		var rs: float = ring_scale() * (1.0 + 0.30 * open)
		if not wide:                                                           # compact: the dark annulus and the dimming disc keep the text readable on the globe
			var ink := TBTokens.c("table")
			draw_arc(c, R * 1.026, 0.0, TAU, 180, TBTokens.with_a(ink, 0.97 * a), R * 0.056, true)
			draw_circle(c, R * 1.0, TBTokens.with_a(ink, 0.50 * a))
		draw_arc(c, R * rs, 0.0, TAU, 180, TBTokens.with_a(gold, 0.95 * a), 1.5, true)
		draw_arc(c, R * (rs + (0.06 if wide else 0.04)), 0.0, TAU, 180, TBTokens.with_a(gold, 0.40 * a), 1.0, true)
		var r_in: float = R * rs
		for i in 72:                                                           # one tick every 5 degrees, a long one every 30, turning with the globe
			var ang := i * TAU / 72.0 + spin
			var d := Vector2(cos(ang), sin(ang))
			var long := i % 6 == 0
			var r1: float = r_in + R * ((0.06 if long else 0.034) if wide else (0.04 if long else 0.02))
			draw_line(c + d * r_in, c + d * r1, TBTokens.with_a(gold if long else lo, (0.9 if long else 0.55) * a), 2.0 if long else 1.0, true)
		if wide and not eras.is_empty():
			_draw_eras(c, R, rs, a)
		else:
			for q in 4:                                                        # N / E / S / W lubber marks
				var ang2 := q * PI * 0.5 - PI * 0.5
				var d2 := Vector2(cos(ang2), sin(ang2))
				var p := c + d2 * R * (rs + 0.043)
				var t := d2.orthogonal()
				draw_colored_polygon(PackedVector2Array([p, p + d2 * R * 0.03 + t * R * 0.014, p + d2 * R * 0.03 - t * R * 0.014]), TBTokens.with_a(gold, a))
	## the thirteen worlds around the ring, the chosen one at the top with a brass diamond
	func _draw_eras(c: Vector2, R: float, rs: float, a: float) -> void:
		var f := TBKit.mono_b()
		var fsz := TBKit.fs(11.0 * size.y / 720.0 * 0.9)
		var n := eras.size()
		var top := 0
		for i in n:
			if eras[i][0] == cur_era: top = i
		for i in n:
			var ang: float = -PI * 0.5 + float(i - top) * TAU / float(n)
			var d := Vector2(cos(ang), sin(ang))
			var is_top := i == top
			var pn: Vector2 = c + d * R * (rs + 0.02)
			var col: Color = TBTokens.c("brass_lt") if is_top else TBTokens.BZ_DIM2
			var pd: Vector2 = c + d * R * (rs + 0.0)
			var s: float = R * (0.035 if is_top else 0.02)
			var t := d.orthogonal()
			var dia := PackedVector2Array([pd + d * s, pd + t * s * 0.7, pd - d * s, pd - t * s * 0.7])
			draw_colored_polygon(dia, TBTokens.with_a(col, a * (1.0 if is_top else 0.8)))
			var txt: String = eras[i][1]
			var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			var lp: Vector2 = c + d * R * (rs + 0.15) - Vector2(tw * 0.5, -f.get_ascent(fsz) * 0.35)
			draw_string(f, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz + (2 if is_top else 0), TBTokens.with_a(col, a))

# ================================================================================================================================ the Continue card (style 4)
## A notched card: flag medal (or a globe glyph), title in tracked caps, an italic line below and a chevron. `kind`: "continue" shows the flag, "new" the globe.
class CardBtn extends Button:
	var title := ""
	var sub := ""
	var flag: Texture2D
	var glyph := ""
	var u := 1.0                          # design scale (screen height / 720)
	var _press := false
	signal chosen(btn: CardBtn)
	func _init(title_text: String, sub_text: String, flag_tex: Texture2D, glyph_name: String, scale_u: float, cb: Callable, a11y: String = "") -> void:
		title = title_text; sub = sub_text; flag = flag_tex; glyph = glyph_name; u = scale_u
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		custom_minimum_size = Vector2(270.0 * u, maxf(78.0 * u, float(TBKit.touch())))
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, title_text, "button", sub_text if a11y == "" else a11y)
		mouse_entered.connect(_enter); focus_entered.connect(func(): chosen.emit(self)); button_down.connect(queue_redraw); button_up.connect(queue_redraw)
		mouse_exited.connect(queue_redraw); focus_exited.connect(queue_redraw)
	func _enter() -> void:
		if not has_focus() and not OS.has_feature("mobile"): grab_focus()
		queue_redraw()
	func _draw() -> void:
		var w := size.x; var h := size.y
		var hot: bool = is_hovered() or has_focus()
		var down: bool = get_draw_mode() == BaseButton.DRAW_PRESSED
		var cut: float = 12.0 * u
		var pts := TBTitleParts.notch(w, h, cut, 0.5)
		var cols := PackedColorArray()
		for p in pts:
			var k: float = clampf(p.x / w * 0.7 + p.y / h * 0.3, 0.0, 1.0)
			var left: Color = TBTokens.BZ_BTN_FILL_HOT if hot else TBTokens.BZ_BTN_FILL
			var right: Color = TBTokens.BZ_PLATE_BOT
			cols.append(left.lerp(right, k) if not down else TBTokens.BZ_TUNER.lerp(TBTokens.BZ_SHADOW, k))
		draw_polygon(pts, cols)
		if hot and not down:                                               # a brass wash from the left edge
			var wash := PackedColorArray([TBTokens.with_a(TBTokens.BZ_HI, 0.10), TBTokens.with_a(TBTokens.BZ_HI, 0.0), TBTokens.with_a(TBTokens.BZ_HI, 0.0), TBTokens.with_a(TBTokens.BZ_HI, 0.0), TBTokens.with_a(TBTokens.BZ_HI, 0.04), TBTokens.with_a(TBTokens.BZ_HI, 0.10)])
			draw_polygon(pts, wash)
		var line: Color = TBTokens.BZ_HI if hot else TBTokens.BZ_LO
		var closed := pts.duplicate(); closed.append(pts[0])
		draw_polyline(closed, line, 1.2, true)
		if down: draw_rect(Rect2(cut, 1.0, w - cut * 2.0, 3.0 * u), TBTokens.with_a(TBTokens.BZ_SHADOW, 0.6))
		var oy: float = 1.0 if down else 0.0
		var cx: float = 16.0 * u + 22.0 * u
		var cy: float = h * 0.5 + oy
		if flag != null:
			TBFlags.draw_flag_medal(self, flag, Vector2(cx, cy), 46.0 * u)
		else:
			draw_circle(Vector2(cx, cy), 22.0 * u, TBTokens.BZ_FACE)
			draw_arc(Vector2(cx, cy), 22.0 * u, 0.0, TAU, 48, TBTokens.BZ_LO, 1.0, true)
			TBGlyph.draw(self, glyph if glyph != "" else "globe", Vector2(cx, cy), 20.0 * u, TBTokens.c("brass_lt"))
		var tx: float = cx + 22.0 * u + 14.0 * u
		var maxw: float = w - tx - 38.0 * u
		var f := TBKit.tracked(TBKit.alegreya(700) if TBKit.readable_fonts else TBKit.wordmark(), 3)
		var fsz := TBKit.fs(16.0 * u)
		var ink: Color = TBTokens.c("brass_lt") if (down or hot) else TBTokens.c("cream")
		var tw: float = minf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, maxw)
		var two := sub != ""
		var ty: float = cy - (7.0 * u if two else 0.0) + f.get_ascent(fsz) * 0.5 - 2.0
		draw_string(f, Vector2(tx, roundf(ty)), title, HORIZONTAL_ALIGNMENT_LEFT, maxw, fsz, ink)
		if two:
			var sf := TBKit.body_i()
			var ssz := TBKit.fs(13.5 * u)
			draw_string(sf, Vector2(tx, roundf(cy + 14.0 * u + sf.get_ascent(ssz) * 0.5 - 4.0)), sub, HORIZONTAL_ALIGNMENT_LEFT, maxw, ssz, TBTokens.c("smoke"))
		# chevron
		var chx: float = w - 22.0 * u
		var s: float = 5.0 * u
		draw_polyline(PackedVector2Array([Vector2(chx - s * 0.5, cy - s), Vector2(chx + s * 0.5, cy), Vector2(chx - s * 0.5, cy + s)]), TBTokens.c("brass_lt"), 1.8, true)

# ================================================================================================================================ the quiet rows
## A row: brass diamond, caps text, a hairline below. Disabled rows are dimmed (and say why in the tooltip).
class RowBtn extends Button:
	var title := ""
	var u := 1.0
	signal chosen(btn: RowBtn)
	func _init(title_text: String, scale_u: float, cb: Callable, why_disabled: String = "") -> void:
		title = title_text; u = scale_u
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		custom_minimum_size = Vector2(270.0 * u, maxf(40.0 * u, float(TBKit.touch())))
		if why_disabled != "": disabled = true; tooltip_text = why_disabled
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, title_text, "button", why_disabled)
		mouse_entered.connect(_enter); focus_entered.connect(func(): chosen.emit(self)); mouse_exited.connect(queue_redraw); focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw); button_up.connect(queue_redraw)
	func _enter() -> void:
		if disabled: return
		if not has_focus() and not OS.has_feature("mobile"): grab_focus()
		queue_redraw()
	func _draw() -> void:
		var w := size.x; var h := size.y
		var hot: bool = (is_hovered() or has_focus()) and not disabled
		var down: bool = get_draw_mode() == BaseButton.DRAW_PRESSED and not disabled
		var dim: float = 0.45 if disabled else 1.0
		draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), TBTokens.with_a(TBTokens.BZ_LO if hot else TBTokens.BZ_ROW_LINE, dim), 1.0)
		var cy: float = h * 0.5 + (1.0 if down else 0.0)
		var dx: float = 12.0 * u
		var s: float = 3.4 * u
		var dia := PackedVector2Array([Vector2(dx, cy - s), Vector2(dx + s, cy), Vector2(dx, cy + s), Vector2(dx - s, cy)])
		if hot: draw_circle(Vector2(dx, cy), s * 2.2, TBTokens.with_a(TBTokens.BZ_HI, 0.16))
		draw_colored_polygon(dia, TBTokens.with_a(TBTokens.BZ_HI if hot else TBTokens.BZ_LO, dim))
		var f := TBKit.tracked(TBKit.alegreya(700) if TBKit.readable_fonts else TBKit.wordmark(), 3)
		var fsz := TBKit.fs(13.5 * u)
		var ink: Color = TBTokens.c("brass_lt") if down else (TBTokens.c("cream") if hot else TBTokens.c("smoke"))
		draw_string(f, Vector2(dx + 22.0 * u, roundf(cy + f.get_ascent(fsz) * 0.5 - 2.0)), title, HORIZONTAL_ALIGNMENT_LEFT, w - dx - 30.0 * u, fsz, TBTokens.with_a(ink, dim))

# ================================================================================================================================ the one selection bracket
## Four corner brackets drawn over the menu; it glides to the focused entry (jumps with Effects Off). `flash()` is the press feedback.
class SelFrame extends Control:
	var u := 1.0
	var rect := Rect2()                   # current drawn rectangle, in this control's space
	var _tw: Tween
	var _boost := 0.0
	var _has := false
	func _init(scale_u: float) -> void:
		u = scale_u; mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_preset(Control.PRESET_FULL_RECT)
	## target: global rectangle of the entry
	func go_to(global_rect: Rect2) -> void:
		var r := Rect2(global_rect.position - global_position, global_rect.size).grow(6.0 * u)
		if _tw != null and _tw.is_valid(): _tw.kill()
		if not _has or not TBFx.on(TBFx.LIGHT) or not is_inside_tree():
			rect = r; _has = true; queue_redraw(); return
		var from := rect
		_tw = TBFx.run(self, 0.20, func(t: float):
			var e: float = 1.0 - pow(1.0 - t, 3.0)
			rect = Rect2(from.position.lerp(r.position, e), from.size.lerp(r.size, e)); queue_redraw(), Callable(), TBFx.LIGHT)
	func flash() -> void:
		if not TBFx.on(TBFx.LIGHT): return
		var tw := TBFx.run(self, 0.28, func(t: float): _boost = 1.0 - t; queue_redraw(), Callable(), TBFx.LIGHT)
		_boost = 1.0
	func _draw() -> void:
		if not _has: return
		var arm: float = 12.0 * u
		var r := rect.grow(-_boost * 3.0 * u)
		var col := TBTokens.BZ_HI
		for pass_i in 2:
			var cc: Color = TBTokens.with_a(col, 0.20 + 0.3 * _boost) if pass_i == 0 else col
			var wd: float = 5.0 if pass_i == 0 else 1.5
			var x0 := r.position.x; var y0 := r.position.y; var x1 := r.end.x; var y1 := r.end.y
			draw_polyline(PackedVector2Array([Vector2(x0, y0 + arm), Vector2(x0, y0), Vector2(x0 + arm, y0)]), cc, wd)
			draw_polyline(PackedVector2Array([Vector2(x1 - arm, y0), Vector2(x1, y0), Vector2(x1, y0 + arm)]), cc, wd)
			draw_polyline(PackedVector2Array([Vector2(x0, y1 - arm), Vector2(x0, y1), Vector2(x0 + arm, y1)]), cc, wd)
			draw_polyline(PackedVector2Array([Vector2(x1 - arm, y1), Vector2(x1, y1), Vector2(x1, y1 - arm)]), cc, wd)

# ================================================================================================================================ the campaign card (right side)
class Campaign extends Control:
	var u := 1.0
	var flag: Texture2D
	var nation := ""
	var line1 := ""
	var line2 := ""
	var caption := ""
	var head := ""
	func _init(scale_u: float, flag_tex: Texture2D, nation_name: String, l1: String, l2: String, cap: String, head_text: String) -> void:
		u = scale_u; flag = flag_tex; nation = nation_name; line1 = l1; line2 = l2; caption = cap; head = head_text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(268.0 * u, 140.0 * u)
	func _draw() -> void:
		var w := size.x; var cap_h: float = 22.0 * u
		var cf := TBKit.tracked(TBKit.wordmark(), 2)
		var csz := TBKit.fs(10.5 * u)
		TBMenuParts.glow_text(self, cf, Vector2(0, roundf(cap_h * 0.7)), caption.to_upper(), w, csz, TBTokens.c("smoke"))
		var y0: float = cap_h
		var h: float = size.y - cap_h
		var pts := TBTitleParts.notch(w, h, 10.0 * u, 0.5)
		for i in pts.size(): pts[i] += Vector2(0, y0)
		var cols := PackedColorArray()
		for p in pts: cols.append(TBTokens.BZ_BTN_FILL.lerp(TBTokens.BZ_PLATE_BOT, clampf(p.x / w * 0.8, 0.0, 1.0)))
		draw_polygon(pts, cols)
		var closed := pts.duplicate(); closed.append(pts[0])
		draw_polyline(closed, TBTokens.BZ_LO, 1.0, true)
		var cx: float = 18.0 * u + 24.0 * u
		var cy: float = y0 + h * 0.5
		if flag != null: TBFlags.draw_flag_medal(self, flag, Vector2(cx, cy), 52.0 * u)
		var tx: float = cx + 24.0 * u + 14.0 * u
		var maxw: float = w - tx - 10.0 * u
		var hf := TBKit.tracked(TBKit.wordmark(), 2)
		draw_string(hf, Vector2(tx, roundf(y0 + 24.0 * u)), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, maxw, TBKit.fs(10.0 * u), TBTokens.c("brass_lt"))
		var nf := TBKit.wordmark()
		draw_string(nf, Vector2(tx, roundf(y0 + 50.0 * u)), nation, HORIZONTAL_ALIGNMENT_LEFT, maxw, TBKit.fs(22.0 * u), TBTokens.c("cream"))
		var sf := TBKit.body_i()
		draw_string(sf, Vector2(tx, roundf(y0 + 70.0 * u)), line1, HORIZONTAL_ALIGNMENT_LEFT, maxw, TBKit.fs(12.5 * u), TBTokens.c("smoke"))
		draw_string(sf, Vector2(tx, roundf(y0 + 88.0 * u)), line2, HORIZONTAL_ALIGNMENT_LEFT, maxw, TBKit.fs(12.5 * u), TBTokens.c("brass_lt"))
