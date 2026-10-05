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


# ---------------------------------------------------------------- royal marriages (rules >= 1)
const DP_MARRY := 3

static func can_marry(g: TBGame, a: int, b: int) -> bool:
	if g.rules < 1 or a == b or a == g.rebel or b == g.rebel or g.alive[a] == 0 or g.alive[b] == 0: return false
	var r := g.get_rel(a, b)
	return (r == D.REL_PEACE or r == D.REL_NAP) and TBRulers.is_hereditary(g, a) and TBRulers.is_hereditary(g, b) and g.overlord[a] == 0 and g.overlord[b] == 0

static func marry(g: TBGame, n: int, t: int) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "rules"}
	if not can_marry(g, n, t): return {"ok": false, "err": "state"}
	if g.dp[n] < DP_MARRY: return {"ok": false, "err": "dp"}
	if g.has_truce(n, t) and g.human[t] == 0: return {"ok": false, "err": "truce"}
	if g.human[t] == 0 and not TBAI.accepts_pact(g, t, n, D.REL_ALLY): return {"ok": false, "err": "refused"}
	g.dp[n] -= DP_MARRY
	g.set_rel(n, t, D.REL_MARRIAGE)
	g.grudge[n * g.N1 + t] = maxi(0, g.grudge[n * g.N1 + t] - 40); g.grudge[t * g.N1 + n] = maxi(0, g.grudge[t * g.N1 + n] - 40)
	g.log.append({"turn": g.turn, "kind": "marriage", "a": n, "b": t})
	return {"ok": true}

## called when n's ruler changes: the marriage may lapse, or the match may bring a personal union under the stronger partner
static func on_succession(g: TBGame, n: int, rng: TBRng) -> void:
	for x in range(1, g.N1):
		if x == n or g.alive[x] == 0 or g.get_rel(n, x) != D.REL_MARRIAGE: continue
		var roll := rng.next()
		if roll < 0.22 and g.overlord[n] == 0 and g.overlord[x] == 0 and g.own_count(x) * 10 >= g.own_count(n) * 8 and g.human[n] == 0:
			g.overlord[n] = x; g.tribute[n] = 0; g.liberty[n] = 0.0
			g.log.append({"turn": g.turn, "kind": "union", "a": x, "b": n})
		elif roll < 0.5:
			g.set_rel(n, x, D.REL_PEACE)
			g.log.append({"turn": g.turn, "kind": "marriage_end", "a": n, "b": x})
		return

static func ai_marry(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.dp[n] < DP_MARRY + 1.0 or g.rng.next() > 0.04 or not TBRulers.is_hereditary(g, n): return
	for o in range(1, g.N1):
		if o != n and can_marry(g, n, o) and g.human[o] == 0 and g.own_count(o) >= 6:
			marry(g, n, o); return
