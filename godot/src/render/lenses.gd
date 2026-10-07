## Map lenses: province -> packed 0xRRGGBB colour. Mirrors the legacy lenses.
## Colour-vision modes (A11Y-CVD-001/002/005): `TBLenses.cvd` != "off" swaps every palette for an Okabe-Ito derived one, recolours
## the political lens with an adjacency-aware graph colouring (cached, stable, re-solved only where owners now clash) and keeps every
## sequential ramp monotone in luminance. The palette statics (`STAB_RAMP`, `REL_COL`, ...) always hold the ACTIVE set, so the HUD legend
## follows without change.
class_name TBLenses
extends RefCounted

const D = preload("res://src/engine/data.gd")
const NAMES := ["political", "diplomatic", "economic", "military", "wars", "stability", "population", "buildings", "governments", "terrain"]
const MODES := ["off", "deuter", "protan", "tritan"]

const NEUTRAL := 0x5b5142
const DISCOVERABLE := 0x6a5d46

# ---- standard palettes (historical look) ------------------------------------------------------------------------------------------
const REGIME_STD := [0x7a6a4a, 0x8a6d3b, 0xc79a3a, 0x4a86c4, 0x9c3f5a, 0x3fb56b, 0xc0463a, 0x5a5f6b, 0xb5803a, 0x3aa9b8, 0x888888]
const TERRAIN_STD := [0x9dbb6a, 0xa89868, 0x8a8478, 0x4f7f4a, 0x6f8a6a, 0xc6b676]
const BUILD_STD := [0, 0xc0463a, 0xd08a3a, 0x3aa9b8, 0xecc63c, 0x9c8243, 0x7a9a3b, 0x6f8fd0, 0x6ba368, 0xb07a4a]
const POP_STD := [0x10243f, 0x1f5d9c, 0x46a3d8, 0xb8ecff]
const ARMY_STD := [0x2a1410, 0x8a2c22, 0xe0623a, 0xffd27a]
const ECON_STD := [0x2a2308, 0x8a6d1c, 0xe0b63a, 0xfff0a0]
## art bible 4.6: the old red-green ramp had a dark last stop; this one climbs monotonically (L 0.052 -> 0.742)
const STAB_STD := [0x7a1f1f, 0xc9632e, 0xe6c04a, 0xbdebc4]
const REL_STD := {0: 0x8a93a3, 1: 0xd94a3a, 2: 0x4ab8c1, 3: 0x4a86d8, 4: 0xc46ad0}
const SELF_STD := 0x46c36b

# ---- colour-vision palettes (Okabe-Ito: orange E69F00, sky 56B4E9, green 009E73, yellow F0E442, blue 0072B2, vermilion D55E00, purple CC79A7) --
const REGIME_CVD := [0x8c8c8c, 0xE69F00, 0xF0E442, 0x0072B2, 0xCC79A7, 0x009E73, 0xD55E00, 0x4a4a4a, 0x56B4E9, 0xf7d9a4, 0x2a2a2a]
const TERRAIN_CVD := [0xb8d97a, 0xd2b04a, 0x8a7a66, 0x1f7a4d, 0x56B4E9, 0xf0e8b0]
const BUILD_CVD := [0, 0xD55E00, 0xE69F00, 0x56B4E9, 0xF0E442, 0x8c6d1f, 0x009E73, 0x0072B2, 0xCC79A7, 0xb8b8b8]
const POP_CVD := [0x0b1f3a, 0x1f5d9c, 0x56B4E9, 0xe8f6ff]                 # blue ramp: survives all three simulations
const ARMY_CVD := [0x1a0c2e, 0x7a1f6e, 0xe0623a, 0xfff2b0]                # magma-like
const ECON_CVD := [0x2b0a3d, 0x2f6c8e, 0x35b779, 0xfde725]                # viridis-like
const REL_CVD := {0: 0x9aa0a6, 1: 0xD55E00, 2: 0x009E73, 3: 0x0072B2, 4: 0xCC79A7}
const SELF_CVD := 0xF0E442
const OWN_CVD := 0x4a9bd9                                               # reserved: nobody else may use it, own land always reads the same
const BLOC_CVD := [0xE69F00, 0x56B4E9, 0x009E73, 0xF0E442, 0xCC79A7, 0xD55E00, 0x0072B2, 0x999999]
## base hues for the adjacency colouring; each gets a light and a dark step, plus two greys
const NAT_HUES := [0xE69F00, 0x009E73, 0xF0E442, 0xD55E00, 0xCC79A7, 0x56B4E9]

## active palettes (what color() and the legend read)
static var cvd := "off"
static var REGIME_COL: Array = REGIME_STD
static var TERRAIN_COL: Array = TERRAIN_STD
static var BUILD_COL: Array = BUILD_STD
static var POP_RAMP: Array = POP_STD
static var ARMY_RAMP: Array = ARMY_STD
static var ECON_RAMP: Array = ECON_STD
static var STAB_RAMP: Array = STAB_STD
static var REL_COL: Dictionary = REL_STD
static var SELF_COL := SELF_STD

static func set_cvd(mode: String) -> bool:
	if not MODES.has(mode): mode = "off"
	if mode == cvd: return false
	cvd = mode
	var on := mode != "off"
	REGIME_COL = REGIME_CVD if on else REGIME_STD
	TERRAIN_COL = TERRAIN_CVD if on else TERRAIN_STD
	BUILD_COL = BUILD_CVD if on else BUILD_STD
	POP_RAMP = POP_CVD if on else POP_STD
	ARMY_RAMP = ARMY_CVD if on else ARMY_STD
	ECON_RAMP = ECON_CVD if on else ECON_STD
	STAB_RAMP = STAB_STD
	REL_COL = REL_CVD if on else REL_STD
	SELF_COL = SELF_CVD if on else SELF_STD
	return true

var g: TBGame
var mode := "political"
var nat_rgb := PackedInt32Array()
var max_army := 1.0
var max_pop := 1.0
var max_econ := 1.0
var war_col := PackedInt32Array()
var war_bloc := PackedInt32Array()      # nation -> bloc letter index (0 = A) or -1
var _pal_idx := PackedInt32Array()      # nation -> palette index (-1 unassigned, -2 own)
var _pal_cols: Array = []               # [rgb] palette used by the colouring (hues x light/dark + greys)
var _de_cache := {}                     # mode -> PackedFloat32Array of pairwise distances

func _init(game: TBGame) -> void:
	g = game
	refresh_nations()

## nation colours. Off: the historical colour lifted 18 %. Colour-vision modes: the adjacency-aware assignment. Returns true when any colour changed.
func refresh_nations() -> bool:
	var before := nat_rgb.duplicate()
	nat_rgb.resize(g.N1)
	if cvd == "off":
		for n in range(1, g.N1):
			nat_rgb[n] = lerp_rgb(g.color[n], 0x000000, 0.16)
	else:
		_assign_cvd()
		for n in range(1, g.N1):
			var i := _pal_idx[n]
			nat_rgb[n] = OWN_CVD if i == -2 else (int(_pal_cols[i]) if i >= 0 else lerp_rgb(g.color[n], 0xFFFFFF, 0.18))
	nat_rgb[g.rebel] = 0x777777
	return before != nat_rgb

func cvd_active() -> bool: return cvd != "off"

## the colour a nation's army band / marker carries: the map colour in colour-vision modes, the raw nation colour otherwise
func marker_rgb(n: int) -> int:
	return nat_rgb[n] if cvd != "off" else g.color[n]

# ---------------------------------------------------------------- adjacency colouring
func _ensure_palette() -> void:
	if not _pal_cols.is_empty(): return
	for h in NAT_HUES:
		_pal_cols.append(lerp_rgb(h, 0xFFFFFF, 0.22))
		_pal_cols.append(lerp_rgb(h, 0x000000, 0.34))
	_pal_cols.append(0xc4c4c4); _pal_cols.append(0x6e6e6e)

## Machado et al. 2009 matrices (severity 1.0) on linear RGB
const _MACH := {
	"protan": [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	"deuter": [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	"tritan": [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
}

static func _lin(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

## simulate how a colour looks under a CVD mode (rgb in, rgb out; "off" returns it unchanged)
static func simulate(rgb: int, m: String) -> int:
	if not _MACH.has(m): return rgb
	var a: Array = _MACH[m]
	var r := _lin(((rgb >> 16) & 255) / 255.0); var gg := _lin(((rgb >> 8) & 255) / 255.0); var b := _lin((rgb & 255) / 255.0)
	var o := [a[0] * r + a[1] * gg + a[2] * b, a[3] * r + a[4] * gg + a[5] * b, a[6] * r + a[7] * gg + a[8] * b]
	var out := 0
	for i in 3:
		var v: float = clampf(o[i], 0.0, 1.0)
		var s: float = 12.92 * v if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055
		out = (out << 8) | int(round(clampf(s, 0.0, 1.0) * 255.0))
	return out

## CIE76 Lab distance between two colours as seen under mode m
static func delta_e(a: int, b: int, m: String = "off") -> float:
	var la := _lab(simulate(a, m)); var lb := _lab(simulate(b, m))
	return la.distance_to(lb)

static func _lab(rgb: int) -> Vector3:
	var r := _lin(((rgb >> 16) & 255) / 255.0); var g_ := _lin(((rgb >> 8) & 255) / 255.0); var b := _lin((rgb & 255) / 255.0)
	var x := (0.4124564 * r + 0.3575761 * g_ + 0.1804375 * b) / 0.95047
	var y := 0.2126729 * r + 0.7151522 * g_ + 0.0721750 * b
	var z := (0.0193339 * r + 0.1191920 * g_ + 0.9503041 * b) / 1.08883
	var fx := _f(x); var fy := _f(y); var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))

static func _f(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0

func _pal_de(i: int, j: int) -> float:
	if not _de_cache.has(cvd):
		var n := _pal_cols.size()
		var t := PackedFloat32Array(); t.resize(n * n)
		for a in n:
			for b in n: t[a * n + b] = delta_e(_pal_cols[a], _pal_cols[b], cvd)
		_de_cache[cvd] = t
	return (_de_cache[cvd] as PackedFloat32Array)[i * _pal_cols.size() + j]

## greedy graph colouring on the nation adjacency graph. Existing assignments are kept (colours do not jump between turns);
## only nations that now clash with a neighbour, or have no colour yet, are re-solved, biggest degree first.
func _assign_cvd() -> void:
	_ensure_palette()
	var n1 := g.N1
	var fresh := _pal_idx.size() != n1
	if fresh:
		_pal_idx.resize(n1); _pal_idx.fill(-1)
	var adj: Array = []
	adj.resize(n1)
	var cnt := PackedInt32Array(); cnt.resize(n1)
	for p in g.P:
		var o := g.owner[p]
		if o == 0: continue
		cnt[o] += 1
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[e]
			var oq := g.owner[q]
			if oq == 0 or oq == o: continue
			if adj[o] == null: adj[o] = {}
			if adj[oq] == null: adj[oq] = {}
			adj[o][oq] = true; adj[oq][o] = true
	var order: Array = []
	for n in range(1, n1):
		if cnt[n] > 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: int = (adj[a] as Dictionary).size() if adj[a] != null else 0
		var db: int = (adj[b] as Dictionary).size() if adj[b] != null else 0
		return cnt[a] > cnt[b] if da == db else da > db)
	var usage := PackedInt32Array(); usage.resize(_pal_cols.size())
	var fixed := {}
	for n in order:
		if n == g.human_id and g.human_id != 0:
			_pal_idx[n] = -2; fixed[n] = true; continue
		var nbrs: Dictionary = adj[n] if adj[n] != null else {}
		var cur := _pal_idx[n]
		var clash := cur < 0
		if not clash:
			for q in nbrs:
				if fixed.has(q) and _pal_idx[q] == cur: clash = true; break
		if clash:
			var best := -1; var best_s := -1.0
			for c in _pal_cols.size():
				var used := false
				var md := 1000.0
				for q in nbrs:
					var qi := _pal_idx[q]
					if qi < 0 or not fixed.has(q): continue
					if qi == c: used = true; break
					md = minf(md, _pal_de(c, qi))
				if used: continue
				var s := md - float(usage[c]) * 0.4
				if s > best_s: best_s = s; best = c
			if best < 0: best = int(n) % _pal_cols.size()                # more neighbours than colours: the border line separates them
			cur = best
			_pal_idx[n] = cur
		fixed[n] = true
		if cur >= 0: usage[cur] += 1
	for n in range(1, n1):
		if cnt[n] == 0 and n != g.human_id: _pal_idx[n] = -1

## call before painting a batch (computes lens normalisation)
func prepare() -> void:
	match mode:
		"military":
			max_army = 1.0
			for p in g.P: max_army = maxf(max_army, g.army[p])
		"population":
			max_pop = 1.0
			for p in g.P: max_pop = maxf(max_pop, g.pop[p])
		"economic":
			max_econ = 1.0
			for p in g.P: max_econ = maxf(max_econ, g.pop[p] / 80.0 + g.dev[p] * 2.0 + g.econ[p])
		"wars":
			_war_groups()

func color(p: int) -> int:
	var o := g.owner[p]
	if g.discoverable[p] != 0 and o == 0: return DISCOVERABLE
	var me := g.human_id
	match mode:
		"political": return nat_rgb[o] if o != 0 else NEUTRAL
		"diplomatic":
			if o == 0: return NEUTRAL
			if o == me: return SELF_COL
			return REL_COL.get(g.get_rel(me, o), 0x8a93a3)
		"economic":
			return ramp(ECON_RAMP, sqrt((g.pop[p] / 80.0 + g.dev[p] * 2.0 + g.econ[p]) / max_econ)) if o != 0 else NEUTRAL
		"military": return ramp(ARMY_RAMP, sqrt(g.army[p] / max_army)) if o != 0 else NEUTRAL
		"wars":
			if o == 0: return NEUTRAL
			return war_col[o] if war_col[o] != 0 else lerp_rgb(nat_rgb[o], 0x000000, 0.35)
		"stability": return ramp(STAB_RAMP, g.stab[p] / 100.0) if o != 0 else NEUTRAL
		"population": return ramp(POP_RAMP, sqrt(g.pop[p] / max_pop)) if o != 0 else NEUTRAL
		"buildings": return BUILD_COL[g.building[p]] if g.building[p] != 0 else NEUTRAL
		"governments": return REGIME_COL[g.regime[o]] if o != 0 else NEUTRAL
		"terrain": return TERRAIN_COL[g.terrain[p]]
	return NEUTRAL

func _war_groups() -> void:
	var N1 := g.N1
	var parent := PackedInt32Array(); parent.resize(N1)
	for i in N1: parent[i] = i
	for a in range(1, N1):
		if g.war_cnt[a] == 0: continue
		for b in range(a + 1, N1):
			if g.rel[a * N1 + b] == D.REL_WAR and g.alive[a] != 0 and g.alive[b] != 0:
				var ra := _find(parent, a); var rb := _find(parent, b)
				parent[ra] = rb
	war_col.resize(N1); war_col.fill(0)
	war_bloc.resize(N1); war_bloc.fill(-1)
	var letters := {}                                   # root -> bloc index, in nation order so letters are stable between repaints
	for a in range(1, N1):
		if g.alive[a] != 0 and g.war_cnt[a] > 0:
			var r := _find(parent, a)
			if not letters.has(r): letters[r] = letters.size()
			var bi: int = letters[r]
			war_bloc[a] = bi
			if cvd == "off": war_col[a] = Color.from_hsv(fmod(r * 67.0, 360.0) / 360.0, 0.7, 0.8).to_rgba32() >> 8
			else: war_col[a] = BLOC_CVD[bi % BLOC_CVD.size()]

static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x

static func lerp_rgb(a: int, b: int, t: float) -> int:
	var ar := (a >> 16) & 255; var ag := (a >> 8) & 255; var ab := a & 255
	var br := (b >> 16) & 255; var bg := (b >> 8) & 255; var bb := b & 255
	return (int(ar + (br - ar) * t) << 16) | (int(ag + (bg - ag) * t) << 8) | int(ab + (bb - ab) * t)

static func ramp(stops: Array, t: float) -> int:
	t = clampf(t, 0.0, 1.0)
	var s := t * (stops.size() - 1)
	var i := mini(stops.size() - 2, int(s))
	return lerp_rgb(stops[i], stops[i + 1], s - i)

## WCAG relative luminance of a packed rgb
static func lum(rgb: int) -> float:
	return 0.2126 * _lin(((rgb >> 16) & 255) / 255.0) + 0.7152 * _lin(((rgb >> 8) & 255) / 255.0) + 0.0722 * _lin((rgb & 255) / 255.0)

# ---------------------------------------------------------------- legend helpers (letters / patterns, never hue alone)
## the letter printed in legend swatch i of a categorical lens (A, B, C ...). Ramps have none; they carry ticks and low / high.
static func swatch_letter(lens: String, i: int) -> String:
	if lens in ["diplomatic", "governments", "terrain", "buildings", "wars"]: return char(65 + clampi(i, 0, 25))
	return ""

## draws a legend swatch: the fill, a 1 px border and (categorical lenses) its letter in ink or cream, whichever reads on the fill.
## Use a swatch of at least 16 px so the 12 px letter fits.
static func draw_swatch(ci: CanvasItem, r: Rect2, lens: String, i: int, rgb: int) -> void:
	ci.draw_rect(r, Color.hex((rgb << 8) | 0xFF))
	ci.draw_rect(r, TBTokens.c("rule_dark"), false, 1.0)
	var l := swatch_letter(lens, i)
	if l == "": return
	var f: Font = TBKit.mono_b()
	var fs := 12
	var tw := f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var col := TBTokens.c("ink_0") if lum(rgb) > 0.22 else TBTokens.c("cream")
	ci.draw_string(f, r.get_center() + Vector2(-tw.x * 0.5, f.get_ascent(fs) * 0.5 - 1.0), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## one plain-language line about the active lens for province p (hover card, long-press peek, keyboard cursor readout)
func describe(p: int) -> String:
	var o := g.owner[p]
	var T: Callable = TBI18n.T
	var me := g.human_id
	match mode:
		"diplomatic":
			if o == 0: return ""
			var words := ["rel_peace", "rel_war", "rel_nap", "rel_ally", "rel_marriage"]
			return "%s: %s" % [T.call("lens_diplomatic"), T.call("leg_self") if o == me else T.call(words[clampi(g.get_rel(me, o), 0, 4)])]
		"economic": return "%s: %s" % [T.call("lens_economic"), TBKit.fmt(int(g.pop[p] / 80.0 + g.dev[p] * 2.0 + g.econ[p]))] if o != 0 else ""
		"military": return "%s: %s" % [T.call("lens_military"), TBKit.fmt(g.army[p])] if o != 0 else ""
		"stability": return "%s: %d" % [T.call("lens_stability"), int(g.stab[p])] if o != 0 else ""
		"population": return "%s: %s" % [T.call("lens_population"), TBKit.fmt(g.pop[p])] if o != 0 else ""
		"buildings": return "%s: %s %s" % [T.call("lens_buildings"), swatch_letter("buildings", g.building[p] - 1), T.call("b_" + D.BUILDINGS[g.building[p] - 1]["id"])] if g.building[p] != 0 else ""
		"governments": return "%s: %s %s" % [T.call("lens_governments"), swatch_letter("governments", g.regime[o]), T.call("g_" + D.REGIME_ID[g.regime[o]])] if o != 0 else ""
		"terrain": return "%s: %s %s" % [T.call("lens_terrain"), swatch_letter("terrain", g.terrain[p]), T.call("t_" + D.TERRAIN_ID[g.terrain[p]])]
		"wars":
			if o == 0 or war_bloc.size() <= o or war_bloc[o] < 0: return ""
			return "%s: %s" % [T.call("lens_wars"), char(65 + war_bloc[o] % 26)]
	return ""
