## Overlay drawn above the GPU map: army chips, capital stars, battle effects. Redraws only when the view
## or game state changed; hidden while dragging (cheap frames). Uses precomputed unit vectors (no per-province trig).
class_name TBMapLabels
extends Control

var map: TBMapView
var g: TBGame
var max_labels := 90
var _unit := PackedVector3Array()
var _fx: Array = []          # {kind, from, to, col, t0, dur}
var hidden_while_dragging := false
var _tracked: Font

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
	queue_redraw()

func add_fx(kind: String, from: int, to: int, col: Color, delay_ms: int = 0) -> void:
	_fx.append({"kind": kind, "from": from, "to": to, "col": col, "t0": Time.get_ticks_msec() + delay_ms, "dur": 700 if kind == "atk" else 900})
	queue_redraw()

## nation names at their centroid; bigger nations get bigger text; overlapping names are skipped
func _draw_nation_names(font: Font) -> void:
	if map.zoom > (4.0 if map.mode == 0 else 5.5): return
	if _tracked == null: _tracked = TBKit.tracked(font, 2)
	font = _tracked
	var N1 := g.N1
	var sx := PackedFloat32Array(); sx.resize(N1)
	var sy := PackedFloat32Array(); sy.resize(N1)
	var sz := PackedFloat32Array(); sz.resize(N1)
	var cnt := PackedInt32Array(); cnt.resize(N1)
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		var u := _unit[p]
		sx[o] += u.x; sy[o] += u.y; sz[o] += u.z; cnt[o] += 1
	var order: Array = []
	for n in range(1, N1):
		if cnt[n] >= 3 and g.alive[n] != 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a, b): return cnt[a] > cnt[b])
	var placed: Array = []
	var shown := 0
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	for n in order:
		if shown >= 70: break
		var v := Vector3(sx[n], sy[n], sz[n])
		var len := v.length()
		if len < 0.0001: continue
		v /= len
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
		var fs := int(clampf(8.0 + sqrt(float(cnt[n])) * 1.4 * minf(map.zoom, 2.2), 10.0, 24.0))
		var txt: String = g.dname(n)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rect := Rect2(pos - tw * 0.5, tw).grow(3.0)
		var clash := false
		for r in placed:
			if r.intersects(rect): clash = true; break
		if clash: continue
		placed.append(rect); shown += 1
		var a := clampf(depth * 1.6, 0.35, 0.95)
		var mine: bool = n == g.human_id
		draw_string_outline(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.03, 0.07, a * 0.85))
		draw_string(font, pos + Vector2(-tw.x * 0.5, tw.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.8, 0.4, a) if mine else Color(0.94, 0.9, 0.82, a * 0.92))

## province names when zoomed in far enough to read them (engraved small text, no overlaps)
func _draw_province_names() -> void:
	if map.zoom < (4.0 if map.mode == 0 else 5.5): return
	var f: Font = TBKit.display_lo()
	var placed: Array = _frame_rects.duplicate()     # plaques claim their space first
	var shown := 0
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
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
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var rect := Rect2(pos + Vector2(-tw.x * 0.5, 6), tw).grow(2.0)
		var clash := false
		for r in placed:
			if r.intersects(rect): clash = true; break
		if clash: continue
		placed.append(rect); shown += 1
		draw_string_outline(f, rect.position + Vector2(2, tw.y * 0.8 + 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.02, 0.03, 0.07, 0.8))
		draw_string(f, rect.position + Vector2(2, tw.y * 0.8 + 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.86, 0.76, 0.85))

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

func _star(pos: Vector2, al: float = 1.0) -> void:
	var pts := PackedVector2Array()
	var k := 0.7 + 0.3 * al
	for i in 10: pts.append(pos + Vector2(sin(i * PI / 5.0), -cos(i * PI / 5.0)) * (7.0 if i % 2 == 0 else 3.2) * k)
	draw_colored_polygon(pts, Color(0.953, 0.773, 0.322, al))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.03, 0.05, 0.1, al), 1.2, true)

## screen position + visibility for province p given the map camera
func _project(p: int, c0: float, s0: float, sl: float, cl: float, R: float, cx: float, cy: float) -> Vector3:
	var u := _unit[p]
	# rotate: first about y by -lon0, then about x by lat0
	var x := u.x * cl - u.z * sl
	var z0 := u.x * sl + u.z * cl
	var y := u.y * c0 - z0 * s0
	var z := u.y * s0 + z0 * c0
	return Vector3(cx + R * x, cy - R * y, z)

# ---------------------------------------------------------------- army plaques (stateful: they fade, pop and count)
var _pl := {}                  # province -> {a: alpha, t: target alpha, shown: displayed army, last: army last seen, pop: 0..1, dn: pending delta, dt: delta timer, x, y, tier}
var _frame_rects: Array = []
var _stars := {}               # province -> {a, t}
const TIERS := [25, 60, 140]

func _tier(a: int) -> int:
	var t := 0
	for lim in TIERS:
		if a >= lim: t += 1
	return t

func _state(p: int) -> Dictionary:
	var st: Dictionary = _pl.get(p, {})
	if st.is_empty():
		st = {"a": 0.0, "t": 0.0, "shown": float(g.army[p]), "last": g.army[p], "pop": 0.0, "dn": 0, "dt": 0.0, "x": 0.0, "y": 0.0, "tier": _tier(g.army[p]), "limb": 1.0}
		_pl[p] = st
	return st

## advance fades, count roll-ups and pops; ask for a redraw while anything is moving
func _process(delta: float) -> void:
	var busy := not _fx.is_empty()
	if g != null:
		var dead: Array = []
		for p in _pl:
			var st: Dictionary = _pl[p]
			var a: int = g.army[p]
			if a != st["last"]:
				var d: int = a - int(st["last"])
				if st["a"] > 0.2:                      # only visible plaques announce changes
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

func _draw() -> void:
	if map == null or g == null or hidden_while_dragging: return
	var font: Font = TBKit.display()
	var nfont: Font = TBKit.mono_b()
	if g.human_id == 0:                 # nation-pick screen: names only
		_draw_nation_names(font)
		return
	var me := g.human_id
	# ---- progressive disclosure: far away only what matters, everything once you are close
	var z := map.zoom / (1.0 if map.mode == 0 else 1.6)          # flat maps are wider at the same zoom number
	var lvl := 0 if z < 1.6 else (1 if z < 3.0 else 2)
	var R := map.radius_px(); var cx := map.size.x * 0.5; var cy := map.size.y * 0.5
	var c0 := cos(map.lat0); var s0 := sin(map.lat0); var cl := cos(map.lon0); var sl := sin(map.lon0)
	var key := {}                                                  # provinces that deserve a plaque at lvl 1
	if lvl == 1 and g.human_id != 0:
		var own: Array = []                                        # (not g.owned(): that may rebuild shared caches while a turn runs on a worker thread)
		for p in g.P:
			if g.owner[p] == me: own.append(p)
		var big: Array = []
		for p in own: if g.army[p] >= 20: big.append(p)
		big.sort_custom(func(a, b): return g.army[a] > g.army[b])
		for k in mini(6, big.size()): key[big[k]] = true            # my largest stacks
		for p in own:                                              # the fronts of my wars
			for e in range(g.nb_off[p], g.nb_off[p + 1]):
				var q: int = g.nb[e]
				var eo: int = g.owner[q]
				if eo != 0 and eo != me and g.get_rel(me, eo) == 1:
					if g.army[p] >= 12: key[p] = true
					if g.army[q] >= 20: key[q] = true
	if map.selected >= 0: key[map.selected] = true
	if map.hover >= 0 and lvl >= 1: key[map.hover] = true
	# ---- candidates: (province, x, y, priority, limb factor, army)
	var vis: Array = []
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		var cap := g.capital[p] != 0
		var star := cap and (o == me or z >= 2.0)
		var want := lvl == 2 or key.has(p)
		if not want and not star: continue
		var pr := _screen(p, c0, s0, sl, cl, R, cx, cy)
		var limb := 1.0
		if map.mode == 0:
			if pr.z < 0.2: continue
			limb = smoothstep(0.2, 0.55, pr.z)                     # nothing near the horizon
		elif pr.x < -24 or pr.y < -24 or pr.x > map.size.x + 24 or pr.y > map.size.y + 24: continue
		var shown_before := _pl.has(p) and float(_pl[p]["t"]) > 0.5
		var pri := 0 if (o == me or key.has(p)) else (1 if star else 2)
		vis.append([p, pr.x, pr.y, pri * 4 + (0 if shown_before else 1), limb, g.army[p], want])
	vis.sort_custom(func(a, b): return a[3] < b[3] if a[3] != b[3] else (a[5] > b[5] if a[5] != b[5] else a[0] < b[0]))
	# ---- choose without overlap; everything else fades out
	for p in _pl: _pl[p]["t"] = 0.0
	for p in _stars: _stars[p]["t"] = 0.0
	var grid := {}
	_frame_rects.clear()
	var drawn := 0
	var chosen: Array = []
	var chosen_set := {}
	var zs := 0.74 if lvl == 1 else clampf(0.78 + 0.07 * z, 0.84, 1.1)
	var cap_n := mini(max_labels, 14 if lvl == 1 else max_labels)
	for v in vis:
		if drawn >= cap_n: break
		var p: int = v[0]
		var pos := Vector2(v[1], v[2])
		if not v[6]:
			if _claim(grid, Rect2(pos - Vector2(9, 9), Vector2(18, 18))):
				if not _stars.has(p): _stars[p] = {"a": 0.0, "t": 1.0}
				_stars[p]["t"] = 1.0; _stars[p]["x"] = pos.x; _stars[p]["y"] = pos.y; _stars[p]["limb"] = v[4]
				drawn += 1
			continue
		var a: int = g.army[p]
		if a <= 0: continue
		var st := _state(p)
		var tier: int = st["tier"]
		var fs := 9 + tier
		var tw := nfont.get_string_size("%d" % maxi(a, int(st["shown"])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 + tier
		var prect := Rect2(pos.x - tw * 0.5 - 1.0, pos.y - 11.0, tw + 2.0, 24.0)
		if not _claim(grid, prect): continue
		_frame_rects.append(prect)
		st["t"] = 1.0; st["x"] = pos.x; st["y"] = pos.y; st["limb"] = v[4]
		chosen.append(p); chosen_set[p] = true
		drawn += 1
	# ---- draw: fading ones first (underneath), then the chosen, own realm on top
	var order: Array = []
	for p in _pl:
		if float(_pl[p]["a"]) > 0.01 and not chosen_set.has(p): order.append(p)
	for i in range(chosen.size() - 1, -1, -1): order.append(chosen[i])
	for p in _stars:
		var ss: Dictionary = _stars[p]
		if float(ss["a"]) > 0.01: _star(Vector2(ss["x"], ss["y"]), float(ss["a"]) * float(ss["limb"]))
	for p in order:
		var st: Dictionary = _pl[p]
		var al: float = float(st["a"]) * float(st["limb"])
		if al <= 0.01: continue
		var pos := Vector2(st["x"], st["y"])
		if not chosen_set.has(p):               # a fading plaque keeps following its province
			var pr2 := _screen(p, c0, s0, sl, cl, R, cx, cy)
			if map.mode == 0 and pr2.z < 0.04: continue
			pos = Vector2(pr2.x, pr2.y)
		_draw_plaque(p, pos, st, al, nfont, me, zs)
	_draw_nation_names(font)
	_draw_province_names()
	_draw_fx()

## one heraldic plaque: tier decides size and pips, owner's colour along the top, rim by relation
func _draw_plaque(p: int, pos: Vector2, st: Dictionary, al: float, nfont: Font, me: int, zs: float) -> void:
	var o := g.owner[p]
	var tier: int = st["tier"]
	var fs := 9 + tier
	var txt := TBKit.fmt(int(round(st["shown"])))
	if o != me and g.get_rel(me, o) != 1 and p != map.selected and p != map.hover: al *= 0.62       # quiet foreign stacks recede
	var ease_in: float = float(st["a"])
	var sc := zs * (0.6 + 0.4 * (1.0 + 1.70158 * pow(ease_in - 1.0, 3.0) + 2.70158 * pow(ease_in - 1.0, 2.0)))   # easeOutBack on appear
	sc *= 1.0 + 0.26 * float(st["pop"]) * float(st["pop"])
	if p == map.selected: sc *= 1.18
	elif p == map.hover: sc *= 1.1
	var tw := nfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 + tier
	var h := 15.0 + tier
	var rim := TBKit.GOLD2 if o == me else (TBKit.RED if g.get_rel(me, o) == 1 else Color(0.62, 0.66, 0.75, 0.9))
	draw_set_transform(pos, 0.0, Vector2(sc, sc))
	var x0 := -tw * 0.5; var x1 := tw * 0.5; var y0 := -h * 0.5 - 0.5; var y1 := h * 0.5 - 0.5
	var shield := PackedVector2Array([Vector2(x0 + 3, y0), Vector2(x1 - 3, y0), Vector2(x1, y0 + 3), Vector2(x1, y1), Vector2(0, y1 + 4.5), Vector2(x0, y1), Vector2(x0, y0 + 3)])
	var body := Color(0.03, 0.05, 0.1, 0.92 * al)
	if p == map.selected: body = Color(0.10, 0.12, 0.17, 0.96 * al)
	draw_colored_polygon(shield, body)
	var oc := Color.hex((g.color[o] << 8) | 0xFF); oc.a = al
	draw_rect(Rect2(x0 + 1, y0 + 1, tw - 2, 2.2), oc, true)
	var ring := shield.duplicate(); ring.append(shield[0])
	if o == me:                                         # own realm: a soft outer halo
		var halo := PackedVector2Array()
		for v in ring: halo.append(v + (v - Vector2(0, 0)).normalized() * 1.6)
		draw_polyline(halo, Color(rim.r, rim.g, rim.b, 0.28 * al), 1.4, true)
	draw_polyline(ring, Color(rim.r, rim.g, rim.b, 0.9 * al), 1.0, true)
	# tier pips above the plaque: one to three small diamonds
	for k in tier:
		var px := (k - (tier - 1) * 0.5) * 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(px, y0 - 5.2), Vector2(px + 2.0, y0 - 3.2), Vector2(px, y0 - 1.2), Vector2(px - 2.0, y0 - 3.2)]), Color(rim.r, rim.g, rim.b, 0.9 * al))
	draw_string(nfont, Vector2(x0 + 5.0 + tier * 0.5, y1 - 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.85, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# floating change: +15 / -12 rises and fades
	if float(st["dt"]) > 0.0 and int(st["dn"]) != 0 and (o == me or absi(int(st["dn"])) >= 10):
		var k := 1.0 - float(st["dt"]) / 1.3
		var dcol := Color(0.55, 0.95, 0.6, 1.0 - k) if int(st["dn"]) > 0 else Color(1.0, 0.55, 0.5, 1.0 - k)
		var dtxt := "%+d" % int(st["dn"])
		var dp := pos + Vector2(-nfont.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, -16.0 - 16.0 * k)
		draw_string_outline(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.02, 0.03, 0.07, 0.8 * (1.0 - k)))
		draw_string(nfont, dp, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dcol)

## battle arrows, marching tokens and impact rings
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
			var e := minf(1.0, k * 1.5)
			e = 1.0 - pow(1.0 - e, 3.0)
			var tip := from2.lerp(to2, e)
			var fade := 1.0 - maxf(0.0, (k - 0.55) / 0.45)
			col.a = fade
			# tapered trail: a few fading segments behind the head
			for j in 6:
				var t0 := maxf(0.0, e - 0.07 * (j + 1)); var t1 := maxf(0.0, e - 0.07 * j)
				var c2 := col; c2.a = fade * (1.0 - j / 6.0) * 0.9
				draw_line(from2.lerp(to2, t0), from2.lerp(to2, t1), c2, 4.0 - j * 0.5, true)
			var dir := (to2 - from2).normalized()
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([tip + dir * 7.0, tip - dir * 3.0 + side * 5.0, tip - dir * 1.0, tip - dir * 3.0 - side * 5.0]), col)
		else:
			col.a = 1.0 - k
			draw_arc(to2, 6.0 + k * 28.0, 0.0, TAU, 28, col, 2.5 * (1.0 - k * 0.6), true)
			if k < 0.35:
				var c3 := col; c3.a = (0.35 - k) / 0.35 * 0.6
				draw_circle(to2, 5.0 + k * 20.0, c3)
	_fx = keep
