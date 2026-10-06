## Overlay drawn above the GPU map (art bible 5 and 6.3): zoom-disclosed army markers (dot / pennant / gonfalon) with
## affiliation outlines, general stars, capital rings, order arrows with casing, the Tab focus ring, nation and province names and
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

# ---------------------------------------------------------------- order arrow (set by TBOrderFlow)
var _order := {}             # {from, to, attack, dashed, label}
var _path := PackedVector2Array()
var _path_key := ""
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _chev := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _seg := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _fx_pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func set_order(from: int, to: int, attack: bool, dashed: bool, label: String = "") -> void:
	_order = {"from": from, "to": to, "attack": attack, "dashed": dashed, "label": label}
	_path_key = ""
	queue_redraw()

func clear_order() -> void:
	if _order.is_empty(): return
	_order = {}
	queue_redraw()

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
	queue_redraw()

func add_fx(kind: String, from: int, to: int, col: Color, delay_ms: int = 0) -> void:
	_fx.append({"kind": kind, "from": from, "to": to, "col": col, "t0": Time.get_ticks_msec() + delay_ms, "dur": 700 if kind == "atk" else 900})
	queue_redraw()

static func tk(name: String) -> Color: return TBTokens.c(name)
static func _a(c: Color, al: float) -> Color:
	c.a *= al
	return c

var _hex := {}
func _nat_col(o: int) -> Color:
	var v: int = g.color[o]
	if not _hex.has(v): _hex[v] = Color.hex((v << 8) | 0xFF)
	return _hex[v]

var _core_sig := -1
var _core_v := PackedVector3Array()
var _core_n := PackedInt32Array()

## the label anchor of each nation: the centroid of its main body (provinces within ~30 degrees of the province nearest the overall
## centroid), so overseas colonies do not drag the name into the ocean. Rebuilt only when ownership changed.
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

## nation names at their centroid (Cinzel 700, cream, 2 px table halo); bigger nations get bigger text; overlapping names are skipped
func _draw_nation_names() -> void:
	if map.zoom > (4.0 if map.mode == 0 else 5.5): return
	if _tracked == null: _tracked = TBKit.tracked(TBKit.display_hi(), 2)
	var font := _tracked
	var N1 := g.N1
	_rebuild_cores()
	var sx := _core_v; var cnt := _core_n
	var order: Array = []
	for n in range(1, N1):
		if cnt[n] >= 3 and g.alive[n] != 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a, b): return cnt[a] > cnt[b])
	var placed: Array = []
	var shown := 0
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var halo := tk("table"); var cream := tk("cream"); var brass := tk("brass_lt")
	for n in order:
		if shown >= 70: break
		var v: Vector3 = sx[n]
		if v == Vector3.ZERO: continue
		var pos: Vector2
		var depth := 1.0
		if map.mode == 0:
			var x := v.x * cl - v.z * sl
			var z0 := v.x * sl + v.z * cl
			var y := v.y * c0 - z0 * s0
			depth = v.y * s0 + z0 * c0
			if depth < 0.25: continue
			pos = Vector2(cx + R * x, cy - R * y)
		else:
			var lon := atan2(v.x, v.z); var lat := asin(clampf(v.y, -1.0, 1.0))
			var pt := map.project(rad_to_deg(lon), rad_to_deg(lat))
			pos = Vector2(pt.x, pt.y)
		if pos.x < 0 or pos.y < 0 or pos.x > map.size.x or pos.y > map.size.y: continue
		var fs := int(clampf(8.0 + sqrt(float(cnt[n])) * 1.4 * minf(map.zoom, 2.2), 12.0, 28.0))
		var txt: String = g.dname(n)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rect := Rect2(pos - tw * 0.5, tw).grow(3.0)
		var clash := _blocked(rect)
		for r in placed:
			if clash: break
			if r.intersects(rect): clash = true
		if clash: continue
		placed.append(rect); shown += 1
		var a := clampf(depth * 1.6, 0.5, 0.97)
		for fr in _frame_rects:                      # standards sit on top of the name: soften it where they cross
			if (fr as Rect2).intersects(rect): a *= 0.45; break
		var mine: bool = n == g.human_id
		draw_string_outline(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, _a(halo, a * 0.85))
		draw_string(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _a(brass if mine else cream, a))

## province names when zoomed in far enough to read them (Alegreya 500 12, cream, 2 px halo; no overlaps, capitals in Alegreya 700)
func _draw_province_names() -> void:
	if map.zoom < (4.0 if map.mode == 0 else 5.5): return
	var f: Font = TBKit.body()
	var fb: Font = TBKit.body_b()
	var placed: Array = _frame_rects.duplicate()     # markers claim their space first
	var shown := 0
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var halo := _a(tk("table"), 0.85); var cream := _a(tk("cream"), 0.95)
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
		var tw := ff.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var rect := Rect2(pos + Vector2(-tw.x * 0.5, 8), tw).grow(2.0)
		var clash := _blocked(rect)
		for r in placed:
			if clash: break
			if r.intersects(rect): clash = true
		if clash: continue
		placed.append(rect); shown += 1
		draw_string_outline(ff, rect.position + Vector2(2, tw.y * 0.8 + 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, halo)
		draw_string(ff, rect.position + Vector2(2, tw.y * 0.8 + 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cream)

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
	var u := _unit[p]
	# rotate: first about y by -lon0, then about x by lat0
	var x := u.x * cl - u.z * sl
	var z0 := u.x * sl + u.z * cl
	var y := u.y * c0 - z0 * s0
	var z := u.y * s0 + z0 * c0
	return Vector3(cx + R * x, cy - R * y, z)

# ---------------------------------------------------------------- army markers (stateful: they fade, pop and count)
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
		st = {"a": 0.0, "t": 0.0, "shown": float(g.army[p]), "last": g.army[p], "pop": 0.0, "dn": 0, "dt": 0.0, "x": 0.0, "y": 0.0, "tier": _tier(g.army[p]), "limb": 1.0, "extra": 0, "zt": 2}
		_pl[p] = st
	return st

## advance fades, count roll-ups and pops; ask for a redraw while anything is moving
func _process(delta: float) -> void:
	var busy := not _fx.is_empty()
	if not _order.is_empty() and bool(_order["dashed"]) and TBMapView.animate: busy = true       # marching dashes
	if g != null:
		var dead: Array = []
		for p in _pl:
			var st: Dictionary = _pl[p]
			var a: int = g.army[p]
			if a != st["last"]:
				var d: int = a - int(st["last"])
				if st["a"] > 0.2:                      # only visible markers announce changes
					st["pop"] = 1.0
					st["dn"] = int(st["dn"]) + d if float(st["dt"]) > 0.0 else d
					st["dt"] = 1.3
				st["last"] = a
				st["tier"] = _tier(a)
			if not TBMapView.animate:
				if st["a"] != st["t"]: busy = true
				st["a"] = st["t"]; st["shown"] = float(a)
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
			ss["a"] = ss["t"] if not TBMapView.animate else move_toward(ss["a"], ss["t"], delta * 6.0)
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

func _draw() -> void:
	if map == null or g == null or hidden_while_dragging: return
	_refresh_keepout()
	if g.human_id == 0:                 # nation-pick screen: names only
		_draw_nation_names()
		return
	var me := g.human_id
	var psz := prov_px()
	var ztier := 0 if psz < 14.0 else (1 if psz < 40.0 else 2)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var sel := map.selected; var hov := map.hover
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
				1: want = o == me or war or rel == 3 or p == sel or p == hov or a >= 20
				_: want = true
		var ring := cap and (o == me or ztier >= 1 or p == sel)
		if not want and not ring: continue
		var pr := _screen(p, c0, s0, sl, cl, R, cx, cy)
		var limb := 1.0
		if map.mode == 0:
			if pr.z < 0.2: continue
			limb = smoothstep(0.2, 0.55, pr.z)                         # nothing near the horizon
		elif pr.x < -24 or pr.y < -24 or pr.x > map.size.x + 24 or pr.y > map.size.y + 24: continue
		var shown_before := _pl.has(p) and float(_pl[p]["t"]) > 0.5
		var pri := 0 if (o == me or p == sel) else (1 if war else (2 if cap else 3))
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
		var gw := _gon_w(nfont, maxi(a, int(st["shown"])))
		var prect: Rect2
		match ztier:
			0: prect = Rect2(pos.x - 6.0, pos.y - 6.0, 12.0, 12.0)
			1: prect = Rect2(pos.x - 16.0, pos.y - 12.0, 32.0, 24.0)
			_: prect = Rect2(pos.x - gw * 0.5 - 4.0, pos.y - (28.0 if g.gen[p] != 0 else 19.0), gw + 8.0, 38.0 if g.gen[p] == 0 else 47.0)
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
	# ---- draw: fading markers (underneath), then the chosen, own realm on top, then the order arrow (above, so a short arrow is never hidden)
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
var _gon_cache := {}           # body width -> {poly, line, grown}
var _star_poly := PackedVector2Array()
var _star_line := PackedVector2Array()
var _penn_poly := PackedVector2Array([Vector2(-10, -7), Vector2(10, -7), Vector2(10, 7), Vector2(0, 3), Vector2(-10, 7)])
var _penn_line := PackedVector2Array([Vector2(-10, -7), Vector2(10, -7), Vector2(10, 7), Vector2(0, 3), Vector2(-10, 7), Vector2(-10, -7)])
var _diamond := PackedVector2Array([Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])
var _diamond_line := PackedVector2Array([Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0), Vector2(0, -6)])

func _gon_w(f: Font, n: int) -> float:
	return maxf(32.0, f.get_string_size(TBKit.fmt(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 10.0)

func _gon(w: float) -> Dictionary:
	var k := int(w)
	if _gon_cache.has(k): return _gon_cache[k]
	var h := w * 0.5
	var poly := PackedVector2Array([Vector2(-h, -11), Vector2(h, -11), Vector2(h, 15), Vector2(0, 9), Vector2(-h, 15)])
	var line := poly.duplicate(); line.append(poly[0])
	var hg := h + 3.0
	var grown := PackedVector2Array([Vector2(-hg, -14), Vector2(hg, -14), Vector2(hg, 18), Vector2(0, 11.0), Vector2(-hg, 18), Vector2(-hg, -14)])
	var ring := PackedVector2Array([Vector2(-h - 3, -14), Vector2(h + 3, -14), Vector2(h + 3, 18), Vector2(0, 12), Vector2(-h - 3, 18), Vector2(-h - 3, -14)])
	var d := {"poly": poly, "line": line, "grown": grown, "ring": ring}
	_gon_cache[k] = d
	return d

func _ensure_star() -> void:
	if not _star_poly.is_empty(): return
	for i in 10: _star_poly.append(Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * 4.5 * (1.0 if i % 2 == 0 else 0.42))
	_star_line = _star_poly.duplicate(); _star_line.append(_star_poly[0])

## capital: a 10 px ring with a filled 6 px square (a star always means "general")
func _capital_mark(pos: Vector2, al: float, mine: bool) -> void:
	var casing := _a(tk("ink_0"), 0.9 * al)
	var c := _a(tk("brass_lt") if mine else tk("cream"), al)
	draw_circle(pos, 7.0, casing)
	draw_arc(pos, 5.0, 0.0, TAU, 20, c, 1.5, true)
	draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), c)

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
	var sc := 0.6 + 0.4 * (1.0 + 1.70158 * pow(ease_in - 1.0, 3.0) + 2.70158 * pow(ease_in - 1.0, 2.0))   # easeOutBack on appear
	sc *= 1.0 + 0.26 * float(st["pop"]) * float(st["pop"])
	if p == map.hover and not hot: sc *= 1.1
	var nat := _nat_col(o)
	var ink := tk("ink_0"); var paper := tk("paper_0")
	var lift := -4.0 if (hot and ztier == 2) else 0.0
	if ztier == 0:
		var r := 4.0 * sc
		if war:
			draw_set_transform(pos, 0.0, Vector2(sc, sc))
			draw_colored_polygon(_diamond, _a(nat, al)); draw_polyline(_diamond_line, _a(tk("neg_bar"), al), 2.0 / sc, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(pos, r + (2.0 if own else 1.0), _a(tk("brass_lt") if own else ink, al))
			draw_circle(pos, r + (0.8 if own else 0.0), _a(ink, al) if own else _a(nat, al))
			draw_circle(pos, r - (0.4 if own else 0.0), _a(nat, al))
		if hot: draw_arc(pos, r + 5.0, 0.0, TAU, 24, _a(tk("cream"), al), 2.0, true)
		_floater(p, pos, st, o, me, nfont)
		return
	if ztier == 1:
		var k := 1.0 if army < 20 else (1.2 if army < 100 else 1.4)
		var s2 := sc * k
		draw_set_transform(pos + Vector2(0, lift), 0.0, Vector2(s2, s2))
		draw_colored_polygon(_penn_poly, _a(paper, al))
		draw_rect(Rect2(-10, -7, 20, 4), _a(nat, al))
		_outline(_penn_line, null, own, war, ally, hot, al, s2, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_pip(pos + Vector2(10.0 * s2, -8.0 * s2), war, ally, al, 0.8)
		_floater(p, pos, st, o, me, nfont)
		return
	# ---- near: the gonfalon
	var txt := TBKit.fmt(int(round(st["shown"])))
	var w := _gon_w(nfont, maxi(army, int(st["shown"])))
	var d := _gon(w)
	if hot:
		draw_set_transform(pos + Vector2(0, 3.0 + lift), 0.0, Vector2(sc, sc))
		draw_colored_polygon(d["poly"], _a(Color.BLACK, 0.26 * al))                          # the one hard shadow (elevation 1)
	draw_set_transform(pos + Vector2(0, lift), 0.0, Vector2(sc, sc))
	var h := w * 0.5
	draw_rect(Rect2(-h - 2.0, -15.0, w + 4.0, 4.0), _a(ink, al))                             # crossbar
	draw_colored_polygon(d["poly"], _a(paper, al))                                           # laid-paper body
	draw_rect(Rect2(-h, -11.0, w, 6.0), _a(nat, al))                                         # nation band
	_outline(d["line"], d, own, war, ally, hot, al, sc, 1.0)
	var fnt: Font = nfont
	var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(fnt, Vector2(-tw * 0.5, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _a(ink, al))
	var extra := int(st["extra"])
	if extra > 0:                                                                            # "+n" tab: stacked armies collapse here
		var et := "+%d" % extra
		var ew := TBKit.mono_b().get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6.0
		draw_rect(Rect2(h + 1.0, -9.0, ew, 14.0), _a(ink, al))
		draw_string(TBKit.mono_b(), Vector2(h + 4.0, 2.0), et, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _a(tk("cream"), al))
	if g.gen[p] != 0:                                                                        # general: 1-5 brass stars above the crossbar
		_ensure_star()
		var n := mini(5, TBGenerals.skill(g, p))
		for i in n:
			var sx := (i - (n - 1) * 0.5) * 9.0
			draw_set_transform(pos + Vector2(sx * sc, (-21.0 + lift) * sc), 0.0, Vector2(sc, sc))
			draw_colored_polygon(_star_poly, _a(tk("brass_lt"), al))
			draw_polyline(_star_line, _a(ink, al), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pip(pos + Vector2((h + 1.0) * sc, (-13.0 + lift) * sc), war, ally, al, 1.0)
	if g.capital[p] != 0: _capital_mark(pos + Vector2((-h - 7.0) * sc, (-12.0 + lift) * sc), al, own)
	_floater(p, pos, st, o, me, nfont)

## affiliation outline in the CURRENT transform. own: 2 px brass + 1 px ink outer; ally: double 1 px info line; war: 2 px neg + ink outer; foreign: 1 px ink
func _outline(line: PackedVector2Array, d: Variant, own: bool, war: bool, ally: bool, hot: bool, al: float, sc: float, wmul: float) -> void:
	var u := 1.0 / maxf(0.5, sc)
	if own or war:
		draw_polyline(line, _a(tk("ink_0"), al), 4.0 * u, true)
		draw_polyline(line, _a(tk("brass_lt") if own else tk("neg_bar"), al), 2.0 * u, true)
	elif ally:
		draw_polyline(line, _a(tk("info_bar"), al), 1.0 * u, true)
		if d != null: draw_polyline((d as Dictionary)["grown"], _a(tk("info_bar"), al), 1.0 * u, true)
		else: draw_polyline(line, _a(tk("info_bar"), al), 3.0 * u, true)
	else:
		draw_polyline(line, _a(tk("ink_0"), al), 1.0 * u, true)
	if hot:
		var ring: PackedVector2Array = (d as Dictionary)["ring"] if d != null else line
		draw_polyline(ring, _a(tk("ink_0"), al), 5.0 * u, true)
		draw_polyline(ring, _a(tk("cream"), al), 3.0 * u, true)

## 6 px affiliation pip at a corner: crossed swords for war, linked rings for allies
func _pip(c: Vector2, war: bool, ally: bool, al: float, k: float) -> void:
	if not (war or ally): return
	draw_circle(c, 5.5 * k, _a(tk("bar_0"), 0.95 * al))
	TBCmdCard.glyph(self, "swords" if war else "link", c, 8.0 * k, _a(tk("neg_bar") if war else tk("info_bar"), al), 1.2)

func _floater(p: int, pos: Vector2, st: Dictionary, o: int, me: int, nfont: Font) -> void:
	# floating change: +15 / -12 rises and fades
	if float(st["dt"]) > 0.0 and int(st["dn"]) != 0 and (o == me or absi(int(st["dn"])) >= 10):
		var k := 1.0 - float(st["dt"]) / 1.3
		var dcol := _a(tk("pos_bar") if int(st["dn"]) > 0 else tk("neg_bar"), 1.0 - k)
		var dtxt := "%+d" % int(st["dn"])
		var dp := pos + Vector2(-nfont.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, -26.0 - 16.0 * k)
		draw_string_outline(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, _a(tk("table"), 0.85 * (1.0 - k)))
		draw_string(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dcol)

func _draw_focus() -> void:
	var f := map.focus_province
	if f < 0 or f >= g.P: return
	var pt := map.project(g.world.lon[f], g.world.lat[f])
	if pt.z <= 0.0: return
	var c := Vector2(pt.x, pt.y)
	draw_arc(c, 24.0, 0.0, TAU, 32, _a(tk("bar_0"), 0.9), 5.0, true)
	draw_arc(c, 24.0, 0.0, TAU, 32, tk("cream"), 2.0, true)

# ---------------------------------------------------------------- order arrows (4 px core + 2 px casing, double chevron for attacks, dashed preview)
func _order_path(from: int, to: int) -> int:
	var key := "%d>%d|%.4f|%.4f|%.3f|%d" % [from, to, map.lon0, map.lat0, map.zoom, map.mode]
	if key == _path_key: return _path.size()
	_path_key = key
	var n := 14
	_path.resize(n)
	var ok := true
	if map.mode == 0:
		var a := _unit[from]; var b := _unit[to]
		var om := acos(clampf(a.dot(b), -1.0, 1.0))
		var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
		var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
		for i in n:
			var t := float(i) / float(n - 1)
			var v: Vector3 = a.lerp(b, t) if om < 0.001 else (a * sin((1.0 - t) * om) + b * sin(t * om)) / sin(om)
			var x := v.x * cl - v.z * sl
			var z0 := v.x * sl + v.z * cl
			var y := v.y * c0 - z0 * s0
			var z := v.y * s0 + z0 * c0
			if z < 0.05: ok = false
			_path[i] = Vector2(cx + R * x, cy - R * y)
	else:
		var pa := map.project(g.world.lon[from], g.world.lat[from]); var pb := map.project(g.world.lon[to], g.world.lat[to])
		for i in n: _path[i] = Vector2(pa.x, pa.y).lerp(Vector2(pb.x, pb.y), float(i) / float(n - 1))
		if absf(pa.x - pb.x) > map.size.x * 0.6: ok = false          # across the seam: skip
	if not ok: _path.resize(0)
	return _path.size()

func _draw_order() -> void:
	if _order.is_empty(): return
	var n := _order_path(int(_order["from"]), int(_order["to"]))
	if n < 2: return
	var phase := 0.0
	if bool(_order["dashed"]) and TBMapView.animate: phase = fmod(Time.get_ticks_msec() / 1000.0 * 24.0, 14.0)
	_draw_arrow(_path, n, bool(_order["attack"]), bool(_order["dashed"]), 1.0, phase)
	var lab: String = _order["label"]
	if lab != "":
		var mid := _path[n / 2]
		var f: Font = TBKit.mono_b()
		var tw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var r := Rect2(mid - Vector2(tw * 0.5 + 5.0, 30.0), Vector2(tw + 10.0, 16.0))
		draw_rect(r.grow(1.0), _a(tk("table"), 0.85))
		draw_rect(r, tk("paper_0"))
		draw_string(f, r.position + Vector2(5.0, 12.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tk("ink_0"))

## polyline arrow along pts[0..n): casing under a 4 px core, then a filled triangle (move) or a double chevron (attack) head
func _draw_arrow(pts: PackedVector2Array, n: int, attack: bool, dashed: bool, alpha: float, phase: float) -> void:
	var core := _a(tk("neg_bar") if attack else tk("brass_lt"), alpha)
	var casing := _a(tk("table"), 0.85 * alpha)
	var d0 := (pts[1] - pts[0]).normalized()
	var d1 := (pts[n - 1] - pts[n - 2]).normalized()
	var span := pts[0].distance_to(pts[n - 1])
	var trim := clampf(span * 0.3, 8.0, 21.0)                   # leave the markers at both ends uncovered
	var start := pts[0] + d0 * trim
	var tip := pts[n - 1] - d1 * trim
	var hl := 14.0 if attack else 12.0
	var base := tip - d1 * hl
	var side := Vector2(-d1.y, d1.x)
	# body: the path with trimmed ends. Solid arrows stroke the casing for the whole path first, then the core (no seams at joints)
	if not dashed:
		_stroke(pts, n, start, base, casing, 8.0)
		_stroke(pts, n, start, base, core, 4.0)
	else:
		var prev := start
		var run := 0.0
		for i in range(1, n):
			var q := pts[i] if i < n - 1 else base
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
			prev = q
	# head
	if attack:
		for k in 2:
			var off := -7.0 * k
			_chev[0] = tip + d1 * off - d1 * 7.0 + side * 6.0
			_chev[1] = tip + d1 * off
			_chev[2] = tip + d1 * off - d1 * 7.0 - side * 6.0
			draw_polyline(_chev, casing, 8.0, true)
		for k in 2:
			var off2 := -7.0 * k
			_chev[0] = tip + d1 * off2 - d1 * 7.0 + side * 6.0
			_chev[1] = tip + d1 * off2
			_chev[2] = tip + d1 * off2 - d1 * 7.0 - side * 6.0
			draw_polyline(_chev, core, 4.0, true)
	else:
		_tri[0] = tip + d1 * 2.0; _tri[1] = base + side * 6.5; _tri[2] = base - side * 6.5
		draw_colored_polygon(_tri, casing)
		draw_polyline(_tri, casing, 4.0, true)
		_tri[0] = tip; _tri[1] = base + side * 5.0; _tri[2] = base - side * 5.0
		draw_colored_polygon(_tri, core)

func _stroke(pts: PackedVector2Array, n: int, start: Vector2, base: Vector2, col: Color, w: float) -> void:
	var prev := start
	for i in range(1, n):
		var q := pts[i] if i < n - 1 else base
		if prev.distance_to(q) >= 0.5: draw_line(prev, q, col, w, true)
		prev = q

## battle arrows (same arrow language, solid, fading over 120 ms at the end) and impact rings
func _draw_fx() -> void:
	var now := Time.get_ticks_msec()
	var keep: Array = []
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
			var e := minf(1.0, k * 1.8)
			e = 1.0 - pow(1.0 - e, 3.0)
			var fade := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
			if from2.distance_to(to2) > 30.0:
				_fx_pts[0] = from2; _fx_pts[1] = from2.lerp(to2, e)
				if _fx_pts[0].distance_to(_fx_pts[1]) > 30.0: _draw_arrow(_fx_pts, 2, f["kind"] == "atk", false, fade, 0.0)
		else:
			col.a = 1.0 - k
			draw_arc(to2, 6.0 + k * 28.0, 0.0, TAU, 28, col, 2.5 * (1.0 - k * 0.6), true)
			if k < 0.35:
				var c3 := col; c3.a = (0.35 - k) / 0.35 * 0.6
				draw_circle(to2, 5.0 + k * 20.0, c3)
	_fx = keep
