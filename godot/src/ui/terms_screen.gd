## Peace terms: the window behind the "Terms" verb. The war score on both sides, then what you may ask for (white peace, land, a vassal), each with its
## likelihood and a Send button. Like every request to a court it is sent now and answered next turn.
class_name TBTermsScreen
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## lkBar(q, 28): the likelihood as one notched bar. The decline share at the left in thin red diagonals (135 degrees, 1.5 on 8), the accept share at the right in brass; each
## figure sits in its own part (a part under 14 % puts its figure above the bar). Hairline #7F6A33, notch 9, track #0C0A07.
class ChanceBar extends Control:
	var pct := 0
	const H := 28.0
	func _init(p: int) -> void:
		pct = p; mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, H + (22.0 if (p < 14 or p > 86) else 6.0))
	func _draw() -> void:
		var top: float = size.y - H
		var w := size.x
		var c := roundf(H / 3.2)
		var ci := get_canvas_item()
		TBBz.poly(ci, TBBz.notch(0.0, top, w, top + H, c), TBTokens.BZ_LO)
		var inner := TBBz.notch(1.0, top + 1.0, w - 1.0, top + H - 1.0, c)
		TBBz.poly(ci, inner, TBTokens.BZ_TRACK_BG)
		var iw: float = w - 2.0
		var xs: float = 1.0 + iw * float(100 - pct) / 100.0                       # where the decline part ends
		var red_rect := PackedVector2Array([Vector2(1.0, top + 1.0), Vector2(xs, top + 1.0), Vector2(xs, top + H - 1.0), Vector2(1.0, top + H - 1.0)])
		var gold_rect := PackedVector2Array([Vector2(xs, top + 1.0), Vector2(w - 1.0, top + 1.0), Vector2(w - 1.0, top + H - 1.0), Vector2(xs, top + H - 1.0)])
		for piece in Geometry2D.intersect_polygons(gold_rect, inner):
			var pts: PackedVector2Array = piece
			var cols := PackedColorArray()
			for q in pts: cols.append(TBTokens.BZ_G_A.lerp(TBTokens.BZ_BRASS, clampf((q.y - (top + 1.0)) / (H - 2.0), 0.0, 1.0)))
			draw_polygon(pts, cols)
		var clip: Array = Geometry2D.intersect_polygons(red_rect, inner)
		var step: float = 9.5 * sqrt(2.0)                                         # 9.5 along the 135 degree gradient line = 13.4 across
		var k: float = 1.0 - H
		while k < xs:
			var line := PackedVector2Array([Vector2(k, top + H), Vector2(k + H, top)])
			for piece in clip:
				for seg in Geometry2D.intersect_polyline_with_polygon(line, piece):
					draw_polyline(seg, TBTokens.BZ_LK_RED, 1.2, true)
			k += step
		var fb: Font = TBKit.alegreya(700)
		var no_pct: int = 100 - pct
		_label(fb, no_pct, 1.0, xs, top, TBTokens.BZ_LK_NO_TXT, true)
		_label(fb, pct, xs, w - 1.0, top, TBTokens.BZ_LK_YES_TXT, false)
	## a part of 14 % or more carries its figure inside (the decline figure on a dark pill); a smaller one above the bar
	func _label(f: Font, v: int, x0: float, x1: float, top: float, col: Color, pill: bool) -> void:
		var txt := "%d%%" % v
		var mid: float = (x0 + x1) * 0.5
		if v >= 14:
			var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var base: float = top + H * 0.5 + (f.get_ascent(17) - f.get_height(17) * 0.5)
			if pill: draw_rect(Rect2(mid - tw * 0.5 - 7.0, top + H * 0.5 - f.get_height(17) * 0.5, tw + 14.0, f.get_height(17)), TBTokens.with_a(TBTokens.BZ_SHADOW, 0.6))
			draw_string(f, Vector2(mid - tw * 0.5, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		else:
			var tw2: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f, Vector2(mid - tw2 * 0.5, top - 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TBTokens.BZ_IVORY)

static func _card(title_text: String, body_text: String, pct: int, off: String, label: String, on_send: Callable) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = TBTokens.BZ_WELL; sb.border_color = TBTokens.BZ_WELL_LINE
	sb.set_border_width_all(1); sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := K.vbox(6); pc.add_child(v)
	var hd := K.hbox(8)
	var t := K.title(title_text, 16, TBTokens.c("ink_0")); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(t)
	hd.add_child(K.label("%d%%" % pct, 18, TBTokens.BZ_IVORY))
	v.add_child(hd)
	v.add_child(K.para_bz(body_text, 15.0, 1.3))
	v.add_child(ChanceBar.new(pct))
	var row := K.hbox(8)
	if off != "":
		var why := K.label(off, 14, TBTokens.BZ_BAD_TXT); why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; why.size_flags_horizontal = Control.SIZE_EXPAND_FILL; why.custom_minimum_size.x = 40
		row.add_child(why)
	else:
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
	var b := K.button(label, on_send, off == "", false, "envoys")
	if off != "": K.disable(b, off)
	row.add_child(b)
	v.add_child(row)
	return pc

## opts: on_cmd(cmd) receives {"cmd": "ask", ...}; the window is rebuilt after a request is sent
static func open(parent: Control, g: TBGame, enemy: int, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var on_cmd: Callable = opts.get("on_cmd", Callable())
	var ws_me: int = g.war_score[me * g.N1 + enemy]
	var ws_them: int = g.war_score[enemy * g.N1 + me]
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("terms_title"), "flag", {"w": 560, "h": 760, "key": "terms",
		"sub": T.call("terms_sub", {"a": g.dname(enemy), "k": g.war_turns[me * g.N1 + enemy]})})
	var body: VBoxContainer = h.body
	body.add_theme_constant_override("separation", 10)
	# ---- the war score, both sides
	var cells := K.hbox(8); cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.add_child(TBNationParts.StatCell.new("war", "%d%%" % ws_me, T.call("terms_you")))
	cells.add_child(TBNationParts.StatCell.new("war", "%d%%" % ws_them, T.call("terms_them")))
	body.add_child(cells)
	body.add_child(K.para_bz(T.call("terms_hint"), 15.0, 1.3))
	var asked: Dictionary = TBAsks.find(g, me, enemy)
	var live: bool = g.human[enemy] == 0 and g.rules >= 1
	var options: Array = [["white", "terms_white", "terms_white_d", "peace", "dip_peace", TBData.DP_PEACE], ["cede", "terms_cede", "terms_cede_d", "peace", "dip_land", 0], ["vassal", "terms_vassal", "terms_vassal_d", "peace", "dip_vassal", 0]]
	for o in options:
		var op: String = o[0]
		var off := ""
		var pct := 0
		var mine: bool = not asked.is_empty() and String(asked["kind"]) == "peace" and String(asked["op"]) == op
		if live:
			var chk: Dictionary = TBAsks.check(g, me, "peace", enemy, op)
			pct = TBAsks.chance(g, me, "peace", enemy, op)
			if mine: off = T.call("ask_wait")
			elif not asked.is_empty(): off = T.call("ask_other")
			elif op == "cede" and ws_me < 25: off = T.call("err_warscore") + " (25%)"
			elif op == "vassal" and ws_me < 50: off = T.call("err_warscore") + " (50%)"
			elif not bool(chk["ok"]) and String(chk["reason"]) != "":
				var ek: String = "err_" + String(chk["reason"])
				off = T.call(ek) if TBI18n.has_key(ek) else String(chk["reason"])
			elif pct == 0: off = T.call("dvb_" + String(TBAsks.view(g, me, "peace", enemy, op).get("blocked", "grudge")))
		var send := func() -> void:
			if on_cmd.is_valid(): on_cmd.call({"cmd": "ask", "kind": "peace", "t": enemy, "op": op})
			h.close()
		body.add_child(_card(T.call(String(o[1])), T.call(String(o[2])), pct, off, T.call("ask_proposed") if mine else T.call("terms_send"), send))
	return h
