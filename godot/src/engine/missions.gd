## Rules 3: two uses for what a realm would otherwise let pile up unused.
## Veteran colony (people): a soldier who is not needed in the ranks goes back to the land. Rome settled discharged legionaries in coloniae on conquered ground, the Habsburgs
## held the Military Frontier with soldier-farmers, Russia planted Cossack hosts, Israel its Nahal settlements: the province gains people and settles down.
## Embassy (envoys): an envoy's work is repair and information. The Congress of Vienna was won by missions that cooled grudges, and every resident ambassador was also the court's
## eyes: the grudge a nation bears against you falls, the ripple warms its friends a little, and the staff's reports add to your intelligence.
class_name TBMissions
extends RefCounted

const SETTLE_MEN := 60          # people taken from the pool
const SETTLE_MP := 1.0
const SETTLE_POP := 30          # people added to the province (half of the settlers remain as farmers, the rest are lost on the road and to the first hard winters)
const SETTLE_STAB := 8
const POP_MAX := 2000

const EMBASSY_DP := 2.0
const EMBASSY_GOLD := 40
const EMBASSY_GRUDGE := 12      # off the grudge the other court holds against you
const EMBASSY_RIPPLE := 6       # befriend() amount: the other court's friends warm up by a share of it
const EMBASSY_INTEL := 5.0
const INTEL_MAX := 20.0

## "" = possible, else an error key (the command and TBCan use it)
static func settle_why(g: TBGame, n: int, p: int) -> String:
	if g.rules < 3: return "rules"
	if p < 0 or p >= g.P or g.owner[p] != n or g.occupier[p] != 0: return "notyours"
	if g.pop[p] >= POP_MAX and g.stab[p] >= 100: return "nothing"
	if g.manpower[n] < float(SETTLE_MEN): return "manpower"
	if g.mp[n] + 0.0001 < SETTLE_MP: return "mp"
	return ""

static func settle(g: TBGame, n: int, p: int) -> Dictionary:
	var why := settle_why(g, n, p)
	if why != "": return {"ok": false, "err": why}
	g.manpower[n] -= float(SETTLE_MEN); g.mp[n] -= SETTLE_MP
	g.pop[p] = mini(POP_MAX, g.pop[p] + SETTLE_POP)
	g.stab[p] = mini(100, g.stab[p] + SETTLE_STAB)
	g.touch(p)
	g.log.append({"turn": g.turn, "kind": "settle", "a": n, "p": p})
	return {"ok": true}

static func embassy_why(g: TBGame, n: int, t: int) -> String:
	if g.rules < 3: return "rules"
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: return "target"
	if g.get_rel(n, t) == TBData.REL_WAR: return "war"
	if g.grudge[t * g.N1 + n] == 0 and g.intel[n] >= INTEL_MAX - 0.5: return "nothing"
	if g.dp[n] + 0.0001 < EMBASSY_DP: return "dp"
	if g.gold[n] < float(EMBASSY_GOLD): return "gold"
	return ""

static func embassy(g: TBGame, n: int, t: int) -> Dictionary:
	var why := embassy_why(g, n, t)
	if why != "": return {"ok": false, "err": why}
	g.dp[n] = maxf(0.0, g.dp[n] - EMBASSY_DP); g.gold[n] -= float(EMBASSY_GOLD)
	var had := int(g.grudge[t * g.N1 + n])
	TBDiplo._add_grudge(g, t, n, -EMBASSY_GRUDGE)
	TBDiplo.befriend(g, n, t, EMBASSY_RIPPLE, false)
	g.intel[n] = minf(INTEL_MAX, g.intel[n] + EMBASSY_INTEL)
	g.log.append({"turn": g.turn, "kind": "embassy", "a": n, "b": t, "n": mini(had, EMBASSY_GRUDGE)})
	return {"ok": true}
