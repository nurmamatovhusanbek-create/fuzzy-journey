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
const EXH_TURN := 0.6                  # each turn at war
const EXH_OCC := 0.3                   # per own province held by the enemy (at most OCC_CAP provinces count)
const OCC_CAP := 10
const EXH_CAS_K := 150.0               # per whole population lost in a turn's battles; at most CAS_CAP a turn
const CAS_CAP := 8.0
const EXH_REST := 3.0                  # lost each turn at peace
const WEARY_K := 0.4                   # exhaustion points -> the older 'weariness' that cuts stability and mood

static func morale_mul(g: TBGame, n: int) -> float:
	return 1.0 + MORALE_SWING * (g.morale[n] - MORALE_START) / 100.0

## a battle was fought: winner and loser change heart; the men lost count towards the nations' weariness this turn
static func on_battle(g: TBGame, win_n: int, lose_n: int, win_lost: int, win_before: int, lose_lost: int, lose_before: int) -> void:
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
		if g.occupier[p] != 0 and g.occupier[p] != n: occ += 1
	var up: float = EXH_TURN + EXH_OCC * float(mini(occ, OCC_CAP)) + minf(CAS_CAP, EXH_CAS_K * float(lost) / float(maxi(1, pop)))
	g.exh[n] = minf(100.0, g.exh[n] + up)
	var m: float = g.morale[n]
	m += (MORALE_START - m) * 0.05                                  # the fighting spirit settles back to its usual level
	if g.exh[n] > 50.0: m -= (g.exh[n] - 50.0) * 0.03               # a tired country fights with less heart
	g.morale[n] = clampf(m, 0.0, 100.0)

## the older 'weariness' (0-40) the stability and mood formulas already take
static func weary(g: TBGame, n: int) -> float:
	return minf(40.0, g.exh[n] * WEARY_K)
