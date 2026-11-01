## Covert operations, rules 4 (docs/ESPIONAGE_DESIGN.md): the chance an operation succeeds depends on who is ahead in learning, how well the target guards itself and what you already have inside
## (a recent report, a marriage, a trade route); the target may catch the agents or trace the work, and then it resents it, the world hears, and ties can be cut.
class_name TBSpy
extends RefCounted

const D = preload("res://src/engine/data.gd")

const BASE := 0.80
const OP_COST := {"steal": 0.0, "sabotage": 0.05, "incite": 0.10}          # the nastier the work, the harder it is
const GRUDGE := {"steal": 25, "sabotage": 40, "incite": 55}
const INFAMY := {"steal": 1.0, "sabotage": 3.0, "incite": 5.0}
const SEV := {"steal": 1, "sabotage": 2, "incite": 3}

## how well a court watches its own house: learning and administration
static func guard(g: TBGame, t: int) -> float:
	return clampf(0.15 + 0.06 * float(g.tech_level[t]), 0.10, 0.55)

## the sum behind the chance, [[key, value], ...] (the same terms the interface may list)
static func terms(g: TBGame, n: int, t: int, op: String) -> Array:
	var out: Array = [["sp_base", BASE]]
	var lead: float = clampf((g.tech_level[n] - g.tech_level[t]) * 0.10, -0.3, 0.3)
	if lead != 0.0: out.append(["sp_lead", lead])
	out.append(["sp_guard", -guard(g, t)])
	if g.see_until[n * g.N1 + t] > g.turn: out.append(["sp_report", 0.08])                         # a fresh report from their court: you know the doors
	if g.get_rel(n, t) == D.REL_MARRIAGE or g.get_rel(t, n) == D.REL_MARRIAGE: out.append(["sp_kin", 0.10])
	if TBTrade.has(g, n, t): out.append(["sp_merchants", 0.06])                                  # merchants are eyes and ears
	var own := g.owned(t)
	if not own.is_empty():
		var st := 0.0
		for p in own: st += g.stab[p]
		if st / float(own.size()) < 55.0: out.append(["sp_unrest", 0.06])                         # a restless country watches its agents less
	var oc: float = float(OP_COST.get(op, 0.0))
	if oc > 0.0: out.append(["sp_hard", -oc])
	return out

static func chance(g: TBGame, n: int, t: int, op: String) -> float:
	var s := 0.0
	for tm in terms(g, n, t, op): s += float(tm[1])
	return clampf(s, 0.10, 0.90)

## what comes of an operation: returns {"caught": bool, "traced": bool, "cut": [what, ...]}. Failed and caught: the full price. Succeeded but traced: half of it.
## The grudge goes through TBDiplo.hurt, so the target's friends feel it too; infamy is the offender's; ties are cut by chance with the severity of the work.
static func consequences(g: TBGame, n: int, t: int, op: String, ok: bool) -> Dictionary:
	var out := {"caught": false, "traced": false, "cut": []}
	var gd := guard(g, t)
	if not ok: out["caught"] = g.rng.next() < clampf(0.55 + gd * 0.6, 0.0, 0.9)
	else: out["traced"] = op != "steal" and g.rng.next() < 0.10 + gd * 0.5
	if not (bool(out["caught"]) or bool(out["traced"])): return out
	var scale := 1.0 if bool(out["caught"]) else 0.5
	TBDiplo.hurt(g, t, n, int(round(float(GRUDGE[op]) * scale)))
	g.infamy[n] = minf(100.0, g.infamy[n] + float(INFAMY[op]) * scale)
	var sev: int = SEV[op]
	if sev >= 2 and g.rng.next() < (0.5 if sev == 2 else 0.8) * scale:
		var key: int = mini(n, t) * g.N1 + maxi(n, t)
		if g.get_rel(n, t) == D.REL_NAP:
			g.set_rel(n, t, D.REL_PEACE); g.nap_expiry.erase(key); (out["cut"] as Array).append("nap")
		if TBTrade.has(g, n, t):
			TBTrade.set_deal(g, n, t, false); (out["cut"] as Array).append("trade")
		g.see_until[t * g.N1 + n] = 0                                                              # the offender's eyes are shut out
	return out
