## The bottom information bar (Age of Civilizations style): owner flag and name, owner figures and the terrain strip on the left; a 4 x 3 grid of
## province figures on the right (name, stability, development / population, economy, happiness, defence / building, army, supply).
## Pure drawing + three hit zones: close (top-right), the owner flag (opens the nation card), the name cell (toggles the Details drawer).
class_name TBInfoBar
extends Control

signal closed
signal owner_pressed(n: int)
signal details_pressed

const P = preload("res://src/ui/hud_parts.gd")
const D = preload("res://src/engine/data.gd")
var g: TBGame
var s := -1
var cs := {}
var drawer_open := false
var tag: Array = []                       # [glyph, text, token] relation tag shown under the owner's name (not for your own provinces)
var _hit_close := Rect2()
var _hit_owner := Rect2()
var _hit_name := Rect2()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(game: TBGame, province: int, case: Dictionary, drawer: bool) -> void:
	g = game; s = province; cs = case; drawer_open = drawer
	custom_minimum_size = Vector2(0, P.R(140.0))
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = (e as InputEventMouseButton).position
		if _hit_close.grow(P.R(6.0)).has_point(pos): closed.emit()
		elif _hit_owner.has_point(pos) and int(cs.get("o", 0)) != 0: owner_pressed.emit(int(cs["o"]))
		elif _hit_name.has_point(pos): details_pressed.emit()
		accept_event()

func _cell(r: Rect2, glyph: String, text: String, col: Color = Color.TRANSPARENT, gcol: Color = Color.TRANSPARENT, hot: bool = false) -> void:
	draw_style_box(P.sbox(P.al(Color.BLACK, 0.2) if not hot else P.al(P.tk("bar_2"), 0.7), Color.TRANSPARENT, P.R(4.0), 0), r)
	var fb: Font = P.body()
	var fz: int = P.fr(19.0)
	var gp: float = P.R(24.0)
	var tw: float = P.tw(fb, text, fz)
	var gx: float = r.position.x + P.R(8.0)
	if glyph != "":
		var gc: Color = gcol if gcol.a > 0.0 else P.tk("brass_lt")
		if glyph == "star" or glyph == "revolt": TBGlyph.draw_filled(self, glyph, Vector2(gx + gp * 0.5, r.get_center().y), gp * 1.0, gc, P.al(Color.BLACK, 0.0))
		else: TBGlyph.draw(self, glyph, Vector2(gx + gp * 0.5, r.get_center().y), gp * 0.8, gc, 1.8)
		gx += gp + P.R(4.0)
	var avail: float = r.end.x - gx - P.R(6.0)
	var t: String = P.fit(fb, text, fz, avail) if tw > avail else text
	draw_string(fb, Vector2(gx, P.base(fb, fz, r.get_center().y)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fz, col if col.a > 0.0 else P.tk("cream"))

func _draw() -> void:
	if g == null or s < 0: return
	var o: int = int(cs.get("o", 0))
	var me: int = int(cs.get("me", 0))
	var w: float = size.x
	var h: float = size.y
	var lw: float = clampf(w * 0.31, P.R(150.0), P.R(200.0))
	var pad: float = P.R(5.0)
	var fb: Font = P.body_b()
	# ---- left column
	var lr := Rect2(pad, pad, lw - pad, h - pad * 2.0)
	draw_style_box(P.sbox(P.al(Color.BLACK, 0.2), Color.TRANSPARENT, P.R(4.0), 0), lr)
	var fl := Rect2(lr.position + Vector2(P.R(8.0), P.R(9.0)), Vector2(P.R(58.0), P.R(40.0)))
	_hit_owner = Rect2(lr.position, Vector2(lr.size.x, P.R(56.0)))
	if o != 0:
		draw_texture_rect(TBFlags.texture(g.nat_code[o], g.color[o]), fl, false)
		draw_rect(fl, P.al(Color.BLACK, 0.6), false, 1.0)
	else:
		draw_rect(fl, P.al(P.tk("rule"), 0.35), false, 1.0)
	var oname: String = g.dname(o) if o != 0 else TBI18n.T.call("cc_tag_unclaimed")
	var nfz: int = P.fr(21.0)
	var ntx: float = fl.end.x + P.R(8.0)
	var lines: Array = [oname]
	if P.tw(fb, oname, nfz) > lr.end.x - ntx - P.R(4.0) and oname.contains(" "):
		var cut: int = oname.rfind(" ", oname.length() / 2 + 3)
		if cut < 0: cut = oname.find(" ")
		lines = [oname.substr(0, cut), oname.substr(cut + 1)]
	var lh: float = fb.get_height(nfz)
	var y0: float = fl.get_center().y - lh * lines.size() * 0.5
	for i in lines.size():
		var ln: String = lines[i]
		var tt: String = P.fit(fb, ln, nfz, lr.end.x - ntx - P.R(4.0))
		draw_string(fb, Vector2(ntx, y0 + lh * i + fb.get_ascent(nfz)), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfz, P.tk("cream"))
	# owner figures: treasury for the player; the relation tag for everyone else
	var fy: float = fl.end.y + P.R(19.0)
	var fr_: Font = P.body()
	if o == me and o != 0:
		TBGlyph.draw_filled(self, "coin", Vector2(lr.position.x + P.R(22.0), fy), P.R(24.0), P.tk("brass_lt"), P.tk("bar_0"))
		draw_string(fr_, Vector2(lr.position.x + P.R(42.0), P.base(fr_, P.fr(21.0), fy)), TBKit.fmt(int(g.gold[o])), HORIZONTAL_ALIGNMENT_LEFT, -1, P.fr(21.0), P.tk("brass_lt"))
	elif tag.size() >= 3 and String(tag[1]) != "":
		var tc: Color = P.tk(String(tag[2]))
		var gx2: float = lr.position.x + P.R(10.0)
		if String(tag[0]) != "":
			TBGlyph.draw(self, String(tag[0]), Vector2(gx2 + P.R(11.0), fy), P.R(22.0), tc, 1.8)
			gx2 += P.R(28.0)
		var tt2: String = String(tag[1])
		draw_string(fb, Vector2(gx2, P.base(fb, P.fr(19.0), fy)), P.fit(fb, tt2, P.fr(19.0), lr.end.x - gx2 - P.R(4.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, P.fr(19.0), tc)
	# terrain strip with the terrain name
	var th: float = P.R(36.0)
	var tr := Rect2(lr.position.x + P.R(4.0), lr.end.y - th - P.R(4.0), lr.size.x - P.R(8.0), th)
	var tcol: Color = Color.hex((TBLenses.TERRAIN_COL[g.terrain[s]] << 8) | 0xff)
	draw_rect(tr, tcol.darkened(0.25))
	draw_rect(Rect2(tr.position, Vector2(tr.size.x, tr.size.y * 0.5)), P.al(Color.WHITE, 0.07))
	draw_rect(Rect2(tr.position.x, tr.end.y - tr.size.y * 0.55, tr.size.x, tr.size.y * 0.55), P.al(Color.BLACK, 0.35))
	var tn: String = TBI18n.T.call("t_" + D.TERRAIN_ID[g.terrain[s]])
	draw_string(fb, Vector2(tr.position.x + P.R(8.0), P.base(fb, P.fr(19.0), tr.end.y - tr.size.y * 0.3)), tn, HORIZONTAL_ALIGNMENT_LEFT, -1, P.fr(19.0), P.tk("cream"))
	if g.capital[s] != 0: TBGlyph.draw(self, "capital", Vector2(tr.end.x - P.R(16.0), tr.get_center().y), P.R(22.0), P.tk("brass_lt"), 1.8)
	draw_rect(tr, P.al(P.tk("rule"), 0.8), false, 1.0)
	# ---- right grid
	var gx0: float = lw + pad
	var gw: float = w - gx0 - pad
	var gap: float = P.R(4.0)
	var rows := 3
	var rh: float = (h - pad * 2.0 - gap * (rows - 1)) / rows
	var cw: float = (gw - gap * 3.0) / 4.0
	var stab: int = g.stab[s]
	var warn: Color = P.tk("neg_bar") if stab < 30 else (P.tk("warn_bar") if stab < 50 else P.tk("pos_bar"))
	# row 1: name (2 cols), stability, development
	var r1 := Rect2(gx0, pad, cw * 2.0 + gap, rh)
	_hit_name = r1
	draw_style_box(P.sbox(P.al(P.tk("bar_2"), 0.6) if drawer_open else P.al(Color.BLACK, 0.2), Color.TRANSPARENT, P.R(4.0), 0), r1)
	var sn: String = TBI18n.place(g.world.name[s])
	var sfz: int = P.fr(21.0)
	var stw: float = P.tw(fb, sn, sfz)
	var avail: float = r1.size.x - P.R(46.0)
	var snt: String = P.fit(fb, sn, sfz, avail) if stw > avail else sn
	draw_string(fb, Vector2(r1.position.x + (r1.size.x - P.tw(fb, snt, sfz)) * 0.5 - P.R(4.0), P.base(fb, sfz, r1.get_center().y)), snt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfz, P.tk("cream"))
	P.tri(self, Vector2(r1.end.x - P.R(14.0), r1.get_center().y), P.R(11.0), P.tk("smoke"), not drawer_open)
	_cell(Rect2(gx0 + (cw + gap) * 2.0, pad, cw, rh), "revolt" if stab < 30 else "scales", "%d%%" % stab, warn, warn)
	_cell(Rect2(gx0 + (cw + gap) * 3.0, pad, cw, rh), "star", "%d" % g.dev[s], P.tk("brass_lt"), P.tk("brass_lt"))
	# row 2
	var y2: float = pad + rh + gap
	_cell(Rect2(gx0, y2, cw, rh), "men", TBKit.fmt(g.pop[s]), P.tk("cream"), P.tk("smoke"))
	_cell(Rect2(gx0 + (cw + gap), y2, cw, rh), "coin", "%d" % g.econ[s], P.tk("brass_lt"), P.tk("brass_lt"))
	_cell(Rect2(gx0 + (cw + gap) * 2.0, y2, cw, rh), "smile", "%d%%" % g.happy[s], P.tk("cream"), P.tk("warn_bar"))
	_cell(Rect2(gx0 + (cw + gap) * 3.0, y2, cw, rh), "shield", "%d" % g.defense[s], P.tk("cream"), P.tk("info"))
	# row 3: building (2 cols), army, supply / general
	var y3: float = pad + (rh + gap) * 2.0
	var bname: String = "—"
	if g.b_building[s] != 0: bname = "%s · %d" % [TBI18n.T.call("b_" + D.BUILDINGS[g.b_building[s] - 1]["id"]), g.b_turns[s]]
	elif g.building[s] != 0: bname = "%s %d" % [TBI18n.T.call("b_" + D.BUILDINGS[g.building[s] - 1]["id"]), g.b_level[s]]
	_cell(Rect2(gx0, y3, cw * 2.0 + gap, rh), "lamp" if g.building[s] == 0 and g.b_building[s] == 0 else "shield", bname, P.tk("cream") if bname != "—" else P.tk("ink_off"), P.tk("smoke"))
	_cell(Rect2(gx0 + (cw + gap) * 2.0, y3, cw, rh), "swords", TBKit.fmt(g.army[s]), P.tk("cream"), P.tk("brass_lt"))
	if g.rules >= 1 and g.gen[s] != 0:
		_cell(Rect2(gx0 + (cw + gap) * 3.0, y3, cw, rh), "star", "%d" % TBGenerals.skill(g, s), P.tk("brass_lt"), P.tk("brass_lt"))
	elif g.rules >= 1:
		_cell(Rect2(gx0 + (cw + gap) * 3.0, y3, cw, rh), "supply", "%d" % g.supply_limit(s), P.tk("cream"), P.tk("smoke"))
	# close
	var cr := Rect2(w - P.R(26.0) - 1.0, 1.0, P.R(26.0), P.R(26.0))
	_hit_close = cr
	draw_style_box(P.sbox(P.al(P.tk("bar_0"), 0.9), P.tk("rule"), P.R(4.0), 1), cr)
	TBGlyph.draw(self, "close", cr.get_center(), P.R(15.0), P.tk("cream"), 1.6)
	draw_rect(Rect2(0, 0, w, h), P.al(Color.TRANSPARENT, 0.0))
