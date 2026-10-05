## Casus belli, infamy and coalitions (rules >= 1).
## Taking land and attacking without a reason raises infamy; high infamy forms a coalition that gives everyone a free casus belli.
class_name TBDiplo
extends RefCounted

const D = preload("res://src/engine/data.gd")
const COALITION_ON := 22.0
const COALITION_OFF := 12.0
const NO_CB_INFAMY := 8.0
const LAND_INFAMY := 1.2
const VASSAL_INFAMY := 4.0
const DECAY := 0.45

## "" = no casus belli. Order matters: the cheapest justification wins.
static func cb(g: TBGame, n: int, t: int) -> String:
	if g.rules < 1: return ""
	if t == g.rebel or n == g.rebel: return "rebels"
	if g.coalition[t] != 0 and not g.friendly(n, t) and g.overlord[n] != t: return "coalition"
	for p in g.owned(t):
		if g.core[p] == n: return "reclaim"
	if g.grudge[n * g.N1 + t] >= 40: return "revenge"
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == D.REL_ALLY and g.get_rel(o, t) == D.REL_WAR: return "ally"
	return ""

## called by declareWar
static func on_declare(g: TBGame, n: int, t: int) -> String:
	var k := cb(g, n, t)
	if g.rules >= 1 and k == "": g.infamy[n] = minf(100.0, g.infamy[n] + NO_CB_INFAMY)
	return k

static func on_land_taken(g: TBGame, p: int, from: int, to: int) -> void:
	if g.rules < 1 or from == 0 or to == 0 or from == g.rebel or to == g.rebel: return
	if g.core[p] == to: return              # taking back your own land is not aggression
	g.infamy[to] = minf(100.0, g.infamy[to] + LAND_INFAMY)

## per turn: decay and coalition hysteresis
static func tick(g: TBGame) -> void:
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel:
			g.infamy[n] = 0.0; g.coalition[n] = 0; continue
		if g.infamy[n] > 0.0: g.infamy[n] = maxf(0.0, g.infamy[n] - DECAY)
		if g.coalition[n] == 0 and g.infamy[n] >= COALITION_ON:
			g.coalition[n] = 1
			g.log.append({"turn": g.turn, "kind": "coalition", "a": n})
		elif g.coalition[n] != 0 and g.infamy[n] < COALITION_OFF:
			g.coalition[n] = 0
			g.log.append({"turn": g.turn, "kind": "coalition_end", "a": n})
