## Atlas Ledger inspector parts (guide 6.1, 6.3, 6.4): the card header, the stat grid, and the action rows / primary button.
## Pure drawing; the province panel (province_panel.gd) assembles them and owns every command.
class_name TBInspector
extends RefCounted

const P = preload("res://src/ui/hud_parts.gd")
const CC = preload("res://src/ui/cmd_card.gd")

# ---------------------------------------------------------------- header
## 52 px card header: flag (or a pin for unclaimed land) + province name 16/600 + subtitle 12 (owner · relation) + close
class Header extends Control:
	signal closed
	signal owner_pressed
	var tex: Texture2D
	var title := ""
	var subtitle := ""
	var sub_col := "smoke"
	var linkable := false
	var _hit_sub := Rect2()
	var _hit_close := Rect2()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(0, 52)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = (e as InputEventMouseButton).position
			if _hit_close.has_point(pos): closed.emit()
			elif linkable and _hit_sub.has_point(pos): owner_pressed.emit()
			accept_event()
	func _draw() -> void:
		var h: float = size.y
		var x: float = 16.0
		if tex != null:
			var fr := Rect2(x, (h - 20.0) * 0.5, 30.0, 20.0)
			draw_texture_rect(tex, fr, false)
			draw_rect(fr, P.al(Color.WHITE, 0.14), false, 1.0)
			x += 30.0 + 10.0
		else:
			TBGlyph.draw(self, "pin", Vector2(x + 10.0, h * 0.5), 20.0, P.tk("smoke"), 1.5)
			x += 20.0 + 10.0
		var fb: Font = TBKit.body_b()
		var fz: int = P.fs(16.0)
		var avail: float = size.x - x - 52.0
		var has_sub: bool = subtitle != ""
		var ty: float = h * (0.38 if has_sub else 0.5)
		draw_string(fb, Vector2(x, P.base(fb, fz, ty)), P.fit(fb, title, fz, avail), HORIZONTAL_ALIGNMENT_LEFT, -1, fz, P.tk("cream"))
		if has_sub:
			var f2: Font = TBKit.body()
			var z2: int = P.fs(12.0)
			var st: String = P.fit(f2, subtitle, z2, avail - (14.0 if linkable else 0.0))
			var sw: float = P.tw(f2, st, z2)
			draw_string(f2, Vector2(x, P.base(f2, z2, h * 0.72)), st, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, P.tk(sub_col))
			_hit_sub = Rect2(x, h * 0.55, sw + (16.0 if linkable else 0.0), h * 0.4)
			if linkable: P.chev(self, Vector2(x + sw + 8.0, h * 0.72), 8.0, P.tk(sub_col), 1.3)
		var cr := Rect2(size.x - 44.0, (h - 36.0) * 0.5, 36.0, 36.0)
		_hit_close = cr.grow(4.0)
		TBGlyph.draw(self, "close", cr.get_center(), 16.0, P.tk("smoke"), 1.5)
		draw_rect(Rect2(0, h - 1.0, size.x, 1.0), P.tk("rule"))

# ---------------------------------------------------------------- stat grid
## label (12 / 600, uppercase, paper-500) over a value (16 / 600, tabular) with an optional signed delta and a 6 px bar; 2 columns, 12 px gaps
class Grid extends Control:
	var cells: Array = []              # [{label, value, col, bar (0..1 or -1), tip, span}]
	var cols := 2
	var _layout: Array = []
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_PASS
	func _cell_h(c: Dictionary) -> float: return 48.0 if float(c.get("bar", -1.0)) < 0.0 else 58.0
	func _compute(w: float) -> float:
		_layout = []
		var gap: float = 12.0
		var cw: float = (w - gap * (cols - 1)) / cols
		var x: int = 0
		var y: float = 0.0
		var row_h: float = 0.0
		for c in cells:
			var span: int = mini(int(c.get("span", 1)), cols)
			if x + span > cols:
				x = 0; y += row_h + 8.0; row_h = 0.0
			var rc := Rect2(x * (cw + gap), y, cw * span + gap * (span - 1), _cell_h(c))
			_layout.append(rc)
			row_h = maxf(row_h, rc.size.y)
			x += span
			if x >= cols: x = 0; y += row_h + 8.0; row_h = 0.0
		return y + row_h
	func _get_minimum_size() -> Vector2:
		var w: float = size.x if size.x > 20.0 else 300.0
		return Vector2(0, _compute(w))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: update_minimum_size()
	func _get_tooltip(at: Vector2) -> String:
		for i in _layout.size():
			if (_layout[i] as Rect2).has_point(at): return String(cells[i].get("tip", ""))
		return ""
	func _draw() -> void:
		_compute(size.x)
		for i in cells.size():
			var c: Dictionary = cells[i]
			var rc: Rect2 = _layout[i]
			var f1: Font = TBKit.body_b()
			var z1: int = P.fs(12.0)
			var lab: String = String(c["label"])
			lab = lab.to_upper() if TBI18n.lang != "ru" else lab
			var lf: Font = TBKit.tracked(f1, 0)
			draw_string(f1, Vector2(rc.position.x, rc.position.y + f1.get_ascent(z1)), P.fit(f1, lab, z1, rc.size.x), HORIZONTAL_ALIGNMENT_LEFT, -1, z1, P.tk("ink_off"))
			var fv: Font = TBKit.mono_b()
			var z2: int = P.fs(16.0)
			var vy: float = rc.position.y + 18.0 + fv.get_ascent(z2)
			var val: String = String(c["value"])
			var col: Color = c["col"] if c.get("col") is Color else P.tk("cream")
			var vw: float = P.tw(fv, val, z2)
			draw_string(fv, Vector2(rc.position.x, vy), P.fit(fv, val, z2, rc.size.x), HORIZONTAL_ALIGNMENT_LEFT, -1, z2, col)
			var dl: String = String(c.get("delta", ""))
			if dl != "":
				var fm: Font = TBKit.mono()
				var dcol: Color = P.tk("pos_bar") if dl.begins_with("+") else (P.tk("neg_bar") if dl.begins_with("−") else P.tk("smoke"))
				draw_string(fm, Vector2(rc.position.x + vw + 8.0, vy), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, P.fs(12.0), dcol)
			var b: float = float(c.get("bar", -1.0))
			if b >= 0.0:
				var br := Rect2(rc.position.x, rc.end.y - 8.0, rc.size.x, 6.0)
				draw_style_box(P.sbox(P.tk("bar_2"), Color.TRANSPARENT, 3.0, 0), br)
				if b > 0.01: draw_style_box(P.sbox(col, Color.TRANSPARENT, 3.0, 0), Rect2(br.position, Vector2(br.size.x * clampf(b, 0.0, 1.0), br.size.y)))

# ---------------------------------------------------------------- action row / primary button
## a list row (44 px: icon, label 14/500, 12 px subtitle, keycap) or, with `filled`, a 44 px button (primary / danger / secondary)
class Row extends TBCmdCard.VerbBtn:
	var sub_text := "":
		set(v): sub_text = v; _upd()
	var filled := false:
		set(v): filled = v; _upd()
	func _init() -> void:
		super()
		_upd()
	## Button ignores a script `_get_minimum_size`, so the row height is a custom minimum size
	func _upd() -> void:
		custom_minimum_size = Vector2(0, 44.0 if (filled or sub_text == "") else 52.0)
	func _draw_keycap(right: float, cy: float, col: Color) -> void:
		if hot == "" or not TBCmdCard.show_hotkeys: return
		var f: Font = TBKit.mono_b()
		var z: int = 12
		var w: float = maxf(20.0, P.tw(f, hot, z) + 10.0)
		var r := Rect2(right - w, cy - 10.0, w, 20.0)
		draw_style_box(P.sbox(Color.TRANSPARENT, P.al(col, 0.45), 4.0, 1), r)
		draw_string(f, Vector2(r.position.x + (w - P.tw(f, hot, z)) * 0.5, P.base(f, z, cy)), hot, HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.al(col, 0.8))
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var shift := Vector2(0, 1) if (button_pressed and not blocked) else Vector2.ZERO
		var f: Font = TBKit.body_m()
		var z: int = P.fs(14.0)
		if filled:
			var fill: Color = P.tk("bar_1"); var ink: Color = P.tk("cream"); var edge: Color = P.tk("rule")
			if primary: fill = P.tk("act"); ink = P.tk("on_act"); edge = Color.TRANSPARENT
			elif danger: fill = P.tk("wax"); ink = P.tk("on_wax"); edge = Color.TRANSPARENT
			if blocked: fill = P.tk("bar_1"); ink = P.tk("ink_off"); edge = P.tk("rule")
			elif is_hovered(): fill = fill.lerp(Color.WHITE, 0.06)
			if button_pressed and not blocked: fill = fill.lerp(Color.BLACK, 0.12)
			draw_style_box(P.sbox(fill, edge, 10.0, 1 if edge.a > 0.0 else 0), r)
			var ff: Font = TBKit.tracked(TBKit.display(), 1) if TBFrame.bezel else f
			var zz: int = P.fs(13.0) if TBFrame.bezel else z
			var lt: String = TBKit._cap(label)
			var lw: float = P.tw(ff, lt, zz)
			var cx: float = size.x * 0.5
			var gw: float = 0.0
			if glyph != "": gw = 22.0
			var left: float = cx - (lw + gw) * 0.5
			if glyph != "": TBGlyph.draw(self, glyph, Vector2(left + 8.0, size.y * 0.5) + shift, 16.0, ink, 1.5); left += gw
			draw_string(ff, Vector2(left, P.base(ff, zz, size.y * 0.5)) + shift, P.fit(ff, lt, zz, size.x - 24.0 - gw - (34.0 if hot != "" else 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, zz, ink)
			_draw_keycap(size.x - 12.0, size.y * 0.5, ink)
			if has_focus(): P.focus_ring(self, r)
			return
		var alpha: float = 0.5 if blocked else 1.0
		if (is_hovered() or has_focus()) and not blocked: draw_style_box(P.sbox(P.tk("bar_1"), Color.TRANSPARENT, 6.0, 0), r)
		if button_pressed and not blocked: draw_style_box(P.sbox(P.tk("bar_2"), Color.TRANSPARENT, 6.0, 0), r)
		var gcol: Color = P.tk("neg_bar") if danger else (P.tk("brass_lt") if primary else P.tk("smoke"))
		var tcol: Color = P.tk("neg_bar") if danger else P.tk("cream")
		var x: float = 12.0
		if glyph != "":
			TBGlyph.draw(self, glyph, Vector2(x + 10.0, size.y * 0.5) + shift, 20.0, P.al(gcol, alpha), 1.5)
			x += 20.0 + 12.0
		var right: float = size.x - 12.0
		var has_key: bool = hot != "" and TBCmdCard.show_hotkeys
		var key_w: float = (maxf(20.0, P.tw(TBKit.mono_b(), hot, 12) + 10.0) + 8.0) if has_key else 0.0
		var avail: float = right - x - key_w
		var has_sub: bool = sub_text != ""
		var ly: float = size.y * (0.36 if has_sub else 0.5)
		draw_string(f, Vector2(x, P.base(f, z, ly)) + shift, P.fit(f, label, z, avail), HORIZONTAL_ALIGNMENT_LEFT, -1, z, P.al(tcol, alpha))
		if has_sub:
			var f2: Font = TBKit.body()
			var z2: int = P.fs(12.0)
			var scol: Color = P.tk("warn_bar") if blocked else P.tk("smoke")
			draw_string(f2, Vector2(x, P.base(f2, z2, size.y * 0.72)) + shift, P.fit(f2, sub_text, z2, avail), HORIZONTAL_ALIGNMENT_LEFT, -1, z2, P.al(scol, 1.0 if blocked else alpha))
		if has_key: _draw_keycap(right, size.y * 0.5, P.tk("smoke"))
		if blocked and not has_sub: TBGlyph.draw(self, "lock", Vector2(right - 8.0, size.y * 0.5), 14.0, P.al(P.tk("ink_off"), 0.8), 1.4)
