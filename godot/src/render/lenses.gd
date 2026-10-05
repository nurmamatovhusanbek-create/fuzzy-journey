## Map lenses: province -> packed 0xRRGGBB colour. Mirrors the legacy lenses.
class_name TBLenses
extends RefCounted

const D = preload("res://src/engine/data.gd")
const NAMES := ["political", "diplomatic", "economic", "military", "wars", "stability", "population", "buildings", "governments", "terrain"]

const NEUTRAL := 0x5b5142
const DISCOVERABLE := 0x2f2a24
const REGIME_COL := [0x7a6a4a, 0x8a6d3b, 0xc79a3a, 0x4a86c4, 0x9c3f5a, 0x3fb56b, 0xc0463a, 0x5a5f6b, 0xb5803a, 0x3aa9b8, 0x888888]
const TERRAIN_COL := [0x9dbb6a, 0xa89868, 0x8a8478, 0x4f7f4a, 0x6f8a6a, 0xc6b676]
const BUILD_COL := [0, 0xc0463a, 0xd08a3a, 0x3aa9b8, 0xecc63c, 0x9c8243, 0x7a9a3b, 0x6f8fd0, 0x6ba368, 0xb07a4a]
const POP_RAMP := [0x10243f, 0x1f5d9c, 0x46a3d8, 0xb8ecff]
const ARMY_RAMP := [0x2a1410, 0x8a2c22, 0xe0623a, 0xffd27a]
const ECON_RAMP := [0x2a2308, 0x8a6d1c, 0xe0b63a, 0xfff0a0]
const STAB_RAMP := [0xa02a2a, 0xd08a3a, 0xc9d04a, 0x46c36b]
const REL_COL := {0: 0x8a93a3, 1: 0xd94a3a, 2: 0x4ab8c1, 3: 0x4a86d8, 4: 0xc46ad0}

var g: TBGame
var mode := "political"
var nat_rgb := PackedInt32Array()
var max_army := 1.0
var max_pop := 1.0
var max_econ := 1.0
var war_col := PackedInt32Array()

func _init(game: TBGame) -> void:
	g = game
	refresh_nations()

func refresh_nations() -> void:
	nat_rgb.resize(g.N1)
	for n in range(1, g.N1):
		nat_rgb[n] = lerp_rgb(g.color[n], 0xFFFFFF, 0.18)
	nat_rgb[g.rebel] = 0x777777

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
			if o == me: return 0x46c36b
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
	for a in range(1, N1):
		if g.alive[a] != 0 and g.war_cnt[a] > 0:
			var r := _find(parent, a)
			war_col[a] = Color.from_hsv(fmod(r * 67.0, 360.0) / 360.0, 0.7, 0.8).to_rgba32() >> 8

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
