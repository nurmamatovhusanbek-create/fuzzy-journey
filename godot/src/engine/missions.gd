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

## Colonies (rules 4): a new province costs gold that grows with the realm, settlers taken from the people, and two moves; hard ground costs more; a horde pays less gold and fewer settlers
## (it moves its whole camp). Every requirement is listed with its state, so a refused order always says what is missing.
const COLONY_GOLD := 50
const COLONY_GOLD_PER_PROVINCE := 3
const COLONY_MEN := 40
const COLONY_MOVES := 2.0
const COLONY_GARRISON := 4
static var COLONY_TERRAIN_MUL: Array = [1.0, 1.1, 1.3, 1.1, 1.2, 0.9]       # plains, hills, mountain, forest, marsh, steppe
const COLONY_TECH := 2.0                                         # land across the sea ("discoverable") needs this technology

static func colony_cost(g: TBGame, n: int, p: int) -> Dictionary:
	var reg: Dictionary = TBData.REGIMES[g.regime[n]]
	var free: bool = bool(reg["colonyFree"])
	if g.rules < 4: return {"gold": 0 if free else 60 + g.own_count(n) * 2, "men": 0, "moves": 2}
	var tm: float = COLONY_TERRAIN_MUL[clampi(g.terrain[p], 0, COLONY_TERRAIN_MUL.size() - 1)] if p >= 0 and p < g.P else 1.0
	var gold: int = int(ceil(float(COLONY_GOLD + COLONY_GOLD_PER_PROVINCE * g.own_count(n)) * tm * (0.6 if free else 1.0)))
	var men: int = int(round(float(COLONY_MEN) * (0.6 if free else 1.0)))
	return {"gold": gold, "men": men, "moves": int(COLONY_MOVES)}

## does one of n's provinces touch p by land (or by sea with a port)
static func colony_border(g: TBGame, n: int, p: int) -> bool:
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		var q: int = g.nb[i]
		if g.owner[q] == n and (g.nb_sea[i] == 0 or g.bl(q, TBData.B_PORT) > 0): return true
	return false

## every requirement of a colony, in the order the player reads them: [[met, key, vars]] (the texts are i18n keys colony_need_*)
static func colony_needs(g: TBGame, n: int, p: int) -> Array:
	var cost := colony_cost(g, n, p)
	var out: Array = []
	out.append([colony_border(g, n, p), "colony_need_border", {}])
	if g.discoverable[p] != 0: out.append([g.tech_level[n] >= COLONY_TECH, "colony_need_tech", {"t": "%.1f" % COLONY_TECH}])
	out.append([g.gold[n] >= float(cost["gold"]), "colony_need_gold", {"g": int(cost["gold"]), "h": int(g.gold[n])}])
	if int(cost["men"]) > 0: out.append([g.manpower[n] >= float(cost["men"]), "colony_need_men", {"m": int(cost["men"]), "h": int(g.manpower[n])}])
	out.append([g.mp[n] + 0.0001 >= float(cost["moves"]), "colony_need_moves", {"m": int(cost["moves"]), "h": snappedf(g.mp[n], 0.1)}])
	return out

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
	if g.pop[p] >= (POP_MAX if g.rules < 5 else g.pop_cap(p)) and g.stab[p] >= 100: return "nothing"
	if g.manpower[n] < float(SETTLE_MEN): return "manpower"
	if g.mp[n] + 0.0001 < SETTLE_MP: return "mp"
	return ""

static func settle(g: TBGame, n: int, p: int) -> Dictionary:
	var why := settle_why(g, n, p)
	if why != "": return {"ok": false, "err": why}
	g.manpower[n] -= float(SETTLE_MEN); g.mp[n] -= SETTLE_MP
	g.pop[p] = mini(POP_MAX if g.rules < 5 else g.pop_cap(p), g.pop[p] + g.pu(float(SETTLE_POP)))
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
