class_name TBWar
extends RefCounted
## Rules 4: what a war does to the men and to the people (docs/WAR_DESIGN.md section 7).
## Morale (0-100, 70 is the usual) scales how hard an army hits; exhaustion (0-100) is the people's weariness with the war, it lowers their mood and makes a government ready for peace.
## Every figure is derived from things that happen (battles, hunger, occupation, the length of the war), nothing is random.

const MORALE_START := 70.0
const MORALE_SWING := 0.30             # the strength factor runs 1 - 0.30 * 0.70 = 0.79 at morale 0 to 1 + 0.30 * 0.30 = 1.09 at 100
const WIN_GAIN := 8.0
const LOSS_BASE := 6.0
const LOSS_SHARE_K := 30.0             # plus this many points per whole army lost
const BROKEN := 30.0                   # below this an army deserts
const DESERT := 0.01
const EXH_TURN := 0.4                  # each turn at war
const EXH_OCC := 0.2                   # per own province held by the enemy (at most OCC_CAP provinces count)
const OCC_CAP := 10
const EXH_CAS_K := 100.0               # per whole population lost in a turn's battles; at most CAS_CAP a turn
const CAS_CAP := 5.0
const EXH_ADAPT := 0.985               # a long war is borne: what is already felt fades by this factor a turn, so the figure settles (a quiet war near 27, a bloody one higher) instead of climbing to 100
const EXH_REST := 3.0                  # lost each turn at peace
const BATTLE_PTS := 30.0               # war score for a battle: this many points per whole enemy army destroyed (at most BATTLE_CAP)
const BATTLE_CAP := 8.0
const SIEGE_PTS := 4.0
const CAPITAL_PTS := 15.0
const EXH_SCORE := 0.2                 # an exhausted enemy is easier to bargain with: a fifth of his exhaustion is added to the score
const OCC_SHARE := 0.5                 # of the owner's tax an occupier collects
const RES_START := 40                  # resistance of a province the day it falls
const RES_DOWN := 2                    # per turn while the garrison is large enough
const RES_UP := 3                      # per turn when it is not
const RES_GARRISON := 0.06             # share of the people the garrison must reach to keep order
const RES_BLOW := 0.5                  # share of the garrison lost when the province rises
const RES_POINTS := 2.0                # war score the owner earns by it
const WEARY_K := 0.3                   # exhaustion points -> the older 'weariness' that cuts stability and mood

static func morale_mul(g: TBGame, n: int) -> float:
	return 1.0 + MORALE_SWING * (g.morale[n] - MORALE_START) / 100.0

## a battle was fought: winner and loser change heart; the men lost count towards the nations' weariness this turn
static func on_battle(g: TBGame, win_n: int, lose_n: int, win_lost: int, win_before: int, lose_lost: int, lose_before: int) -> void:
	if win_n != 0 and lose_n != 0 and g.get_rel(win_n, lose_n) == TBData.REL_WAR:                # the dead of a lost battle are points for the winner
		var total := lose_before
		var sum := 0
		for p in g.owned(lose_n): sum += g.army[p]
		total = maxi(total, sum + lose_lost)
		earn(g, win_n, lose_n, minf(BATTLE_CAP, BATTLE_PTS * float(lose_lost) / float(maxi(1, total))))
	if win_n != 0:
		g.lost_turn[win_n] += win_lost
		g.morale[win_n] = minf(100.0, g.morale[win_n] + WIN_GAIN)
	if lose_n != 0:
		g.lost_turn[lose_n] += lose_lost
		var share: float = float(lose_lost) / float(maxi(1, lose_before))
		g.morale[lose_n] = maxf(0.0, g.morale[lose_n] - LOSS_BASE - LOSS_SHARE_K * share)

## once a turn for one nation, after its wars are counted. `pop` = its people (men under arms are measured against them)
static func tick(g: TBGame, n: int, at_war: bool, pop: int) -> void:
	var lost: int = g.lost_turn[n]; g.lost_turn[n] = 0
	if not at_war:
		g.exh[n] = maxf(0.0, g.exh[n] - EXH_REST)
		g.morale[n] = minf(100.0, g.morale[n] + 1.5)
		return
	var occ := 0
	for p in g.owned(n):
		if g.occupier[p] != 0 and g.occupier[p] != n and g.siege[p] == 0: occ += 1
	var up: float = EXH_TURN + EXH_OCC * float(mini(occ, OCC_CAP)) + minf(CAS_CAP, EXH_CAS_K * float(lost) / float(maxi(1, pop)))
	g.exh[n] = minf(100.0, g.exh[n] * EXH_ADAPT + up)
	var m: float = g.morale[n]
	m += (MORALE_START - m) * 0.05                                  # the fighting spirit settles back to its usual level
	if g.exh[n] > 50.0: m -= (g.exh[n] - 50.0) * 0.03               # a tired country fights with less heart
	g.morale[n] = clampf(m, 0.0, 100.0)

## the older 'weariness' (0-40) the stability and mood formulas already take
static func weary(g: TBGame, n: int) -> float:
	return minf(40.0, g.exh[n] * WEARY_K)

## points toward the war score of w against l
static func earn(g: TBGame, w: int, l: int, pts: float) -> void:
	if w == 0 or l == 0 or w == g.rebel or l == g.rebel or pts <= 0.0: return
	var i := w * g.N1 + l
	g.war_pts[i] = minf(100.0, g.war_pts[i] + pts)

## the war score of n against o: the share of o's land n holds, plus what it won in the field, plus a fifth of o's exhaustion
static func score(g: TBGame, n: int, o: int, occ_pct: float) -> int:
	return clampi(int(round(occ_pct + g.war_pts[n * g.N1 + o] + g.exh[o] * EXH_SCORE)), 0, 100)

## once a turn for an occupied province (rules >= 4, siege over): the garrison either keeps order or the people wear it down; at 100 the province rises and returns to its owner
## returns true when it rose
static func resist(g: TBGame, p: int) -> bool:
	var oc := g.occupier[p]; var o := g.owner[p]
	var need := int(float(g.pop[p]) * RES_GARRISON)
	if g.army[p] >= need: g.unrest[p] = maxi(0, g.unrest[p] - RES_DOWN)
	else: g.unrest[p] = mini(100, g.unrest[p] + RES_UP)
	if g.unrest[p] < 100: return false
	g.occupier[p] = 0; g.unrest[p] = 0; g.siege[p] = 0
	g.army[p] = maxi(1, int(float(g.army[p]) * (1.0 - RES_BLOW))); g.occ_rev += 1; g.touch(p)
	earn(g, o, oc, RES_POINTS)
	if g.human[o] != 0 or g.human[oc] != 0 or g.capital[p] != 0: g.log.append({"turn": g.turn, "kind": "liberated", "a": oc, "b": o, "p": p})
	return true


# ---------------------------------------------------------------- calls to arms (docs/WAR_DESIGN.md section 11)
const CALL_YES := 0.45                 # an AI ally joins when its willingness is above this
const CALL_SNUB_GRUDGE := 20           # the injured ally's grudge against one who stays out of his war

## how ready ally `o` is to fight for `t`, whom `n` attacked: 0.5 x trust + 0.3 x the threat n is to o + 0.2 x a shared border - 0.4 x the distance to the war - 0.3 x its own exhaustion.
## Every term is in 0..1; the result is returned with its terms for the interface.
static func call_terms(g: TBGame, o: int, t: int, n: int) -> Array:
	var trust: float = clampf(1.0 - float(g.grudge[o * g.N1 + t]) / 60.0, 0.0, 1.0)
	var po := 1.0; var pn := 1.0
	for p in g.owned(o): po += float(g.army[p])
	for p in g.owned(n): pn += float(g.army[p])
	var threat: float = clampf(pn / (pn + po), 0.0, 1.0)                           # a stronger aggressor is a danger to everyone near him
	var border := 0.0
	for p in g.owned(o):
		if border > 0.0: break
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.owner[g.nb[i]] == n: border = 1.0; break
	var dist := 1.0
	var co: int = g.capital_of[o]; var ct: int = g.capital_of[t]
	if co >= 0 and ct >= 0:
		var a1 := deg_to_rad(g.world.lat[co]); var a2 := deg_to_rad(g.world.lat[ct])
		var dl := deg_to_rad(g.world.lon[co] - g.world.lon[ct])
		var c := clampf(sin(a1) * sin(a2) + cos(a1) * cos(a2) * cos(dl), -1.0, 1.0)
		dist = acos(c) / PI                                                         # 0 = the same place, 1 = the far side of the world
	var weary: float = g.exh[o] / 100.0
	return [["trust", 0.5 * trust], ["threat", 0.3 * threat], ["border", 0.2 * border], ["distance", -0.4 * dist], ["weary", -0.3 * weary]]

static func call_willingness(g: TBGame, o: int, t: int, n: int) -> float:
	var w := 0.0
	for tm in call_terms(g, o, t, n): w += float(tm[1])
	return w
