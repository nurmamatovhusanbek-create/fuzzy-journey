## Overlay drawn above the GPU map (art bible 5 and 6.3): zoom-disclosed army markers (dot / pennant / gonfalon) with
## affiliation outlines, general stars, capital rings, order arrows with casing, the keyboard cursor, nation and province names and
## battle effects. Redraws only when the view or game state changed; hidden while dragging. Polygons are cached (no per-frame
## PackedVector2Array allocation in _draw). Never calls g.owned() (a turn may be running on the worker thread).
class_name TBMapLabels
extends Control

var map: TBMapView
var g: TBGame
var max_labels := 90
var _unit := PackedVector3Array()
var _fx: Array = []          # {kind, from, to, col, t0, dur}
var hidden_while_dragging := false
var _tracked: Font
var _tracked_own: Font
var _tracked_for := -1       # readable-fonts state the cached faces were built for

# ---------------------------------------------------------------- order arrow (set by TBOrderFlow)
var _order := {}             # {from, to, attack, dashed, label, hover}
var _path := PackedVector2Array()
var _path_key := ""
var _cut := PackedVector2Array()
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _chev := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _seg := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _fx_pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _push_p := -1            # the order's target marker is slid away from the source so the shaft stays visible between them
var _push_v := Vector2.ZERO
var _push_sp := -1           # ... and, when the order is committed or previewed (not on hover), the source marker slides back by a share
var _push_sv := Vector2.ZERO
var last_shaft := 0.0        # visible shaft length of the current order arrow (px; tests assert it)
var _order_box := Rect2()    # screen bounds of the arrow + label + source marker (the preview chip keeps out of it)
const SHAFT_MIN := 30.0      # visible shaft between the two marker rims (px)

func set_order(from: int, to: int, attack: bool, dashed: bool, label: String = "", hover: bool = false) -> void:
	_order = {"from": from, "to": to, "attack": attack, "dashed": dashed, "label": label, "hover": hover}
	_path_key = ""
	queue_redraw()

func clear_order() -> void:
	if _order.is_empty(): return
	_order = {}
	_push_p = -1; _order_box = Rect2()
	queue_redraw()

## screen bounds of the current order arrow (control-local); empty Rect2 when there is none
func order_bounds() -> Rect2: return _order_box

func attach(m: TBMapView) -> void:
	map = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func set_game(game: TBGame) -> void:
	g = game
	var w := g.world
	_unit.resize(g.P)
	for p in g.P:
		var lon := deg_to_rad(w.lon[p]); var lat := deg_to_rad(w.lat[p])
		var cl := cos(lat)
		_unit[p] = Vector3(cl * sin(lon), sin(lat), cl * cos(lon))   # x east, y north, z toward lon=0
	_order = {}
	_core_sig = -1
	queue_redraw()

func add_fx(kind: String, from: int, to: int, col: Color, delay_ms: int = 0) -> void:
	_fx.append({"kind": kind, "from": from, "to": to, "col": col, "t0": Time.get_ticks_msec() + delay_ms, "dur": 700 if kind == "atk" else 900})
	queue_redraw()

static func tk(name: String) -> Color: return TBTokens.c(name)
static func _a(c: Color, al: float) -> Color:
	c.a *= al
	return c

## relation / selection patterns are subtle in the standard look and strong in colour-vision or high-contrast modes
static func strong() -> bool: return TBLenses.cvd != "off" or TBTokens.is_hc()
## marker geometry follows the text size up to 1.5x (labels follow it fully)
static func mk() -> float: return clampf(TBKit.text_scale, 1.0, 1.5)

var _hex := {}
func _nat_col(o: int) -> Color:
	var v: int = map.lenses.marker_rgb(o)
	if not _hex.has(v): _hex[v] = Color.hex((v << 8) | 0xFF)
	return _hex[v]

var _core_sig := -1
var _core_v := PackedVector3Array()
var _core_n := PackedInt32Array()
var _ax_dir := PackedVector3Array()      # unit tangent along each nation's long axis at its core
var _ax_ext := PackedFloat32Array()      # angular half extent (radians) along that axis

## the label anchor of each nation: the centroid of its main body (provinces within ~30 degrees of the province nearest the overall
## centroid), so overseas colonies do not drag the name into the ocean. Also its long axis and extent: a colliding label slides along
## the axis. Rebuilt only when ownership changed.
func _rebuild_cores() -> void:
	var sig := 0
	for p in g.P: sig = (sig * 31 + g.owner[p] + p) & 0x3fffffff
	if sig == _core_sig and _core_v.size() == g.N1: return
	_core_sig = sig
	var n1 := g.N1
	var sum := PackedVector3Array(); sum.resize(n1)
	_core_n = PackedInt32Array(); _core_n.resize(n1)
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		sum[o] += _unit[p]; _core_n[o] += 1
	var best := PackedInt32Array(); best.resize(n1); best.fill(-1)
	var bd := PackedFloat32Array(); bd.resize(n1); bd.fill(-2.0)
	for n in range(1, n1):
		sum[n] = sum[n].normalized() if sum[n].length() > 0.0001 else Vector3.ZERO
	for p in g.P:
		var o := g.owner[p]
		if o == 0 or sum[o] == Vector3.ZERO: continue
		var d := _unit[p].dot(sum[o])
		if d > bd[o]: bd[o] = d; best[o] = p
	var core := PackedVector3Array(); core.resize(n1)
	for p in g.P:
		var o := g.owner[p]
		if o == 0 or best[o] < 0: continue
		if _unit[p].dot(_unit[best[o]]) > 0.866: core[o] += _unit[p]
	for n in range(1, n1):
		core[n] = core[n].normalized() if core[n].length() > 0.0001 else Vector3.ZERO
	_core_v = core
	# principal axis of the core provinces in the tangent plane at the core
	var east := PackedVector3Array(); east.resize(n1)
	var north := PackedVector3Array(); north.resize(n1)
	var sxx := PackedFloat32Array(); sxx.resize(n1)
	var syy := PackedFloat32Array(); syy.resize(n1)
	var sxy := PackedFloat32Array(); sxy.resize(n1)
	var cn := PackedInt32Array(); cn.resize(n1)
	for n in range(1, n1):
		if core[n] == Vector3.ZERO: continue
		var e := Vector3(0, 1, 0).cross(core[n])
		e = e.normalized() if e.length() > 0.001 else Vector3(1, 0, 0)
		east[n] = e; north[n] = core[n].cross(e)
	for p in g.P:
		var o := g.owner[p]
		if o == 0 or core[o] == Vector3.ZERO or _unit[p].dot(core[o]) < 0.866: continue
		var a := _unit[p].dot(east[o]); var b := _unit[p].dot(north[o])
		sxx[o] += a * a; syy[o] += b * b; sxy[o] += a * b; cn[o] += 1
	_ax_dir = PackedVector3Array(); _ax_dir.resize(n1)
	_ax_ext = PackedFloat32Array(); _ax_ext.resize(n1)
	for n in range(1, n1):
		if cn[n] < 2: continue
		var th := 0.5 * atan2(2.0 * sxy[n], sxx[n] - syy[n])
		_ax_dir[n] = east[n] * cos(th) + north[n] * sin(th)
		_ax_ext[n] = 1.5 * sqrt(maxf(sxx[n], syy[n]) / float(cn[n]))

var _nl_rects: Array = []     # nation label rects drawn this frame (province names keep out of them)

## screen position + depth of a unit vector for the current camera
func _proj_vec(v: Vector3) -> Vector3:
	if map.mode == 0:
		var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
		return _project_v(v, c0, s0, sl, cl, map.radius_px(), map.size.x * 0.5, map.size.y * 0.5)
	var lon := atan2(v.x, v.z); var lat := asin(clampf(v.y, -1.0, 1.0))
	var pt := map.project(rad_to_deg(lon), rad_to_deg(lat))
	return Vector3(pt.x, pt.y, 1.0)

func _project_v(u: Vector3, c0: float, s0: float, sl: float, cl: float, R: float, cx: float, cy: float) -> Vector3:
	var x := u.x * cl - u.z * sl
	var z0 := u.x * sl + u.z * cl
	var y := u.y * c0 - z0 * s0
	var z := u.y * s0 + z0 * c0
	return Vector3(cx + R * x, cy - R * y, z)

func _label_fonts() -> void:
	var rf := (1 if TBKit.readable_fonts else 0) + (2 if TBKit.serif else 0)
	if _tracked != null and _tracked_for == rf: return
	_tracked_for = rf
	if TBKit.readable_fonts:
		_tracked = TBKit.heavy(); _tracked_own = TBKit.heavy()
	else:
		_tracked = TBKit.tracked(TBKit.heavy(), 1); _tracked_own = TBKit.tracked(TBKit.heavy(), 1)

## halo alpha chosen from the land under the label: pale land gets the full halo, dark land a lighter one (CON-006). Opaque in high contrast.
func _halo_alpha(pos: Vector2) -> float:
	if TBTokens.is_hc(): return 1.0
	var p := map.pick_at(pos)
	if p < 0 or map.lenses == null: return 0.9
	var l := TBLenses.lum(map.lenses.color(p))
	return lerpf(0.78, 1.0, smoothstep(0.08, 0.4, l))

const GENERIC_FIRST := ["Kingdom", "Republic", "Empire", "United", "Grand", "Holy", "Duchy", "Sultanate", "Emirate", "Khanate", "Principality", "Confederation"]
const NAME_PREFIXES := ["Kingdom of the ", "Kingdom of ", "Republic of the ", "Republic of ", "Empire of ", "Grand Duchy of ", "Duchy of ", "Sultanate of ", "Emirate of ", "Principality of ", "Confederation of "]
func _core_name(txt: String) -> String:
	for pre in NAME_PREFIXES:
		if txt.begins_with(pre) and txt.length() > pre.length() + 2: return txt.substr(pre.length())
	return txt

func _two_lines(txt: String) -> PackedStringArray:
	var out := PackedStringArray()
	if txt.length() <= 14 or not txt.contains(" "): return out
	var words := txt.split(" ")
	var best := 0; var bd := 999
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i)); var b := " ".join(words.slice(i))
		var d := absi(a.length() - b.length())
		if d < bd: bd = d; best = i
	out.append(" ".join(words.slice(0, best))); out.append(" ".join(words.slice(best)))
	return out

## nation names (Cinzel 700 cream, 2 px halo, never faded, own realm in the heavier face): bigger nations get bigger text; a name that
## collides with a marker, a HUD panel, the order arrow or a higher-priority name slides along the nation's axis, wraps to two lines,
## drops to its first word, and is dropped only when none of that fits.
func _draw_nation_names() -> void:
	_nl_rects.clear()
	if map.zoom > (4.0 if map.mode == 0 else 5.5): return
	_label_fonts()
	var N1 := g.N1
	_rebuild_cores()
	var cnt := _core_n
	var order: Array = []
	for n in range(1, N1):
		if cnt[n] >= 3 and g.alive[n] != 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a, b): return (a == g.human_id) or (b != g.human_id and cnt[a] > cnt[b]))      # your own realm is placed first
	var shown := 0
	var cream := tk("cream"); var halo := tk("table")
	var hc := TBTokens.is_hc()
	var hsz := 5 if hc else 3
	var lens_wars: bool = map.lenses.mode == "wars"
	var tsc := TBKit.text_scale
	var mnx := 16.0
	var strong_on := strong()
	var steps := [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9, 1.2, -1.2, 1.6, -1.6]
	for n in order:
		if shown >= 70: break
		var core: Vector3 = _core_v[n]
		if core == Vector3.ZERO: continue
		var fs := int(clampf(8.0 + sqrt(float(cnt[n])) * 0.9 * minf(map.zoom, 2.2), 12.0, 20.0) * tsc)
		fs = clampi(maxi(fs, TBKit.min_font()), TBKit.min_font(), 44)
		var mine: bool = n == g.human_id
		var font: Font = _tracked_own if mine else _tracked
		var txt: String = g.dname(n)
		if lens_wars and map.lenses.war_bloc.size() > n and map.lenses.war_bloc[n] >= 0: txt += " " + char(65 + map.lenses.war_bloc[n] % 26)
		var variants: Array = [[txt]]
		var two := _two_lines(txt)
		if not two.is_empty(): variants.append([two[0], two[1]])
		var core_name := _core_name(txt)
		if core_name != txt: variants.append([core_name])                      # "Kingdom of the Two Sicilies" -> "Two Sicilies"
		if txt.contains(" ") and not GENERIC_FIRST.has(txt.split(" ")[0]): variants.append([txt.split(" ")[0]])
		var rel := -1 if mine else g.get_rel(g.human_id, n)
		var atlas: bool = map.atlas_look() and not TBKit.readable_fonts
		if atlas:                                                           # Atlas: Barlow Condensed 600, uppercase, +.08em, paper-100 at 85 % over a 3 px ink-900 halo
			font = TBKit.tracked(TBKit.map_font(), maxi(1, roundi(fs * 0.08)))
			for vi in variants.size(): variants[vi] = (variants[vi] as Array).map(func(t: String) -> String: return t.to_upper())
		var placed_ok := false
		var ext := _ax_ext[n]
		var perp := core.cross(_ax_dir[n]).normalized() if _ax_dir[n] != Vector3.ZERO else Vector3.ZERO
		for ci in steps.size() * 3:
			if placed_ok: break
			var st: float = steps[ci / 3]
			var ps: float = [0.0, 0.35, -0.35][ci % 3]
			if (st != 0.0 or ps != 0.0) and (ext <= 0.001 or _ax_dir[n] == Vector3.ZERO): break
			var a: float = clampf(st * ext, -0.22, 0.22)               # never drift far from the body of the nation
			var v := core
			if st != 0.0 or ps != 0.0:
				v = (core * cos(a) + _ax_dir[n] * sin(a)).normalized()
				v = (v * cos(clampf(ps * ext, -0.12, 0.12)) + perp * sin(clampf(ps * ext, -0.12, 0.12))).normalized()
			var pr := _proj_vec(v)
			if map.mode == 0 and pr.z < 0.25: continue
			var pos := Vector2(pr.x, pr.y)
			for vr in variants:
				var lines: Array = vr
				var lh := font.get_height(fs)
				var w := 0.0
				for ln in lines: w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				var gw := float(fs) + 4.0 if (strong_on and (mine or rel >= 1)) else 0.0
				var rect := Rect2(pos - Vector2((w + gw) * 0.5, lh * lines.size() * 0.5), Vector2(w + gw, lh * lines.size())).grow(3.0)
				if rect.position.x < mnx or rect.position.y < 56.0 or rect.end.x > map.size.x - mnx or rect.end.y > map.size.y - mnx: continue
				if _blocked(rect) or _hits_marker(rect) or _hits_order(rect): continue
				var clash := false
				for r in _nl_rects:
					if (r as Rect2).intersects(rect): clash = true; break
				if clash: continue
				_nl_rects.append(rect); shown += 1; placed_ok = true
				var ha := _halo_alpha(pos)
				var tx := rect.position.x + 3.0 + gw
				for li in lines.size():
					var ln: String = lines[li]
					var lw := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					var bp := Vector2(tx + (w - lw) * 0.5, rect.position.y + 3.0 + lh * li + font.get_ascent(fs))
					if atlas:
						draw_string_outline(font, bp, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(TBTokens.INK_900, 0.9))
						draw_string(font, bp, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(TBTokens.PAPER_100, 0.85))
					else:
						draw_string_outline(font, bp, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hsz, _a(halo, ha))
						draw_string(font, bp, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
				if gw > 0.0: _rel_glyph(Vector2(rect.position.x + 3.0 + float(fs) * 0.5, rect.get_center().y), rel, mine, fs, ha)
				break

func _hits_marker(r: Rect2) -> bool:
	for fr in _frame_rects:
		if (fr as Rect2).intersects(r): return true
	return false

func _hits_order(r: Rect2) -> bool:
	return not _order_box.size.is_zero_approx() and _order_box.intersects(r)

## relation glyph beside a nation name in colour-vision / high-contrast modes: swords (war), linked rings (ally), hourglass (truce), ring + square (own)
func _rel_glyph(c: Vector2, rel: int, mine: bool, fs: int, ha: float) -> void:
	var sz := float(fs)
	draw_circle(c, sz * 0.62, _a(tk("table"), ha))
	if mine:
		draw_arc(c, sz * 0.32, 0.0, TAU, 16, tk("brass_lt"), 1.5, true)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), tk("brass_lt"))
	elif rel == 1: TBGlyph.draw(self, "swords", c, sz * 0.9, tk("neg_bar"), 1.6)
	elif rel == 3 or rel == 4: TBGlyph.draw(self, "link", c, sz * 0.9, tk("info_bar"), 1.6)
	elif rel == 2: TBGlyph.draw(self, "hourglass", c, sz * 0.9, tk("cream"), 1.5)

## province names when zoomed in far enough to read them (Alegreya 500 12+, cream, halo; no overlaps, capitals in Alegreya 700)
func _draw_province_names() -> void:
	if map.zoom < (4.0 if map.mode == 0 else 5.5): return
	var f: Font = TBKit.body()
	var fb: Font = TBKit.body_b()
	var fs := TBKit.fs(12.0)
	var placed: Array = _frame_rects.duplicate()     # markers claim their space first
	placed.append_array(_nl_rects)
	var shown := 0
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var cream := tk("cream")
	var hsz := 5 if TBTokens.is_hc() else 3
	for p in g.P:
		if shown >= 70: break
		var pos: Vector2
		if map.mode == 0:
			var pr := _project(p, c0, s0, sl, cl, R, cx, cy)
			if pr.z < 0.3: continue
			pos = Vector2(pr.x, pr.y)
		else:
			var pt := map.project(g.world.lon[p], g.world.lat[p])
			pos = Vector2(pt.x, pt.y)
		if pos.x < 20 or pos.y < 70 or pos.x > map.size.x - 20 or pos.y > map.size.y - 20: continue
		var txt: String = TBI18n.place(g.world.name[p])
		var cap := g.capital[p] != 0
		var ff: Font = fb if cap else f
		var tw := ff.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rect := Rect2(pos + Vector2(-tw.x * 0.5, 8), tw).grow(2.0)
		var clash := _blocked(rect) or _hits_order(rect)
		for r in placed:
			if clash: break
			if r.intersects(rect): clash = true
		if clash: continue
		placed.append(rect); shown += 1
		var bp := rect.position + Vector2(2, ff.get_ascent(fs) + 2)
		draw_string_outline(ff, bp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hsz, _a(tk("table"), _halo_alpha(pos)))
		draw_string(ff, bp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)

## true when r overlaps nothing placed so far (and records it)
func _claim(grid: Dictionary, r: Rect2) -> bool:
	var x0 := int(floor(r.position.x / 32.0)); var x1 := int(floor(r.end.x / 32.0))
	var y0 := int(floor(r.position.y / 24.0)); var y1 := int(floor(r.end.y / 24.0))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var cell: Array = grid.get(Vector2i(cx, cy), [])
			for q in cell:
				if (q as Rect2).intersects(r): return false
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if not grid.has(key): grid[key] = []
			grid[key].append(r)
	return true

## screen position + visibility for province p given the map camera
func _project(p: int, c0: float, s0: float, sl: float, cl: float, R: float, cx: float, cy: float) -> Vector3:
	return _project_v(_unit[p], c0, s0, sl, cl, R, cx, cy)

# ---------------------------------------------------------------- army markers (stateful: they fade and count)
var _pl := {}                  # province -> {a: alpha, t: target alpha, shown: displayed army, last: army last seen, pop: 0..1, dn: pending delta, dt: delta timer, x, y, tier, extra, gen}
var _frame_rects: Array = []
var _stars := {}               # province -> {a, t, x, y, limb}: capital rings without an army marker
const TIERS := [25, 60, 140]

func _tier(a: int) -> int:
	var t := 0
	for lim in TIERS:
		if a >= lim: t += 1
	return t

func _state(p: int) -> Dictionary:
	var st: Dictionary = _pl.get(p, {})
	if st.is_empty():
		st = {"a": 0.0, "t": 0.0, "shown": float(g.army[p]), "last": g.army[p], "pop": 0.0, "dn": 0, "dt": 0.0, "x": 0.0, "y": 0.0, "tier": _tier(g.army[p]), "limb": 1.0, "extra": 0, "zt": 2, "tx": 0.0, "ty": 0.0}
		_pl[p] = st
	return st

## advance fades, count roll-ups and pops; ask for a redraw while anything is moving
func _process(delta: float) -> void:
	var busy := not _fx.is_empty()
	var motion := TBKit.motion_ok()
	if not _order.is_empty() and bool(_order["dashed"]) and motion: busy = true       # marching dashes
	if g != null:
		var dead: Array = []
		for p in _pl:
			var st: Dictionary = _pl[p]
			var a: int = g.army[p]
			if a != st["last"]:
				var d: int = a - int(st["last"])
				if st["a"] > 0.2:                      # only visible markers announce changes
					st["pop"] = 1.0 if motion else 0.0
					st["dn"] = int(st["dn"]) + d if float(st["dt"]) > 0.0 else d
					st["dt"] = 1.3
				st["last"] = a
				st["tier"] = _tier(a)
			if not motion:
				if st["a"] != st["t"]: busy = true
				st["a"] = st["t"]; st["shown"] = float(a)
				st["dt"] = maxf(0.0, st["dt"] - delta)
			else:
				st["a"] = move_toward(st["a"], st["t"], delta * 6.0)
				st["shown"] += (float(a) - st["shown"]) * (1.0 - exp(-11.0 * delta))
				if absf(float(a) - st["shown"]) < 0.5: st["shown"] = float(a)
				st["pop"] = maxf(0.0, st["pop"] - delta * 3.2)
				st["dt"] = maxf(0.0, st["dt"] - delta)
			if st["a"] != st["t"] or st["pop"] > 0.0 or st["dt"] > 0.0 or int(round(st["shown"])) != a: busy = true
			if st["a"] <= 0.0 and st["t"] <= 0.0: dead.append(p)
		for p in dead: _pl.erase(p)
		var sdead: Array = []
		for p in _stars:
			var ss: Dictionary = _stars[p]
			var sa: float = ss["a"]
			ss["a"] = ss["t"] if not motion else move_toward(ss["a"], ss["t"], delta * 6.0)
			if ss["a"] != ss["t"] or sa != ss["a"]: busy = true
			if ss["a"] <= 0.0 and ss["t"] <= 0.0: sdead.append(p)
		for p in sdead: _stars.erase(p)
	if busy: queue_redraw()

func _screen(p: int, c0: float, s0: float, sl: float, cl: float, R: float, cx: float, cy: float) -> Vector3:
	if map.mode == 0:
		return _project(p, c0, s0, sl, cl, R, cx, cy)
	var pt := map.project(g.world.lon[p], g.world.lat[p])
	return Vector3(pt.x, pt.y, 1.0)

## average province size on screen (px): picks the marker tier. Far < 14 (dot), mid 14-40 (pennant), near > 40 (gonfalon)
func prov_px() -> float:
	var k := sqrt(3.7 / float(maxi(1, g.P)))
	return (map.radius_px() if map.mode == 0 else map.flat_scale()) * k

## half extent of a marker along direction d (unit) at tier zt, for the arrow trim and the target push
func _ext_tier(zt: int, army: int, d: Vector2, hot: bool = false) -> float:
	var m := mk()
	if hot: return _ext_tier(zt, army, d) + 5.0 * m
	if zt == 0: return 9.0 * m
	var near := zt >= 2
	var hw := _badge_w(TBKit.body_b(), maxi(army, 1), near) * 0.5 + 3.0
	var hh := _badge_h(near) * 0.5 + 3.0
	return (absf(d.x) * hw + absf(d.y) * hh + (maxf(0.0, d.x) * 26.0 if near else 0.0)) * m          # near: + room for a "+n" tab on the right

## claim rectangle of a marker at pos for the tier: covers everything it draws (outline, pip, tab room), so no two markers overlap
func _marker_rect(pos: Vector2, ztier: int, army: int, gen: bool, gw: float) -> Rect2:
	var m := mk()
	match ztier:
		0: return Rect2(pos.x - 8.0 * m, pos.y - 8.0 * m, 16.0 * m, 16.0 * m)
		1: return Rect2(pos.x - (gw * 0.5 + 4.0) * m, pos.y - (_badge_h(false) * 0.5 + 4.0) * m, (gw + 8.0) * m, (_badge_h(false) + 8.0) * m)
	return Rect2(pos.x - (gw * 0.5 + 4.0) * m, pos.y - ((_badge_h(true) * 0.5 + 16.0) if gen else (_badge_h(true) * 0.5 + 5.0)) * m, (gw + 8.0) * m, ((_badge_h(true) + 21.0) if gen else (_badge_h(true) + 10.0)) * m)

func _draw() -> void:
	if map == null or g == null or hidden_while_dragging: return
	_refresh_keepout()
	_nl_rects.clear()
	if g.human_id == 0:                 # nation-pick screen: names only
		_frame_rects.clear(); _order_box = Rect2()
		_draw_nation_names()
		return
	var me := g.human_id
	var psz := prov_px()
	var ztier := 0 if psz < 14.0 else (1 if psz < 40.0 else 2)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var sel := map.selected; var hov := map.hover
	# ---- the order's target marker slides away from the source when the two would leave no visible shaft between them
	_push_p = -1; _push_v = Vector2.ZERO; _push_sp = -1; _push_sv = Vector2.ZERO
	if not _order.is_empty():
		var of: int = _order["from"]; var ot: int = _order["to"]
		var pa := _screen(of, c0, s0, sl, cl, R, cx, cy); var pb := _screen(ot, c0, s0, sl, cl, R, cx, cy)
		var dv := Vector2(pb.x - pa.x, pb.y - pa.y)
		var dl := dv.length()
		if dl > 1.0 and (map.mode != 0 or (pa.z > 0.2 and pb.z > 0.2)):
			var dn := dv / dl
			var head := 14.0 if bool(_order["attack"]) else 12.0
			var req := _ext_tier(ztier, g.army[of], dn, of == sel) + (_ext_tier(ztier, g.army[ot], -dn) if g.army[ot] > 0 else 5.0) + SHAFT_MIN + head + 4.0
			if dl < req:
				var need := req - dl
				if bool(_order.get("hover", false)): _push_p = ot; _push_v = dn * minf(need, 90.0)
				else:
					var share := minf(need * 0.5, 70.0)
					_push_p = ot; _push_v = dn * share; _push_sp = of; _push_sv = -dn * share
		# ---- candidates: (province, x, y, priority, limb factor, army, wants a marker)
	var vis: Array = []
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		var a := g.army[p]
		var cap := g.capital[p] != 0
		var rel := g.get_rel(me, o) if o != me else -1
		var war := rel == 1
		var want := false
		if a > 0:
			match ztier:
				0: want = o == me or war or p == sel
				1: want = o == me or war or rel == 3 or p == sel or p == hov
				_: want = true
		var ring := cap and (o == me or ztier >= 2 or p == sel)
		if not want and not ring: continue
		var pr := _screen(p, c0, s0, sl, cl, R, cx, cy)
		var limb := 1.0
		if map.mode == 0:
			if pr.z < 0.2: continue
			limb = smoothstep(0.2, 0.55, pr.z)                         # nothing near the horizon
		elif pr.x < -24 or pr.y < -24 or pr.x > map.size.x + 24 or pr.y > map.size.y + 24: continue
		if p == _push_p: pr.x += _push_v.x; pr.y += _push_v.y
		elif p == _push_sp: pr.x += _push_sv.x; pr.y += _push_sv.y
		var shown_before := _pl.has(p) and float(_pl[p]["t"]) > 0.5
		var pri := 0 if (o == me or p == sel) else (1 if war else (2 if cap else 3))
		if not _order.is_empty() and (p == int(_order["from"]) or p == int(_order["to"])): pri = -1      # the order's two ends always get their markers
		vis.append([p, pr.x, pr.y, pri * 4 + (0 if shown_before else 1), limb, a, want])
	vis.sort_custom(func(a, b): return a[3] < b[3] if a[3] != b[3] else (a[5] > b[5] if a[5] != b[5] else a[0] < b[0]))
	# ---- choose without overlap; stacks that would overlap collapse into one marker with a "+n" tab
	for p in _pl: _pl[p]["t"] = 0.0; _pl[p]["extra"] = 0
	for p in _stars: _stars[p]["t"] = 0.0
	var grid := {}
	_frame_rects.clear()
	var drawn := 0
	var chosen: Array = []
	var chosen_set := {}
	var chosen_rects: Array = []
	var cap_n := mini(max_labels, 60 if ztier == 0 else max_labels)
	var nfont: Font = TBKit.mono_b()
	for v in vis:
		if drawn >= cap_n: break
		var p: int = v[0]
		var pos := Vector2(v[1], v[2])
		var o := g.owner[p]
		if not v[6]:
			var rr := Rect2(pos - Vector2(9, 9), Vector2(18, 18))
			if not _blocked(rr) and _claim(grid, rr):
				if not _stars.has(p): _stars[p] = {"a": 0.0, "t": 1.0}
				_stars[p]["t"] = 1.0; _stars[p]["x"] = pos.x; _stars[p]["y"] = pos.y; _stars[p]["limb"] = v[4]
				drawn += 1
			continue
		var a: int = v[5]
		if a <= 0: continue
		var st := _state(p)
		var gw := _badge_w(nfont, maxi(a, int(st["shown"])), ztier >= 2)
		var prect := _marker_rect(pos, ztier, a, g.gen[p] != 0, gw)
		if _blocked(prect): continue
		if not _claim(grid, prect):
			# collapse into the same nation's marker that already holds this spot
			for i in chosen.size():
				if (chosen_rects[i] as Rect2).intersects(prect) and g.owner[chosen[i]] == o:
					_pl[chosen[i]]["extra"] = int(_pl[chosen[i]]["extra"]) + 1; break
			continue
		_frame_rects.append(prect)
		st["t"] = 1.0; st["x"] = pos.x; st["y"] = pos.y; st["limb"] = v[4]; st["zt"] = ztier
		chosen.append(p); chosen_set[p] = true; chosen_rects.append(prect)
		drawn += 1
	# ---- draw: fading markers (underneath), then the chosen, own realm on top
	var order: Array = []
	for p in _pl:
		if float(_pl[p]["a"]) > 0.01 and not chosen_set.has(p): order.append(p)
	for i in range(chosen.size() - 1, -1, -1): order.append(chosen[i])
	for p in _stars:
		var ss: Dictionary = _stars[p]
		if float(ss["a"]) > 0.01: _capital_mark(Vector2(ss["x"], ss["y"]), float(ss["a"]) * float(ss["limb"]), g.owner[p] == me)
	for p in order:
		var st: Dictionary = _pl[p]
		var al: float = float(st["a"]) * float(st["limb"])
		if al <= 0.01: continue
		var pos := Vector2(st["x"], st["y"])
		if not chosen_set.has(p):               # a fading marker keeps following its province
			var pr2 := _screen(p, c0, s0, sl, cl, R, cx, cy)
			if map.mode == 0 and pr2.z < 0.04: continue
			pos = Vector2(pr2.x, pr2.y)
		_draw_marker(p, pos, st, al, nfont, me, int(st["zt"]))
	for p in order:                             # "+n" tabs last: a neighbouring marker never covers them
		var st2: Dictionary = _pl[p]
		if int(st2["extra"]) > 0 and int(st2["zt"]) == 2 and chosen_set.has(p): _draw_tab(st2, float(st2["a"]) * float(st2["limb"]))
	_draw_order()
	_draw_focus()
	_draw_nation_names()
	_draw_province_names()
	_draw_fx()

## screen areas covered by the interface (dock, seal, ribbon, command card): labels keep out of them. Callable -> Array[Rect2] in global coordinates
var _ko: Array = []

func _refresh_keepout() -> void:
	_ko.clear()
	if not map.keepout_fn.is_valid(): return
	var o := get_global_rect().position
	for r in map.keepout_fn.call(): _ko.append(Rect2((r as Rect2).position - o, (r as Rect2).size))

func _blocked(r: Rect2) -> bool:
	for k in _ko:
		if (k as Rect2).intersects(r): return true
	return false

# ---------------------------------------------------------------- cached marker shapes
var _star_poly := PackedVector2Array()
var _star_line := PackedVector2Array()
## army badge size (px, before the marker scale): a flat rectangle, wider for bigger numbers; the near tier is a little larger
func _badge_w(f: Font, n: int, near: bool, flag := true) -> float:
	if map != null and map.atlas_look():                                # Atlas token: 6 px owner stripe, 16 px flag, number 14/600
		return 6.0 + 6.0 + (22.0 if flag else 0.0) + 6.0 + f.get_string_size(TBKit.fmt(n), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(14.0 if near else 13.0)).x + 10.0
	return (_badge_h(near) * 1.3 + 3.0 + 4.0 if flag else 8.0) + f.get_string_size(TBKit.fmt(n), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13.0 if near else 12.0)).x + 6.0
func _badge_h(near: bool) -> float:
	if map != null and map.atlas_look(): return 28.0 if near else 24.0
	return 22.0 if near else 19.0

func _ensure_star() -> void:
	if not _star_poly.is_empty(): return
	for i in 10: _star_poly.append(Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * 4.5 * (1.0 if i % 2 == 0 else 0.42))
	_star_line = _star_poly.duplicate(); _star_line.append(_star_poly[0])

## capital: a 10 px ring with a filled 6 px square (a star always means "general")
func _capital_mark(pos: Vector2, al: float, mine: bool) -> void:
	var casing := _a(tk("table"), 0.9 * al)
	var c := _a(tk("brass_lt") if mine else tk("cream"), al)
	draw_circle(pos, 7.0, casing)
	draw_arc(pos, 5.0, 0.0, TAU, 20, c, 1.5, true)
	draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), c)

## far tier: an 8 px dot. Affiliation by outline: own = 2 px brass + ink outer, war = 2 px red outline, others 1 px ink
func _draw_dot(pos: Vector2, al: float, own: bool, war: bool, hot: bool, nat: Color) -> void:
	var m := mk()
	var r := 4.0 * m
	var ink := tk("table")
	if hot: draw_circle(pos, r + 5.0, _a(ink, al)); draw_circle(pos, r + 4.0, _a(tk("cream"), al)); draw_circle(pos, r + 1.0, _a(ink, al))
	if own:
		draw_circle(pos, r + 3.0, _a(ink, al)); draw_circle(pos, r + 2.0, _a(tk("brass_lt"), al))
	elif war:
		draw_circle(pos, r + 3.0, _a(ink, al)); draw_circle(pos, r + 2.0, _a(tk("neg_bar"), al))
	else:
		draw_circle(pos, r + 1.0, _a(ink, al))
	draw_circle(pos, r, _a(ink, al) if (own or war) else _a(nat, al))
	draw_circle(pos, r - 1.0, _a(nat, al))

## one army marker for the current zoom tier: dot (far), pennant (mid) or gonfalon (near); affiliation by outline, never by colour alone
func _draw_marker(p: int, pos: Vector2, st: Dictionary, al: float, nfont: Font, me: int, ztier: int) -> void:
	var o := g.owner[p]
	var rel := g.get_rel(me, o) if o != me else -1
	var own := o == me
	var war := rel == 1
	var ally := rel == 3
	var hot := p == map.selected
	var army: int = g.army[p]
	if not own and not war and not ally and not hot and p != map.hover: al *= 0.7        # quiet foreign stacks recede
	var ease_in: float = float(st["a"])
	var sc := (0.6 + 0.4 * (1.0 - pow(1.0 - ease_in, 3.0))) * mk()                       # out-cubic appear, no overshoot
	sc *= 1.0 + 0.26 * float(st["pop"]) * float(st["pop"])
	if hot and map.atlas_look(): sc *= 1.08
	var nat := _nat_col(o)
	var ink := tk("ink_0")
	var lift := -4.0 if (hot and ztier == 2) else 0.0
	if ztier == 0:
		_draw_dot(pos, al, own, war, hot, nat)
		_floater(p, pos, st, o, me, nfont)
		return
	# AoC-style army marker: a dark rounded pill with the nation's flag and the strength; own gold, war red, ally blue, others cream
	var txt := TBKit.fmt(int(round(st["shown"])))
	var near: bool = ztier == 2
	var atlas := map.atlas_look()
	var fsz: int = TBKit.fs((14.0 if near else 13.0) if atlas else (13.0 if near else 12.0))
	var tw := nfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var bw := _badge_w(nfont, int(round(st["shown"])), near, o != 0)
	var bh: float = _badge_h(near)
	if atlas:
		_draw_token(p, pos + Vector2(0, lift), st, al, nfont, o, own, war, ally, hot, txt, fsz, bw, bh, sc, near)
		return
	draw_set_transform(pos + Vector2(0, lift), 0.0, Vector2(sc, sc))
	var r := Rect2(-bw * 0.5, -bh * 0.5, bw, bh)
	var edge := Color.TRANSPARENT
	if own: edge = _a(tk("brass_lt"), 0.9 * al)
	elif war: edge = _a(tk("neg_bar"), 0.95 * al)
	elif ally: edge = _a(tk("info_bar"), 0.95 * al)
	if hot: edge = _a(tk("cream"), al)
	if hot: draw_style_box(TBHudParts.sbox(_a(tk("table"), 0.35 * al), Color.TRANSPARENT, 7.0, 0), r.grow(3.0))
	draw_style_box(TBHudParts.sbox(_a(tk("table"), 0.86 * al), edge, 5.0, 1 if edge.a > 0.0 else 0), r)
	var fl_w := bh * 1.3
	var fl := Rect2(r.position + Vector2(3.0, 3.0), Vector2(fl_w, bh - 6.0))
	if o != 0:
		draw_texture_rect(TBFlags.texture(g.nat_code[o], g.color[o]), fl, false, _a(Color.WHITE, al))
		draw_rect(fl, _a(tk("table"), 0.7 * al), false, 1.0)
	var tcol: Color = tk("cream")
	if own: tcol = tk("brass_lt")
	elif war: tcol = tk("neg_bar")
	elif ally: tcol = tk("info_bar")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := pos + Vector2(0, lift)
	draw_string(nfont, base + Vector2(((fl.end.x + 4.0) if o != 0 else (-bw * 0.5 + 5.0)) * sc, (bh * 0.5 - 4.5) * sc), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, _a(tcol, al))
	if not near:
		_pip(base + Vector2((bw * 0.5 + 1.0) * sc, -bh * 0.5 * sc), war, ally, al, 0.8)
		_floater(p, pos, st, o, me, nfont)
		return
	st["tx"] = pos.x + (bw * 0.5 + 3.0) * sc; st["ty"] = pos.y + (-bh * 0.5 + lift) * sc
	if g.gen[p] != 0:                                                                        # general: 1-5 brass stars above the badge
		_ensure_star()
		var n := mini(5, TBGenerals.skill(g, p))
		for i in n:
			var sx := (i - (n - 1) * 0.5) * 9.0
			draw_set_transform(pos + Vector2(sx * sc, (-bh * 0.5 - 8.0 + lift) * sc), 0.0, Vector2(sc, sc))
			draw_colored_polygon(_star_poly, _a(tk("brass_lt"), al))
			draw_polyline(_star_line, _a(ink, al), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pip(base + Vector2((bw * 0.5 + 1.0) * sc, -bh * 0.5 * sc), war, ally, al, 1.0)
	if g.capital[p] != 0: _capital_mark(base + Vector2((-bw * 0.5 - 8.0) * sc, -bh * 0.5 * sc), al, own)
	_floater(p, pos, st, o, me, nfont)

## Atlas map token: ink-800 pill, 6 px stripe in the owner's colour on the left, 16 px flag, number 14/600; ring = own accent / hostile bad / allied info
func _draw_token(p: int, pos: Vector2, st: Dictionary, al: float, nfont: Font, o: int, own: bool, war: bool, ally: bool, hot: bool, txt: String, fsz: int, bw: float, bh: float, sc: float, near: bool) -> void:
	var ring := TBTokens.INK_500
	if own: ring = TBTokens.accent
	elif war: ring = TBTokens.BAD
	elif ally: ring = TBTokens.INFO
	if hot: ring = TBTokens.PAPER_100
	var r := Rect2(pos + Vector2(-bw * 0.5, -bh * 0.5) * sc, Vector2(bw, bh) * sc)
	if hot: draw_style_box(TBHudParts.sbox(_a(TBTokens.INK_900, 0.4 * al), Color.TRANSPARENT, bh * 0.5 * sc + 3.0, 0), r.grow(3.0))
	draw_style_box(TBHudParts.sbox(_a(TBTokens.INK_800, 0.97 * al), _a(ring, al), bh * 0.5 * sc, 2 if (own or war or ally or hot) else 1), r)
	if o != 0:                                                       # stripe: the circular segment of the left cap, 6 px wide
		var rad := bh * 0.5 * sc
		var sw := 6.0 * sc
		var cth := acos(clampf((sw - rad) / rad, -1.0, 1.0))
		var poly := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var th := cth + (TAU - 2.0 * cth) * float(i) / steps
			poly.append(Vector2(r.position.x + rad + rad * cos(th), r.position.y + rad + rad * sin(th)))
		draw_colored_polygon(poly, _a(_nat_col(o), al))
	var fx := r.position.x + (6.0 + 6.0) * sc
	if o != 0:
		var fl := Rect2(fx, pos.y - 8.0 * sc, 22.0 * sc, 16.0 * sc)
		draw_texture_rect(TBFlags.texture(g.nat_code[o], g.color[o]), fl, false, _a(Color.WHITE, al))
		draw_rect(fl, _a(TBTokens.INK_900, 0.6 * al), false, 1.0)
		fx = fl.end.x + 6.0 * sc
	else:
		fx = r.position.x + 12.0 * sc
	var asc := nfont.get_ascent(fsz); var hgt := nfont.get_height(fsz)
	draw_string(nfont, Vector2(fx, pos.y + (asc - hgt * 0.5) * 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, _a(TBTokens.PAPER_100, al))
	st["tx"] = r.end.x - 4.0; st["ty"] = r.position.y - 10.0
	if near and g.gen[p] != 0:                                       # general: 1-5 stars above the pill
		_ensure_star()
		var n := mini(5, TBGenerals.skill(g, p))
		for i in n:
			var sx := (i - (n - 1) * 0.5) * 9.0
			draw_set_transform(Vector2(pos.x + sx * sc, r.position.y - 7.0), 0.0, Vector2(sc, sc))
			draw_colored_polygon(_star_poly, _a(TBTokens.WARN, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if near and g.capital[p] != 0: _capital_mark(Vector2(r.position.x - 8.0 * sc, r.position.y + 2.0), al, own)
	_pip(Vector2(r.end.x + 1.0, r.position.y), war, ally, al, 1.0 if near else 0.8)
	_floater(p, pos, st, o, 0 if g == null else g.human_id, nfont)

## "+n" tab: stacked armies collapse into one gonfalon (12 px Mono 700, drawn above every marker)
func _draw_tab(st: Dictionary, al: float) -> void:
	var et := "+%d" % int(st["extra"])
	var fs := TBKit.fs(12.0)
	var f: Font = TBKit.mono_b()
	var ew := f.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
	var eh := float(fs) + 4.0
	var r := Rect2(float(st["tx"]), float(st["ty"]), ew, eh)
	if map.atlas_look():                                              # count badge: round-cornered ink-700 chip with a hairline
		draw_style_box(TBHudParts.sbox(_a(TBTokens.INK_700, al), _a(TBTokens.INK_500, al), eh * 0.5, 1), r)
		draw_string(f, r.position + Vector2(4.0, f.get_ascent(fs) + 2.0), et, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _a(TBTokens.PAPER_100, al))
		return
	draw_rect(r.grow(1.0), _a(tk("cream"), al))
	draw_rect(r, _a(tk("table"), al))
	draw_string(f, r.position + Vector2(4.0, f.get_ascent(fs) + 2.0), et, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _a(tk("cream"), al))

## affiliation outline in the CURRENT transform. own: 2 px brass + 1 px ink outer; ally: double 1 px info line; war: 2 px neg + ink outer; foreign: 1 px ink
func _outline(line: PackedVector2Array, d: Variant, own: bool, war: bool, ally: bool, hot: bool, al: float, sc: float, wmul: float) -> void:
	var u := 1.0 / maxf(0.5, sc)
	if own or war:
		draw_polyline(line, _a(tk("table"), al), 4.0 * u, true)
		draw_polyline(line, _a(tk("brass_lt") if own else tk("neg_bar"), al), 2.0 * u, true)
	elif ally:
		draw_polyline(line, _a(tk("info_bar"), al), 1.0 * u, true)
		if d != null: draw_polyline((d as Dictionary)["grown"], _a(tk("info_bar"), al), 1.0 * u, true)
		else: draw_polyline(line, _a(tk("info_bar"), al), 3.0 * u, true)
	else:
		draw_polyline(line, _a(tk("table"), al), 1.0 * u, true)
	if hot:
		var ring: PackedVector2Array = (d as Dictionary)["ring"] if d != null else line
		draw_polyline(ring, _a(tk("table"), al), 5.0 * u, true)
		draw_polyline(ring, _a(tk("cream"), al), 3.0 * u, true)

## 6 px affiliation pip at a corner: crossed swords for war, linked rings for allies
func _pip(c: Vector2, war: bool, ally: bool, al: float, k: float) -> void:
	if not (war or ally): return
	draw_circle(c, 5.5 * k, _a(tk("bar_0"), 0.95 * al))
	TBGlyph.draw(self, "swords" if war else "link", c, 8.0 * k, _a(tk("neg_bar") if war else tk("info_bar"), al), 1.2)

func _floater(p: int, pos: Vector2, st: Dictionary, o: int, me: int, nfont: Font) -> void:
	# floating change: +15 / -12 rises and fades (static for the same 1.3 s under reduced motion), signed with a glyph
	if float(st["dt"]) > 0.0 and int(st["dn"]) != 0 and (o == me or absi(int(st["dn"])) >= 10):
		var k := 1.0 - float(st["dt"]) / 1.3
		var moving := TBKit.motion_ok()
		var fade := (1.0 - k) if moving else 1.0
		var dcol := _a(tk("pos_bar") if int(st["dn"]) > 0 else tk("neg_bar"), fade)
		var dtxt := "%s%s" % ["▲" if int(st["dn"]) > 0 else "▼", TBKit.fmt(absi(int(st["dn"])))]
		var fs := TBKit.fs(12.0)
		var dp := pos + Vector2(-nfont.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, -26.0 - (16.0 * k if moving else 8.0))
		draw_string_outline(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, _a(tk("table"), 0.85 * fade))
		draw_string(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dcol)

## keyboard cursor (A11Y-KBD-004 / CVD-007): a static double ring with corner brackets; never colour-only, never animated
func _draw_focus() -> void:
	var f := map.focus_province
	if f < 0 or f >= g.P: return
	var pt := map.project(g.world.lon[f], g.world.lat[f])
	if pt.z <= 0.0: return
	var c := Vector2(pt.x, pt.y)
	var r := 22.0 * mk()
	draw_arc(c, r, 0.0, TAU, 40, _a(tk("table"), 0.95), 6.0, true)
	draw_arc(c, r, 0.0, TAU, 40, tk("cream"), 3.0, true)
	var b := r + 7.0; var l := 9.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(b * sx, b * sy)
			draw_line(corner, corner - Vector2(l * sx, 0), tk("table"), 5.0, true); draw_line(corner, corner - Vector2(0, l * sy), tk("table"), 5.0, true)
			draw_line(corner, corner - Vector2(l * sx, 0), tk("cream"), 2.0, true); draw_line(corner, corner - Vector2(0, l * sy), tk("cream"), 2.0, true)

# ---------------------------------------------------------------- order arrows (4 px core + 2 px casing, double chevron for attacks, dashed preview)
func _order_path(from: int, to: int) -> int:
	var key := "%d>%d|%.4f|%.4f|%.3f|%d|%d,%d|%d,%d" % [from, to, map.lon0, map.lat0, map.zoom, map.mode, int(_push_v.x * 4.0), int(_push_v.y * 4.0), int(_push_sv.x * 4.0), int(_push_sv.y * 4.0)]
	if key == _path_key: return _path.size()
	_path_key = key
	var n := 14
	_path.resize(n)
	var ok := true
	if map.mode == 0:
		var a := _unit[from]; var b := _unit[to]
		var om := acos(clampf(a.dot(b), -1.0, 1.0))
		for i in n:
			var t := float(i) / float(n - 1)
			var v: Vector3 = a.lerp(b, t) if om < 0.001 else (a * sin((1.0 - t) * om) + b * sin(t * om)) / sin(om)
			var pr := _proj_vec(v)
			if pr.z < 0.05: ok = false
			_path[i] = Vector2(pr.x, pr.y)
	else:
		var pa := map.project(g.world.lon[from], g.world.lat[from]); var pb := map.project(g.world.lon[to], g.world.lat[to])
		for i in n: _path[i] = Vector2(pa.x, pa.y).lerp(Vector2(pb.x, pb.y), float(i) / float(n - 1))
		if absf(pa.x - pb.x) > map.size.x * 0.6: ok = false          # across the seam: skip
	if ok and _push_p == to:
		for i in n:
			var t2 := float(i) / float(n - 1)
			_path[i] += _push_v * (t2 * t2) + _push_sv * ((1.0 - t2) * (1.0 - t2))
	if not ok: _path.resize(0)
	return _path.size()

func _path_len(pts: PackedVector2Array, n: int) -> float:
	var l := 0.0
	for i in range(n - 1): l += pts[i].distance_to(pts[i + 1])
	return l

## point at arc length s along the polyline
func _pt_at(pts: PackedVector2Array, n: int, s: float) -> Vector2:
	var acc := 0.0
	for i in range(n - 1):
		var l := pts[i].distance_to(pts[i + 1])
		if acc + l >= s and l > 0.0001: return pts[i].lerp(pts[i + 1], (s - acc) / l)
		acc += l
	return pts[n - 1]

## the polyline between arc lengths s0 and s1 into _cut; returns the point count
func _clip(pts: PackedVector2Array, n: int, s0: float, s1: float) -> int:
	_cut.resize(n + 2)
	var k := 0
	var acc := 0.0
	for i in range(n - 1):
		var a := pts[i]; var b := pts[i + 1]
		var l := a.distance_to(b)
		if l < 0.001: continue
		var lo := maxf(s0, acc); var hi := minf(s1, acc + l)
		if hi > lo:
			if k == 0: _cut[0] = a.lerp(b, (lo - acc) / l); k = 1
			_cut[k] = a.lerp(b, (hi - acc) / l); k += 1
		acc += l
	return k

## where a marker's rim is along the arrow: half extent of the marker drawn (or a small allowance when none is)
func _rim(p: int, d: Vector2) -> float:
	if not _pl.has(p) or float(_pl[p]["t"]) < 0.5: return 6.0
	var st: Dictionary = _pl[p]
	return _ext_tier(int(st["zt"]), g.army[p], d, p == map.selected)

func _draw_order() -> void:
	_order_box = Rect2()
	if _order.is_empty(): return
	var of: int = _order["from"]; var ot: int = _order["to"]
	var n := _order_path(of, ot)
	if n < 2: return
	var phase := 0.0
	if bool(_order["dashed"]) and TBKit.motion_ok(): phase = fmod(Time.get_ticks_msec() / 1000.0 * 24.0, 14.0)
	var attack := bool(_order["attack"])
	var total := _path_len(_path, n)
	var d0 := (_path[1] - _path[0]).normalized()
	var d1 := (_path[n - 1] - _path[n - 2]).normalized()
	var ta := _rim(of, d0) + 2.0
	var tb := _rim(ot, -d1) + 3.0
	var head := 14.0 if attack else 12.0
	var avail := total - ta - tb
	if avail < head + 10.0:                                        # no room: keep the arrow, trim the ends less
		var f := clampf((total - head - 10.0) / maxf(1.0, ta + tb), 0.0, 1.0)
		ta *= f; tb *= f
	var s_tip := total - tb
	var s_base := maxf(ta, s_tip - head)
	var tip := _pt_at(_path, n, s_tip); var base := _pt_at(_path, n, s_base)
	var dir := (tip - base).normalized() if tip.distance_to(base) > 0.5 else d1
	var k := _clip(_path, n, ta, s_base)
	last_shaft = s_base - ta
	_draw_arrow_cut(k, tip, dir, attack, bool(_order["dashed"]), 1.0, phase)
	# bounds for the chip placement: the shaft, the head and the source marker
	var bb := Rect2(tip, Vector2.ZERO).expand(_path[0]).grow(26.0)
	for i in k: bb = bb.expand(_cut[i])
	_order_box = bb.grow(8.0)
	var lab: String = _order["label"]
	if lab != "":
		var mid := _pt_at(_path, n, (ta + s_base) * 0.5)
		var f: Font = TBKit.mono_b()
		var fs := TBKit.fs(12.0)
		var tw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := maxf(20.0, tw + 10.0); var ch := float(fs) + 6.0
		var nrm := Vector2(-dir.y, dir.x)
		if nrm.y > 0.0: nrm = -nrm                                # the chip sits on the side of the shaft with the fewer markers (upper first)
		var off := 7.0 + absf(nrm.x) * cw * 0.5 + absf(nrm.y) * ch * 0.5
		var r := Rect2(mid + nrm * off - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
		var r2 := Rect2(mid - nrm * off - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
		var bad1 := (4 if _blocked(r) else 0) + (1 if _hits_marker(r) else 0)
		var bad2 := (4 if _blocked(r2) else 0) + (1 if _hits_marker(r2) else 0)
		if bad2 < bad1: r = r2
		draw_rect(r.grow(2.0), _a(tk("table"), 0.85))
		draw_rect(r, tk("paper_0"))
		draw_string(f, r.position + Vector2(5.0, f.get_ascent(fs) + 3.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tk("table"))
		_order_box = _order_box.merge(r.grow(6.0))

## arrow body = _cut[0..k) (casing 2 px each side under a 4 px core), then the head at tip pointing along dir
func _draw_arrow_cut(k: int, tip: Vector2, d1: Vector2, attack: bool, dashed: bool, alpha: float, phase: float) -> void:
	var core := _a(tk("neg_bar") if attack else tk("brass_lt"), alpha)
	var casing := _a(tk("table"), 0.85 * alpha)
	var side := Vector2(-d1.y, d1.x)
	if not dashed:
		for i in range(1, k): draw_line(_cut[i - 1], _cut[i], casing, 8.0, true)
		for i in range(1, k): draw_line(_cut[i - 1], _cut[i], core, 4.0, true)
	else:
		var run := 0.0
		for i in range(1, k):
			var prev := _cut[i - 1]; var q := _cut[i]
			var seg_len: float = prev.distance_to(q)
			if seg_len < 0.5: continue
			var dir := (q - prev) / seg_len
			var s := 0.0
			while s < seg_len:
				var cyc := fmod(run + s + phase, 14.0)
				if cyc >= 8.0:
					s += 14.0 - cyc; continue
				var e := minf(seg_len, s + 8.0 - cyc)
				_seg[0] = prev + dir * s; _seg[1] = prev + dir * e
				draw_line(_seg[0], _seg[1], casing, 8.0, true)
				draw_line(_seg[0], _seg[1], core, 4.0, true)
				s = e
			run += seg_len
	# head (fixed size in px)
	if attack:
		for pass_i in 2:
			for kk in 2:
				var off := -7.0 * kk
				_chev[0] = tip + d1 * off - d1 * 7.0 + side * 6.0
				_chev[1] = tip + d1 * off
				_chev[2] = tip + d1 * off - d1 * 7.0 - side * 6.0
				draw_polyline(_chev, casing if pass_i == 0 else core, 8.0 if pass_i == 0 else 4.0, true)
	else:
		var base := tip - d1 * 12.0
		_tri[0] = tip + d1 * 2.0; _tri[1] = base + side * 6.5; _tri[2] = base - side * 6.5
		draw_colored_polygon(_tri, casing)
		draw_polyline(_tri, casing, 4.0, true)
		_tri[0] = tip; _tri[1] = base + side * 5.0; _tri[2] = base - side * 5.0
		draw_colored_polygon(_tri, core)

## polyline arrow along pts[0..n) for battle effects (no marker trimming)
func _draw_arrow(pts: PackedVector2Array, n: int, attack: bool, dashed: bool, alpha: float, phase: float) -> void:
	var span := pts[0].distance_to(pts[n - 1])
	var d1 := (pts[n - 1] - pts[n - 2]).normalized()
	var trim := clampf(span * 0.3, 8.0, 21.0)
	var head := 14.0 if attack else 12.0
	var total := _path_len(pts, n)
	var s_tip := total - trim
	var s_base := maxf(trim, s_tip - head)
	var k := _clip(pts, n, trim, s_base)
	_draw_arrow_cut(k, _pt_at(pts, n, s_tip), d1, attack, dashed, alpha, phase)

## battle arrows (same arrow language, solid, fading over 120 ms at the end) and impact rings
func _draw_fx() -> void:
	var now := Time.get_ticks_msec()
	var keep: Array = []
	var motion := TBKit.motion_ok()
	for f in _fx:
		var k: float = float(now - int(f["t0"])) / float(f["dur"])
		if k >= 1.0: continue
		keep.append(f)
		if k < 0.0: continue
		var pt_to := map.project(g.world.lon[f["to"]], g.world.lat[f["to"]])
		if pt_to.z <= 0.0: continue
		var col: Color = f["col"]
		var to2 := Vector2(pt_to.x, pt_to.y)
		if f["kind"] == "atk" or f["kind"] == "march":
			var pt_from := map.project(g.world.lon[f["from"]], g.world.lat[f["from"]])
			if pt_from.z <= 0.0: continue
			var from2 := Vector2(pt_from.x, pt_from.y)
			var e := minf(1.0, k * 1.8) if motion else 1.0
			e = 1.0 - pow(1.0 - e, 3.0)
			var fade := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
			if from2.distance_to(to2) > 30.0:
				_fx_pts[0] = from2; _fx_pts[1] = from2.lerp(to2, e)
				if _fx_pts[0].distance_to(_fx_pts[1]) > 30.0: _draw_arrow(_fx_pts, 2, f["kind"] == "atk", false, fade, 0.0)
		else:
			col.a = 1.0 - k
			var rk := k if motion else 0.5
			draw_arc(to2, 6.0 + rk * 28.0, 0.0, TAU, 28, col, 2.5 * (1.0 - rk * 0.6), true)
			if rk < 0.35:
				var c3 := col; c3.a = (0.35 - rk) / 0.35 * 0.6
				draw_circle(to2, 5.0 + rk * 20.0, c3)
	_fx = keep
