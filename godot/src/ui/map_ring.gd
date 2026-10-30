## The command ring (Bezel): the selected province's verbs as brass medallions on a graduated ring around it, the army in the middle.
## It mirrors the inspector's verb list (same ids, same costs, same hotkeys): a press runs the panel's own verb. Pure view over TBProvincePanel.
class_name TBMapRing
extends Control

signal pressed(idx: int)
signal hovered(idx: int)
signal dossier_requested(p: int)
signal nation_requested(n: int)

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")
const BZ = preload("res://src/ui/bezel.gd")

var map: TBMapView
var g: TBGame
var avoid_fn: Callable = Callable()              # () -> Array of global Rect2 the ring keeps clear of (inspector, rail, bar)
var subject := -1
var verbs: Array = []                            # [{id, glyph, label, can, why, primary, danger, hot}]
var armed := false                               # false while an order is being previewed / confirmed: the ring steps aside
var sel := -1                                    # the selected province (a foreign one shows the nation ring and its tag card)
var tag: TBTagCard
var _tag_key := ""
var _tag_off := 118.0
var _hover := -1
var _tip: Control                                  # the verb tooltip (the demo's showTip: 220 ms after the pointer rests on a verb)
var _tip_wait := 0.0
var _t := 0.0
var _draw_key: Array = []
var _draw_ms := 0
var _c := Vector2.ZERO                           # ring centre, local
var _spots: Array = []                           # [{p: Vector2, r: float}] per verb, local

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

## the screen rectangle the ring and its labels fill (empty when no ring is up): what a picker that opens from it must keep clear of
func ring_rect() -> Rect2:
	if not visible or _c == Vector2.INF: return Rect2()
	var r: Vector2 = Vector2(_rect_off + 40.0, _rect_off + 40.0)
	return Rect2(get_global_position() + _c - r, r * 2.0)

## a province name on one line, or on two at the space that makes the wider line shortest; a line still too wide ends in an ellipsis
func _split_name(f: Font, nm: String, z: int, maxw: float) -> PackedStringArray:
	if P.tw(f, nm, z) <= maxw or not nm.contains(" "): return PackedStringArray([P.fit(f, nm, z, maxw)])
	var words: PackedStringArray = nm.split(" ")
	var best_a := nm; var best_b := ""; var best_w := INF
	for i in range(1, words.size()):
		var a: String = " ".join(words.slice(0, i)); var b: String = " ".join(words.slice(i))
		var wd: float = maxf(P.tw(f, a, z), P.tw(f, b, z))
		if wd < best_w: best_w = wd; best_a = a; best_b = b
	return PackedStringArray([P.fit(f, best_a, z, maxw), P.fit(f, best_b, z, maxw)])

## the ring with the verbs' names around it (global), for map names to keep out of; empty when no ring is up
func label_rect() -> Rect2:
	if not visible or _c == Vector2.INF or _is_armed() or _spots.is_empty(): return Rect2()
	var R: float = _radius()
	var l: float = maxf(R + 34.0, _lab_l) + 4.0
	var r: float = maxf(R + 34.0, _lab_r) + 4.0
	var v: float = R + 50.0
	return Rect2(get_global_position() + _c - Vector2(l, v), Vector2(l + r, v * 2.0))

func show_verbs(p: int, list: Array) -> void:
	var same: bool = p == subject and visible and _same_ids(list)         # a rebuild of the same ring (a hover, a refresh) must not replay the pop-in
	subject = p; verbs = list
	if not same: _t = 0.0
	visible = _want()
	_hover = -1
	set_process(p >= 0); queue_redraw()

func _tip_hide() -> void:
	if _tip != null and is_instance_valid(_tip): _tip.queue_free()
	_tip = null

## showTip(): centred under the verb, 10 units below its label (above it when that does not fit), kept 6 from the edges
func _tip_show(i: int) -> void:
	_tip_hide()
	if i < 0 or i >= _spots.size() or i >= verbs.size() or _is_armed(): return
	var v: Dictionary = verbs[i]
	var id: String = String(v["id"])
	var key := "vt_" + id.trim_prefix("cmd:")
	var body: String = TBI18n.T(key) if TBI18n.has_key(key) else ""
	var hot: String = String(TBProvincePanel.HOT.get(id, ""))
	_tip = TBHudParts.tip_box(String(v.get("label", "")).split("  ")[0], body, 190.0, [], hot)
	_tip.z_index = 20
	add_child(_tip)
	var sz: Vector2 = _tip.get_combined_minimum_size()
	_tip.size = sz
	var sp: Dictionary = _spots[i]
	var c: Vector2 = sp["p"]; var r: float = float(sp["r"])
	var below: float = c.y + r + (16.0 if (size.y >= 560.0 and c.y > _c.y + 40.0) else 0.0) + 10.0        # only the bottom verb has its label under the medallion
	var y: float = below if below + sz.y <= size.y - 6.0 else c.y - r - sz.y - 10.0
	_tip.position = Vector2(clampf(c.x - sz.x * 0.5, 6.0, maxf(6.0, size.x - sz.x - 6.0)), maxf(4.0, y)).floor()

func _same_ids(list: Array) -> bool:
	if list.size() != verbs.size(): return false
	for i in list.size():
		if String(list[i]["id"]) != String(verbs[i]["id"]): return false
	return true

func clear() -> void:
	subject = -1; verbs = []; visible = false; set_process(false); _drop_tag()

## the selection (any province): foreign land shows the nation ring and tag card, own land the verb ring (its verbs arrive in show_verbs)
func set_selection(p: int) -> void:
	sel = p
	_tag_key = ""
	visible = _want()
	set_process(p >= 0 or subject >= 0); queue_redraw()
	if p < 0: _drop_tag()

func _nation_mode() -> bool:
	if g == null or sel < 0 or sel >= g.P or g.human_id <= 0: return false
	var o: int = g.owner[sel]
	return o != 0 and o != g.human_id

func _want() -> bool:
	if _nation_mode(): return not _is_armed()
	return subject >= 0 and (not verbs.is_empty() or _is_armed())

func _drop_tag() -> void:
	if tag != null and is_instance_valid(tag): tag.queue_free()
	tag = null; _tag_key = ""

func set_armed(a: bool) -> void:
	armed = a
	visible = _want()
	set_process(subject >= 0); queue_redraw()

func _process(d: float) -> void:
	var want: bool = _want()                                                        # while an order is previewed the panel sends no verbs: the armed medallion stays
	if want != visible: visible = want; _t = 0.0
	_t += d
	if _tip_wait > 0.0:
		_tip_wait -= d
		if _tip_wait <= 0.0 and _hover >= 0: _tip_show(_hover)
	if _hover < 0 or not visible: _tip_hide()
	_sync_tag()
	# redrawn only when it can look different: the pop-in, a hover, the camera moving it, a changed order; the armed medallion's dots turn, at 15 frames a second
	var key: Array = [_anchor(), _hover, visible, size, armed, subject, sel, verbs.size(), has_focus(), TBKit.text_scale]
	var still: bool = key == _draw_key and _t > 0.8
	if still and _is_armed() and K.motion_ok() and Time.get_ticks_msec() - _draw_ms >= 66: still = false
	if not still:
		_draw_key = key; _draw_ms = Time.get_ticks_msec()
		queue_redraw()

## the demo's ring metrics (desktop stage: R 88; phone stage: rs .66, no verb labels)
func _rs() -> float: return 0.66 if size.y < 560.0 else 1.0
func _radius() -> float: return 88.0 * _rs()
## orders armed (a target is being chosen / previewed): the ring becomes the demo's instrument medallion
func _is_armed() -> bool: return armed or (map != null and map.labels != null and map.labels.order_committed())

## the province the ring is drawn at: the selection, or (armed medallion) the army that is ordered
func _subj() -> int:
	if _is_armed() and map != null and map.labels != null:
		var f: int = map.labels.order_from()
		if f >= 0: return f
	return subject if subject >= 0 else sel

## where the province sits on screen (ring-local coordinates), or Vector2.INF when it is on the far side of the globe
func _anchor() -> Vector2:
	var sj: int = _subj()
	if g == null or map == null or sj < 0 or sj >= g.P: return Vector2.INF
	var pr: Vector3 = map.project(g.world.lon[sj], g.world.lat[sj])
	if pr.z <= 0.05: return Vector2.INF
	return Vector2(pr.x, pr.y) + map.global_position - global_position

## the tag card: built when the selection or its numbers change, shown beside the ring (never while an order is armed)
func _sync_tag() -> void:
	if g == null or not visible or _is_armed() or sel < 0 or sel >= g.P:
		if tag != null: tag.visible = false
		return
	var key: String
	if _nation_mode(): key = "n%d:%d" % [g.owner[sel], g.turn]
	else: key = "p%d:%d:%d:%d" % [sel, g.stab[sel], g.happy[sel], g.pop[sel]]
	if key == _tag_key and tag != null and is_instance_valid(tag): tag.visible = _c != Vector2.INF; return
	_drop_tag(); _tag_key = key
	var me: int = g.human_id
	var o: int = g.owner[sel]
	if _nation_mode():
		var army := 0
		for q in g.P:
			if g.owner[q] == o: army += g.army[q]
		var op: int = TBNationsScreen.opinion(g, me, o)
		var ruler := ""
		if g.rules >= 1 and g.r_name[o] != "": ruler = "%s %s" % [TBI18n.T(TBRulers.title_key(g, o)), TBRulers.display_name(g, o)]
		tag = TBTagCard.new().build_nation({"state": TBNationsScreen.rel_text(g, me, o, op), "name": g.dname(o), "ruler": ruler,
			"army": K.fmt(float(army)), "rel": ("+%d" % op) if op > 0 else str(op), "rel_col": TBNationsScreen.rel_color(op)})
		tag.link_pressed.connect(func(): nation_requested.emit(o))
	else:
		var oname: String = g.dname(o) if o != 0 else TBI18n.T("cc_tag_unclaimed")
		var mine: bool = o == me
		tag = TBTagCard.new().build_province({"name": TBI18n.place(g.world.name[sel]), "owner_name": oname, "own": mine, "tag": TBI18n.T("tag_yours") if mine else "",
			"pop": K.fmt(float(g.pop[sel])), "stab": g.stab[sel], "happy": g.happy[sel]})
		var pp: int = sel
		tag.link_pressed.connect(func(): dossier_requested.emit(pp))
	tag.size = tag.get_combined_minimum_size(); tag.z_index = 5
	add_child(tag)

func _place_tag(off: float, rect_off: float = -1.0) -> void:
	if tag == null or not is_instance_valid(tag):
		return
	if _c == Vector2.INF:
		tag.visible = false
		return
	tag.visible = true
	tag.size = tag.get_combined_minimum_size()
	var w: float = tag.size.x
	var h: float = tag.size.y
	var x: float = _c.x + off + 34.0
	var flip: bool = x + w > size.x - 28.0
	if flip: x = _c.x - off - 34.0 - w
	var y: float = clampf(_c.y - h * 0.45, 150.0, maxf(150.0, size.y - h - 110.0))
	tag.position = Vector2(x, y).floor()
	_tag_off = off; _tag_flip = flip
	_rect_off = rect_off if rect_off >= 0.0 else off

var _tag_flip := false
var _lab_l := 0.0                         # how far the verbs' names reach left / right of the centre (map names keep out of this)
var _lab_r := 0.0
var _rect_off := 118.0                    # the ring's own reach (what pickers keep clear of): not the card's offset, which also makes room for the verbs' names
func _draw_connector() -> void:
	if tag == null or not is_instance_valid(tag) or not tag.visible or _c == Vector2.INF: return
	var y: float = _c.y
	if _tag_flip: draw_line(Vector2(tag.position.x, y), Vector2(_c.x - _tag_off - 4.0, y), TBTokens.BZ_BRASS, 1.2)
	else: draw_line(Vector2(_c.x + _tag_off + 4.0, y), Vector2(tag.position.x, y), TBTokens.BZ_BRASS, 1.2)

func _layout() -> void:
	_spots.clear()
	var a: Vector2 = _anchor()
	if a == Vector2.INF: _c = Vector2.INF; return
	var R: float = _radius()
	var n: int = verbs.size()
	var reach: float = R + 56.0
	if a.x < -40.0 or a.y < -40.0 or a.x > size.x + 40.0 or a.y > size.y + 40.0:          # the province is not on screen: no ring for it
		_c = Vector2.INF; return
	var c: Vector2 = a
	# keep the whole ring on screen: below the top bar, above the bottom row
	c.x = clampf(c.x, reach, maxf(reach, size.x - reach)); c.y = clampf(c.y, minf(reach + 70.0, size.y * 0.5), maxf(reach + 70.0, size.y - reach - 20.0))
	if avoid_fn.is_valid():                  # the inspector and the rail are tall rectangles: slide sideways clear of them
		for r in avoid_fn.call():
			var rc := Rect2((r as Rect2).position - global_position, (r as Rect2).size)
			if rc.size.y < 140.0: continue
			if Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0).intersects(rc):
				if rc.position.x > c.x: c.x = minf(c.x, rc.position.x - reach - 4.0)
				elif rc.end.x < c.x: c.x = maxf(c.x, rc.end.x + reach + 4.0)
	c.x = clampf(c.x, reach * 0.5, size.x - reach * 0.5)
	_c = c
	for i in n:
		var ang: float = -PI * 0.5 + TAU * float(i) / maxf(1.0, float(n))
		var prim: bool = bool(verbs[i].get("primary", false)) and i == 0
		var rr: float = (28.0 if prim else 23.0) * _rs()
		_spots.append({"p": c + Vector2(cos(ang), sin(ang)) * R, "r": rr, "a": ang})

func _has_point(pt: Vector2) -> bool:
	if not visible or _c == Vector2.INF or _is_armed(): return false
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		if pt.distance_to(s["p"]) <= maxf(float(s["r"]), P.touch() * 0.5): return true
	return false

func _idx_at(pt: Vector2) -> int:
	var best := -1; var bd := 1e9
	if _is_armed(): return -1
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		var d: float = pt.distance_to(s["p"])
		if d <= maxf(float(s["r"]), P.touch() * 0.5) and d < bd: bd = d; best = i
	return best

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var i := _idx_at((e as InputEventMouseMotion).position)
		if i != _hover:
			_hover = i; hovered.emit(i if i >= 0 else 0); queue_redraw()
			_tip_hide(); _tip_wait = 0.22 if i >= 0 else 0.0
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed:
		var j := _idx_at((e as InputEventMouseButton).position)
		if j >= 0: _tip_hide(); _tip_wait = 0.0; pressed.emit(j); accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _idx_at((e as InputEventMouseButton).position) >= 0: accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1; _tip_hide(); _tip_wait = 0.0; queue_redraw()

## the demo's ring icons (IC.move / recruit / build / fortify / attack, 24 box, stroke 2 round): true when drawn, false for a verb the demo has no icon for
func _demo_icon(id: String, c: Vector2, px: float, col: Color, w: float) -> bool:
	var u := px / 24.0
	var paths: Array = []                         # polylines in 24-box coordinates
	var closed: Array = []
	match id:
		"move": paths = [[Vector2(3, 12), Vector2(19, 12)], [Vector2(13, 6), Vector2(19, 12), Vector2(13, 18)]]
		"attack": paths = [[Vector2(4, 20), Vector2(16, 8)], [Vector2(16, 8), Vector2(12, 8)], [Vector2(16, 8), Vector2(16, 12)], [Vector2(20, 20), Vector2(8, 8)], [Vector2(8, 8), Vector2(12, 8)], [Vector2(8, 8), Vector2(8, 12)]]
		"recruit":
			draw_arc(c, 9.0 * u, 0.0, TAU, 32, col, w, true)
			paths = [[Vector2(12, 7.5), Vector2(12, 16.5)], [Vector2(7.5, 12), Vector2(16.5, 12)]]
		"build":
			paths = [[Vector2(4, 20), Vector2(4, 10), Vector2(12, 4), Vector2(20, 10), Vector2(20, 20), Vector2(4, 20)], [Vector2(10, 20), Vector2(10, 14), Vector2(14, 14), Vector2(14, 20)]]
		"fortify":
			paths = [[Vector2(4, 20), Vector2(4, 7), Vector2(7, 7), Vector2(7, 10), Vector2(9.5, 10), Vector2(9.5, 7), Vector2(14.5, 7), Vector2(14.5, 10), Vector2(17, 10), Vector2(17, 7), Vector2(20, 7), Vector2(20, 20), Vector2(4, 20)], [Vector2(10, 20), Vector2(10, 16), Vector2(14, 16), Vector2(14, 20)]]
		_: return false
	for pl in paths:
		var pts := PackedVector2Array()
		for q in pl: pts.append(c + (q - Vector2(12, 12)) * u)
		draw_polyline(pts, col, w, true)
		draw_circle(pts[0], w * 0.5, col); draw_circle(pts[pts.size() - 1], w * 0.5, col)
	return true

const BRASS_A := TBTokens.MAP_BRASS_A; const BRASS_B := TBTokens.MAP_BRASS_MID; const BRASS_C := TBTokens.MAP_BRASS_C

## the demo's gBrass: a linear gradient from the top left (#EBCF85) through #B38F3E to the bottom right (#6F5A27) over the ring's bounding box
static func _gbrass(a: float) -> Color:
	var t: float = (2.0 + cos(a) + sin(a)) * 0.25
	return BRASS_A.lerp(BRASS_B, t * 2.0) if t < 0.5 else BRASS_B.lerp(BRASS_C, (t - 0.5) * 2.0)

## graduated marks (the demo's tickMarks): `n` marks from radius r inwards, every `major`-th 1.7 x longer
func _ticks(c: Vector2, r: float, n: int, len_px: float, major: int, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n) - PI * 0.5
		var l: float = len_px * (1.7 if i % major == 0 else 1.0)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r); pts.append(c + d * (r - l))
	draw_multiline(pts, col, w)

## dotted circle (stroke-dasharray "1 5"): dashes of 1 unit every 6 along the circumference, starting at `rot`
func _dots(c: Vector2, r: float, col: Color, w: float, dash: float, gap: float, rot: float = 0.0) -> void:
	var n: int = int(TAU * r / (dash + gap))
	var da: float = dash / r
	for i in n:
		var a: float = rot + float(i) * (dash + gap) / r
		draw_arc(c, r, a, a + da, 2, col, w, true)

func _draw() -> void:
	if g == null or map == null or not visible: return
	_layout()
	if _c == Vector2.INF: return
	var rs: float = _rs()
	var R: float = _radius()
	var n: int = verbs.size()
	if _nation_mode() and not _is_armed():                              # a foreign nation: a small instrument ring with the nations icon (the demo's `nat` selection)
		draw_circle(_c, 26.0 * rs + 6.0, TBTokens.MAP_SHADE)
		TBBezel.ring(self, _c, 24.0 * rs, 36, Color.TRANSPARENT, true, false, 1.0)
		TBBzIcons.draw(self, "nations", _c, 24.0 * 1.17 * rs, TBTokens.MAP_HI, 1.7)
		_place_tag(26.0 * rs); _draw_connector()
		return
	var grow: float = 1.0 if not K.motion_ok() else 1.0 - pow(1.0 - clampf(_t / 0.22, 0.0, 1.0), 3.0)
	var army: int = g.army[_subj()] if _subj() >= 0 and _subj() < g.P else 0
	var fb: Font = K.body_b()
	var tx: String = K.fmt(float(army))
	if _is_armed():
		# orders armed: a dark disc, the instrument medallion (r 40) with the army, and a dashed ring turning once per 12 s
		draw_circle(_c, 54.0 * rs * grow, TBTokens.MAP_SHADE45)
		var mr: float = 40.0 * rs * grow
		draw_circle(_c, mr + 2.0, TBTokens.MAP_SHADOW)
		draw_circle(_c, mr, TBTokens.MAP_FACE)
		draw_arc(_c, mr - 0.7, 0.0, TAU, 64, Color(TBTokens.BZ_BRASS, 0.85), 1.3, true)
		_ticks(_c, mr - 3.0, 36, 3.2, 5, TBTokens.MAP_TICK, 0.7)
		var z2: int = P.fs(26.0 * rs)
		if grow > 0.5: draw_string(fb, Vector2(_c.x - P.tw(fb, tx, z2) * 0.5, _c.y + 8.0 * rs), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, TBTokens.c("cream"))
		_dots(_c, 50.0 * rs * grow, TBTokens.MAP_HI, 1.0, 2.0, 5.0, (Time.get_ticks_msec() / 12000.0 * TAU) if K.motion_ok() else 0.0)
		return
	# the dial: a translucent disc, a brass gradient band with graduated marks, a dotted outer ring
	draw_circle(_c, (R + 22.0 * rs) * grow, TBTokens.MAP_SHADE)
	var seg: int = 72
	for i in seg:
		var a0: float = TAU * float(i) / seg
		var a1: float = a0 + TAU / seg + 0.03
		draw_arc(_c, R * grow, a0, a1, 3, _gbrass((a0 + a1) * 0.5), 10.0 * rs, true)
	draw_arc(_c, (R - 5.0 * rs) * grow, 0.0, TAU, 72, TBTokens.MAP_FACE, 2.0, true)
	_ticks(_c, (R - 6.0 * rs) * grow, 72, 5.0 * rs, 6, TBTokens.BZ_BRASS, 0.8)
	_dots(_c, (R + 8.0 * rs) * grow, Color(TBTokens.BZ_BRASS, 0.7), 0.6, 1.0, 5.0)
	# the centre: the army
	var cr: float = 54.0 * rs * grow
	draw_circle(_c, cr, TBTokens.MAP_FACE92)
	draw_arc(_c, cr, 0.0, TAU, 48, TBTokens.BZ_LO, 1.0, true)
	if grow > 0.5:                                                           # the centre says which province this is, and what stands in it
		var nf: Font = K.tracked(K.display(), 1)
		var nz: int = maxi(8, P.fs(10.0 * rs))
		var nm: String = TBI18n.place(g.world.name[_subj()]) if (_subj() >= 0 and _subj() < g.P) else ""
		nm = nm.to_upper() if TBI18n.lang != "ru" else nm
		var lines: PackedStringArray = _split_name(nf, nm, nz, 84.0 * rs)
		while nz > 7 and (lines[0].ends_with("…") or (lines.size() > 1 and lines[1].ends_with("…"))):           # a long name is set smaller before it is cut
			nz -= 1; lines = _split_name(nf, nm, nz, 84.0 * rs)
		var lh: float = nf.get_height(nz)
		var z: int = P.fs(21.0 * rs)
		var num_h: float = float(z) * 0.78
		var gap: float = 6.0 * rs
		var block: float = lines.size() * lh + gap + num_h
		var y0: float = _c.y - block * 0.5
		for li in lines.size():
			draw_string(nf, Vector2(_c.x - P.tw(nf, lines[li], nz) * 0.5, y0 + li * lh + nf.get_ascent(nz)), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, nz, TBTokens.BZ_BRASS)
		var ry: float = y0 + lines.size() * lh + gap * 0.5
		draw_line(Vector2(_c.x - 14.0 * rs, ry), Vector2(_c.x + 14.0 * rs, ry), Color(TBTokens.BZ_BRASS, 0.55), 1.0)
		var ic: float = 11.0 * rs
		var tw_: float = P.tw(fb, tx, z)
		var gx: float = _c.x - (ic + 4.0 * rs + tw_) * 0.5
		TBHudParts.icon(self, "swords", Vector2(gx + ic * 0.5, y0 + lines.size() * lh + gap + num_h * 0.5), ic, TBTokens.BZ_BRASS, 1.2)
		draw_string(fb, Vector2(gx + ic + 4.0 * rs, y0 + lines.size() * lh + gap + num_h), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, z, TBTokens.c("cream"))
	var tag_off: float = R + 30.0 * rs
	_lab_l = 0.0; _lab_r = 0.0
	if rs >= 1.0:                                                            # the verbs' names stand beside their medallions: the card starts clear of the longest one on either side
		var lf2: Font = K.tracked(K.display(), 2)
		var lz2: int = P.fs(12.0)
		for i in n:
			var d2 := Vector2(cos(float(_spots[i]["a"])), sin(float(_spots[i]["a"])))
			if absf(d2.x) < 0.3: continue
			var lab2: String = String(verbs[i]["label"])
			lab2 = lab2.to_upper() if TBI18n.lang != "ru" else lab2
			lab2 = P.fit(lf2, lab2, lz2, 150.0)
			var edge2: float = R * absf(d2.x) + 44.0 + P.tw(lf2, lab2, lz2)
			tag_off = maxf(tag_off, edge2 - 26.0)
			if d2.x > 0.0: _lab_r = maxf(_lab_r, edge2)
			else: _lab_l = maxf(_lab_l, edge2)
	_place_tag(tag_off, R + 30.0 * rs); _draw_connector()
	for i in n:
		var st: float = clampf((_t - 0.04 * i) / 0.2, 0.0, 1.0) if K.motion_ok() else 1.0
		var k: float = 1.0 - pow(1.0 - st, 3.0)
		if k <= 0.0: continue
		var v: Dictionary = verbs[i]
		var s: Dictionary = _spots[i]
		var pp: Vector2 = _c + (Vector2(s["p"]) - _c) * k
		var rr: float = float(s["r"]) * (0.5 + 0.5 * k)
		var ok: bool = bool(v["can"]["ok"])
		var prim: bool = bool(v.get("primary", false)) and i == 0
		var danger: bool = bool(v.get("danger", false))
		var hot: bool = i == _hover
		if hot and ok:                                                       # .rv:hover  drop-shadow(0 0 8px rgba(229,199,122,.7))
			for gi in 4: draw_circle(pp, rr + 4.0 + 8.0 - float(gi) * 2.5, Color(TBTokens.MAP_HI, 0.12))
		draw_circle(pp, rr + 4.0, TBTokens.MAP_DISC_EDGE)
		var face: Color = TBTokens.BZ_BRASS if (prim and ok) else TBTokens.MAP_PLATE
		var edge: Color = TBTokens.BZ_HI if (prim and ok) else TBTokens.MAP_BRASS_MID
		draw_circle(pp, rr, face)
		draw_arc(pp, rr, 0.0, TAU, 40, edge, 2.0, true)
		var ink: Color = TBTokens.MAP_ON_BRASS if (prim and ok) else (TBTokens.c("neg_bar") if danger else TBTokens.MAP_HI)
		if not ok: ink = TBTokens.c("ink_off")
		var ipx: float = 24.0 * (1.1 if prim else 0.95) * rs
		if not _demo_icon(String(v["id"]), pp, ipx, ink, 2.0 * 1.0): P.icon(self, String(v["glyph"]), pp, ipx, ink, 2.0)
		if hot or has_focus():
			draw_arc(pp, rr + 5.5, 0.0, TAU, 36, TBTokens.c("cream"), 1.6, true)
		if not ok: TBHudParts.icon(self, "lock", pp + Vector2(rr * 0.6, rr * 0.6), 11.0, TBTokens.c("neg_bar"), 1.4)
		# labels (desktop stage only): Cinzel 700 12 / ls 2.4, #EFE6CF over a 4 wide #05070a stroke, outside the medallion on the side facing away from the centre
		if st >= 0.6 and rs >= 1.0:
			var lf: Font = K.tracked(K.display(), 2)
			var lz: int = P.fs(12.0)
			var lab: String = String(v["label"])
			lab = lab.to_upper() if TBI18n.lang != "ru" else lab
			lab = P.fit(lf, lab, lz, 150.0)
			var lw: float = P.tw(lf, lab, lz)
			var dir := Vector2(cos(float(s["a"])), sin(float(s["a"])))
			var lp: Vector2
			if absf(dir.x) < 0.3: lp = Vector2(pp.x - lw * 0.5, pp.y - (34.0 + 8.0) if dir.y < 0.0 else pp.y + 34.0 + 19.0)
			elif dir.x > 0.0: lp = Vector2(pp.x + 34.0 + 10.0, pp.y + 5.0)
			else: lp = Vector2(pp.x - 34.0 - 10.0 - lw, pp.y + 5.0)
			var col: Color = TBTokens.MAP_IVORY if ok else TBTokens.c("ink_off")
			draw_string_outline(lf, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, 4, TBTokens.MAP_INK)
			draw_string(lf, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lz, col)
