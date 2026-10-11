## Peace terms: the window behind the "Terms" verb. The war score on both sides, then what you may ask for (white peace, land, a vassal), each with its
## likelihood and a Send button. Like every request to a court it is sent now and answered next turn.
class_name TBTermsScreen
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## the likelihood as one notched bar: accepted share in brass, the declined share as thin red diagonals
class ChanceBar extends Control:
	var pct := 0
	func _init(p: int) -> void:
		pct = p; custom_minimum_size = Vector2(0, 22); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var w := size.x; var h := size.y
		var r := Rect2(0.5, 8.5, w - 1.0, 10.0)
		draw_rect(r, TBTokens.BZ_TRACK_BG)
		var fw: float = (r.size.x - 2.0) * float(pct) / 100.0
		if fw > 0.0: draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, fw, r.size.y - 2.0), TBTokens.c("brass_lt"))
		var x0: float = r.position.x + 1.0 + fw
		var x1: float = r.end.x - 1.0
		var y0: float = r.position.y + 1.0; var y1: float = r.end.y - 1.0
		var red: Color = TBTokens.with_a(TBTokens.BZ_BAD, 0.9)
		var k: float = x0 - (y1 - y0)
		while k < x1:
			var a := Vector2(k, y1); var b := Vector2(k + (y1 - y0), y0)
			if a.x < x0: a = Vector2(x0, y1 - (x0 - a.x))
			if b.x > x1: b = Vector2(x1, y0 + (b.x - x1))
			if a.x <= x1 and b.x >= x0 and a.y >= y0 and b.y <= y1: draw_line(a, b, red, 1.0)
			k += 8.0
		draw_rect(r, TBTokens.BZ_TRACK_LINE, false, 1.0)

static func _card(title_text: String, body_text: String, pct: int, off: String, label: String, on_send: Callable) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = TBTokens.BZ_WELL; sb.border_color = TBTokens.BZ_WELL_LINE
	sb.set_border_width_all(1); sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := K.vbox(6); pc.add_child(v)
	var hd := K.hbox(8)
	var t := K.title(title_text, 16, TBTokens.c("ink_0")); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(t)
	var pl := K.label("%d%%" % pct, 18, TBTokens.c("brass_lt")); hd.add_child(pl)
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
