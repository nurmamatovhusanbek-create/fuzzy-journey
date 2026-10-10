## The Bezel demo's icon set (docs/ui_variants/src/bezel_kit.js `IC`): 24 x 24 grid, 1.7 stroke, round caps and joins, outline only.
## The SVG path strings are kept verbatim and parsed once into polylines, so a drawn icon is the demo's icon, not a look-alike.
class_name TBBzIcons
extends RefCounted

const IC := {
	"nations": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3v18M6.5 6q5.500 6 11 0M6.500 18q5.500-6 11 0"/>',
	"treasury": '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5q0 3 7 3t7-3V7M5 12v5q0 3 7 3t7-3v-5"/>',
	"decrees": '<path d="M12 3v18M6 21h12M4 7h16M4 7l-2.500 7h5zM20 7l-2.500 7h5z"/>',
	"council": '<path d="M3 9l9-5 9 5zM5 20h14M6 9v8M10 9v8M14 9v8M18 9v8"/>',
	"annals": '<path d="M3 5q4.500-1.500 9 1.500q4.500-3 9-1.500v13q-4.500-1.500-9 1.500q-4.500-3-9-1.500zM12 6.500v13"/>',
	"goals": '<path d="M7 4h10v6q0 5-5 5t-5-5zM7 6.500H4q0 4 3 4.500M17 6.500h3q0 4-3 4.500M12 15v4M8 20h8"/>',
	"army": '<path d="M5 19L18 6M18 6h-4M18 6v4M19 19L6 6M6 6h4M6 6v4M3.500 17.500l3 3M20.500 17.500l-3 3"/>',
	"people": '<circle cx="9" cy="8" r="3.200"/><path d="M3 20q0-6 6-6t6 6M16 5.500a3 3 0 010 5.500M18 14q3 1 3 6"/>',
	"envoys": '<rect x="3" y="6" width="18" height="13" rx="1.500"/><path d="M3.500 7l8.500 7 8.500-7"/>',
	"gold": '<circle cx="12" cy="12" r="9"/><path d="M12 7v10M9.500 9.500q0-2 2.500-2t2.500 1.800q0 1.700-2.500 2.200t-2.500 2.200q0 1.800 2.500 1.800t2.500-2"/>',
	"move": '<path d="M3 12h16M13 6l6 6-6 6"/>',
	"recruit": '<circle cx="12" cy="12" r="9"/><path d="M12 7.500v9M7.500 12h9"/>',
	"build": '<path d="M4 20V10l8-6 8 6v10zM10 20v-6h4v6"/>',
	"fortify": '<path d="M4 20V7h3v3h2.500V7h5v3H17V7h3v13zM10 20v-4h4v4"/>',
	"attack": '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
	"pact": '<circle cx="9" cy="12" r="5.500"/><circle cx="15" cy="12" r="5.500"/>',
	"trade": '<path d="M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4"/>',
	"spy": '<path d="M2 12q4.500-7 10-7t10 7q-4.500 7-10 7T2 12z"/><circle cx="12" cy="12" r="3"/>',
	"war": '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
	"settings": '<circle cx="12" cy="12" r="3.500"/><path d="M12 2.500v3M12 18.500v3M2.500 12h3M18.500 12h3M5.300 5.300l2.100 2.100M16.600 16.600l2.100 2.100M5.300 18.700l2.100-2.100M16.600 7.400l2.100-2.100"/>',
	"save": '<path d="M12 4v11M7 11l5 5 5-5M4 20h16"/>',
	"load": '<path d="M12 16V5M7 9l5-5 5 5M4 20h16"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"warn": '<path d="M12 3L22 20H2zM12 10v5M12 17.500v.5"/>',
	"info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.500v.5"/>',
	"check": '<path d="M4 12.500l5 5L20 6.500"/>',
	"star": '<path d="M12 3l2.600 5.600 6.100.7-4.500 4.200 1.200 6L12 16.500 6.600 19.500l1.200-6L3.300 9.300l6.100-.7z"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.500 2"/>',
	"research": '<path d="M12 3v4M12 7L6 21M12 7l6 14M8.500 16h7"/><circle cx="12" cy="4" r="1.200"/>',
	"invest": '<path d="M4 19l5-6 4 3 7-9M15 7h5v5"/>',
	"tax": '<circle cx="8" cy="8" r="2.500"/><circle cx="16" cy="16" r="2.500"/><path d="M18 5L6 19"/>',
	"happy": '<circle cx="12" cy="12" r="9"/><path d="M8 14q4 4 8 0M9 9.500v.5M15 9.500v.5"/>',
	"terrain": '<path d="M2 19l7-12 4 7 3-4 6 9z"/>',
	"menu": '<path d="M4 7h16M4 12h16M4 17h16"/>',
	"flag": '<path d="M5 21V4M5 5h13l-3 4 3 4H5"/>',
	"lock": '<rect x="5" y="11" width="14" height="9" rx="1.500"/><path d="M8 11V8a4 4 0 018 0v3"/>',
	"crown": '<path d="M3 18l1.500-10 5 4L12 5l2.500 7 5-4L21 18zM4 21h16"/>',
	"skull": '<path d="M12 3q8 0 8 8 0 3-2 4.500V20H6v-4.500Q4 14 4 11q0-8 8-8zM9 12v1M15 12v1M10 17v3M14 17v3"/>',
	"heart": '<path d="M12 20S3 14 3 8.500A4.500 4.500 0 0112 7a4.500 4.500 0 019 1.500C21 14 12 20 12 20z"/>',
	"ship": '<path d="M3 15h18l-2.500 5h-13zM12 3v12M12 4l6 8h-6M12 6L7 12h5z"/>',
	"dots": '<circle cx="6" cy="12" r="1.200"/><circle cx="12" cy="12" r="1.200"/><circle cx="18" cy="12" r="1.200"/>',
}

static var _cache: Dictionary = {}

static func has(name: String) -> bool: return IC.has(name)

## polylines (24 grid units) of one icon: Array of PackedVector2Array; a closed one repeats its first point
static func shape(name: String) -> Array:
	if _cache.has(name): return _cache[name]
	var out: Array = []
	var src: String = String(IC.get(name, ""))
	var re := RegEx.new()
	re.compile("<(\\w+)\\s([^>]*)/>")
	for m in re.search_all(src):
		var tag: String = m.get_string(1)
		var at: Dictionary = _attrs(m.get_string(2))
		match tag:
			"path": out.append_array(_path(String(at.get("d", ""))))
			"circle": out.append(_ellipse(float(at["cx"]), float(at["cy"]), float(at["r"]), float(at["r"])))
			"ellipse": out.append(_ellipse(float(at["cx"]), float(at["cy"]), float(at["rx"]), float(at["ry"])))
			"rect": out.append(_rect(float(at["x"]), float(at["y"]), float(at["width"]), float(at["height"]), float(at.get("rx", 0.0))))
	_cache[name] = out
	return out

static func _attrs(s: String) -> Dictionary:
	var d := {}
	var re := RegEx.new()
	re.compile("(\\w+)=\"([^\"]*)\"")
	for m in re.search_all(s): d[m.get_string(1)] = m.get_string(2)
	return d

static func _ellipse(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 41:
		var a: float = TAU * i / 40.0
		p.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return p

static func _rect(x: float, y: float, w: float, h: float, rx: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	if rx <= 0.0:
		p.append_array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y)])
		return p
	var corners := [[x + w - rx, y + rx, -90.0], [x + w - rx, y + h - rx, 0.0], [x + rx, y + h - rx, 90.0], [x + rx, y + rx, 180.0]]
	for c in corners:
		for i in 7:
			var a: float = deg_to_rad(float(c[2]) + 90.0 * i / 6.0)
			p.append(Vector2(float(c[0]) + rx * cos(a), float(c[1]) + rx * sin(a)))
	p.append(p[0])
	return p

# ---- SVG path data -> polylines
static func _path(d: String) -> Array:
	var subs: Array = []
	var cur := PackedVector2Array()
	var pos := Vector2.ZERO
	var start := Vector2.ZERO
	var last_ctrl := Vector2.ZERO
	var last_cmd := ""
	var i: int = 0
	var n: int = d.length()
	var cmd := ""
	while i < n:
		var ch: String = d[i]
		if ch == " " or ch == ",":
			i += 1; continue
		if ch in "MmLlHhVvQqTtAaZz":
			cmd = ch; i += 1
			if ch == "Z" or ch == "z":
				if cur.size() > 0:
					cur.append(start); subs.append(cur); cur = PackedVector2Array()
				pos = start
				last_cmd = "Z"
				continue
		# read the arguments of `cmd` (repeated while numbers follow)
		var rel: bool = cmd == cmd.to_lower()
		var up: String = cmd.to_upper()
		var args: Array = []
		var need: int = {"M": 2, "L": 2, "H": 1, "V": 1, "Q": 4, "T": 2, "A": 7}.get(up, 0)
		var got_first: bool = true
		while args.size() < need and i < n:
			if d[i] == " " or d[i] == ",": i += 1; continue
			if up == "A" and (args.size() == 3 or args.size() == 4):
				args.append(float(d[i])); i += 1; continue                     # arc flags are single characters
			var r := _num(d, i)
			if r[1] == i: got_first = false; break
			args.append(r[0]); i = r[1]
		if not got_first or args.size() < need:
			break
		match up:
			"M":
				if cur.size() > 0: subs.append(cur)
				cur = PackedVector2Array()
				pos = (pos + Vector2(args[0], args[1])) if rel else Vector2(args[0], args[1])
				start = pos; cur.append(pos)
				cmd = "l" if rel else "L"                                        # further pairs are lineto
			"L":
				pos = (pos + Vector2(args[0], args[1])) if rel else Vector2(args[0], args[1]); cur.append(pos)
			"H":
				pos = Vector2(pos.x + args[0] if rel else args[0], pos.y); cur.append(pos)
			"V":
				pos = Vector2(pos.x, pos.y + args[0] if rel else args[0]); cur.append(pos)
			"Q":
				var c1: Vector2 = (pos + Vector2(args[0], args[1])) if rel else Vector2(args[0], args[1])
				var e1: Vector2 = (pos + Vector2(args[2], args[3])) if rel else Vector2(args[2], args[3])
				_quad(cur, pos, c1, e1); pos = e1; last_ctrl = c1
			"T":
				var c2: Vector2 = pos * 2.0 - last_ctrl if (last_cmd == "Q" or last_cmd == "T") else pos
				var e2: Vector2 = (pos + Vector2(args[0], args[1])) if rel else Vector2(args[0], args[1])
				_quad(cur, pos, c2, e2); pos = e2; last_ctrl = c2
			"A":
				var e3: Vector2 = (pos + Vector2(args[5], args[6])) if rel else Vector2(args[5], args[6])
				_arc(cur, pos, float(args[0]), float(args[1]), float(args[2]), args[3] != 0.0, args[4] != 0.0, e3)
				pos = e3
		last_cmd = up
	if cur.size() > 0: subs.append(cur)
	return subs

## number at d[i..]: [value, next index]; a second '.' or a '-' starts a new number
static func _num(d: String, i: int) -> Array:
	var j: int = i
	var n: int = d.length()
	if j < n and (d[j] == "-" or d[j] == "+"): j += 1
	var dot: bool = false
	while j < n:
		var c: String = d[j]
		if c >= "0" and c <= "9": j += 1
		elif c == "." and not dot: dot = true; j += 1
		else: break
	if j == i or (j == i + 1 and not (d[i] >= "0" and d[i] <= "9")): return [0.0, i]
	return [float(d.substr(i, j - i)), j]

static func _quad(out: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2) -> void:
	for k in range(1, 13):
		var t: float = k / 12.0
		out.append(p0 * ((1.0 - t) * (1.0 - t)) + c * (2.0 * (1.0 - t) * t) + p1 * (t * t))

static func _arc(out: PackedVector2Array, p0: Vector2, rx: float, ry: float, rot_deg: float, large: bool, sweep: bool, p1: Vector2) -> void:
	if rx == 0.0 or ry == 0.0 or p0 == p1:
		out.append(p1); return
	var phi: float = deg_to_rad(rot_deg)
	var cp: float = cos(phi); var sp: float = sin(phi)
	var dx: float = (p0.x - p1.x) * 0.5; var dy: float = (p0.y - p1.y) * 0.5
	var x1: float = cp * dx + sp * dy; var y1: float = -sp * dx + cp * dy
	rx = absf(rx); ry = absf(ry)
	var lam: float = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
	if lam > 1.0:
		var s: float = sqrt(lam); rx *= s; ry *= s
	var num: float = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
	var den: float = rx * rx * y1 * y1 + ry * ry * x1 * x1
	var co: float = sqrt(maxf(0.0, num / den)) * (-1.0 if large == sweep else 1.0)
	var cxp: float = co * rx * y1 / ry; var cyp: float = -co * ry * x1 / rx
	var cx: float = cp * cxp - sp * cyp + (p0.x + p1.x) * 0.5
	var cy: float = sp * cxp + cp * cyp + (p0.y + p1.y) * 0.5
	var a0: float = atan2((y1 - cyp) / ry, (x1 - cxp) / rx)
	var a1: float = atan2((-y1 - cyp) / ry, (-x1 - cxp) / rx)
	var da: float = a1 - a0
	if sweep and da < 0.0: da += TAU
	elif not sweep and da > 0.0: da -= TAU
	var steps: int = maxi(6, int(ceil(absf(da) / (PI / 12.0))))
	for k in range(1, steps + 1):
		var a: float = a0 + da * k / steps
		var px: float = rx * cos(a); var py: float = ry * sin(a)
		out.append(Vector2(cp * px - sp * py + cx, sp * px + cp * py + cy))

## draw icon `name` centred at c, `size` px square (24 grid scaled), stroke width w in 24-grid units (the demo's 1.7), round caps
static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, w: float = 1.7) -> void:
	var k: float = size / 24.0
	var sw: float = w * k
	var aw: float = TBBezel.aw(sw)                          # Godot widens an antialiased stroke by ~0.8 screen px of feather
	for sub in shape(name):
		var pts: PackedVector2Array = sub
		if pts.size() < 1: continue
		var q := PackedVector2Array()
		for p in pts: q.append(c + (p - Vector2(12, 12)) * k)
		if q.size() == 1:
			ci.draw_circle(q[0], sw * 0.5, col)
			continue
		ci.draw_polyline(q, col, aw, true)
		if q[0] != q[q.size() - 1]:
			ci.draw_circle(q[0], sw * 0.5, col); ci.draw_circle(q[q.size() - 1], sw * 0.5, col)
